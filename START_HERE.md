# 🎙️ START HERE - WhisperForge Quick Start

Welcome to **WhisperForge** - your autonomous transcription empire!

---

## 👋 First Time Here?

This system transforms audio/video files into searchable, refined transcripts automatically using local AI models running on your home servers.

### What You Get:
✅ Automatic transcription (Whisper AI)
✅ Text refinement (Local LLM)
✅ Job tracking database
✅ Real-time monitoring dashboard
✅ Complete automation workflows
✅ Translation support (OmegaT)

**No cloud APIs. No monthly fees. Total privacy.**

---

## 🚀 Quick Start (15 Minutes)

### Step 1: Check Your System
Run this on **each machine** to verify readiness:
```bash
./check-system.sh
```

### Step 2: Run Setup Wizard
On your **Orchestration Server** (orchestration server):
```bash
./quickstart.sh
```

This will:
- Install Node.js dependencies
- Configure database connection
- Test everything
- Show next steps

### Step 3: Follow the Guide
Open **DEPLOYMENT_GUIDE.md** and follow the step-by-step instructions for:
- NAS configuration
- Compute server setup (Whisper + Ollama)
- n8n workflow installation

### Step 4: Test It!
Drop a test audio file in `/mnt/whisperforge/intake/` and watch the magic happen.

Monitor progress with:
```bash
npm run dashboard
```

---

## 📚 Documentation Roadmap

Read in this order:

### 1. **README.md** (Start Here)
Overview of the entire system, quick start guide, and usage examples.

**Read if:** You want to understand what WhisperForge does.

### 2. **QUICK_REFERENCE.md** (Daily Use)
One-page cheat sheet with common commands and troubleshooting.

**Read if:** You need quick answers during daily operations.

### 3. **DEPLOYMENT_GUIDE.md** (Setup)
Step-by-step instructions for deploying on your hardware stack.

**Read if:** You're setting up WhisperForge for the first time.

### 4. **ARCHITECTURE.md** (Deep Dive)
System design, data flow, scaling strategies, and performance details.

**Read if:** You want to understand how everything works together.

### 5. **FILES_OVERVIEW.md** (Reference)
Detailed explanation of every file, function, and configuration option.

**Read if:** You're troubleshooting or customizing the system.

### 6. **DELIVERABLES.md** (Inventory)
Complete list of everything included in this package.

**Read if:** You want to see what you've received.

---

## 🎯 Your Hardware Stack

WhisperForge is designed for your specific setup:

```
┌─────────────────────┐
│  Orchestration Server        │  ← Runs n8n, Node.js, monitoring
│  16GB RAM, 2TB SSD  │     (Orchestration server)
└─────────────────────┘

┌─────────────────────┐
│  Compute Server      │  ← Runs Whisper, Ollama
│  16GB RAM, 1TB NVMe │     (Heavy compute)
└─────────────────────┘

┌─────────────────────┐
│  NAS Array (2x)     │  ← File storage and distribution
│  Ubuntu             │     (Central storage)
└─────────────────────┘

┌─────────────────────┐
│  Supabase Database  │  ← Job tracking and analytics
│  Cloud/Self-hosted  │     (Managed database)
└─────────────────────┘
```

---

## 🔧 What Gets Installed Where

### On Orchestration Server (Orchestration):
- Node.js 20+
- n8n workflow engine
- This project (`~/whisperforge/`)
- Dashboard and monitoring scripts

### On Compute Server (Compute):
- Python 3.8+
- OpenAI Whisper
- Ollama (local LLM)
- Processing scripts (`~/scripts/`)

### On NAS:
- Shared directory: `/mnt/whisperforge/`
- NFS server configuration

---

## 📋 Pre-Flight Checklist

Before starting, ensure you have:

- [ ] Ubuntu installed on all machines
- [ ] Network connectivity between machines
- [ ] Supabase account (free tier works)
- [ ] At least 50GB free disk space
- [ ] SSH access between machines

---

## 🎬 Typical Workflow

Once set up, using WhisperForge is simple:

### Automatic Mode (Recommended):
1. Drop audio/video file into `/mnt/whisperforge/intake/`
2. Wait 5-20 minutes (depends on file length)
3. Find refined transcript in `/mnt/whisperforge/refined/`
4. Query via AnythingLLM

### Manual Mode:
```bash
# On compute server
python3 ~/scripts/whisper_batch.py input.mp3 output.txt
python3 ~/scripts/llm_refine.py output.txt refined.txt
```

---

## 📊 Monitoring Your System

### Real-Time Dashboard:
```bash
npm run dashboard
```

Shows:
- Total jobs (completed, processing, pending, failed)
- Storage usage across all directories
- Recent job history
- Auto-refreshes every 5 seconds

### One-Time Stats:
```bash
npm run stats
```

### Database Access:
Visit your Supabase dashboard to query jobs, transcripts, and translations.

---

## 🐛 Something Not Working?

### Quick Fixes:

**Files not processing?**
```bash
sudo systemctl status n8n
mount | grep whisperforge
```

**Out of memory?**
```bash
# Use smaller model
python3 whisper_batch.py input.mp3 output.txt small.en
```

**SSH errors?**
```bash
ssh user@compute-server "echo success"
```

**Database connection failed?**
```bash
cat .env
node db-tracker.js stats
```

---

## 💡 Pro Tips

### Speed Up Processing:
- Use GPU if available (5-10x faster)
- Process multiple files in parallel
- Use smaller models for quick drafts

### Optimize Storage:
- Archive old files regularly
- Use compression for audio files
- Monitor disk usage weekly

### Improve Accuracy:
- Add domain-specific terms to Whisper prompt
- Use larger models for critical content
- Review and correct important transcripts

---

## 🌟 Cool Features to Try

### Generate Summaries:
```bash
python3 llm_refine.py transcript.txt summary.txt summarize
```

### Add Timestamps:
```bash
python3 whisper_batch.py input.mp3 output.txt medium.en --timestamps
```

### Translate Content:
```bash
bash create_translation_project.sh meeting_notes en es
```

### Query Your Documents:
Use AnythingLLM to ask questions about your entire transcript library.

---

## 📞 Need Help?

### Documentation:
1. **Quick answers:** QUICK_REFERENCE.md
2. **Setup issues:** DEPLOYMENT_GUIDE.md
3. **How it works:** ARCHITECTURE.md
4. **File details:** FILES_OVERVIEW.md

### System Checks:
```bash
./check-system.sh  # Verify requirements
npm run stats      # Check pipeline health
```

---

## 🎉 You're Ready!

### Next Steps:

1. ✅ Read **README.md** for overview
2. ✅ Run `./check-system.sh` on all machines
3. ✅ Run `./quickstart.sh` on Orchestration Server
4. ✅ Follow **DEPLOYMENT_GUIDE.md** step-by-step
5. ✅ Test with a sample audio file
6. ✅ Monitor with `npm run dashboard`

### Success Looks Like:
- Drop file in `/intake/`
- Dashboard shows "processing"
- 5-20 minutes later: refined transcript ready
- Query it via AnythingLLM

**Welcome to automated transcription!** 🚀

---

## 📈 What's Next?

Once you're comfortable with the basics:

- Customize LLM prompts for your domain
- Add email notifications
- Build a web interface
- Scale to multiple compute nodes
- Integrate with your existing tools

**This is YOUR system. Make it work for YOU.**

---

*Built with ❤️ for self-hosted automation enthusiasts.*

*Questions? Check the documentation. Still stuck? Review the architecture diagram in ARCHITECTURE.md.*

**Happy transcribing!** 🎙️
