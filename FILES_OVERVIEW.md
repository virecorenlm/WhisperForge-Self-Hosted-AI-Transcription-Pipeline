# WhisperForge Files Overview

This document explains what each file does and where it should be deployed.

---

## 🏠 Root Directory Files

### Configuration & Setup

**`.env`**
- Supabase database credentials
- **Location:** All machines that run Node.js scripts
- **Never commit to git** (add to `.gitignore`)

**`package.json`**
- Node.js project configuration and dependencies
- **Location:** Orchestration server (HP Pavilion)

**`.gitignore`**
- Prevents committing sensitive files (`.env`, `node_modules`, etc.)
- **Location:** Git repository root

---

## 📚 Documentation Files

**`README.md`**
- Main project documentation
- Quick start guide and overview
- **Audience:** Anyone using WhisperForge

**`DEPLOYMENT_GUIDE.md`**
- Step-by-step deployment instructions
- Detailed configuration for each machine
- **Audience:** System administrators, first-time setup

**`FILES_OVERVIEW.md`** (this file)
- Explains what each file does
- **Audience:** Developers, troubleshooters

---

## 🔧 Setup Scripts

### `quickstart.sh`
**Purpose:** Automated first-time setup wizard
**Runs on:** HP Pavilion (orchestration server)
**What it does:**
- Verifies dependencies (Node.js, Python, etc.)
- Sets up `.env` file with Supabase credentials
- Installs npm packages
- Tests database connection
- Provides next steps

**Usage:**
```bash
chmod +x quickstart.sh
./quickstart.sh
```

### `check-system.sh`
**Purpose:** System requirements validation
**Runs on:** Any machine
**What it does:**
- Checks RAM, disk space, OS version
- Verifies required software is installed
- Validates directory structure
- Tests network connectivity
- Color-coded output (green=good, yellow=warning, red=error)

**Usage:**
```bash
chmod +x check-system.sh
./check-system.sh
```

---

## 🗄️ Database Scripts (Node.js)

### `db-tracker.js`
**Purpose:** Database operations and job tracking
**Runs on:** HP Pavilion (orchestration server)
**Dependencies:** `@supabase/supabase-js`, `dotenv`

**Functions:**
- `createJob(filename, filepath)` - Register new transcription job
- `updateJobStatus(jobId, status)` - Update job progress
- `saveTranscript(jobId, rawText, refinedText)` - Store results
- `createTranslation(transcriptId, sourceLang, targetLang)` - Track translations
- `getJobStats()` - Get pipeline statistics
- `getPendingJobs()` - List jobs waiting for processing

**CLI Usage:**
```bash
node db-tracker.js stats
node db-tracker.js create-job "meeting.mp3" "/path/to/file"
node db-tracker.js update-status <job-id> processing
node db-tracker.js save-transcript <job-id> /path/to/transcript.txt
node db-tracker.js pending
```

**Import as Module:**
```javascript
const tracker = require('./db-tracker');
const job = await tracker.createJob('test.mp3', '/tmp/test.mp3');
```

### `dashboard.js`
**Purpose:** Real-time monitoring interface
**Runs on:** HP Pavilion (orchestration server)
**Dependencies:** Same as `db-tracker.js`

**Features:**
- Live job statistics (total, pending, processing, completed, failed)
- Storage usage breakdown by directory
- Recent jobs list with status icons
- Auto-refreshes every 5 seconds

**Usage:**
```bash
# Live monitoring
node dashboard.js

# One-time snapshot
node dashboard.js --once

# Or use npm script
npm run dashboard
```

---

## 🐍 Python Processing Scripts

### `whisper_batch.py`
**Purpose:** Audio/video transcription using OpenAI Whisper
**Runs on:** HP M01-F3003W (compute server)
**Dependencies:** `openai-whisper`, `torch`, `ffmpeg`

**Features:**
- Batch transcription with intelligent prompting
- Multiple model size support (tiny, small, medium, large)
- Word-level timestamps
- JSON output with full metadata
- Business terminology optimization

**Model Recommendations:**
- `small.en` - Fast, good for testing (2GB RAM)
- `medium.en` - **Production recommended** (5GB RAM)
- `large` - Best quality (10GB RAM)

**Usage:**
```bash
# Basic transcription
python3 whisper_batch.py input.mp3 output.txt

# Specify model
python3 whisper_batch.py input.mp3 output.txt medium.en

# With timestamps
python3 whisper_batch.py input.mp3 output.txt medium.en --timestamps
```

**Output Files:**
- `output.txt` - Clean transcript text
- `output.json` - Full results with segments and timestamps
- `output_timestamped.txt` - Human-readable timestamps (if `--timestamps` used)

### `llm_refine.py`
**Purpose:** Enhance transcripts using local LLM (Ollama)
**Runs on:** HP M01-F3003W (compute server)
**Dependencies:** `ollama` (command-line tool)

**Modes:**
1. **refine** (default) - Fix grammar, remove fillers, add paragraphs
2. **summarize** - Extract key points, decisions, action items
3. **diarize** - Add speaker labels (experimental)

**Recommended Model:**
- `mistral:7b-instruct` - Best balance of quality and speed

**Usage:**
```bash
# Refine transcript
python3 llm_refine.py raw.txt refined.txt

# Generate summary
python3 llm_refine.py raw.txt summary.txt summarize

# Add speaker labels
python3 llm_refine.py raw.txt labeled.txt diarize

# Use different model
python3 llm_refine.py raw.txt refined.txt refine llama3.1:8b

# Batch process directory
python3 llm_refine.py --batch /path/to/transcripts/ /path/to/output/
```

**Output Files:**
- Refined/processed text file
- `.meta.json` - Processing metadata (mode, model, word counts)

---

## 🔄 Workflow Configuration

### `n8n-workflow-template.json`
**Purpose:** Pre-configured n8n automation workflow
**Import into:** n8n web interface (http://pavilion-ip:5678)

**Workflow Steps:**
1. **File Trigger** - Watches `/mnt/whisperforge/intake/`
2. **Create DB Job** - Registers job in database
3. **Move File** - To processing directory
4. **SSH: Whisper** - Run transcription on LLM machine
5. **Update Status** - Mark as processing
6. **SSH: LLM Refine** - Enhance transcript
7. **Save to DB** - Store results
8. **Mark Complete** - Update job status
9. **Archive** - Move original to archive

**Configuration Required:**
- SSH credentials for LLM machine
- Absolute paths to scripts
- IP address of compute server

**Import Steps:**
1. Open n8n UI
2. Click "Workflows" → "Import from File"
3. Select `n8n-workflow-template.json`
4. Update SSH credentials
5. Activate workflow (toggle to green)

---

## 📋 Bash Helper Scripts

### `create_translation_project.sh`
**Purpose:** Initialize OmegaT translation project
**Location:** Create in `~/scripts/` on any machine with OmegaT

**Usage:**
```bash
bash create_translation_project.sh meeting_transcript en es
# Creates project in /mnt/whisperforge/omegat-projects/meeting_transcript_es/
```

**Parameters:**
1. Transcript filename (without extension)
2. Source language code (default: en)
3. Target language code (default: es)

### `sync_to_anythingllm.sh`
**Purpose:** Sync refined transcripts to AnythingLLM
**Location:** Create in `~/scripts/` on machine running AnythingLLM
**Schedule:** Add to crontab for automatic syncing

**Usage:**
```bash
bash sync_to_anythingllm.sh
```

**Cron Setup:**
```bash
# Edit crontab
crontab -e

# Add line to sync every 5 minutes
*/5 * * * * ~/scripts/sync_to_anythingllm.sh
```

---

## 📂 Directory Structure Reference

### Expected on All Machines (via NFS):

```
/mnt/whisperforge/
├── intake/              # Drop new files here
├── processing/          # Files being actively processed
├── transcripts/         # Raw Whisper output (.txt and .json)
├── refined/             # LLM-enhanced versions
├── archive/             # Completed original files
└── omegat-projects/     # Translation projects
```

### On HP Pavilion (Orchestration):

```
~/whisperforge/          # This project
├── .env
├── package.json
├── node_modules/
├── db-tracker.js
├── dashboard.js
├── quickstart.sh
├── check-system.sh
├── n8n-workflow-template.json
└── README.md
```

### On HP M01-F3003W (Compute):

```
~/scripts/
├── whisper_batch.py
└── llm_refine.py

~/whisper-env/           # Python virtual environment (optional)
```

---

## 🔄 Typical Workflow Execution

### Automatic Processing (via n8n):

```
1. User drops "meeting.mp4" in /mnt/whisperforge/intake/
2. n8n detects new file
3. db-tracker.js creates job in database
4. File moved to /processing/
5. SSH to compute: whisper_batch.py transcribes
6. Output: /transcripts/meeting.txt + meeting.json
7. SSH to compute: llm_refine.py enhances
8. Output: /refined/meeting.txt
9. db-tracker.js saves transcript to database
10. Original moved to /archive/
11. User queries via AnythingLLM
```

### Manual Processing:

```bash
# On compute server (HP M01-F3003W)
cd /mnt/whisperforge

# Transcribe
python3 ~/scripts/whisper_batch.py \
  intake/podcast_ep5.mp3 \
  transcripts/podcast_ep5.txt

# Refine
python3 ~/scripts/llm_refine.py \
  transcripts/podcast_ep5.txt \
  refined/podcast_ep5.txt

# On orchestration server (HP Pavilion)
# Track manually if needed
node db-tracker.js create-job "podcast_ep5.mp3" "/mnt/whisperforge/intake/podcast_ep5.mp3"
```

---

## 🛠️ Troubleshooting Guide

### Issue: "Module not found" errors

**File affected:** `db-tracker.js`, `dashboard.js`
**Solution:**
```bash
cd ~/whisperforge
npm install
```

### Issue: Python script fails with ImportError

**Files affected:** `whisper_batch.py`, `llm_refine.py`
**Solution:**
```bash
# On compute server
pip install openai-whisper torch
curl -fsSL https://ollama.com/install.sh | sh
```

### Issue: n8n can't execute scripts

**File affected:** `n8n-workflow-template.json`
**Solution:**
1. Check SSH key is set up: `ssh user@compute-server "echo success"`
2. Verify absolute paths in workflow nodes
3. Ensure scripts are executable: `chmod +x ~/scripts/*.py`

### Issue: Files not detected in /intake/

**Solution:**
1. Verify n8n is running: `sudo systemctl status n8n`
2. Check workflow is activated (green toggle in n8n UI)
3. Verify permissions: `ls -lah /mnt/whisperforge/intake/`

---

## 📊 Performance Optimization

### For Low RAM Systems (8-12GB):

**whisper_batch.py:**
- Use `small.en` model instead of `medium.en`
- Add swap space: `sudo fallocate -l 8G /swapfile`

**llm_refine.py:**
- Use `phi3:mini` instead of `mistral:7b-instruct`
- Process shorter segments

### For High-Performance Systems (32GB+):

**whisper_batch.py:**
- Use `large` model for best quality
- Enable GPU acceleration if available

**llm_refine.py:**
- Use `llama3.1:70b` or similar large models
- Process multiple files in parallel

---

## 🔐 Security Notes

- **Never commit `.env`** to git (contains database credentials)
- SSH keys more secure than passwords for automation
- Tighten Supabase RLS policies if multiple users access data
- All processing happens locally (data never leaves your network)

---

## 💡 Customization Tips

### Add Custom Terminology (whisper_batch.py):

Edit the `initial_prompt` variable to include your domain-specific terms:

```python
initial_prompt = (
    "This is a medical consultation transcript. "
    "Use proper medical terminology. "
    "Common terms: hypertension, diabetes, cardiovascular, ..."
)
```

### Create Custom LLM Modes (llm_refine.py):

Add new prompts to the `prompts` dictionary:

```python
LEGAL_FORMAT_PROMPT = """Format this transcript as a legal deposition.
Include Q: and A: labels. Preserve all statements exactly.
...
"""
```

### Add Notifications (n8n):

After "Mark Completed" node:
1. Add HTTP Request node
2. POST to Slack/Discord webhook
3. Include `{{ $json.filename }}` and status

---

This completes the file overview. For deployment, start with `quickstart.sh`, then follow `DEPLOYMENT_GUIDE.md`.
