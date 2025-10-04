# WhisperForge Quick Reference Card

A one-page cheat sheet for common tasks and commands.

---

## 🚀 Common Commands

### Monitoring & Stats
```bash
# Live dashboard (refreshes every 5 seconds)
npm run dashboard

# One-time statistics
npm run stats

# List pending jobs
npm run pending

# Check system requirements
./check-system.sh
```

### Manual Job Management
```bash
# Create a job
node db-tracker.js create-job "meeting.mp3" "/path/to/file"

# Update job status
node db-tracker.js update-status <job-id> processing

# Save transcript
node db-tracker.js save-transcript <job-id> /path/to/transcript.txt
```

### Manual Transcription (on HP M01-F3003W)
```bash
# Basic transcription
python3 ~/scripts/whisper_batch.py input.mp3 output.txt

# With specific model
python3 ~/scripts/whisper_batch.py input.mp3 output.txt small.en

# With timestamps
python3 ~/scripts/whisper_batch.py input.mp3 output.txt medium.en --timestamps
```

### Manual LLM Processing (on HP M01-F3003W)
```bash
# Refine transcript
python3 ~/scripts/llm_refine.py raw.txt refined.txt

# Generate summary
python3 ~/scripts/llm_refine.py raw.txt summary.txt summarize

# Batch process directory
python3 ~/scripts/llm_refine.py --batch /path/to/transcripts/
```

---

## 📁 Important Directories

| Path | Purpose |
|------|---------|
| `/mnt/whisperforge/intake/` | Drop files here for processing |
| `/mnt/whisperforge/processing/` | Files being processed |
| `/mnt/whisperforge/transcripts/` | Raw Whisper output |
| `/mnt/whisperforge/refined/` | LLM-enhanced transcripts |
| `/mnt/whisperforge/archive/` | Completed original files |
| `~/whisperforge/` | Project scripts (HP Pavilion) |
| `~/scripts/` | Python scripts (HP M01-F3003W) |

---

## 🔧 Service Management

### n8n
```bash
# Start n8n
sudo systemctl start n8n

# Stop n8n
sudo systemctl stop n8n

# Restart n8n
sudo systemctl restart n8n

# Check status
sudo systemctl status n8n

# View logs
sudo journalctl -u n8n -f
```

### Ollama
```bash
# List models
ollama list

# Pull a model
ollama pull mistral:7b-instruct

# Test a model
ollama run mistral:7b-instruct "Hello"

# Check Ollama status
ps aux | grep ollama
```

---

## 🐛 Troubleshooting Quick Fixes

### Files not being processed
```bash
# 1. Check n8n is running
sudo systemctl status n8n

# 2. Check NFS mount
mount | grep whisperforge

# 3. Check file permissions
ls -lah /mnt/whisperforge/intake/

# 4. Manually trigger workflow in n8n UI
```

### Out of Memory errors
```bash
# Use smaller Whisper model
python3 whisper_batch.py input.mp3 output.txt small.en

# Add swap space
sudo fallocate -l 8G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

### SSH connection failed
```bash
# Test SSH manually
ssh user@llm-machine-ip "echo success"

# Regenerate SSH keys
ssh-keygen -t ed25519
ssh-copy-id user@llm-machine-ip
```

### Database connection error
```bash
# Check .env file exists
cat ~/whisperforge/.env

# Test connection
node ~/whisperforge/db-tracker.js stats
```

---

## 📊 Status Icons Reference

| Icon | Meaning |
|------|---------|
| ✅ | Completed successfully |
| ⚙️ | Currently processing |
| ⏳ | Pending/waiting |
| ❌ | Failed |
| 📥 | In intake folder |
| 📝 | Transcript available |
| ✨ | Refined/enhanced |
| 📦 | Archived |

---

## 🔑 Key Environment Variables

```bash
# In ~/whisperforge/.env
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key-here
```

---

## 🎯 Whisper Models

| Model | RAM | Speed | Quality | Use Case |
|-------|-----|-------|---------|----------|
| tiny.en | 1GB | Very Fast | Low | Testing |
| base.en | 1GB | Fast | Decent | Quick drafts |
| small.en | 2GB | Fast | Good | General use |
| medium.en | 5GB | Moderate | High | **Production** |
| large | 10GB | Slow | Best | Critical accuracy |

---

## 🤖 Ollama Models

| Model | RAM | Quality | Use Case |
|-------|-----|---------|----------|
| phi3:mini | 4GB | Good | Low-end hardware |
| mistral:7b-instruct | 8GB | Excellent | **Production** |
| llama3.1:8b | 8GB | Excellent | Alternative |

---

## 📈 Expected Processing Times

| Audio Length | Transcription | Refinement | Total |
|--------------|---------------|------------|-------|
| 5 minutes | 1-2 min | 30-60 sec | ~2-3 min |
| 30 minutes | 5-10 min | 2-4 min | ~7-14 min |
| 1 hour | 10-20 min | 4-8 min | ~14-28 min |

---

## 🌐 Web Interfaces

| Service | URL | Purpose |
|---------|-----|---------|
| n8n | http://pavilion-ip:5678 | Workflow management |
| Supabase | https://supabase.com/dashboard | Database admin |
| AnythingLLM | http://pavilion-ip:3001 | Document queries |

---

## 📞 Quick Setup Checklist

- [ ] Run `check-system.sh` on all machines
- [ ] Install Node.js on HP Pavilion
- [ ] Install Python + Whisper on HP M01-F3003W
- [ ] Install Ollama on HP M01-F3003W
- [ ] Create NFS share on NAS
- [ ] Mount NFS on both servers
- [ ] Run `quickstart.sh` on HP Pavilion
- [ ] Install n8n on HP Pavilion
- [ ] Configure SSH keys between machines
- [ ] Import workflow template into n8n
- [ ] Test with a sample file

---

## 💡 Pro Tips

1. **Use `screen` or `tmux` for long-running tasks**
   ```bash
   screen -S whisperforge
   python3 whisper_batch.py huge_file.mp3 output.txt
   # Press Ctrl+A, then D to detach
   screen -r whisperforge  # Reattach later
   ```

2. **Monitor disk usage regularly**
   ```bash
   df -h /mnt/whisperforge
   du -sh /mnt/whisperforge/*
   ```

3. **Archive old files periodically**
   ```bash
   # Move files older than 90 days
   find /mnt/whisperforge/archive/ -mtime +90 -exec mv {} /backups/ \;
   ```

4. **Check database growth**
   ```bash
   node db-tracker.js stats
   ```

5. **Batch process existing files**
   ```bash
   for f in /mnt/whisperforge/intake/*.mp3; do
     python3 ~/scripts/whisper_batch.py "$f" "/mnt/whisperforge/transcripts/$(basename "$f" .mp3).txt"
   done
   ```

---

## 🔒 Security Reminders

- ✅ Never commit `.env` to git
- ✅ Use SSH keys, not passwords
- ✅ Keep Supabase API keys secret
- ✅ Regularly update system packages
- ✅ Backup `/refined/` directory weekly
- ✅ Monitor unauthorized access attempts

---

## 📚 Documentation Quick Links

- **README.md** - Overview and quick start
- **DEPLOYMENT_GUIDE.md** - Step-by-step setup
- **FILES_OVERVIEW.md** - What each file does
- **ARCHITECTURE.md** - System design and data flow
- **DELIVERABLES.md** - Complete inventory
- **This file** - Quick reference

---

## 🆘 Emergency Contacts

| Issue | Action |
|-------|--------|
| NFS down | Check NAS, remount with: `sudo mount -a` |
| n8n crashed | Restart: `sudo systemctl restart n8n` |
| Disk full | Clear `/archive/` or add more storage |
| DB error | Check Supabase dashboard status |
| Unknown | Run `check-system.sh` for diagnostics |

---

**Keep this card handy for daily operations!**

Print or bookmark for quick access.
