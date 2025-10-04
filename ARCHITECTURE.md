# 🏗️ WhisperForge System Architecture

## Visual System Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         USER INTERACTION                         │
└─────────────────────────────────────────────────────────────────┘
                                 │
                                 │ Drop audio/video files
                                 ▼
┌─────────────────────────────────────────────────────────────────┐
│                      NAS ARRAY (Storage Hub)                     │
│  2x Compaq Machines running Ubuntu                              │
│                                                                  │
│  /mnt/whisperforge/                                             │
│  ├── intake/          ◄── Files dropped here                   │
│  ├── processing/      ◄── Active jobs                          │
│  ├── transcripts/     ◄── Raw Whisper output                   │
│  ├── refined/         ◄── LLM-enhanced text                    │
│  ├── archive/         ◄── Completed originals                  │
│  └── omegat-projects/ ◄── Translation projects                 │
│                                                                  │
│  Shared via NFS to all machines                                │
└─────────────────────────────────────────────────────────────────┘
                      │                        │
                      │ Mounted via NFS        │ Mounted via NFS
                      ▼                        ▼
┌───────────────────────────────┐  ┌───────────────────────────────┐
│   HP PAVILION SERVER          │  │   HP M01-F3003W (LLM)        │
│   (Orchestration Brain)       │  │   (Heavy Compute)            │
│   16GB RAM, 2TB SATA SSD      │  │   16GB RAM, 1TB NVMe SSD     │
│   Ubuntu Server               │  │   Ubuntu Desktop             │
│                               │  │                              │
│  ┌─────────────────────────┐ │  │  ┌────────────────────────┐ │
│  │   n8n Workflow Engine   │ │  │  │  Whisper (Python)      │ │
│  │   - File watcher        │ │  │  │  - medium.en model     │ │
│  │   - Orchestration       │◄─┼──┼─►│  - Batch processing    │ │
│  │   - SSH remote exec     │ │  │  │  - JSON + text output  │ │
│  └─────────────────────────┘ │  │  └────────────────────────┘ │
│                               │  │                              │
│  ┌─────────────────────────┐ │  │  ┌────────────────────────┐ │
│  │  Node.js Scripts        │ │  │  │  Ollama (Local LLM)    │ │
│  │  - db-tracker.js        │ │  │  │  - mistral:7b-instruct │ │
│  │  - dashboard.js         │ │  │  │  - Text refinement     │ │
│  │  - Job management       │ │  │  │  - Summarization       │ │
│  └─────────────────────────┘ │  │  └────────────────────────┘ │
│                               │  │                              │
│  ┌─────────────────────────┐ │  │  ┌────────────────────────┐ │
│  │  AnythingLLM            │ │  │  │  Python Scripts        │ │
│  │  - Document search      │ │  │  │  - whisper_batch.py    │ │
│  │  - Intelligent queries  │ │  │  │  - llm_refine.py       │ │
│  │  - User interface       │ │  │  │  - CLI tools           │ │
│  └─────────────────────────┘ │  │  └────────────────────────┘ │
└───────────────────────────────┘  └───────────────────────────────┘
                      │
                      │ Read/Write via API
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                    SUPABASE DATABASE (Cloud)                     │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │  jobs table  │  │ transcripts  │  │ translations │         │
│  │              │  │   table      │  │    table     │         │
│  │ - filename   │  │ - raw_text   │  │ - source     │         │
│  │ - status     │  │ - refined    │  │ - target     │         │
│  │ - timestamps │  │ - metadata   │  │ - status     │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
│                                                                  │
│  + Row Level Security (RLS)                                     │
│  + Indexes for fast queries                                     │
│  + Foreign key relationships                                    │
└─────────────────────────────────────────────────────────────────┘
```

---

## Data Flow: End-to-End Processing

```
┌─────────────────┐
│  1. FILE DROP   │  User drops "meeting.mp4" into /intake/
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│  2. DETECTION (n8n)                                         │
│  - File trigger fires                                       │
│  - Extracts: filename, path, size                           │
└────────┬────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│  3. DATABASE REGISTRATION (db-tracker.js)                   │
│  - Creates job record                                       │
│  - Status: 'pending'                                        │
│  - Returns: job_id = "abc-123"                              │
└────────┬────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│  4. FILE STAGING (bash)                                     │
│  - Move: /intake/meeting.mp4 → /processing/meeting.mp4     │
│  - Prevents re-triggering                                   │
└────────┬────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│  5. TRANSCRIPTION (SSH → whisper_batch.py)                  │
│  - SSH to HP M01-F3003W                                     │
│  - Load Whisper model (medium.en)                           │
│  - Process: /processing/meeting.mp4                         │
│  - Output: /transcripts/meeting.txt + meeting.json          │
│  - Duration: ~5-10min for 30min audio                       │
└────────┬────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│  6. STATUS UPDATE (db-tracker.js)                           │
│  - Update job_id "abc-123"                                  │
│  - Status: 'processing'                                     │
│  - started_at: now()                                        │
└────────┬────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│  7. LLM REFINEMENT (SSH → llm_refine.py)                    │
│  - SSH to HP M01-F3003W                                     │
│  - Load Ollama (mistral:7b-instruct)                        │
│  - Process: /transcripts/meeting.txt                        │
│  - Fix grammar, remove fillers, add paragraphs              │
│  - Output: /refined/meeting.txt                             │
│  - Duration: ~2-4min                                        │
└────────┬────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│  8. SAVE TRANSCRIPT (db-tracker.js)                         │
│  - Read: /refined/meeting.txt                               │
│  - Create transcript record                                 │
│  - Link to job_id "abc-123"                                 │
│  - Store: raw_text, refined_text, word_count                │
└────────┬────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│  9. COMPLETION (db-tracker.js)                              │
│  - Update job_id "abc-123"                                  │
│  - Status: 'completed'                                      │
│  - completed_at: now()                                      │
└────────┬────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│  10. ARCHIVAL (bash)                                        │
│  - Move: /processing/meeting.mp4 → /archive/meeting.mp4    │
│  - Keeps storage organized                                  │
└────────┬────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│  11. INDEXING (sync script)                                 │
│  - Copy: /refined/meeting.txt → AnythingLLM docs/          │
│  - Makes searchable via LLM queries                         │
└─────────────────────────────────────────────────────────────┘
```

**Total Time:** 7-14 minutes for 30-minute audio (fully automated)

---

## Component Interaction Matrix

| Component | Talks To | Protocol | Purpose |
|-----------|----------|----------|---------|
| **n8n** | NAS | NFS mount | Read/write files |
| **n8n** | db-tracker.js | Local exec | Database operations |
| **n8n** | HP M01-F3003W | SSH | Remote command execution |
| **db-tracker.js** | Supabase | HTTPS/REST | Job tracking |
| **dashboard.js** | Supabase | HTTPS/REST | Statistics display |
| **whisper_batch.py** | NAS | NFS mount | Read audio, write transcripts |
| **llm_refine.py** | NAS | NFS mount | Read transcripts, write refined |
| **llm_refine.py** | Ollama | Local API | LLM inference |
| **AnythingLLM** | NAS | File sync | Document indexing |

---

## Scalability Paths

### Current Capacity
- **1 machine** (HP M01-F3003W) processing
- **Sequential processing** (one job at a time)
- **Throughput:** ~30 hours of audio per day

### Scale Option 1: Add More Compute
```
Add 2nd HP M01-F3003W → 2x throughput (60 hours/day)
- n8n can round-robin SSH commands
- Shared NAS storage
- Same database
```

### Scale Option 2: GPU Acceleration
```
Add NVIDIA GPU to HP M01-F3003W → 5-10x faster
- Whisper uses CUDA automatically
- Same code, no changes needed
- 150-300 hours/day throughput
```

### Scale Option 3: Distributed Processing
```
Add dedicated machines:
- Machine A: Whisper only
- Machine B: LLM only
- Machine C: Post-processing
Load balance via n8n
```

---

## Security Architecture

### Network Security
```
Internet ─→ Router/Firewall
              │
              ├─→ [NAS] Private network only
              ├─→ [HP Pavilion] Private + Supabase outbound
              └─→ [HP M01-F3003W] Private only
```

### Data Security
- ✅ All processing local (no cloud transcription)
- ✅ Database credentials in `.env` (git-ignored)
- ✅ SSH keys (no passwords in workflows)
- ✅ RLS policies on Supabase tables
- ✅ File permissions restrict access

### Access Control
```
User → NAS intake folder (write-only)
n8n → NAS all folders (read/write)
n8n → HP M01-F3003W (SSH key, limited user)
Node.js → Supabase (API key, RLS enforced)
```

---

## Failure Handling

### File Processing Failures
```
Whisper fails
  ├─→ n8n catches error
  ├─→ db-tracker updates status: 'failed'
  ├─→ error_message populated
  ├─→ Original file NOT deleted
  └─→ Manual retry possible
```

### LLM Failures
```
Ollama fails
  ├─→ llm_refine.py catches exception
  ├─→ Copies raw transcript to refined/
  ├─→ Process continues (degraded mode)
  └─→ Transcript still usable
```

### Network Failures
```
SSH connection lost
  ├─→ n8n workflow pauses
  ├─→ Job remains in 'processing' state
  ├─→ Dashboard shows stuck job
  └─→ Manual intervention needed
```

### Database Failures
```
Supabase unreachable
  ├─→ File processing continues
  ├─→ Outputs still written to NAS
  ├─→ Retry database operations when back
  └─→ No data loss
```

---

## Monitoring & Observability

### Real-Time Monitoring
```bash
# Live dashboard
npm run dashboard

# Output shows:
# - Jobs: total, pending, processing, completed, failed
# - Storage: size and file count per directory
# - Recent jobs: last 10 with status
```

### Log Files
```
n8n: sudo journalctl -u n8n -f
Whisper: Logs to stdout (captured by n8n)
Ollama: ollama logs
System: /var/log/syslog
```

### Metrics Available
- Processing time per job
- Average transcription duration
- Storage usage trends
- Success/failure rates
- Throughput (hours/day)

---

## Technology Stack Summary

### Frontend/Orchestration
- **n8n** - Visual workflow automation
- **AnythingLLM** - Document intelligence UI

### Backend/Database
- **Node.js 20+** - Scripting and API calls
- **Supabase (PostgreSQL)** - Job tracking database

### AI/ML Processing
- **OpenAI Whisper** - Speech-to-text (local)
- **Ollama** - Local LLM inference
- **Mistral 7B** - Text refinement model

### Infrastructure
- **NFS** - Shared network storage
- **SSH** - Remote command execution
- **systemd** - Service management
- **Ubuntu** - Operating system

### Languages
- **JavaScript (Node.js)** - Orchestration, database
- **Python 3** - AI/ML processing
- **Bash** - System automation

---

## Performance Characteristics

### Resource Usage (Per Job)

| Phase | Machine | CPU | RAM | Duration |
|-------|---------|-----|-----|----------|
| Detection | HP Pavilion | <1% | 50MB | <1s |
| Transcription | HP M01-F3003W | 100% | 5GB | 5-20min |
| Refinement | HP M01-F3003W | 100% | 8GB | 2-4min |
| Database Ops | HP Pavilion | <1% | 100MB | <1s |

### Bottlenecks
1. **Whisper transcription** (slowest step)
2. **LLM refinement** (second slowest)
3. Network I/O (minimal, NFS is fast)
4. Database I/O (minimal, async)

### Optimization Opportunities
- GPU acceleration for Whisper (5-10x faster)
- Parallel processing (multiple files)
- Model quantization (lower RAM, faster inference)
- SSD caching (reduce NFS latency)

---

## Disaster Recovery

### Backup Strategy
```
Critical Data:
├── Database (Supabase) → Auto-backed up by Supabase
├── /refined/ → Backup to external drive weekly
├── /archive/ → Original files preserved
└── Scripts → Version controlled in git
```

### Recovery Procedures
```
NAS failure:
  → Restore from backup
  → Remount on all machines
  → Resume processing

HP Pavilion failure:
  → Reinstall Ubuntu
  → Run quickstart.sh
  → Import n8n workflow
  → Resume processing (jobs tracked in DB)

HP M01-F3003W failure:
  → Reinstall Ubuntu
  → Install Whisper + Ollama
  → Copy scripts
  → Resume processing (n8n redirects)

Database failure:
  → Supabase handles recovery
  → Recent jobs may need manual reconciliation
```

---

## Future Enhancement Ideas

### Short-Term (1-2 weeks)
- Email notifications on job completion
- Web dashboard (replace CLI dashboard)
- Batch upload interface

### Medium-Term (1-3 months)
- Speaker diarization (pyannote.audio)
- Custom vocabulary per project
- Multi-language support
- Auto-translation after transcription

### Long-Term (3-6 months)
- GPU cluster for high-throughput
- Real-time transcription (live streaming)
- Video clip extraction by keyword
- API endpoint for external integrations

---

This architecture is designed to be simple, reliable, and scalable while maintaining complete control over your data and processing.

Built for your specific hardware stack: HP Pavilion + HP M01-F3003W + NAS Array.
