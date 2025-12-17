/*
Firestore Timestamp Normalization Script

Purpose:
- Scan the `captures` collection and normalize the `timestamp` field to Firestore Timestamp objects.

Usage:
1. Install Node.js (>=14) and initialize a small project in this workspace or scripts folder:
   npm init -y
   npm install firebase-admin

2. Provide Firebase credentials. Two options:
   - Set environment variable:
       setx GOOGLE_APPLICATION_CREDENTIALS "C:\path\to\service-account.json"
     (Restart your shell/IDE so env var takes effect)
   - Or pass the path as the first argument to the script.

3. Run the script from the repository root (PowerShell example):
   node scripts/normalize_timestamps.js C:\path\to\service-account.json

Notes:
- The script makes batched updates (max 500 writes per batch) and logs summary counts.
- It attempts to convert these timestamp shapes:
  - Firestore Timestamp -> left unchanged
  - JavaScript Date / ISO string -> parsed
  - Numeric (seconds or milliseconds) -> interpreted heuristically
  - String containing integer -> parsed as number
  - Missing/null -> sets `timestamp` to serverTimestamp()

Use with care: run on a small sample or backup first.
*/

const admin = require('firebase-admin');
const {Timestamp, FieldValue} = require('firebase-admin').firestore;
const path = require('path');

async function initAdmin(credPath) {
  if (credPath) {
    admin.initializeApp({
      credential: admin.credential.cert(require(path.resolve(credPath))),
    });
  } else {
    // try Application Default Credentials
    admin.initializeApp();
  }
  return admin.firestore();
}

function parsePossibleTimestamp(value) {
  // If already a Firestore Timestamp, return equivalent Timestamp
  if (!value && value !== 0) return null;

  // firebase-admin may hand us Timestamp-like objects from reads; detect
  if (value instanceof Timestamp) return value;

  // If value is a plain JS Date
  if (value instanceof Date) return Timestamp.fromDate(value);

  // Numbers: could be seconds or milliseconds
  if (typeof value === 'number') {
    // Heuristic: if value > 1e12 assume milliseconds, if between 1e9 and 1e12 assume milliseconds too (modern millis ~1.6e12), if too small assume seconds
    if (value > 1e14) {
      // unrealistic: treat as milliseconds
      return Timestamp.fromMillis(Math.floor(value));
    }
    // if value looks like seconds (e.g., 1.6e9 .. 1e10), convert to ms
    if (value < 1e11) {
      // probably seconds
      return Timestamp.fromMillis(Math.floor(value * 1000));
    }
    // otherwise treat as millis
    return Timestamp.fromMillis(Math.floor(value));
  }

  // Strings: try ISO date parsing or integer parsing
  if (typeof value === 'string') {
    // try ISO
    const asDate = new Date(value);
    if (!isNaN(asDate.getTime())) {
      return Timestamp.fromDate(asDate);
    }
    // try integer
    const intv = parseInt(value, 10);
    if (!isNaN(intv)) {
      // same heuristic
      if (intv < 1e11) {
        return Timestamp.fromMillis(intv * 1000);
      }
      return Timestamp.fromMillis(intv);
    }
  }

  // Unknown type: return null to indicate no conversion
  return null;
}

async function normalizeCollection(db, collectionPath, batchSize = 500) {
  console.log(`Scanning collection: ${collectionPath}`);
  const collRef = db.collection(collectionPath);
  const snapshot = await collRef.get();
  console.log(`Documents found: ${snapshot.size}`);

  let updates = 0;
  let unchanged = 0;
  let failed = 0;
  const toUpdate = [];

  snapshot.forEach(doc => {
    const data = doc.data();
    const raw = data && Object.prototype.hasOwnProperty.call(data, 'timestamp') ? data.timestamp : undefined;

    // If already a Firestore Timestamp object (admin.firestore.Timestamp), skip
    if (raw && raw._nanoseconds !== undefined && raw._seconds !== undefined) {
      unchanged++;
      return;
    }

    const parsed = parsePossibleTimestamp(raw);
    if (parsed) {
      // parsed is a firebase-admin Timestamp
      // If raw was already a Timestamp-like object, we counted it earlier; here treat as update
      toUpdate.push({id: doc.id, ts: parsed});
      updates++;
    } else {
      // If timestamp was missing/null or couldn't be parsed, set serverTimestamp
      toUpdate.push({id: doc.id, ts: FieldValue.serverTimestamp()});
      updates++;
    }
  });

  console.log(`Will update ${toUpdate.length} documents (set timestamp normalized).`);

  // Apply updates in batches
  for (let i = 0; i < toUpdate.length; i += batchSize) {
    const batch = db.batch();
    const slice = toUpdate.slice(i, i + batchSize);
    slice.forEach(item => {
      const docRef = collRef.doc(item.id);
      // If item.ts is a FieldValue (serverTimestamp), use it directly
      if (item.ts && item.ts._methodName && item.ts._methodName === 'FieldValue.serverTimestamp') {
        batch.update(docRef, { timestamp: admin.firestore.FieldValue.serverTimestamp() });
      } else if (item.ts instanceof Timestamp) {
        batch.update(docRef, { timestamp: item.ts });
      } else {
        // fallback: set serverTimestamp
        batch.update(docRef, { timestamp: admin.firestore.FieldValue.serverTimestamp() });
      }
    });
    try {
      await batch.commit();
      console.log(`Committed batch ${i / batchSize + 1} (${slice.length} writes)`);
    } catch (err) {
      console.error('Batch commit failed:', err);
      failed += slice.length;
    }
  }

  console.log('Normalization summary:');
  console.log(`  documents scanned: ${snapshot.size}`);
  console.log(`  updated: ${updates}`);
  console.log(`  unchanged: ${unchanged}`);
  console.log(`  failed: ${failed}`);
}

(async () => {
  try {
    const credPath = process.argv[2];
    const db = await initAdmin(credPath);
    await normalizeCollection(db, 'captures');
    console.log('Done.');
    process.exit(0);
  } catch (err) {
    console.error('Fatal error:', err);
    process.exit(2);
  }
})();
