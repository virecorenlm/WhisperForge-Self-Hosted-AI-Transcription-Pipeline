#!/usr/bin/env node

/**
 * WhisperForge Dashboard
 * Real-time monitoring of your transcription pipeline
 */

const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

const supabase = createClient(
  process.env.VITE_SUPABASE_URL,
  process.env.VITE_SUPABASE_ANON_KEY
);

const WHISPERFORGE_ROOT = '/mnt/whisperforge';

function formatBytes(bytes) {
  if (bytes === 0) return '0 Bytes';
  const k = 1024;
  const sizes = ['Bytes', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i];
}

function formatDuration(seconds) {
  if (!seconds) return 'N/A';
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const secs = Math.floor(seconds % 60);

  if (hours > 0) return `${hours}h ${minutes}m`;
  if (minutes > 0) return `${minutes}m ${secs}s`;
  return `${secs}s`;
}

function getDirectorySize(dirPath) {
  try {
    let size = 0;
    const files = fs.readdirSync(dirPath);

    for (const file of files) {
      const filePath = path.join(dirPath, file);
      const stats = fs.statSync(filePath);

      if (stats.isFile()) {
        size += stats.size;
      } else if (stats.isDirectory()) {
        size += getDirectorySize(filePath);
      }
    }

    return size;
  } catch (err) {
    return 0;
  }
}

function getFileCount(dirPath) {
  try {
    return fs.readdirSync(dirPath).length;
  } catch (err) {
    return 0;
  }
}

async function getJobStatistics() {
  const { data: jobs, error } = await supabase
    .from('jobs')
    .select('*')
    .order('created_at', { ascending: false });

  if (error) throw error;

  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const thisWeek = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);

  const stats = {
    total: jobs.length,
    pending: jobs.filter(j => j.status === 'pending').length,
    processing: jobs.filter(j => j.status === 'processing').length,
    completed: jobs.filter(j => j.status === 'completed').length,
    failed: jobs.filter(j => j.status === 'failed').length,
    today: jobs.filter(j => new Date(j.created_at) >= today).length,
    thisWeek: jobs.filter(j => new Date(j.created_at) >= thisWeek).length,
  };

  const completedJobs = jobs.filter(j => j.status === 'completed' && j.started_at && j.completed_at);

  if (completedJobs.length > 0) {
    const totalProcessingTime = completedJobs.reduce((sum, job) => {
      const start = new Date(job.started_at);
      const end = new Date(job.completed_at);
      return sum + (end - start) / 1000;
    }, 0);

    stats.avgProcessingTime = totalProcessingTime / completedJobs.length;
  } else {
    stats.avgProcessingTime = 0;
  }

  const totalDuration = jobs.reduce((sum, job) => sum + (job.duration_seconds || 0), 0);
  stats.totalAudioDuration = totalDuration;

  return stats;
}

async function getRecentJobs(limit = 10) {
  const { data, error } = await supabase
    .from('jobs')
    .select('id, filename, status, created_at, completed_at, whisper_model')
    .order('created_at', { ascending: false })
    .limit(limit);

  if (error) throw error;
  return data;
}

async function getStorageStats() {
  const dirs = ['intake', 'processing', 'transcripts', 'refined', 'archive'];
  const stats = {};

  for (const dir of dirs) {
    const dirPath = path.join(WHISPERFORGE_ROOT, dir);
    stats[dir] = {
      size: getDirectorySize(dirPath),
      files: getFileCount(dirPath)
    };
  }

  return stats;
}

function printDashboard(jobStats, recentJobs, storageStats) {
  console.clear();

  console.log('\n╔═══════════════════════════════════════════════════════════════╗');
  console.log('║              🎙️  WhisperForge Dashboard 🎙️                  ║');
  console.log('╚═══════════════════════════════════════════════════════════════╝\n');

  console.log('📊 JOB STATISTICS');
  console.log('─────────────────────────────────────────────────────────────');
  console.log(`Total Jobs:        ${jobStats.total}`);
  console.log(`Completed:         ${jobStats.completed} ✅`);
  console.log(`Processing:        ${jobStats.processing} ⚙️`);
  console.log(`Pending:           ${jobStats.pending} ⏳`);
  console.log(`Failed:            ${jobStats.failed} ❌`);
  console.log();
  console.log(`Today:             ${jobStats.today}`);
  console.log(`This Week:         ${jobStats.thisWeek}`);
  console.log();
  console.log(`Avg Processing:    ${formatDuration(jobStats.avgProcessingTime)}`);
  console.log(`Total Audio:       ${formatDuration(jobStats.totalAudioDuration)}`);

  console.log('\n💾 STORAGE USAGE');
  console.log('─────────────────────────────────────────────────────────────');

  for (const [dir, stats] of Object.entries(storageStats)) {
    const icon = {
      'intake': '📥',
      'processing': '⚙️',
      'transcripts': '📝',
      'refined': '✨',
      'archive': '📦'
    }[dir] || '📁';

    console.log(`${icon} ${dir.padEnd(12)} ${formatBytes(stats.size).padEnd(12)} (${stats.files} files)`);
  }

  console.log('\n📋 RECENT JOBS');
  console.log('─────────────────────────────────────────────────────────────');

  if (recentJobs.length === 0) {
    console.log('No jobs yet. Drop a file in /mnt/whisperforge/intake/ to start!');
  } else {
    recentJobs.forEach(job => {
      const statusIcon = {
        'completed': '✅',
        'processing': '⚙️',
        'pending': '⏳',
        'failed': '❌'
      }[job.status] || '❓';

      const filename = job.filename.length > 40
        ? job.filename.substring(0, 37) + '...'
        : job.filename;

      const timestamp = new Date(job.created_at).toLocaleString();

      console.log(`${statusIcon} ${filename.padEnd(42)} ${timestamp}`);
    });
  }

  console.log('\n─────────────────────────────────────────────────────────────');
  console.log('Press Ctrl+C to exit | Updates every 5 seconds');
  console.log();
}

async function runDashboard() {
  try {
    const [jobStats, recentJobs, storageStats] = await Promise.all([
      getJobStatistics(),
      getRecentJobs(10),
      getStorageStats()
    ]);

    printDashboard(jobStats, recentJobs, storageStats);
  } catch (err) {
    console.error('❌ Dashboard error:', err.message);
  }
}

async function startLiveMonitoring() {
  await runDashboard();

  setInterval(async () => {
    await runDashboard();
  }, 5000);
}

if (require.main === module) {
  const command = process.argv[2];

  if (command === '--once') {
    runDashboard().then(() => process.exit(0));
  } else {
    console.log('Starting WhisperForge Dashboard...\n');
    startLiveMonitoring();
  }
}

module.exports = {
  getJobStatistics,
  getRecentJobs,
  getStorageStats
};
