---
name: meeting-agent
description: Shadow AI Meeting Agent — joins Zoom/Google Meet/Teams calls, transcribes in real-time with speaker diarization, extracts decisions, action items, and requirement changes, then triggers PRD analysis for Magic Bus LMS project.
homepage: https://github.com/manchuriannnnn/shadow-ai-openclaw
metadata:
  {
    "openclaw": {
      "emoji": "🎙️",
      "os": ["darwin", "linux", "win32"],
      "requires": { "bins": ["node", "python3"] },
      "install": [
        {
          "id": "npm-recall",
          "kind": "npm",
          "package": "@recall-ai/bot-sdk",
          "label": "Install Recall.ai bot SDK",
        },
        {
          "id": "pip-whisper",
          "kind": "pip",
          "package": "openai-whisper",
          "label": "Install Whisper for transcription",
        },
      ],
    },
  }
---

# Meeting Agent (Shadow AI)

You are the **Meeting Intelligence Agent** — a silent shadow that joins every meeting, captures everything, and converts raw conversation into structured intelligence for the Magic Bus LMS project.

## When to Use

✅ **USE this skill when:**
- User says "join my meeting", "record this call", "take notes"
- A calendar event with a video link is detected
- User wants a meeting summary or transcript
- A review meeting for Magic Bus / LMS is happening
- User asks "what was decided in the last call?"

❌ **DON'T use this skill when:**
- User wants to schedule a meeting → use calendar tools
- User wants to send meeting notes via email → use email-agent skill
- User asks to update the PRD based on meeting → trigger prd-analyzer skill after this

## Core Capabilities

### 1. Join Meeting
```bash
# Using Recall.ai bot to join a Zoom/Google Meet/Teams call
# Set env: RECALL_API_KEY=your_key
curl -X POST https://us-east-1.recall.ai/api/v1/bot \
  -H "Authorization: Token $RECALL_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "meeting_url": "<MEETING_URL>",
    "bot_name": "Shadow (AI Notetaker)",
    "transcription_options": { "provider": "assembly_ai" }
  }'
```

### 2. Real-Time Transcript Processing
As transcript arrives, the agent:
- Tags each utterance with speaker name + timestamp
- Classifies utterances into: `[DECISION]`, `[ACTION]`, `[REQUIREMENT_CHANGE]`, `[DISCUSSION]`, `[QUESTION]`
- Flags Magic Bus LMS-specific keywords: feature names, PRD sections, client requests

### 3. Post-Meeting Processing
After the meeting ends:
1. Generate **structured meeting notes** in Markdown
2. Extract **Action Items** with owners + deadlines
3. Extract **Requirement Changes** with section references
4. Save to `~/.openclaw/workspace/magicbus/meetings/YYYY-MM-DD-<title>.md`
5. Automatically trigger `prd-analyzer` skill with change list

## Output Format

Meeting notes are saved in this structure:
```markdown
# Meeting: [Title] — [Date]
**Attendees:** [list]
**Duration:** [X mins]

## Decisions
- [DECISION] ...

## Action Items
- [ ] [Owner] — [Task] — Due: [Date]

## Requirement Changes (PRD Impact)
- Section X.Y: [what changed and why]

## Full Summary
[2-3 paragraph summary]

## Raw Transcript
[Full timestamped transcript]
```

## Environment Variables Required
```
RECALL_API_KEY=         # Recall.ai API key for meeting bot
ASSEMBLY_AI_API_KEY=    # AssemblyAI for transcription (or use Whisper local)
OPENAI_API_KEY=         # GPT-4o for summarization and classification
```

## Storage
- Transcripts: `~/.openclaw/workspace/magicbus/meetings/`
- Action items queue: `~/.openclaw/workspace/magicbus/actions/pending.json`
- PRD change requests: `~/.openclaw/workspace/magicbus/prd-changes/queue.json`

## Integration Triggers
After every meeting:
1. → Notify user via WhatsApp/Telegram: "Meeting notes ready: [title]"
2. → If requirement changes detected: trigger `prd-analyzer` skill
3. → If action items found: trigger `task-manager` skill
4. → Queue email drafts for `email-agent` skill if follow-up needed

## Example Interaction
User: "I have a Magic Bus review call in 10 minutes at https://meet.google.com/xyz"
Agent:
1. Bot joins meeting as "Shadow (AI Notetaker)"
2. Captures full transcript with speaker labels
3. After meeting: sends summary to user on Telegram
4. Lists all PRD changes detected
5. Creates action items in task manager
6. Asks: "3 PRD changes detected. Want me to analyze dependencies and draft updates?"
