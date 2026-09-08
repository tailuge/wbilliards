#!/usr/bin/env node
/**
 * bump-version.js — local release prep for the TWA wrapper.
 *
 * Updates twa-manifest.json (appVersionName/appVersionCode) for a release tag.
 * Optional, but recommended: it keeps the manifest in sync with CI and prints
 * the URLs you need for the Obtainium catalog entry. CI derives the same
 * versionCode from the same rule (`git rev-list --count HEAD`), so a skipped
 * local run can never produce a version mismatch.
 *
 * Usage:
 *   node scripts/bump-version.js <tag>        e.g. node scripts/bump-version.js v1.0.1
 *
 * Requirements: Node 18+ (uses plain fs; no npm install needed).
 * Run from the repo root.
 */
'use strict';

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const MANIFEST = path.join(__dirname, '..', 'twa-manifest.json');

function main() {
  const tag = process.argv[2];
  if (!tag) {
    console.error('Usage: node scripts/bump-version.js <tag>   (e.g. v1.0.1)');
    process.exit(1);
  }

  const name = tag.replace(/^v/, '');
  if (!/^\d+(\.\d+)*$/.test(name)) {
    console.error(`Invalid tag "${tag}" - expected a semver-ish tag like v1.2.3 (or 1.2.3).`);
    process.exit(1);
  }

  // Same rule as .github/workflows/build.yml: versionCode = commit count on main.
  let code;
  try {
    code = execSync('git rev-list --count HEAD', { encoding: 'utf8' }).trim();
  } catch (e) {
    console.error('Failed to count commits (run from the repo root of a full clone): ' + e.message);
    process.exit(1);
  }

  const manifest = JSON.parse(fs.readFileSync(MANIFEST, 'utf8'));
  const before = JSON.stringify(manifest);

  manifest.appVersionName = name;
  manifest.appVersionCode = parseInt(code, 10);

  if (JSON.stringify(manifest) !== before) {
    // 2-space indent matches the existing file formatting.
    fs.writeFileSync(MANIFEST, JSON.stringify(manifest, null, 2) + '\n');
  }

  const repo = 'tailuge/wbilliards';
  console.log(`twa-manifest.json updated: appVersionName=${name}, appVersionCode=${code}`);
  console.log('');
  console.log('Next steps:');
  console.log(`  1. git add twa-manifest.json && git commit -m "Release ${tag}"`);
  console.log('  2. git tag ' + tag + ' && git push origin main --tags');
  console.log('  3. GitHub Actions -> Build Android TWA -> Run workflow (release_tag=' + tag + ')');
  console.log('');
  console.log('Obtainium release assets (fixed names, for the catalog config):');
  console.log('  APK: https://github.com/' + repo + '/releases/latest/download/Billiards.apk');
  console.log('  AAB: https://github.com/' + repo + '/releases/latest/download/app-release-bundle.aab');
}

main();
