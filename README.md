# 🦞 Shadow AI — OpenClaw Skills

> Your professional Shadow. Joins meetings, manages your 1000-page PRD, drafts emails, organizes work — all through OpenClaw on WhatsApp/Telegram.

[![OpenClaw](https://img.shields.io/badge/Built%20for-OpenClaw-red)](https://openclaw.ai)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## What Is This?

This repo contains 4 custom **OpenClaw skills** that together form your **Shadow AI** — a professional AI assistant that:

- 🎙️ **Joins every meeting** (Zoom/Meet/Teams) and takes intelligent notes
- 📊 **Understands your entire PRD** and cascades changes across dependent sections
- ✉️ **Drafts emails** from meeting outcomes — never sends without your approval
- ✅ **Organizes your work** into prioritized to-dos with daily morning briefings

Built specifically for the **Magic Bus LMS project** but fully adaptable to any project.

---

## Skills Included

| Skill | Emoji | Description |
|-------|-------|-------------|
| `meeting-agent` | 🎙️ | Joins calls, transcribes, extracts decisions & requirement changes |
| `prd-analyzer` | 📊 | RAG-powered PRD intelligence — finds what needs changing everywhere |
| `email-agent` | ✉️ | Drafts professional emails with mandatory approval before sending |
| `task-manager` | ✅ | Auto to-do lists, daily 9AM briefings, weekly summaries |

---

## How It All Connects

```
Meeting happens
     ↓
🎙️ meeting-agent joins + transcribes
     ↓
     ├──→ 📊 prd-analyzer: finds all impacted PRD sections
     │         └→ proposes changes (needs your approval)
     │
     ├──→ ✅ task-manager: creates action items from meeting
     │         └→ adds to daily 9AM briefing
     │
     └──→ ✉️ email-agent: drafts follow-up emails
               └→ queues for your approval before sending
```

---

## Quick Start

### Step 1: Install OpenClaw
```bash
npm install -g openclaw@latest
openclaw onboard --install-daemon
```

### Step 2: Connect Your Messaging Channel
Choose one — Telegram is easiest:
```bash
# Telegram: create a bot at @BotFather, then:
openclaw channels login telegram
```
Or WhatsApp:
```bash
openclaw channels login whatsapp
```

### Step 3: Install These Skills
```bash
# Create workspace directories
mkdir -p ~/.openclaw/workspace/magicbus/{meetings,prd,prd-changes,tasks,email-drafts,gmail,scripts,vectorstore}

# Copy skills into your OpenClaw workspace
git clone https://github.com/manchuriannnnn/shadow-ai-openclaw.git
cp -r shadow-ai-openclaw/skills/* ~/.openclaw/workspace/skills/
```

### Step 4: Configure API Keys
Add to `~/.openclaw/openclaw.json`:
```json
{
  "agent": {
    "model": "anthropic/claude-opus-4-6"
  },
  "env": {
    "OPENAI_API_KEY": "sk-...",
    "RECALL_API_KEY": "...",
    "ASSEMBLY_AI_API_KEY": "...",
    "GOOGLE_CLIENT_ID": "...",
    "GOOGLE_CLIENT_SECRET": "...",
    "TODOIST_API_TOKEN": "..." 
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
        "message": "Generate and send weekly project summary",
        "skill": "task-manager"
      }
    ]
  }
}
```

### Step 5: Ingest Your PRD
```bash
# Copy your PRD to the workspace
cp /path/to/MagicBus_LMS_PRD.pdf ~/.openclaw/workspace/magicbus/prd/

# Install Python deps
pip3 install langchain langchain-openai chromadb pypdf tiktoken

# Run the ingestion script (one-time)
python3 ~/.openclaw/workspace/magicbus/scripts/ingest_prd.py
# This embeds all 1000 pages into ChromaDB locally
```

### Step 6: Start Your Shadow AI
```bash
openclaw gateway --port 18789
```

Now message your bot on Telegram/WhatsApp:
- `"I have a Magic Bus review call at https://meet.google.com/xyz in 5 mins"`
- `"What are my tasks today?"`
- `"Show pending PRD changes"`
- `"Check my inbox"`

---

## Required API Keys

| Key | Service | Purpose | Free Tier? |
|-----|---------|---------|------------|
| `OPENAI_API_KEY` | OpenAI | GPT-4o for summaries + embeddings | Pay-as-you-go |
| `RECALL_API_KEY` | [Recall.ai](https://recall.ai) | Meeting bot joins calls | Free trial |
| `ASSEMBLY_AI_API_KEY` | [AssemblyAI](https://assemblyai.com) | Transcription | Free tier |
| `GOOGLE_CLIENT_ID/SECRET` | Google Cloud | Gmail read/send | Free |
| `TODOIST_API_TOKEN` | [Todoist](https://todoist.com) | Task sync (optional) | Free tier |

---

## Workspace File Structure

```
~/.openclaw/workspace/magicbus/
├── prd/
│   ├── MagicBus_LMS_PRD.pdf          # Your original PRD
│   └── MagicBus_LMS_PRD_v{n}.md      # Version-controlled updates
├── vectorstore/                       # ChromaDB (auto-created)
├── meetings/                          # Meeting transcripts + notes
├── prd-changes/
│   ├── queue.json                     # Incoming from meeting-agent
│   └── pending-YYYY-MM-DD.json        # Awaiting your approval
├── tasks/
│   ├── pending.json
│   └── completed.json
├── email-drafts/
│   ├── pending/                       # Awaiting your approval
│   └── sent/
├── gmail/
│   └── credentials.json               # Google OAuth
└── scripts/
    └── ingest_prd.py                  # Run once to index PRD
```

---

## Safety Principles

- ⚠️ **PRD changes**: Never auto-applied. Always shown as diff, requires explicit approval.
- ⚠️ **Emails**: Never auto-sent. Always queued for review first.
- ⚠️ **Full audit trail**: Every change cites its source meeting and timestamp.
- ⚠️ **Local-first**: All data stays in `~/.openclaw/workspace/` on your machine.

---

## Adapting to Other Projects

This was built for Magic Bus LMS but works for any project:
1. Replace `magicbus` folder names with your project name
2. Update skill descriptions with your project context
3. Change the Todoist project name in `task-manager`
4. Update email templates in `email-agent` with your client's name

---

## Built With

- [OpenClaw](https://openclaw.ai) — Personal AI assistant gateway
- [Recall.ai](https://recall.ai) — Meeting bot SDK
- [LangChain](https://langchain.com) + [ChromaDB](https://chromadb.com) — RAG engine
- [OpenAI](https://openai.com) — GPT-4o + text-embedding-3-small
- [Gmail API](https://developers.google.com/gmail/api) — Email integration

---

*Shadow AI — built by manchuriannnnn*
