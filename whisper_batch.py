#!/usr/bin/env python3
"""
WhisperForge Batch Transcription Script
Optimized for business document processing
"""

import whisper
import sys
import json
import os
from pathlib import Path

os.environ['OMP_NUM_THREADS'] = '4'


def transcribe_file(audio_path, output_path, model_size="medium.en"):
    """
    Transcribe audio with intelligent prompting for better formatting.

    Args:
        audio_path: Path to input audio/video file
        output_path: Path for output text file
        model_size: Whisper model to use (tiny, base, small, medium, large)

    Returns:
        dict: Full transcription result with timestamps
    """
    print(f"🎙️  Loading Whisper model: {model_size}")
    model = whisper.load_model(model_size)

    initial_prompt = (
        "This is a professional business meeting or presentation. "
        "Use proper capitalization, punctuation, and paragraph formatting. "
        "Common terms include: API, SaaS, OmegaT, WhisperForge, automation, "
        "workflow, n8n, Node-RED, Supabase, database, transcription, LLM, "
        "Ollama, Docker, Kubernetes, CI/CD, DevOps, cloud, server, Ubuntu."
    )

    print(f"🎧 Transcribing: {Path(audio_path).name}")

    result = model.transcribe(
        str(audio_path),
        language="en",
        initial_prompt=initial_prompt,
        word_timestamps=True,
        condition_on_previous_text=True,
        temperature=0.0,
        compression_ratio_threshold=2.4,
        logprob_threshold=-1.0,
        no_speech_threshold=0.6
    )

    output_path = Path(output_path)

    with open(output_path.with_suffix('.json'), 'w', encoding='utf-8') as f:
        json.dump({
            'text': result['text'],
            'segments': result['segments'],
            'language': result['language']
        }, f, indent=2, ensure_ascii=False)

    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(result["text"].strip())

    word_count = len(result["text"].split())
    duration = result['segments'][-1]['end'] if result['segments'] else 0

    print(f"✅ Transcription complete!")
    print(f"   📝 Words: {word_count}")
    print(f"   ⏱️  Duration: {duration:.1f}s")
    print(f"   📄 Output: {output_path}")
    print(f"   📊 JSON: {output_path.with_suffix('.json')}")

    return result


def transcribe_with_timestamps(audio_path, output_path, model_size="medium.en"):
    """
    Transcribe with detailed timestamp formatting for meeting notes.
    """
    result = transcribe_file(audio_path, output_path, model_size)

    timestamp_output = output_path.parent / f"{output_path.stem}_timestamped.txt"

    with open(timestamp_output, 'w', encoding='utf-8') as f:
        for segment in result['segments']:
            start = segment['start']
            end = segment['end']
            text = segment['text'].strip()

            start_time = f"{int(start//60):02d}:{int(start%60):02d}"
            end_time = f"{int(end//60):02d}:{int(end%60):02d}"

            f.write(f"[{start_time} - {end_time}] {text}\n")

    print(f"   🕒 Timestamped: {timestamp_output}")

    return result


def get_file_duration(audio_path):
    """
    Get audio duration using ffprobe.
    """
    import subprocess

    try:
        result = subprocess.run(
            ['ffprobe', '-v', 'error', '-show_entries',
             'format=duration', '-of', 'json', str(audio_path)],
            capture_output=True,
            text=True
        )
        data = json.loads(result.stdout)
        return float(data['format']['duration'])
    except Exception as e:
        print(f"⚠️  Could not get duration: {e}")
        return None


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python3 whisper_batch.py <audio_file> <output_file> [model_size]")
        print("\nModel sizes:")
        print("  tiny.en    - Fastest, lowest quality (~1GB RAM)")
        print("  base.en    - Fast, decent quality (~1GB RAM)")
        print("  small.en   - Good balance (~2GB RAM)")
        print("  medium.en  - High quality (~5GB RAM) [RECOMMENDED]")
        print("  large      - Best quality (~10GB RAM)")
        sys.exit(1)

    audio_file = Path(sys.argv[1])
    output_file = Path(sys.argv[2])
    model_size = sys.argv[3] if len(sys.argv) > 3 else "medium.en"

    if not audio_file.exists():
        print(f"❌ Error: Audio file not found: {audio_file}")
        sys.exit(1)

    output_file.parent.mkdir(parents=True, exist_ok=True)

    duration = get_file_duration(audio_file)
    if duration:
        print(f"📊 File duration: {int(duration//60)}m {int(duration%60)}s")

        if duration > 3600:
            print("⚠️  Warning: File is longer than 1 hour. Consider splitting for better performance.")

    try:
        if '--timestamps' in sys.argv:
            transcribe_with_timestamps(audio_file, output_file, model_size)
        else:
            transcribe_file(audio_file, output_file, model_size)
    except Exception as e:
        print(f"❌ Transcription failed: {e}")
        sys.exit(1)
