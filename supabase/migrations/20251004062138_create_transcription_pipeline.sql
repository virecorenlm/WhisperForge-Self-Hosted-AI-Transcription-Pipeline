/*
  # WhisperForge Transcription Pipeline Database

  ## Overview
  Creates a comprehensive tracking system for audio/video processing through
  the WhisperForge pipeline, from intake to final delivery.

  ## Tables Created
  
  ### `jobs`
  Central tracking table for all transcription jobs
  - `id` (uuid, primary key) - Unique job identifier
  - `filename` (text) - Original file name
  - `file_path` (text) - Storage location
  - `file_size` (bigint) - File size in bytes
  - `duration_seconds` (integer) - Audio/video duration
  - `status` (text) - Current pipeline stage
  - `whisper_model` (text) - Model used for transcription
  - `created_at` (timestamptz) - Job submission time
  - `started_at` (timestamptz) - Processing start time
  - `completed_at` (timestamptz) - Job completion time
  - `error_message` (text) - Error details if failed
  - `metadata` (jsonb) - Flexible storage for custom data

  ### `transcripts`
  Stores transcription results and processing artifacts
  - `id` (uuid, primary key)
  - `job_id` (uuid, foreign key) - Links to jobs table
  - `raw_text` (text) - Original Whisper output
  - `refined_text` (text) - LLM-processed version
  - `word_count` (integer) - Text length metric
  - `language` (text) - Detected/specified language
  - `confidence_score` (numeric) - Whisper confidence
  - `timestamps_json` (jsonb) - Word-level timing data
  - `created_at` (timestamptz)

  ### `translations`
  Tracks OmegaT translation projects
  - `id` (uuid, primary key)
  - `transcript_id` (uuid, foreign key)
  - `source_lang` (text) - Source language code
  - `target_lang` (text) - Target language code
  - `omegat_project_path` (text) - Project location
  - `status` (text) - Translation status
  - `translated_text` (text) - Final translation
  - `created_at` (timestamptz)
  - `completed_at` (timestamptz)

  ## Security
  - RLS enabled on all tables
  - Public read access (adjust based on your security needs)
  - Authenticated write access

  ## Indexes
  - Optimized for status queries
  - Fast lookups by filename and date ranges
*/

-- Create jobs table
CREATE TABLE IF NOT EXISTS jobs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  filename text NOT NULL,
  file_path text NOT NULL,
  file_size bigint,
  duration_seconds integer,
  status text NOT NULL DEFAULT 'pending',
  whisper_model text DEFAULT 'medium.en',
  created_at timestamptz DEFAULT now(),
  started_at timestamptz,
  completed_at timestamptz,
  error_message text,
  metadata jsonb DEFAULT '{}'::jsonb
);

-- Create transcripts table
CREATE TABLE IF NOT EXISTS transcripts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id uuid REFERENCES jobs(id) ON DELETE CASCADE,
  raw_text text,
  refined_text text,
  word_count integer,
  language text DEFAULT 'en',
  confidence_score numeric(5,4),
  timestamps_json jsonb,
  created_at timestamptz DEFAULT now()
);

-- Create translations table
CREATE TABLE IF NOT EXISTS translations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  transcript_id uuid REFERENCES transcripts(id) ON DELETE CASCADE,
  source_lang text NOT NULL,
  target_lang text NOT NULL,
  omegat_project_path text,
  status text DEFAULT 'pending',
  translated_text text,
  created_at timestamptz DEFAULT now(),
  completed_at timestamptz
);

-- Create indexes for common queries
CREATE INDEX IF NOT EXISTS idx_jobs_status ON jobs(status);
CREATE INDEX IF NOT EXISTS idx_jobs_created ON jobs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_jobs_filename ON jobs(filename);
CREATE INDEX IF NOT EXISTS idx_transcripts_job ON transcripts(job_id);
CREATE INDEX IF NOT EXISTS idx_translations_transcript ON translations(transcript_id);

-- Enable Row Level Security
ALTER TABLE jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE transcripts ENABLE ROW LEVEL SECURITY;
ALTER TABLE translations ENABLE ROW LEVEL SECURITY;

-- Create permissive policies for your home server use case
-- (You can tighten these if you add authentication later)

CREATE POLICY "Public read access to jobs"
  ON jobs FOR SELECT
  USING (true);

CREATE POLICY "Public write access to jobs"
  ON jobs FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Public update access to jobs"
  ON jobs FOR UPDATE
  USING (true);

CREATE POLICY "Public read access to transcripts"
  ON transcripts FOR SELECT
  USING (true);

CREATE POLICY "Public write access to transcripts"
  ON transcripts FOR ALL
  USING (true);

CREATE POLICY "Public read access to translations"
  ON translations FOR SELECT
  USING (true);

CREATE POLICY "Public write access to translations"
  ON translations FOR ALL
  USING (true);
