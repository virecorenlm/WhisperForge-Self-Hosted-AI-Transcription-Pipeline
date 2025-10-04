#!/bin/bash

# WhisperForge System Requirements Check
# Run this on each machine to verify readiness

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║        WhisperForge System Requirements Check                ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

WARNINGS=0
ERRORS=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_command() {
    if command -v $1 &> /dev/null; then
        VERSION=$($1 --version 2>&1 | head -n1)
        echo -e "${GREEN}✅${NC} $1: $VERSION"
        return 0
    else
        echo -e "${RED}❌${NC} $1: Not found"
        ERRORS=$((ERRORS+1))
        return 1
    fi
}

check_optional() {
    if command -v $1 &> /dev/null; then
        VERSION=$($1 --version 2>&1 | head -n1)
        echo -e "${GREEN}✅${NC} $1: $VERSION"
        return 0
    else
        echo -e "${YELLOW}⚠️${NC}  $1: Not found (optional)"
        WARNINGS=$((WARNINGS+1))
        return 1
    fi
}

check_memory() {
    TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')

    if [ "$TOTAL_RAM" -ge 16 ]; then
        echo -e "${GREEN}✅${NC} RAM: ${TOTAL_RAM}GB (recommended for LLM tasks)"
    elif [ "$TOTAL_RAM" -ge 8 ]; then
        echo -e "${YELLOW}⚠️${NC}  RAM: ${TOTAL_RAM}GB (minimum, may need swap)"
        WARNINGS=$((WARNINGS+1))
    else
        echo -e "${RED}❌${NC} RAM: ${TOTAL_RAM}GB (insufficient - 8GB minimum required)"
        ERRORS=$((ERRORS+1))
    fi
}

check_disk() {
    AVAILABLE=$(df -BG /home | tail -1 | awk '{print $4}' | sed 's/G//')

    if [ "$AVAILABLE" -ge 100 ]; then
        echo -e "${GREEN}✅${NC} Disk Space: ${AVAILABLE}GB available"
    elif [ "$AVAILABLE" -ge 50 ]; then
        echo -e "${YELLOW}⚠️${NC}  Disk Space: ${AVAILABLE}GB available (low)"
        WARNINGS=$((WARNINGS+1))
    else
        echo -e "${RED}❌${NC} Disk Space: ${AVAILABLE}GB available (insufficient)"
        ERRORS=$((ERRORS+1))
    fi
}

check_directory() {
    if [ -d "$1" ]; then
        echo -e "${GREEN}✅${NC} Directory exists: $1"

        # Check if writable
        if [ -w "$1" ]; then
            echo -e "   ${GREEN}✓${NC} Writable"
        else
            echo -e "   ${RED}✗${NC} Not writable"
            ERRORS=$((ERRORS+1))
        fi
    else
        echo -e "${YELLOW}⚠️${NC}  Directory missing: $1"
        WARNINGS=$((WARNINGS+1))
    fi
}

echo "📦 Core Requirements:"
echo "─────────────────────────────────────────────────────────────"

# Check OS
if [ -f /etc/os-release ]; then
    OS_NAME=$(grep ^NAME /etc/os-release | cut -d= -f2 | tr -d '"')
    OS_VERSION=$(grep ^VERSION /etc/os-release | cut -d= -f2 | tr -d '"')
    echo -e "${GREEN}✅${NC} OS: $OS_NAME $OS_VERSION"
else
    echo -e "${YELLOW}⚠️${NC}  OS: Unknown"
    WARNINGS=$((WARNINGS+1))
fi

check_memory
check_disk

echo ""
echo "🔧 Software Dependencies:"
echo "─────────────────────────────────────────────────────────────"

# Core tools
check_command bash
check_command python3
check_command node
check_command npm

# Optional but recommended
echo ""
echo "📚 Optional Tools:"
check_optional git
check_optional ffmpeg
check_optional ssh
check_optional ollama
check_optional n8n

echo ""
echo "🐍 Python Packages:"
echo "─────────────────────────────────────────────────────────────"

if command -v python3 &> /dev/null; then
    if python3 -c "import whisper" 2>/dev/null; then
        WHISPER_VER=$(python3 -c "import whisper; print(whisper.__version__)" 2>/dev/null || echo "unknown")
        echo -e "${GREEN}✅${NC} whisper: $WHISPER_VER"
    else
        echo -e "${YELLOW}⚠️${NC}  whisper: Not installed"
        echo "   Install: pip install openai-whisper"
        WARNINGS=$((WARNINGS+1))
    fi

    if python3 -c "import torch" 2>/dev/null; then
        TORCH_VER=$(python3 -c "import torch; print(torch.__version__)" 2>/dev/null)
        echo -e "${GREEN}✅${NC} torch: $TORCH_VER"
    else
        echo -e "${YELLOW}⚠️${NC}  torch: Not installed"
        echo "   Install: pip install torch"
        WARNINGS=$((WARNINGS+1))
    fi
fi

echo ""
echo "📁 Directory Structure:"
echo "─────────────────────────────────────────────────────────────"

WHISPERFORGE_ROOT="/mnt/whisperforge"

if [ -d "$WHISPERFORGE_ROOT" ]; then
    check_directory "$WHISPERFORGE_ROOT/intake"
    check_directory "$WHISPERFORGE_ROOT/processing"
    check_directory "$WHISPERFORGE_ROOT/transcripts"
    check_directory "$WHISPERFORGE_ROOT/refined"
    check_directory "$WHISPERFORGE_ROOT/archive"
else
    echo -e "${RED}❌${NC} WhisperForge root not found: $WHISPERFORGE_ROOT"
    echo "   Create with: sudo mkdir -p $WHISPERFORGE_ROOT/{intake,processing,transcripts,refined,archive}"
    ERRORS=$((ERRORS+1))
fi

echo ""
echo "🌐 Network Configuration:"
echo "─────────────────────────────────────────────────────────────"

# Check if NFS is mounted
if mount | grep -q "$WHISPERFORGE_ROOT"; then
    echo -e "${GREEN}✅${NC} NFS mount active: $WHISPERFORGE_ROOT"
else
    if [ -d "$WHISPERFORGE_ROOT" ]; then
        echo -e "${YELLOW}⚠️${NC}  NFS not mounted (using local directory)"
        WARNINGS=$((WARNINGS+1))
    fi
fi

# Check internet connectivity
if ping -c 1 8.8.8.8 &> /dev/null; then
    echo -e "${GREEN}✅${NC} Internet connectivity"
else
    echo -e "${YELLOW}⚠️${NC}  No internet connectivity (may affect initial setup)"
    WARNINGS=$((WARNINGS+1))
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}🎉 All checks passed! System ready for WhisperForge.${NC}"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠️  $WARNINGS warning(s) found. System should work but may need optimization.${NC}"
    exit 0
else
    echo -e "${RED}❌ $ERRORS error(s) and $WARNINGS warning(s) found. Please address errors before proceeding.${NC}"
    exit 1
fi
