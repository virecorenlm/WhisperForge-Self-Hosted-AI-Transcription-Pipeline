#!/usr/bin/env node

/**
 * WhisperForge Database Tracker
 * Use this from n8n workflows to track pipeline progress
 */

const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabase = createClient(
  process.env.VITE_SUPABASE_URL,
  process.env.VITE_SUPABASE_ANON_KEY
);

async function createJob(filename, filepath, metadata = {}) {
  const { data, error } = await supabase
    .from('jobs')
    .insert({
      filename,
      file_path: filepath,
      status: 'pending',
      metadata
    })
    .select()
    .maybeSingle();

  if (error) throw error;
  console.log(`✓ Job created: ${data.id}`);
  return data;
}

async function updateJobStatus(jobId, status, additionalData = {}) {
  const updates = { status, ...additionalData };

  if (status === 'processing' && !additionalData.started_at) {
    updates.started_at = new Date().toISOString();
  }

  if (status === 'completed' && !additionalData.completed_at) {
    updates.completed_at = new Date().toISOString();
  }

  const { data, error } = await supabase
    .from('jobs')
    .update(updates)
    .eq('id', jobId)
    .select()
    .maybeSingle();

  if (error) throw error;
  console.log(`✓ Job ${jobId} status: ${status}`);
  return data;
}

async function saveTranscript(jobId, rawText, refinedText = null, metadata = {}) {
  const wordCount = rawText ? rawText.split(/\s+/).length : 0;

  const { data, error } = await supabase
    .from('transcripts')
    .insert({
      job_id: jobId,
      raw_text: rawText,
      refined_text: refinedText,
      word_count: wordCount,
      language: metadata.language || 'en',
      confidence_score: metadata.confidence,
      timestamps_json: metadata.timestamps
    })
    .select()
    .maybeSingle();

  if (error) throw error;
  console.log(`✓ Transcript saved for job ${jobId}`);
  return data;
}

async function createTranslation(transcriptId, sourceLang, targetLang, projectPath) {
  const { data, error } = await supabase
    .from('translations')
    .insert({
      transcript_id: transcriptId,
      source_lang: sourceLang,
      target_lang: targetLang,
      omegat_project_path: projectPath,
      status: 'pending'
    })
    .select()
    .maybeSingle();

  if (error) throw error;
  console.log(`✓ Translation project created: ${data.id}`);
  return data;
}

async function getJobStats() {
  const { data, error } = await supabase
    .from('jobs')
    .select('status, whisper_model')
    .order('created_at', { ascending: false })
    .limit(100);

  if (error) throw error;

  const stats = {
    total: data.length,
    pending: data.filter(j => j.status === 'pending').length,
    processing: data.filter(j => j.status === 'processing').length,
    completed: data.filter(j => j.status === 'completed').length,
    failed: data.filter(j => j.status === 'failed').length,
  };

  console.log('📊 Pipeline Statistics:');
  console.log(JSON.stringify(stats, null, 2));
  return stats;
}

async function getPendingJobs() {
  const { data, error } = await supabase
    .from('jobs')
    .select('*')
    .eq('status', 'pending')
    .order('created_at', { ascending: true });

  if (error) throw error;
  return data;
}

if (require.main === module) {
  const command = process.argv[2];

  const commands = {
    'create-job': async () => {
      const filename = process.argv[3];
      const filepath = process.argv[4];
      return await createJob(filename, filepath);
    },

    'update-status': async () => {
      const jobId = process.argv[3];
      const status = process.argv[4];
      return await updateJobStatus(jobId, status);
    },

    'save-transcript': async () => {
      const jobId = process.argv[3];
      const textFile = process.argv[4];
      const fs = require('fs');
      const rawText = fs.readFileSync(textFile, 'utf-8');
      return await saveTranscript(jobId, rawText);
    },

    'stats': getJobStats,

    'pending': getPendingJobs
  };

  if (commands[command]) {
    commands[command]()
      .then(result => {
        if (result) console.log(JSON.stringify(result, null, 2));
        process.exit(0);
      })
      .catch(err => {
        console.error('Error:', err.message);
        process.exit(1);
      });
  } else {
    console.log('Usage: node db-tracker.js <command> [args]');
    console.log('Commands:');
    console.log('  create-job <filename> <filepath>');
    console.log('  update-status <job-id> <status>');
    console.log('  save-transcript <job-id> <text-file>');
    console.log('  stats');
    console.log('  pending');
    process.exit(1);
  }
}

module.exports = {
  createJob,
  updateJobStatus,
  saveTranscript,
  createTranslation,
  getJobStats,
  getPendingJobs,
  supabase
};
