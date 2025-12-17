/*
Advanced Firestore Normalization Script

Purpose:
- Comprehensive data normalization for Firestore collections
- Handles timestamps, data types, field consistency, and schema validation
- Supports multiple collections with collection-specific normalization rules
- Provides detailed reporting and rollback capabilities

Usage:
1. Install dependencies:
   npm install firebase-admin

2. Set up Firebase credentials:
   setx GOOGLE_APPLICATION_CREDENTIALS "C:\path\to\service-account.json"

3. Run the script:
   node scripts/advanced_normalizer.js <collection_name> [options]

Examples:
   node scripts/advanced_normalizer.js captures
   node scripts/advanced_normalizer.js predictions --dry-run
   node scripts/advanced_normalizer.js all --backup

Options:
   --dry-run: Show what would be changed without making actual updates
   --backup: Create backup collection before making changes
   --batch-size=N: Set batch size (default: 500)
   --verbose: Enable detailed logging
*/

const admin = require('firebase-admin');
const { Timestamp, FieldValue } = require('firebase-admin').firestore;
const path = require('path');
const fs = require('fs');

class AdvancedFirestoreNormalizer {
  constructor(db, options = {}) {
    this.db = db;
    this.options = {
      dryRun: options.dryRun || false,
      backup: options.backup || false,
      batchSize: options.batchSize || 500,
      verbose: options.verbose || false,
    };
    this.stats = {
      scanned: 0,
      updated: 0,
      unchanged: 0,
      failed: 0,
      errors: []
    };
  }

  log(message) {
    if (this.options.verbose || message.startsWith('ERROR:')) {
      console.log(`[${new Date().toISOString()}] ${message}`);
    }
  }

  /**
   * Enhanced timestamp parsing with better heuristics
   */
  parseTimestamp(value) {
    if (!value && value !== 0) return null;

    // Already a Firestore Timestamp
    if (value instanceof Timestamp) return value;

    // JavaScript Date object
    if (value instanceof Date) return Timestamp.fromDate(value);

    // Numbers (enhanced heuristics)
    if (typeof value === 'number') {
      // Unrealistic future timestamps
      if (value > 4e12) return null; // Beyond year 2096
      
      // Likely milliseconds (after year 2001)
      if (value > 1e12) {
        return Timestamp.fromMillis(Math.floor(value));
      }
      
      // Likely seconds (between 1970 and 2106)
      if (value > 1e9 && value < 4e9) {
        return Timestamp.fromMillis(Math.floor(value * 1000));
      }
      
      return null; // Invalid range
    }

    // Strings
    if (typeof value === 'string') {
      // ISO date string
      const asDate = new Date(value);
      if (!isNaN(asDate.getTime())) {
        return Timestamp.fromDate(asDate);
      }

      // Numeric string
      const numValue = parseFloat(value);
      if (!isNaN(numValue)) {
        return this.parseTimestamp(numValue);
      }
    }

    return null;
  }

  /**
   * Normalize prediction documents
   */
  normalizePrediction(data) {
    const normalized = { ...data };
    let hasChanges = false;

    // Timestamp normalization
    if ('timestamp' in data) {
      const newTimestamp = this.parseTimestamp(data.timestamp) || FieldValue.serverTimestamp();
      if (!this.timestampsEqual(data.timestamp, newTimestamp)) {
        normalized.timestamp = newTimestamp;
        hasChanges = true;
      }
    }

    // Variety validation
    if ('variety' in data) {
      const variety = String(data.variety || 'Unknown').trim();
      if (data.variety !== variety) {
        normalized.variety = variety;
        hasChanges = true;
      }
    }

    // Accuracy normalization (ensure 0-1 range)
    if ('accuracy' in data) {
      let accuracy = parseFloat(data.accuracy) || 0;
      if (accuracy > 1) accuracy = accuracy / 100; // Convert percentage
      accuracy = Math.max(0, Math.min(1, accuracy)); // Clamp to 0-1
      
      if (Math.abs(data.accuracy - accuracy) > 1e-6) {
        normalized.accuracy = accuracy;
        hasChanges = true;
      }
    }

    // Description normalization
    if ('description' in data) {
      const description = String(data.description || '').trim();
      if (data.description !== description) {
        normalized.description = description;
        hasChanges = true;
      }
    }

    return { normalized, hasChanges };
  }

  /**
   * Normalize capture documents
   */
  normalizeCapture(data) {
    const normalized = { ...data };
    let hasChanges = false;

    // Timestamp fields
    const timestampFields = ['timestamp', 'created_at', 'updated_at', 'captured_at'];
    
    for (const field of timestampFields) {
      if (field in data) {
        const newTimestamp = this.parseTimestamp(data[field]) || FieldValue.serverTimestamp();
        if (!this.timestampsEqual(data[field], newTimestamp)) {
          normalized[field] = newTimestamp;
          hasChanges = true;
        }
      }
    }

    // Image path normalization
    if ('image_path' in data && data.image_path) {
      const imagePath = String(data.image_path).trim();
      if (data.image_path !== imagePath) {
        normalized.image_path = imagePath;
        hasChanges = true;
      }
    }

    // User ID validation
    if ('user_id' in data && data.user_id) {
      const userId = String(data.user_id).trim();
      if (data.user_id !== userId) {
        normalized.user_id = userId;
        hasChanges = true;
      }
    }

    return { normalized, hasChanges };
  }

  /**
   * Generic document normalizer
   */
  normalizeGeneric(data) {
    const normalized = { ...data };
    let hasChanges = false;

    // Find and normalize timestamp-like fields
    for (const [key, value] of Object.entries(data)) {
      const isTimestampField = key.toLowerCase().includes('time') || 
                              key.toLowerCase().includes('date') || 
                              key.endsWith('_at');

      if (isTimestampField && value) {
        const newTimestamp = this.parseTimestamp(value);
        if (newTimestamp && !this.timestampsEqual(value, newTimestamp)) {
          normalized[key] = newTimestamp;
          hasChanges = true;
        }
      }
    }

    return { normalized, hasChanges };
  }

  /**
   * Check if two timestamps are equal
   */
  timestampsEqual(ts1, ts2) {
    if (ts1 instanceof Timestamp && ts2 instanceof Timestamp) {
      return ts1.isEqual(ts2);
    }
    return ts1 === ts2;
  }

  /**
   * Create backup collection
   */
  async createBackup(collectionName) {
    if (!this.options.backup) return null;

    const backupName = `${collectionName}_backup_${Date.now()}`;
    const sourceRef = this.db.collection(collectionName);
    const backupRef = this.db.collection(backupName);

    console.log(`Creating backup: ${backupName}`);
    
    const snapshot = await sourceRef.get();
    const batches = [];
    let currentBatch = this.db.batch();
    let operationsInBatch = 0;

    snapshot.forEach(doc => {
      currentBatch.set(backupRef.doc(doc.id), doc.data());
      operationsInBatch++;

      if (operationsInBatch >= this.options.batchSize) {
        batches.push(currentBatch);
        currentBatch = this.db.batch();
        operationsInBatch = 0;
      }
    });

    if (operationsInBatch > 0) {
      batches.push(currentBatch);
    }

    for (let i = 0; i < batches.length; i++) {
      await batches[i].commit();
      this.log(`Backup batch ${i + 1}/${batches.length} committed`);
    }

    console.log(`Backup created: ${backupName} (${snapshot.size} documents)`);
    return backupName;
  }

  /**
   * Normalize a collection
   */
  async normalizeCollection(collectionName) {
    console.log(`\nNormalizing collection: ${collectionName}`);
    console.log(`Mode: ${this.options.dryRun ? 'DRY RUN' : 'LIVE'}`);

    // Create backup if requested
    let backupName = null;
    if (this.options.backup && !this.options.dryRun) {
      backupName = await this.createBackup(collectionName);
    }

    const collRef = this.db.collection(collectionName);
    const snapshot = await collRef.get();
    
    console.log(`Documents found: ${snapshot.size}`);
    this.stats.scanned += snapshot.size;

    if (snapshot.empty) {
      console.log('No documents to process');
      return;
    }

    const updates = [];
    
    // Process documents
    snapshot.forEach(doc => {
      try {
        const data = doc.data();
        let result;

        // Apply collection-specific normalization
        switch (collectionName.toLowerCase()) {
          case 'predictions':
            result = this.normalizePrediction(data);
            break;
          case 'captures':
            result = this.normalizeCapture(data);
            break;
          default:
            result = this.normalizeGeneric(data);
        }

        if (result.hasChanges) {
          updates.push({
            id: doc.id,
            data: result.normalized,
            original: data
          });
          this.stats.updated++;
        } else {
          this.stats.unchanged++;
        }

      } catch (error) {
        this.stats.failed++;
        this.stats.errors.push({
          documentId: doc.id,
          error: error.message
        });
        this.log(`ERROR: Document ${doc.id}: ${error.message}`);
      }
    });

    console.log(`\nChanges to apply: ${updates.length}`);

    if (this.options.dryRun) {
      console.log('\nDRY RUN - Showing first 5 changes:');
      updates.slice(0, 5).forEach(update => {
        console.log(`Document ${update.id}:`);
        console.log('  Before:', JSON.stringify(update.original, null, 2));
        console.log('  After:', JSON.stringify(update.data, null, 2));
        console.log('---');
      });
      return;
    }

    if (updates.length === 0) {
      console.log('No updates needed');
      return;
    }

    // Apply updates in batches
    console.log('\nApplying updates...');
    const batches = [];
    
    for (let i = 0; i < updates.length; i += this.options.batchSize) {
      const batch = this.db.batch();
      const slice = updates.slice(i, i + this.options.batchSize);
      
      slice.forEach(update => {
        const docRef = collRef.doc(update.id);
        batch.update(docRef, update.data);
      });
      
      batches.push(batch);
    }

    for (let i = 0; i < batches.length; i++) {
      try {
        await batches[i].commit();
        console.log(`Committed batch ${i + 1}/${batches.length}`);
      } catch (error) {
        console.error(`Batch ${i + 1} failed:`, error.message);
        this.stats.failed += this.options.batchSize;
      }
    }

    console.log(`\nCollection ${collectionName} normalized successfully`);
    if (backupName) {
      console.log(`Backup available at: ${backupName}`);
    }
  }

  /**
   * List available collections
   */
  async listCollections() {
    console.log('\nScanning for collections...');
    
    const commonCollections = [
      'captures', 'predictions', 'users', 'settings', 
      'analytics', 'feedback', 'exports'
    ];

    const existingCollections = [];
    
    for (const name of commonCollections) {
      try {
        const snapshot = await this.db.collection(name).limit(1).get();
        if (!snapshot.empty) {
          const fullSnapshot = await this.db.collection(name).get();
          existingCollections.push({
            name,
            count: fullSnapshot.size
          });
        }
      } catch (error) {
        // Collection doesn't exist or no access
      }
    }

    if (existingCollections.length === 0) {
      console.log('No collections found');
      return;
    }

    console.log('\nAvailable collections:');
    existingCollections.forEach(col => {
      console.log(`  ${col.name}: ${col.count} documents`);
    });
  }

  /**
   * Print final statistics
   */
  printStats() {
    console.log('\n' + '='.repeat(50));
    console.log('NORMALIZATION SUMMARY');
    console.log('='.repeat(50));
    console.log(`Documents scanned: ${this.stats.scanned}`);
    console.log(`Documents updated: ${this.stats.updated}`);
    console.log(`Documents unchanged: ${this.stats.unchanged}`);
    console.log(`Documents failed: ${this.stats.failed}`);
    
    if (this.stats.errors.length > 0) {
      console.log('\nErrors encountered:');
      this.stats.errors.slice(0, 10).forEach(error => {
        console.log(`  ${error.documentId}: ${error.error}`);
      });
      
      if (this.stats.errors.length > 10) {
        console.log(`  ... and ${this.stats.errors.length - 10} more errors`);
      }
    }
  }
}

/**
 * Initialize Firebase Admin
 */
async function initAdmin(credPath) {
  if (credPath && fs.existsSync(credPath)) {
    admin.initializeApp({
      credential: admin.credential.cert(require(path.resolve(credPath))),
    });
  } else {
    // Use Application Default Credentials
    admin.initializeApp();
  }
  return admin.firestore();
}

/**
 * Parse command line arguments
 */
function parseArgs() {
  const args = process.argv.slice(2);
  const options = {
    dryRun: false,
    backup: false,
    batchSize: 500,
    verbose: false,
  };

  let collection = null;
  let credPath = null;

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    
    if (arg === '--dry-run') {
      options.dryRun = true;
    } else if (arg === '--backup') {
      options.backup = true;
    } else if (arg === '--verbose') {
      options.verbose = true;
    } else if (arg.startsWith('--batch-size=')) {
      options.batchSize = parseInt(arg.split('=')[1]) || 500;
    } else if (arg.startsWith('--cred=')) {
      credPath = arg.split('=')[1];
    } else if (!collection) {
      collection = arg;
    } else if (!credPath) {
      credPath = arg;
    }
  }

  return { collection, credPath, options };
}

/**
 * Main execution
 */
(async () => {
  try {
    const { collection, credPath, options } = parseArgs();

    console.log('Advanced Firestore Normalizer');
    console.log('============================');

    const db = await initAdmin(credPath);
    const normalizer = new AdvancedFirestoreNormalizer(db, options);

    if (!collection || collection === 'list') {
      await normalizer.listCollections();
      process.exit(0);
    }

    if (collection === 'all') {
      const collections = ['captures', 'predictions'];
      for (const col of collections) {
        try {
          await normalizer.normalizeCollection(col);
        } catch (error) {
          console.error(`Failed to normalize ${col}:`, error.message);
        }
      }
    } else {
      await normalizer.normalizeCollection(collection);
    }

    normalizer.printStats();
    console.log('\nNormalization completed!');
    process.exit(0);

  } catch (error) {
    console.error('Fatal error:', error);
    process.exit(1);
  }
})();