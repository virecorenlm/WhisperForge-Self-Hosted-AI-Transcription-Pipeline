#!/usr/bin/env python3
"""
WhisperForge LLM Refinement Script
Uses local Ollama to enhance Whisper transcripts
"""

import sys
import subprocess
import json
from pathlib import Path


REFINEMENT_PROMPT = """You are a professional transcript editor. Your task:

1. Fix grammar, punctuation, and capitalization errors
2. Remove verbal filler words (um, uh, like, you know, sort of, kind of) while preserving meaning
3. Add paragraph breaks at logical topic transitions
4. Preserve all technical terms, product names, and acronyms exactly as written
5. Format lists and enumerations clearly
6. Do NOT add or invent information
7. Do NOT summarize - maintain full content

TRANSCRIPT:
{transcript}

REFINED VERSION:"""


SUMMARY_PROMPT = """Summarize this meeting transcript into a structured format:

## Key Points
- List main topics discussed

## Decisions Made
- List any decisions or conclusions

## Action Items
- List tasks mentioned with any responsible parties

## Technical Terms
- List important technical concepts or products mentioned

TRANSCRIPT:
{transcript}

SUMMARY:"""


SPEAKER_DIARIZATION_PROMPT = """Add speaker labels to this transcript. Use SPEAKER_1, SPEAKER_2, etc.
Look for conversational patterns like questions/answers, topic changes, and distinct speaking styles.
Add timestamps in [MM:SS] format every 30 seconds.

TRANSCRIPT:
{transcript}

LABELED VERSION:"""


def call_ollama(prompt, model="mistral:7b-instruct", temperature=0.2):
    """
    Call Ollama API with a prompt.

    Args:
        prompt: Text prompt for the LLM
        model: Ollama model name
        temperature: Sampling temperature (lower = more deterministic)

    Returns:
        str: Model response
    """
    try:
        result = subprocess.run(
            ["ollama", "run", model],
            input=prompt,
            capture_output=True,
            text=True,
            timeout=300
        )

        if result.returncode != 0:
            raise Exception(f"Ollama error: {result.stderr}")

        return result.stdout.strip()

    except subprocess.TimeoutExpired:
        raise Exception("Ollama processing timeout (5min limit)")
    except FileNotFoundError:
        raise Exception("Ollama not found. Install with: curl -fsSL https://ollama.com/install.sh | sh")


def refine_transcript(transcript_path, output_path, mode="refine", model="mistral:7b-instruct"):
    """
    Process transcript using local LLM.

    Args:
        transcript_path: Path to raw transcript
        output_path: Path for refined output
        mode: Processing mode (refine, summarize, diarize)
        model: Ollama model to use
    """
    transcript_path = Path(transcript_path)
    output_path = Path(output_path)

    if not transcript_path.exists():
        raise FileNotFoundError(f"Transcript not found: {transcript_path}")

    print(f"📖 Reading: {transcript_path.name}")
    with open(transcript_path, 'r', encoding='utf-8') as f:
        raw_text = f.read().strip()

    word_count = len(raw_text.split())
    print(f"📊 Input: {word_count} words")

    if word_count < 10:
        print("⚠️  Warning: Transcript is very short. Skipping LLM processing.")
        output_path.write_text(raw_text)
        return

    prompts = {
        'refine': REFINEMENT_PROMPT,
        'summarize': SUMMARY_PROMPT,
        'diarize': SPEAKER_DIARIZATION_PROMPT
    }

    if mode not in prompts:
        raise ValueError(f"Invalid mode: {mode}. Use: refine, summarize, or diarize")

    prompt = prompts[mode].format(transcript=raw_text)

    print(f"🤖 Processing with {model}...")
    print(f"   Mode: {mode}")

    try:
        refined_text = call_ollama(prompt, model)

        output_path.parent.mkdir(parents=True, exist_ok=True)
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(refined_text)

        output_words = len(refined_text.split())
        print(f"✅ Complete!")
        print(f"   📝 Output: {output_words} words")
        print(f"   📄 Saved: {output_path}")

        metadata_path = output_path.with_suffix('.meta.json')
        with open(metadata_path, 'w') as f:
            json.dump({
                'mode': mode,
                'model': model,
                'input_words': word_count,
                'output_words': output_words,
                'input_file': str(transcript_path),
                'output_file': str(output_path)
            }, f, indent=2)

        return refined_text

    except Exception as e:
        print(f"❌ LLM processing failed: {e}")
        print("   Copying original transcript as fallback...")
        output_path.write_text(raw_text)
        raise


def batch_refine(directory, output_dir=None, mode="refine"):
    """
    Process all text files in a directory.
    """
    directory = Path(directory)
    output_dir = Path(output_dir) if output_dir else directory.parent / "refined"
    output_dir.mkdir(parents=True, exist_ok=True)

    txt_files = list(directory.glob("*.txt"))

    if not txt_files:
        print(f"⚠️  No .txt files found in {directory}")
        return

    print(f"📁 Processing {len(txt_files)} files...")

    for i, txt_file in enumerate(txt_files, 1):
        print(f"\n[{i}/{len(txt_files)}] {txt_file.name}")
        output_file = output_dir / txt_file.name

        try:
            refine_transcript(txt_file, output_file, mode)
        except Exception as e:
            print(f"   ⚠️  Skipped: {e}")
            continue

    print(f"\n✅ Batch processing complete!")
    print(f"   📂 Output directory: {output_dir}")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python3 llm_refine.py <input_file> <output_file> [mode] [model]")
        print("\nModes:")
        print("  refine     - Clean up and format transcript (default)")
        print("  summarize  - Create structured summary")
        print("  diarize    - Add speaker labels (experimental)")
        print("\nModels:")
        print("  mistral:7b-instruct  - Best quality (default)")
        print("  llama3.1:8b          - Alternative option")
        print("  phi3:mini            - Faster, lower quality")
        print("\nBatch processing:")
        print("  python3 llm_refine.py --batch <directory> [output_dir] [mode]")
        sys.exit(1)

    if sys.argv[1] == "--batch":
        input_dir = sys.argv[2]
        output_dir = sys.argv[3] if len(sys.argv) > 3 else None
        mode = sys.argv[4] if len(sys.argv) > 4 else "refine"
        batch_refine(input_dir, output_dir, mode)
    else:
        input_file = sys.argv[1]
        output_file = sys.argv[2]
        mode = sys.argv[3] if len(sys.argv) > 3 else "refine"
        model = sys.argv[4] if len(sys.argv) > 4 else "mistral:7b-instruct"

        try:
            refine_transcript(input_file, output_file, mode, model)
        except Exception as e:
            print(f"❌ Error: {e}")
            sys.exit(1)
