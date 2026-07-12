#!/usr/bin/env node
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const files = [
  '地球村网络优化报告.html',
  '地球村网络优化报告.md',
  'VPS部署方案.md',
  'earth-village-network-optimizer.sh',
  'hysteria2-vps-deploy.sh',
  'install-clients-and-clean.sh',
];

let passed = 0;
let failed = 0;

for (const file of files) {
  const filepath = path.join(__dirname, '..', file);
  if (!fs.existsSync(filepath)) {
    console.error(`  FAIL: ${file} — not found`);
    failed++;
    continue;
  }
  const stat = fs.statSync(filepath);
  if (stat.size === 0) {
    console.error(`  FAIL: ${file} — empty`);
    failed++;
  } else {
    console.log(`  PASS: ${file} (${(stat.size / 1024).toFixed(1)} KB)`);
    passed++;
  }
}

// Shell syntax check
for (const shFile of ['earth-village-network-optimizer.sh', 'hysteria2-vps-deploy.sh', 'install-clients-and-clean.sh']) {
  try {
    execSync(`bash -n "${path.join(__dirname, '..', shFile)}"`, { stdio: 'pipe' });
    console.log(`  PASS: ${shFile} — valid shell syntax`);
    passed++;
  } catch (e) {
    console.error(`  FAIL: ${shFile} — syntax error`);
    failed++;
  }
}

console.log(`\n${passed} passed, ${failed} failed`);
process.exit(failed > 0 ? 1 : 0);
