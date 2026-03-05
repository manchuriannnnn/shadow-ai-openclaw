#!/usr/bin/env python3
"""
Shadow AI — PRD RAG Ingestion Script
=====================================
Ingest your Magic Bus LMS PRD (PDF or Markdown) into a local
ChromaDB vector store for semantic search and dependency analysis.

Run once after setup:
    python3 ingest_prd.py

Re-run whenever the PRD source document is updated.

Requirements:
    pip3 install langchain langchain-openai langchain-community chromadb pypdf tiktoken
"""

import os
import sys
import json
import hashlib
from pathlib import Path
from datetime import datetime

# ---- Config ------------------------------------------------------------------

HOME = Path.home()
WORKSPACE = HOME / ".openclaw" / "workspace" / "magicbus"
PRD_DIR = WORKSPACE / "prd"
VECTOR_DIR = WORKSPACE / "vectorstore"
SCRIPTS_DIR = WORKSPACE / "scripts"
META_FILE = VECTOR_DIR / "ingest_meta.json"

# Chunk settings — tuned for large technical PRD documents
CHUNK_SIZE = 1500       # characters per chunk
CHUNK_OVERLAP = 200    # overlap between chunks
EMBEDDING_MODEL = "text-embedding-3-small"  # OpenAI embeddings

# ---- Helpers -----------------------------------------------------------------

def print_step(msg):
    print(f"\n\033[34m==>\033[0m \033[32m{msg}\033[0m")

def print_done(msg):
    print(f"\033[32m✅ {msg}\033[0m")

def print_warn(msg):
    print(f"\033[33m⚠️  {msg}\033[0m")

def print_error(msg):
    print(f"\033[31m❌ {msg}\033[0m")

def get_file_hash(filepath):
    """SHA256 hash to detect if PRD has changed since last ingest."""
    h = hashlib.sha256()
    with open(filepath, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            h.update(chunk)
    return h.hexdigest()

def load_meta():
    if META_FILE.exists():
        with open(META_FILE) as f:
            return json.load(f)
    return {}

def save_meta(meta):
    VECTOR_DIR.mkdir(parents=True, exist_ok=True)
    with open(META_FILE, "w") as f:
        json.dump(meta, f, indent=2)

# ---- Main ingestion ----------------------------------------------------------

def ingest():
    print("\n\033[34m🦞 Shadow AI — PRD Ingestion\033[0m")
    print("=" * 45)

    # Check OpenAI key
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        # Try reading from openclaw.json
        openclaw_config = HOME / ".openclaw" / "openclaw.json"
        if openclaw_config.exists():
            with open(openclaw_config) as f:
                config = json.load(f)
            api_key = config.get("env", {}).get("OPENAI_API_KEY", "")
        if not api_key or api_key.startswith("REPLACE"):
            print_error("OPENAI_API_KEY not set. Add it to ~/.openclaw/openclaw.json")
            sys.exit(1)
    os.environ["OPENAI_API_KEY"] = api_key

    # Find PRD files
    prd_files = list(PRD_DIR.glob("*.pdf")) + \
                list(PRD_DIR.glob("*.md")) + \
                list(PRD_DIR.glob("*.txt"))

    if not prd_files:
        print_error(f"No PRD files found in {PRD_DIR}")
        print(f"  → Add your PRD: cp /path/to/MagicBus_LMS_PRD.pdf {PRD_DIR}/")
        sys.exit(1)

    print_step(f"Found {len(prd_files)} PRD file(s):")
    for f in prd_files:
        size_mb = f.stat().st_size / (1024 * 1024)
        print(f"  📄 {f.name} ({size_mb:.1f} MB)")

    # Check if already ingested and unchanged
    meta = load_meta()
    all_hashes = {str(f): get_file_hash(f) for f in prd_files}
    if meta.get("hashes") == all_hashes:
        print_warn("PRD files unchanged since last ingest. Use --force to re-ingest.")
        if "--force" not in sys.argv:
            print(f"  Vector store at: {VECTOR_DIR}")
            print(f"  Chunks stored: {meta.get('chunk_count', 'unknown')}")
            return

    # Import langchain components
    try:
        from langchain_community.document_loaders import PyPDFLoader, TextLoader
        from langchain.text_splitter import RecursiveCharacterTextSplitter
        from langchain_openai import OpenAIEmbeddings
        from langchain_community.vectorstores import Chroma
    except ImportError as e:
        print_error(f"Missing dependency: {e}")
        print("  Run: pip3 install langchain langchain-openai langchain-community chromadb pypdf tiktoken")
        sys.exit(1)

    # Load documents
    print_step("Loading and parsing PRD documents...")
    all_docs = []
    for prd_file in prd_files:
        print(f"  Loading {prd_file.name}...")
        if prd_file.suffix.lower() == ".pdf":
            loader = PyPDFLoader(str(prd_file))
        else:
            loader = TextLoader(str(prd_file), encoding="utf-8")
        docs = loader.load()
        # Tag each chunk with source file metadata
        for doc in docs:
            doc.metadata["source_file"] = prd_file.name
            doc.metadata["project"] = "MagicBus-LMS"
        all_docs.extend(docs)
        print_done(f"  Loaded {len(docs)} pages from {prd_file.name}")

    print_done(f"Total pages loaded: {len(all_docs)}")

    # Split into chunks
    print_step("Chunking documents for RAG...")
    splitter = RecursiveCharacterTextSplitter(
        chunk_size=CHUNK_SIZE,
        chunk_overlap=CHUNK_OVERLAP,
        separators=["\n## ", "\n### ", "\n#### ", "\n\n", "\n", ". ", " "],
        length_function=len,
    )
    chunks = splitter.split_documents(all_docs)
    print_done(f"Created {len(chunks)} chunks (avg {CHUNK_SIZE} chars each)")

    # Create embeddings and store in ChromaDB
    print_step(f"Creating embeddings with {EMBEDDING_MODEL} and storing in ChromaDB...")
    print("  This may take a few minutes for large documents...")
    VECTOR_DIR.mkdir(parents=True, exist_ok=True)

    embeddings = OpenAIEmbeddings(
        model=EMBEDDING_MODEL,
        openai_api_key=api_key
    )

    # Build vector store in batches to avoid rate limits
    BATCH_SIZE = 100
    vectorstore = None
    for i in range(0, len(chunks), BATCH_SIZE):
        batch = chunks[i:i + BATCH_SIZE]
        batch_num = i // BATCH_SIZE + 1
        total_batches = (len(chunks) + BATCH_SIZE - 1) // BATCH_SIZE
        print(f"  Processing batch {batch_num}/{total_batches} ({len(batch)} chunks)...", end="", flush=True)
        if vectorstore is None:
            vectorstore = Chroma.from_documents(
                batch,
                embeddings,
                persist_directory=str(VECTOR_DIR)
            )
        else:
            vectorstore.add_documents(batch)
        print(" ✓")

    print_done(f"Vector store saved to {VECTOR_DIR}")

    # Save metadata
    meta = {
        "ingested_at": datetime.now().isoformat(),
        "chunk_count": len(chunks),
        "page_count": len(all_docs),
        "files": [str(f.name) for f in prd_files],
        "hashes": all_hashes,
        "embedding_model": EMBEDDING_MODEL,
        "chunk_size": CHUNK_SIZE,
        "chunk_overlap": CHUNK_OVERLAP,
    }
    save_meta(meta)

    # Quick verification test
    print_step("Verification — running a test query...")
    test_results = vectorstore.similarity_search("user authentication login", k=3)
    if test_results:
        print_done(f"Test query returned {len(test_results)} results ✔")
        print(f"  Sample: ...{test_results[0].page_content[:120].strip()}...")
    else:
        print_warn("Test query returned no results. PRD may not contain auth-related content.")

    print("")
    print("\033[32m" + "=" * 45 + "\033[0m")
    print("\033[32m🦞 PRD Ingestion Complete!\033[0m")
    print("\033[32m" + "=" * 45 + "\033[0m")
    print(f"")
    print(f"  📊 {len(chunks)} chunks from {len(all_docs)} pages")
    print(f"  🗂️  Stored at: {VECTOR_DIR}")
    print(f"  ⏱️  Ingested at: {meta['ingested_at']}")
    print(f"")
    print("  Your PRD is now ready for Shadow AI analysis!")
    print("  Start OpenClaw and say: 'analyze prd changes from today\'s meeting'")
    print("")


if __name__ == "__main__":
    ingest()
