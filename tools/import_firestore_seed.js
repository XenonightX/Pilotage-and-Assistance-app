#!/usr/bin/env node
/*
 * Import JSON seed files from tools/sql_to_firestore_seed.py into Firestore.
 *
 * Usage:
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/service-account.json \
 *   node tools/import_firestore_seed.js build/firestore_seed \
 *     --user-map build/legacy_user_to_uid.json
 */

const fs = require('fs');
const path = require('path');

let firebaseAdmin = null;
let Timestamp = {
  fromDate: (date) => date.toISOString(),
};
let FieldValue = {
  serverTimestamp: () => '__SERVER_TIMESTAMP__',
};

const TIMESTAMP_FIELDS = new Set([
  'created_at',
  'updated_at',
  'expired_at',
  'pilot_on_board',
  'pilot_finished',
  'vessel_start',
  'pilot_get_off',
]);

const DATE_FIELDS = new Set(['date']);

function parseArgs(argv) {
  const args = {
    seedDir: null,
    userMap: null,
    dryRun: false,
  };

  const positional = [];
  for (let index = 2; index < argv.length; index += 1) {
    const value = argv[index];
    if (value === '--user-map') {
      args.userMap = argv[index + 1];
      index += 1;
    } else if (value === '--dry-run') {
      args.dryRun = true;
    } else {
      positional.push(value);
    }
  }

  args.seedDir = positional[0];
  if (!args.seedDir) {
    throw new Error('Seed directory is required.');
  }
  return args;
}

function readJson(filePath, fallback = null) {
  if (!filePath || !fs.existsSync(filePath)) {
    return fallback;
  }
  return JSON.parse(fs.readFileSync(filePath, 'utf8'));
}

function parseDateTime(value) {
  if (typeof value !== 'string' || value.trim() === '') {
    return value;
  }

  const normalized = value.includes('T')
    ? value
    : value.replace(' ', 'T');
  const date = new Date(normalized);

  if (Number.isNaN(date.getTime())) {
    return value;
  }

  return Timestamp.fromDate(date);
}

function prepareDoc(collectionName, doc, legacyUserToUid) {
  const prepared = {};

  for (const [key, value] of Object.entries(doc)) {
    if (key === '_doc_id') {
      continue;
    }

    if (TIMESTAMP_FIELDS.has(key)) {
      prepared[key] = parseDateTime(value);
    } else if (DATE_FIELDS.has(key)) {
      prepared[key] = value;
      prepared[`${key}_ts`] = parseDateTime(`${value}T00:00:00`);
    } else {
      prepared[key] = value;
    }
  }

  if (
    collectionName === 'activity_logs' &&
    prepared.pilot_user_id != null &&
    legacyUserToUid[String(prepared.pilot_user_id)]
  ) {
    prepared.pilot_uid = legacyUserToUid[String(prepared.pilot_user_id)];
  }

  prepared.imported_at = FieldValue.serverTimestamp();
  return prepared;
}

function getDocId(collectionName, doc, legacyUserToUid) {
  if (collectionName === 'users') {
    const legacyId = String(doc.legacy_id || doc._doc_id);
    return legacyUserToUid[legacyId] || `legacy_${legacyId}`;
  }
  return String(doc._doc_id);
}

async function commitBatch(db, writes, dryRun) {
  if (writes.length === 0) {
    return;
  }

  if (dryRun) {
    return;
  }

  const batch = db.batch();
  for (const write of writes) {
    batch.set(write.ref, write.data, { merge: true });
  }
  await batch.commit();
}

async function importCollection(db, seedDir, collectionName, legacyUserToUid, dryRun) {
  const filePath = path.join(seedDir, `${collectionName}.json`);
  if (!fs.existsSync(filePath)) {
    return 0;
  }

  const docs = readJson(filePath, []);
  let pending = [];
  let count = 0;

  for (const doc of docs) {
    const docId = getDocId(collectionName, doc, legacyUserToUid);
    const data = prepareDoc(collectionName, doc, legacyUserToUid);
    pending.push({
      ref: dryRun ? null : db.collection(collectionName).doc(docId),
      data,
    });
    count += 1;

    if (pending.length >= 450) {
      await commitBatch(db, pending, dryRun);
      pending = [];
    }
  }

  await commitBatch(db, pending, dryRun);
  return count;
}

async function main() {
  const args = parseArgs(process.argv);
  const seedDir = path.resolve(args.seedDir);
  const manifest = readJson(path.join(seedDir, 'manifest.json'));
  if (!manifest) {
    throw new Error(`manifest.json not found in ${seedDir}`);
  }

  const legacyUserToUid = readJson(args.userMap, {});

  if (args.dryRun) {
    console.log('Dry run only. No data will be written.');
  } else {
    firebaseAdmin = require('firebase-admin');
    ({ Timestamp, FieldValue } = require('firebase-admin/firestore'));
    firebaseAdmin.initializeApp();
  }

  const db = args.dryRun ? null : firebaseAdmin.firestore();
  const collectionNames = Object.keys(manifest.collections);

  for (const collectionName of collectionNames) {
    const count = await importCollection(
      db,
      seedDir,
      collectionName,
      legacyUserToUid,
      args.dryRun
    );
    console.log(`${collectionName}: ${count} docs ${args.dryRun ? 'checked' : 'imported'}`);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
