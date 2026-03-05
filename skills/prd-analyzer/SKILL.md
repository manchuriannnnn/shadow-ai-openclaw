---
name: prd-analyzer
description: Shadow AI PRD Dependency Analyzer — ingests your 1000-page Magic Bus LMS PRD into a RAG knowledge base, detects requirement changes from meeting notes, performs cross-document impact analysis, and proposes consistent updates across all dependent sections.
homepage: https://github.com/manchuriannnnn/shadow-ai-openclaw
metadata:
  {
    "openclaw": {
      "emoji": "📊",
      "os": ["darwin", "linux", "win32"],
      "requires": { "bins": ["python3", "node"] },
      "install": [
        {
          "id": "pip-langchain",
          "kind": "pip",
          "package": "langchain langchain-openai chromadb pypdf tiktoken",
          "label": "Install LangChain + ChromaDB for RAG",
        },
      ],
    },
  }
---

# PRD Dependency Analyzer (Shadow AI)

You are the **PRD Intelligence Engine** — the brain that understands every inch of the 1000-page Magic Bus LMS Product Requirements Document. You know how every feature, section, and requirement connects to every other, so when one thing changes, you find everything else that must change too.

## When to Use

✅ **USE this skill when:**
- Meeting notes contain requirement changes flagged by `meeting-agent`
- User says "update the PRD", "reflect the changes from today's meeting"
- User asks "what sections are affected if we change X?"
- User says "check for inconsistencies in the PRD"
- A change request is queued in `~/.openclaw/workspace/magicbus/prd-changes/queue.json`

❌ **DON'T use this skill when:**
- User wants to read a specific PRD section → just use `read` tool directly
- User wants to create a brand new PRD → use a document creation workflow
- User wants to send PRD to client → use `email-agent` skill

## Setup: Ingest PRD into RAG Knowledge Base

First-time setup to index your 1000-page PRD:

```python
# ~/.openclaw/workspace/magicbus/scripts/ingest_prd.py
from langchain_community.document_loaders import PyPDFLoader
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain_openai import OpenAIEmbeddings
from langchain_community.vectorstores import Chroma

# Load your PRD
loader = PyPDFLoader("~/.openclaw/workspace/magicbus/prd/MagicBus_LMS_PRD.pdf")
docs = loader.load()

# Chunk intelligently by section headers
splitter = RecursiveCharacterTextSplitter(
    chunk_size=1500,
    chunk_overlap=200,
    separators=["\n## ", "\n### ", "\n#### ", "\n", " "]
)
chunks = splitter.split_documents(docs)

# Embed and store locally
embeddings = OpenAIEmbeddings(model="text-embedding-3-small")
vectorstore = Chroma.from_documents(
    chunks,
    embeddings,
    persist_directory="~/.openclaw/workspace/magicbus/vectorstore"
)
print(f"Ingested {len(chunks)} chunks from PRD into ChromaDB")
```

Run once: `python3 ~/.openclaw/workspace/magicbus/scripts/ingest_prd.py`

## Core Workflow

### Step 1: Receive Change Request
Input from `meeting-agent` (or user directly):
```json
{
  "source_meeting": "2026-03-05-magic-bus-review.md",
  "changes": [
    {
      "description": "Quiz retry limit changed from 3 to unlimited",
      "keywords": ["quiz", "retry", "attempt limit", "assessment"]
    }
  ]
}
```

### Step 2: RAG Dependency Search
```python
# Query vectorstore for all related sections
results = vectorstore.similarity_search(
    "quiz retry limit attempt assessment",
    k=20  # Get top 20 related chunks
)
# Returns: section names, page numbers, related content
```

### Step 3: Impact Analysis
For each change, the agent:
1. Finds all directly related sections (same feature)
2. Finds all indirectly related sections (dependent features)
3. Checks for contradictions with existing requirements
4. Identifies UI/UX sections that reference this behavior
5. Identifies test cases that need updating
6. Identifies API specs that need updating

### Step 4: Generate Update Proposals
For each affected section, generate a diff-style proposal:
```markdown
## Proposed Change: Section 4.3.2 — Quiz Configuration
**Reason:** Meeting 2026-03-05: Client requested unlimited retries
**Current text:** "Users may attempt a quiz a maximum of 3 times..."
**Proposed text:** "Users may attempt a quiz unlimited times..."
**Confidence:** HIGH
**Related sections also needing update:** 4.3.5, 7.2.1, 9.4, 12.1.3
```

### Step 5: Queue for Approval
All proposals saved to:
`~/.openclaw/workspace/magicbus/prd-changes/pending-YYYY-MM-DD.json`

User is notified: "📊 PRD Analysis complete. Found 8 sections affected by today's 3 changes. Review here: [link]"

## Commands

User can interact via chat:
- `"analyze prd changes from today's meeting"` → processes latest meeting notes
- `"what sections mention user roles?"` → RAG search query
- `"show pending prd changes"` → lists all queued proposals
- `"approve change #3"` → applies the approved change to the PRD
- `"reject change #5"` → discards the proposal
- `"apply all approved changes"` → writes all approved changes to PRD document

## Storage Structure
```
~/.openclaw/workspace/magicbus/
├── prd/
│   ├── MagicBus_LMS_PRD.pdf          # Original PRD
│   └── MagicBus_LMS_PRD_v{n}.md      # Version-controlled Markdown
├── vectorstore/                       # ChromaDB embeddings
├── prd-changes/
│   ├── queue.json                     # Incoming change requests
│   ├── pending-YYYY-MM-DD.json        # Proposals awaiting approval
│   └── approved/                      # Applied changes history
└── scripts/
    └── ingest_prd.py                  # PRD ingestion script
```

## Environment Variables
```
OPENAI_API_KEY=    # For embeddings (text-embedding-3-small) + GPT-4o analysis
```

## Safety Rules
- **NEVER** auto-apply PRD changes without explicit user approval
- Always show a diff (before/after) for every proposed change
- Always cite the meeting source that triggered the change
- Maintain a full audit trail of all changes with timestamps
- Re-run impact analysis if user modifies a proposal before approving
