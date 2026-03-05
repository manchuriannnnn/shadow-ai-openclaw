#!/usr/bin/env bash
# =============================================================================
# Shadow AI — OpenClaw Setup Script
# One-click installer for all Shadow AI skills and dependencies
# Run: bash setup.sh
# =============================================================================

set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
echo "  🦞 Shadow AI — OpenClaw Setup"
echo "  =============================="
echo -e "${NC}"

# ---- Helper functions --------------------------------------------------------

check_command() {
  if ! command -v "$1" &>/dev/null; then
    echo -e "${RED}❌ $1 is not installed. Please install it first.${NC}"
    exit 1
  fi
}

print_step() {
  echo -e "\n${BLUE}==>${NC} ${GREEN}$1${NC}"
}

print_warn() {
  echo -e "${YELLOW}⚠️  $1${NC}"
}

print_done() {
  echo -e "${GREEN}✅ $1${NC}"
}

# ---- Check prerequisites ------------------------------------------------------

print_step "Checking prerequisites..."
check_command node
check_command npm
check_command python3
check_command pip3
check_command git

NODE_VERSION=$(node -v | cut -d. -f1 | tr -d 'v')
if [ "$NODE_VERSION" -lt 22 ]; then
  echo -e "${RED}❌ Node.js v22+ required. You have $(node -v). Please upgrade.${NC}"
  echo "  Install via: https://nodejs.org or use nvm: nvm install 22"
  exit 1
fi
print_done "Node.js $(node -v) ✓"
print_done "Python $(python3 --version) ✓"

# ---- Install OpenClaw ---------------------------------------------------------

print_step "Installing OpenClaw globally..."
if command -v openclaw &>/dev/null; then
  print_warn "OpenClaw already installed: $(openclaw --version 2>/dev/null || echo 'version unknown')"
  print_warn "Upgrading to latest..."
fi
npm install -g openclaw@latest
print_done "OpenClaw installed: $(openclaw --version 2>/dev/null || echo 'OK')"

# ---- Create workspace directories --------------------------------------------

print_step "Creating workspace directories..."

WORKSPACE="$HOME/.openclaw/workspace/magicbus"

mkdir -p "$WORKSPACE/prd"
mkdir -p "$WORKSPACE/meetings"
mkdir -p "$WORKSPACE/vectorstore"
mkdir -p "$WORKSPACE/prd-changes/approved"
mkdir -p "$WORKSPACE/tasks/briefings"
mkdir -p "$WORKSPACE/email-drafts/pending"
mkdir -p "$WORKSPACE/email-drafts/sent"
mkdir -p "$WORKSPACE/email-drafts/discarded"
mkdir -p "$WORKSPACE/gmail"
mkdir -p "$WORKSPACE/scripts"
mkdir -p "$WORKSPACE/actions"

print_done "Workspace created at $WORKSPACE"

# ---- Install Shadow AI skills ------------------------------------------------

print_step "Installing Shadow AI skills into OpenClaw workspace..."

SKILLS_DIR="$HOME/.openclaw/workspace/skills"
mkdir -p "$SKILLS_DIR"

# Clone or update this repo
REPO_DIR="/tmp/shadow-ai-openclaw"
if [ -d "$REPO_DIR" ]; then
  print_warn "Updating existing repo clone..."
  git -C "$REPO_DIR" pull
else
  git clone https://github.com/manchuriannnnn/shadow-ai-openclaw.git "$REPO_DIR"
fi

# Copy skills
cp -r "$REPO_DIR/skills/"* "$SKILLS_DIR/"
print_done "Skills installed:"
ls "$SKILLS_DIR"

# Copy scripts
cp "$REPO_DIR/scripts/ingest_prd.py" "$WORKSPACE/scripts/" 2>/dev/null || true
cp "$REPO_DIR/scripts/gmail_auth.js" "$WORKSPACE/scripts/" 2>/dev/null || true

# ---- Install Python dependencies for PRD RAG ---------------------------------

print_step "Installing Python dependencies (LangChain + ChromaDB for PRD RAG)..."
pip3 install --quiet langchain langchain-openai langchain-community chromadb pypdf tiktoken
print_done "Python dependencies installed"

# ---- Install Node dependencies for Gmail ------------------------------------

print_step "Installing Node.js dependencies for Gmail integration..."
cd "$WORKSPACE/scripts" 2>/dev/null || true
npm install --save googleapis 2>/dev/null || npm install -g googleapis
print_done "Gmail SDK installed"

# ---- Create config template if not exists -----------------------------------

print_step "Setting up OpenClaw config..."

CONFIG_FILE="$HOME/.openclaw/openclaw.json"

if [ -f "$CONFIG_FILE" ]; then
  print_warn "Config already exists at $CONFIG_FILE — skipping (backup at $CONFIG_FILE.bak)"
  cp "$CONFIG_FILE" "$CONFIG_FILE.bak"
else
  cp "$REPO_DIR/openclaw.template.json" "$CONFIG_FILE" 2>/dev/null || cat > "$CONFIG_FILE" << 'JSONEOF'
{
  "agent": {
    "model": "anthropic/claude-opus-4-6"
  },
  "agents": {
    "defaults": {
      "workspace": "~/.openclaw/workspace"
    }
  },
  "env": {
    "OPENAI_API_KEY": "REPLACE_WITH_YOUR_OPENAI_KEY",
    "RECALL_API_KEY": "REPLACE_WITH_YOUR_RECALL_KEY",
    "ASSEMBLY_AI_API_KEY": "REPLACE_WITH_YOUR_ASSEMBLYAI_KEY",
    "GOOGLE_CLIENT_ID": "REPLACE_WITH_YOUR_GOOGLE_CLIENT_ID",
    "GOOGLE_CLIENT_SECRET": "REPLACE_WITH_YOUR_GOOGLE_CLIENT_SECRET",
    "TODOIST_API_TOKEN": "REPLACE_WITH_YOUR_TODOIST_TOKEN_OPTIONAL"
  },
  "cron": {
    "jobs": [
      {
        "id": "morning-briefing",
        "schedule": "0 9 * * *",
        "timezone": "Asia/Kolkata",
        "message": "Generate and send morning briefing for Magic Bus project",
        "skill": "task-manager"
      },
      {
        "id": "weekly-summary",
        "schedule": "0 17 * * 5",
        "timezone": "Asia/Kolkata",
        "message": "Generate and send weekly project summary for Magic Bus",
        "skill": "task-manager"
      }
    ]
  }
}
JSONEOF
  print_done "Config created at $CONFIG_FILE"
fi

# ---- Initialize task and PRD change queue files -----------------------------

print_step "Initializing data files..."

[ -f "$WORKSPACE/tasks/pending.json" ] || echo '[]' > "$WORKSPACE/tasks/pending.json"
[ -f "$WORKSPACE/tasks/completed.json" ] || echo '[]' > "$WORKSPACE/tasks/completed.json"
[ -f "$WORKSPACE/prd-changes/queue.json" ] || echo '[]' > "$WORKSPACE/prd-changes/queue.json"
[ -f "$WORKSPACE/actions/pending.json" ] || echo '[]' > "$WORKSPACE/actions/pending.json"

print_done "Data files initialized"

# ---- Summary ---------------------------------------------------------------

echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  🦞 Shadow AI Setup Complete!${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo ""
echo "  1. Edit your config and add API keys:"
echo "     nano ~/.openclaw/openclaw.json"
echo ""
echo "  2. Connect your messaging channel (choose one):"
echo "     openclaw channels login telegram"
echo "     openclaw channels login whatsapp"
echo ""
echo "  3. Add your PRD document:"
echo "     cp /path/to/MagicBus_LMS_PRD.pdf ~/.openclaw/workspace/magicbus/prd/"
echo ""
echo "  4. Index your PRD (run once, takes ~5 mins for 1000 pages):"
echo "     python3 ~/.openclaw/workspace/magicbus/scripts/ingest_prd.py"
echo ""
echo "  5. Set up Gmail OAuth:"
echo "     node ~/.openclaw/workspace/magicbus/scripts/gmail_auth.js"
echo ""
echo "  6. Start your Shadow AI:"
echo "     openclaw gateway --port 18789"
echo ""
echo "  7. Message your bot: 'I have a Magic Bus review call in 5 mins at [URL]'"
echo ""
echo -e "  📚 Full docs: https://github.com/manchuriannnnn/shadow-ai-openclaw"
echo ""
