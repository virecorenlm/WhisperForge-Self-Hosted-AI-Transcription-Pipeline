#!/bin/bash

# WhisperForge Quick Start Script
# Run this on your Orchestration Server (orchestration server)

set -e

WHISPERFORGE_ROOT="/mnt/whisperforge"
PROJECT_DIR="$HOME/whisperforge"

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║         🎙️  WhisperForge Quick Start Setup 🎙️               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Check if running on correct machine
read -p "Is this the Orchestration Server (orchestration server)? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ This script should run on your orchestration server."
    exit 1
fi

echo "📋 Pre-flight checklist..."
echo ""

# Check Node.js
if ! command -v node &> /dev/null; then
    echo "❌ Node.js not found. Install with:"
    echo "   curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -"
    echo "   sudo apt install nodejs -y"
    exit 1
fi
echo "✅ Node.js $(node --version)"

# Check npm
if ! command -v npm &> /dev/null; then
    echo "❌ npm not found."
    exit 1
fi
echo "✅ npm $(npm --version)"

# Check if WhisperForge directory exists
if [ ! -d "$WHISPERFORGE_ROOT" ]; then
    echo "❌ $WHISPERFORGE_ROOT not found."
    echo "   Please create the directory structure first:"
    echo "   sudo mkdir -p $WHISPERFORGE_ROOT/{intake,processing,transcripts,refined,archive,omegat-projects}"
    exit 1
fi
echo "✅ WhisperForge root directory exists"

echo ""
echo "🔧 Setting up project directory..."

# Create project directory if it doesn't exist
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# Check if .env exists
if [ ! -f ".env" ]; then
    echo ""
    echo "📝 Supabase configuration needed."
    read -p "Enter your Supabase URL: " SUPABASE_URL
    read -p "Enter your Supabase Anon Key: " SUPABASE_KEY

    cat > .env <<EOF
VITE_SUPABASE_URL=$SUPABASE_URL
VITE_SUPABASE_ANON_KEY=$SUPABASE_KEY
EOF
    echo "✅ .env file created"
else
    echo "✅ .env file already exists"
fi

# Install Node dependencies
echo ""
echo "📦 Installing Node.js dependencies..."
if [ ! -f "package.json" ]; then
    npm init -y
fi

npm install @supabase/supabase-js dotenv

echo ""
echo "✅ Dependencies installed"

# Create scripts directory
mkdir -p ~/scripts

echo ""
echo "🐍 Python environment check..."

# Check Python
if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 not found."
    exit 1
fi
echo "✅ Python $(python3 --version)"

echo ""
echo "📊 Testing database connection..."
node -e "
const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabase = createClient(
  process.env.VITE_SUPABASE_URL,
  process.env.VITE_SUPABASE_ANON_KEY
);

supabase.from('jobs').select('count').single().then(result => {
  if (result.error && result.error.code !== 'PGRST116') {
    console.log('❌ Database connection failed:', result.error.message);
    process.exit(1);
  }
  console.log('✅ Database connection successful');
}).catch(err => {
  console.log('❌ Database error:', err.message);
  process.exit(1);
});
"

echo ""
echo "🎉 Setup complete!"
echo ""
echo "Next steps:"
echo ""
echo "1. Set up your LLM machine (Compute Server):"
echo "   - Install Whisper: pip install openai-whisper"
echo "   - Install Ollama: curl -fsSL https://ollama.com/install.sh | sh"
echo "   - Pull model: ollama pull mistral:7b-instruct"
echo "   - Copy whisper_batch.py and llm_refine.py to ~/scripts/"
echo ""
echo "2. Configure SSH access:"
echo "   - ssh-keygen -t ed25519"
echo "   - ssh-copy-id user@llm-machine-ip"
echo ""
echo "3. Install n8n:"
echo "   - npm install -g n8n"
echo "   - Import workflow from n8n-workflow-template.json"
echo ""
echo "4. Test the pipeline:"
echo "   - Drop a test audio file in $WHISPERFORGE_ROOT/intake/"
echo "   - Monitor with: node dashboard.js"
echo ""
echo "5. Read the full guide:"
echo "   - cat DEPLOYMENT_GUIDE.md"
echo ""
echo "🚀 Ready to build your transcription empire!"
