# WhisperForge Deployment Guide

## 🎯 System Overview

**WhisperForge** is your autonomous transcription empire. Here's how the pieces fit together:

```
┌─────────────┐
│  NAS Array  │ ◄─── Central file storage & distribution
└──────┬──────┘
       │
       ├──► /intake/      (Drop files here)
       ├──► /processing/  (Active work)
       ├──► /transcripts/ (Whisper output)
       ├──► /refined/     (LLM-enhanced)
       └──► /archive/     (Completed)

┌──────────────────┐
│  HP Pavilion     │ ◄─── Orchestration brain
│  (n8n + Node-RED)│
└──────────────────┘

┌──────────────────┐
│  HP M01-F3003W   │ ◄─── Heavy compute
│  (Whisper + LLM) │      (16GB RAM)
└──────────────────┘

┌──────────────────┐
│  Supabase DB     │ ◄─── Job tracking & analytics
└──────────────────┘

┌──────────────────┐
│  AnythingLLM     │ ◄─── Document intelligence UI
└──────────────────┘
```

---

## 📦 Step 1: NAS Setup

### On Primary NAS Machine:

```bash
# Create directory structure
sudo mkdir -p /mnt/whisperforge/{intake,processing,transcripts,refined,archive,omegat-projects}

# Set permissions (adjust for your setup)
sudo chown -R $USER:$USER /mnt/whisperforge
chmod -R 755 /mnt/whisperforge

# Share via NFS (install nfs-kernel-server if needed)
sudo apt install nfs-kernel-server -y

# Add to /etc/exports:
echo "/mnt/whisperforge *(rw,sync,no_subtree_check,no_root_squash)" | sudo tee -a /etc/exports

# Apply exports
sudo exportfs -a
sudo systemctl restart nfs-kernel-server
```

### On Other Machines (HP Pavilion & M01-F3003W):

```bash
# Install NFS client
sudo apt install nfs-common -y

# Mount the shared folder (replace NAS_IP with your NAS IP)
sudo mkdir -p /mnt/whisperforge
sudo mount NAS_IP:/mnt/whisperforge /mnt/whisperforge

# Make permanent (add to /etc/fstab):
echo "NAS_IP:/mnt/whisperforge /mnt/whisperforge nfs defaults 0 0" | sudo tee -a /etc/fstab
```

---

## 🧠 Step 2: LLM Machine Setup (HP M01-F3003W)

### Install Whisper:

```bash
# Install Python & dependencies
sudo apt update
sudo apt install python3-pip python3-venv ffmpeg -y

# Create virtual environment
python3 -m venv ~/whisper-env
source ~/whisper-env/bin/activate

# Install Whisper
pip install -U openai-whisper torch

# Test installation
whisper --help
```

### Install Ollama for LLM:

```bash
# Install Ollama
curl -fsSL https://ollama.com/install.sh | sh

# Pull recommended model (Mistral 7B)
ollama pull mistral:7b-instruct

# Test
ollama run mistral:7b-instruct "Say hello"
```

### Deploy Scripts:

```bash
# Create scripts directory
mkdir -p ~/scripts

# Copy the whisper_batch.py and llm_refine.py scripts here
# (From the architecture blueprint earlier in this guide)

# Make executable
chmod +x ~/scripts/*.py

# Test Whisper script
python3 ~/scripts/whisper_batch.py /path/to/test.mp3 /tmp/test_output.txt
```

---

## 🎛️ Step 3: Orchestration Server Setup (HP Pavilion)

### Install Node.js & n8n:

```bash
# Install Node.js 20 LTS
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install nodejs -y

# Install n8n globally
npm install -g n8n

# Create systemd service for n8n
sudo tee /etc/systemd/system/n8n.service > /dev/null <<EOF
[Unit]
Description=n8n workflow automation
After=network.target

[Service]
Type=simple
User=$USER
ExecStart=$(which n8n)
Restart=on-failure
Environment="N8N_BASIC_AUTH_ACTIVE=true"
Environment="N8N_BASIC_AUTH_USER=admin"
Environment="N8N_BASIC_AUTH_PASSWORD=changeme123"
Environment="N8N_HOST=0.0.0.0"
Environment="N8N_PORT=5678"

[Install]
WantedBy=multi-user.target
EOF

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable n8n
sudo systemctl start n8n

# Check status
sudo systemctl status n8n

# Access at: http://pavilion-ip:5678
```

### Setup Database Tracker:

```bash
# Clone/copy your WhisperForge project
git clone <your-repo> ~/whisperforge
cd ~/whisperforge

# Install dependencies
npm install

# Test database connection
node db-tracker.js stats
```

### Import n8n Workflow:

1. Open n8n web UI (http://your-pavilion-ip:5678)
2. Go to **Workflows** → **Import from File**
3. Upload `n8n-workflow-template.json`
4. Update these settings:
   - SSH credentials for LLM machine
   - File paths (if different from defaults)
   - Your db-tracker.js absolute path

---

## 🔐 Step 4: SSH Key Setup (Passwordless Access)

On HP Pavilion (orchestration server):

```bash
# Generate SSH key if you don't have one
ssh-keygen -t ed25519 -C "whisperforge-automation"

# Copy to LLM machine
ssh-copy-id user@llm-machine-ip

# Test connection
ssh user@llm-machine-ip "echo 'Connection successful'"
```

---

## 📊 Step 5: Database Verification

```bash
# On HP Pavilion, test the tracker:
cd ~/whisperforge

# Check stats
node db-tracker.js stats

# Create a test job
node db-tracker.js create-job "test.mp3" "/mnt/whisperforge/intake/test.mp3"

# Update its status
node db-tracker.js update-status <job-id-from-above> processing
```

---

## 🧪 Step 6: End-to-End Test

### Manual Test Run:

```bash
# 1. Get a test audio file
wget https://www2.cs.uic.edu/~i101/SoundFiles/StarWars60.wav -O /mnt/whisperforge/intake/test.wav

# 2. Watch n8n logs
sudo journalctl -u n8n -f

# 3. The workflow should automatically:
#    - Detect the file
#    - Create DB job
#    - Run Whisper
#    - Refine with LLM
#    - Save to database
#    - Archive original

# 4. Verify outputs
ls -lh /mnt/whisperforge/transcripts/
ls -lh /mnt/whisperforge/refined/
ls -lh /mnt/whisperforge/archive/

# 5. Check database
node db-tracker.js stats
```

---

## 🎨 Step 7: OmegaT Integration (Optional)

### Install OmegaT:

```bash
# On any machine with GUI
sudo apt install default-jre -y
wget https://downloads.sourceforge.net/project/omegat/OmegaT%20-%20Latest/OmegaT%206.0.0/OmegaT_6.0.0_Linux_64.tar.bz2
tar -xjf OmegaT_6.0.0_Linux_64.tar.bz2
sudo mv OmegaT_6.0.0 /opt/OmegaT

# Create desktop shortcut
echo "[Desktop Entry]
Name=OmegaT
Exec=/opt/OmegaT/OmegaT
Type=Application" > ~/.local/share/applications/omegat.desktop
```

### Create Translation Project Script:

Save this as `~/scripts/create_translation_project.sh`:

```bash
#!/bin/bash

FILENAME=$1
SOURCE_LANG=${2:-en}
TARGET_LANG=${3:-es}

PROJECT_DIR="/mnt/whisperforge/omegat-projects/${FILENAME}_${TARGET_LANG}"

mkdir -p "$PROJECT_DIR"/{source,target,tm,glossary}

# Copy refined transcript
cp "/mnt/whisperforge/refined/${FILENAME}.txt" "$PROJECT_DIR/source/"

# Create OmegaT project file
cat > "$PROJECT_DIR/omegat.project" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<omegat>
  <project version="1.0">
    <source_language>${SOURCE_LANG}</source_language>
    <target_language>${TARGET_LANG}</target_language>
  </project>
</omegat>
EOF

echo "✓ Translation project created: $PROJECT_DIR"
```

---

## 🚀 Step 8: AnythingLLM Integration

### Install AnythingLLM:

```bash
# Download latest release
wget https://s3.us-west-1.amazonaws.com/public.useanything.com/latest/AnythingLLMDesktop.AppImage

chmod +x AnythingLLMDesktop.AppImage

# Run
./AnythingLLMDesktop.AppImage
```

### Auto-Sync Refined Transcripts:

Create a cron job to sync refined docs to AnythingLLM:

```bash
# Create sync script
cat > ~/scripts/sync_to_anythingllm.sh <<'EOF'
#!/bin/bash

REFINED_DIR="/mnt/whisperforge/refined"
ANYTHINGLLM_DIR="$HOME/.anythingllm/documents/whisperforge"

mkdir -p "$ANYTHINGLLM_DIR"

# Sync new files
rsync -av --ignore-existing "$REFINED_DIR/" "$ANYTHINGLLM_DIR/"

echo "✓ Synced to AnythingLLM"
EOF

chmod +x ~/scripts/sync_to_anythingllm.sh

# Add to cron (run every 5 minutes)
(crontab -l 2>/dev/null; echo "*/5 * * * * ~/scripts/sync_to_anythingllm.sh") | crontab -
```

---

## 📈 Performance Tuning

### For 16GB RAM Machines:

**Whisper Memory Optimization:**

```bash
# In your whisper_batch.py, add at top:
import os
os.environ['OMP_NUM_THREADS'] = '4'
```

**Ollama Configuration:**

```bash
# Create ~/.ollama/config
mkdir -p ~/.ollama
cat > ~/.ollama/config <<EOF
{
  "max_loaded_models": 1,
  "num_parallel": 2
}
EOF
```

### Batch Processing Strategy:

```python
# For large files, split audio first
from pydub import AudioSegment

def split_audio(file_path, chunk_length_ms=1800000):  # 30 min chunks
    audio = AudioSegment.from_file(file_path)
    chunks = []
    for i in range(0, len(audio), chunk_length_ms):
        chunk = audio[i:i + chunk_length_ms]
        chunk_path = f"/tmp/chunk_{i//chunk_length_ms}.mp3"
        chunk.export(chunk_path, format="mp3")
        chunks.append(chunk_path)
    return chunks
```

---

## 🔍 Monitoring & Troubleshooting

### Check System Status:

```bash
# n8n status
sudo systemctl status n8n

# View n8n logs
sudo journalctl -u n8n -f

# Check database stats
cd ~/whisperforge
node db-tracker.js stats

# Monitor disk usage
df -h /mnt/whisperforge

# Check GPU usage (if you have one)
nvidia-smi
```

### Common Issues:

**Problem:** Files not being picked up by n8n
- Check file permissions on /mnt/whisperforge/intake
- Verify NFS mount is active: `mount | grep whisperforge`
- Check n8n workflow is activated

**Problem:** Whisper fails with OOM error
- Use smaller model (small.en instead of medium.en)
- Process shorter audio files
- Add swap space: `sudo fallocate -l 8G /swapfile`

**Problem:** SSH commands failing in n8n
- Verify SSH key is properly configured
- Test manual SSH: `ssh user@llm-machine "whoami"`
- Check SSH node credentials in n8n

---

## 🎉 You're Ready!

Your WhisperForge pipeline is now operational. Drop any audio/video file into `/mnt/whisperforge/intake/` and watch the magic happen:

1. ✅ Auto-detected by n8n
2. ✅ Transcribed with Whisper
3. ✅ Enhanced by local LLM
4. ✅ Tracked in Supabase
5. ✅ Archived and indexed

### Next Steps:

- Set up email/Slack notifications in n8n for job completion
- Create a simple web dashboard using the Supabase data
- Fine-tune LLM prompts for your specific use cases
- Add speaker diarization with pyannote.audio

**Welcome to your autonomous transcription business!** 🚀
