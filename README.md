# 🎙️ WhisperForge: Self-Hosted AI Transcription Pipeline

**An autonomous document processing empire running on your home servers.**

WhisperForge is a complete, production-ready transcription automation system that turns audio and video files into searchable, refined text documents using local AI models. No cloud dependencies, no API costs, total privacy.

---

## 🎯 What It Does

Drop an audio or video file into a watched folder and WhisperForge automatically:

1. **Transcribes** with OpenAI's Whisper (locally)
2. **Refines** using a local LLM via Ollama (grammar, formatting, clarity)
3. **Tracks** progress in a Supabase database
4. **Archives** and indexes for easy retrieval
5. **Optionally translates** via OmegaT
6. **Makes searchable** through AnythingLLM

All of this happens **automatically**, in the background, on **your hardware**.

---

## 🏗️ Architecture

```
┌──────────────┐
│  NAS Storage │  ← Centralized file system
└──────┬───────┘
       │
       ├─→ /intake/       Drop files here
       ├─→ /processing/   Active jobs
       ├─→ /transcripts/  Raw Whisper output
       ├─→ /refined/      LLM-enhanced text
       └─→ /archive/      Completed files

┌─────────────────────┐
│  HP Pavilion        │
│  (Orchestration)    │  ← n8n workflows
│  16GB RAM, 2TB SSD  │     Node.js scripts
└─────────────────────┘

┌─────────────────────┐
│  HP M01-F3003W      │
│  (Compute)          │  ← Whisper transcription
│  16GB RAM, 1TB NVMe │     Local LLM processing
└─────────────────────┘

┌─────────────────────┐
│  Supabase Database  │  ← Job tracking & analytics
└─────────────────────┘
```

---

## 🚀 Quick Start

### Prerequisites

- Ubuntu on all machines
- Networked storage (NFS recommended)
- Node.js 20+ on orchestration server
- Python 3.8+ on compute server

### 1. Clone This Repository

```bash
git clone <your-repo-url> ~/whisperforge
cd ~/whisperforge
```

### 2. Run Quick Start Script

```bash
chmod +x quickstart.sh
./quickstart.sh
```

This will:
- Verify dependencies
- Set up database connection
- Install Node.js packages
- Validate your configuration

### 3. Complete Setup

Follow the **[DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)** for step-by-step instructions to:
- Configure NAS storage
- Install Whisper and Ollama on your compute server
- Set up n8n workflows
- Configure OmegaT and AnythingLLM

---

## 📁 Project Structure

```
whisperforge/
├── db-tracker.js              # Database operations
├── dashboard.js               # Real-time monitoring
├── whisper_batch.py           # Transcription script (deploy to compute server)
├── llm_refine.py              # LLM refinement script (deploy to compute server)
├── n8n-workflow-template.json # Importable n8n workflow
├── quickstart.sh              # Automated setup
├── DEPLOYMENT_GUIDE.md        # Full deployment instructions
└── README.md                  # This file
```

---

## 🔧 Usage

### Monitor Your Pipeline

```bash
# Live dashboard (updates every 5 seconds)
node dashboard.js

# One-time stats
node dashboard.js --once
```

### Database Operations

```bash
# View pipeline statistics
node db-tracker.js stats

# List pending jobs
node db-tracker.js pending

# Create a job manually
node db-tracker.js create-job "meeting.mp3" "/mnt/whisperforge/intake/meeting.mp3"

# Update job status
node db-tracker.js update-status <job-id> completed
```

### Manual Transcription (on compute server)

```bash
# Basic transcription
python3 ~/scripts/whisper_batch.py input.mp3 output.txt

# With specific model
python3 ~/scripts/whisper_batch.py input.mp3 output.txt small.en

# With timestamps
python3 ~/scripts/whisper_batch.py input.mp3 output.txt medium.en --timestamps
```

### Manual LLM Refinement (on compute server)

```bash
# Refine transcript
python3 ~/scripts/llm_refine.py raw.txt refined.txt

# Generate summary
python3 ~/scripts/llm_refine.py raw.txt summary.txt summarize

# Add speaker labels (experimental)
python3 ~/scripts/llm_refine.py raw.txt labeled.txt diarize

# Batch process directory
python3 ~/scripts/llm_refine.py --batch /mnt/whisperforge/transcripts/
```

---

## 🎨 Recommended Workflow

### For Automated Processing

1. Drop files into `/mnt/whisperforge/intake/`
2. n8n automatically processes them
3. Monitor progress with `node dashboard.js`
4. Find refined transcripts in `/mnt/whisperforge/refined/`

### For Translation Projects

1. Wait for automatic processing to complete
2. Run: `bash ~/scripts/create_translation_project.sh meeting_2024 en es`
3. Open OmegaT and load the project
4. Translate with translation memory assistance
5. Export final translation

### For Document Intelligence

1. Refined transcripts automatically sync to AnythingLLM
2. Ask questions like:
   - "What were the key decisions in yesterday's meeting?"
   - "Find all mentions of the product launch timeline"
   - "Summarize the Q1 strategy discussions"

---

## 🎛️ Configuration

### Whisper Model Selection

Choose based on your hardware and quality needs:

| Model | RAM | Speed | Quality | Recommended For |
|-------|-----|-------|---------|-----------------|
| `tiny.en` | ~1GB | Very Fast | Low | Quick drafts |
| `small.en` | ~2GB | Fast | Good | General use |
| `medium.en` | ~5GB | Moderate | High | **Production (recommended)** |
| `large` | ~10GB | Slow | Best | Critical accuracy |

### LLM Model Selection

| Model | RAM | Speed | Quality | Use Case |
|-------|-----|-------|---------|----------|
| `mistral:7b-instruct` | ~8GB | Moderate | Excellent | **General (recommended)** |
| `llama3.1:8b` | ~8GB | Moderate | Excellent | Alternative option |
| `phi3:mini` | ~4GB | Fast | Good | Lower-end hardware |

---

## 📊 Database Schema

WhisperForge tracks everything in Supabase:

### Tables

- **jobs** - Main transcription job tracking
- **transcripts** - Raw and refined text storage
- **translations** - OmegaT translation project tracking

### Query Examples

```javascript
// Get all completed jobs
const { data } = await supabase
  .from('jobs')
  .select('*')
  .eq('status', 'completed')
  .order('completed_at', { ascending: false });

// Get transcript with refinement
const { data } = await supabase
  .from('transcripts')
  .select('*, jobs(*)')
  .eq('job_id', jobId)
  .single();

// Get processing time stats
const { data } = await supabase
  .from('jobs')
  .select('started_at, completed_at')
  .not('started_at', 'is', null)
  .not('completed_at', 'is', null);
```

---

## 🛠️ Troubleshooting

### Files Not Being Processed

**Problem:** Files dropped in `/intake/` are ignored

**Solutions:**
- Verify n8n is running: `sudo systemctl status n8n`
- Check n8n workflow is activated (green toggle in UI)
- Verify file permissions: `ls -lah /mnt/whisperforge/intake/`
- Check NFS mount: `mount | grep whisperforge`

### Whisper Out of Memory

**Problem:** Transcription fails with OOM errors

**Solutions:**
- Use smaller model: `small.en` instead of `medium.en`
- Add swap space: `sudo fallocate -l 8G /swapfile`
- Split long audio files into 30-minute chunks
- Close other applications during processing

### LLM Processing Slow

**Problem:** Refinement takes too long

**Solutions:**
- Use faster model: `phi3:mini`
- Reduce transcript length by splitting
- Verify Ollama configuration: `~/.ollama/config`
- Check CPU usage: `htop`

### Database Connection Failed

**Problem:** Scripts can't connect to Supabase

**Solutions:**
- Verify `.env` file exists and contains correct credentials
- Test connection: `node -e "require('./db-tracker.js').getJobStats()"`
- Check Supabase project is not paused
- Verify network connectivity

---

## 🎓 Advanced Features

### Custom LLM Prompts

Edit `llm_refine.py` to customize prompts for your use case:

```python
CUSTOM_PROMPT = """You are a medical transcription specialist.
Format this transcript according to SOAP note standards.
Preserve all medical terminology exactly as spoken.

TRANSCRIPT:
{transcript}

SOAP NOTE:"""
```

### Webhook Notifications

Add to your n8n workflow:

1. After "Mark Completed" node
2. Add HTTP Request node
3. POST to Slack/Discord webhook
4. Include job details and status

### Speaker Diarization

For better speaker labeling, install pyannote.audio:

```bash
pip install pyannote.audio
```

Then use with Whisper's word timestamps for intelligent speaker segmentation.

### GPU Acceleration

If you have an NVIDIA GPU:

```bash
# Install CUDA-enabled PyTorch
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118

# Whisper will automatically use GPU
```

Expected speedup: **5-10x faster** than CPU.

---

## 📈 Performance Benchmarks

### Typical Processing Times (HP M01-F3003W, medium.en model)

| Audio Length | Transcription | LLM Refinement | Total |
|--------------|---------------|----------------|-------|
| 5 minutes | 1-2 min | 30-60 sec | ~2-3 min |
| 30 minutes | 5-10 min | 2-4 min | ~7-14 min |
| 1 hour | 10-20 min | 4-8 min | ~14-28 min |

### Storage Requirements

- **Raw audio:** Varies (typically 1-5MB per minute)
- **Transcripts:** ~2KB per minute of speech
- **Database:** <1KB per job

**Recommendation:** 500GB for comfortable operation with 100+ hours of audio.

---

## 🔐 Security Considerations

- All processing happens **locally** - no data leaves your network
- Database credentials stored in `.env` (never commit to git)
- SSH keys used for passwordless automation (more secure than passwords)
- File permissions restrict access to your user account
- Supabase RLS policies can be tightened for multi-user scenarios

---

## 🤝 Contributing & Customization

This is **your** system. Customize freely:

- Adjust Whisper prompts for domain-specific terminology
- Create custom LLM refinement modes
- Add new n8n workflow branches (e.g., email transcripts)
- Integrate with your existing tools
- Build a web UI using the Supabase backend

---

## 📚 Resources

- [OpenAI Whisper Documentation](https://github.com/openai/whisper)
- [Ollama Model Library](https://ollama.com/library)
- [n8n Workflow Documentation](https://docs.n8n.io/)
- [OmegaT User Guide](https://omegat.org/documentation)
- [Supabase JavaScript Client](https://supabase.com/docs/reference/javascript)

---

## 💡 Use Cases

- **Meeting transcription** for team documentation
- **Podcast production** (episode notes, transcripts, show notes)
- **Interview processing** for research projects
- **Lecture capture** for educational content
- **Video content repurposing** (YouTube → blog posts)
- **Accessibility** (adding captions/transcripts)
- **Legal/medical transcription** (with appropriate customization)

---

## 🎉 You're Ready!

Your autonomous transcription empire awaits. Drop a file in `/mnt/whisperforge/intake/` and watch WhisperForge work its magic.

**Questions? Issues?** Check the [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) for detailed setup instructions.

**Happy transcribing!** 🚀

---

Built with ❤️ for self-hosted automation enthusiasts.
