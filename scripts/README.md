# Firestore Normalization Scripts

This directory contains scripts to normalize and clean up Firestore data in your Suadinians Dates application.

## Scripts Overview

### 1. `firestore_normalizer.dart` (Dart/Flutter)
A Dart script that integrates with your Flutter project for data normalization.

**Features:**
- Collection-specific normalization for `predictions` and `captures`
- Timestamp standardization to Firestore Timestamps
- Data type validation and correction
- Interactive confirmation prompts
- Detailed progress reporting

**Setup:**
```bash
cd scripts
dart pub get
```

**Usage:**
```bash
# List available collections
dart firestore_normalizer.dart --list

# Normalize specific collections
dart firestore_normalizer.dart captures
dart firestore_normalizer.dart predictions
```

### 2. `advanced_normalizer.js` (Node.js)
An enhanced Node.js script with advanced features and options.

**Features:**
- Dry-run mode to preview changes
- Automatic backup creation
- Batch processing with configurable batch sizes
- Comprehensive error handling and reporting
- Support for multiple collections

**Setup:**
```bash
cd scripts
npm init -y
npm install firebase-admin
```

**Set up Firebase credentials:**
```bash
# Windows
setx GOOGLE_APPLICATION_CREDENTIALS "C:\path\to\service-account.json"

# Or pass as argument
node advanced_normalizer.js captures C:\path\to\service-account.json
```

**Usage:**
```bash
# List available collections
node advanced_normalizer.js list

# Dry run (preview changes without applying)
node advanced_normalizer.js captures --dry-run

# Normalize with backup
node advanced_normalizer.js captures --backup

# Normalize all collections
node advanced_normalizer.js all

# Verbose output with custom batch size
node advanced_normalizer.js predictions --verbose --batch-size=100
```

### 3. `normalize_timestamps.js` (Legacy)
The original timestamp normalization script, focused specifically on timestamp fields.

## Normalization Rules

### Predictions Collection
- **timestamp**: Converts various timestamp formats to Firestore Timestamp
- **variety**: Ensures string type, defaults to "Unknown"
- **accuracy**: Normalizes to 0-1 range, converts percentages
- **description**: Ensures string type, trims whitespace

### Captures Collection  
- **timestamp/created_at/updated_at**: Timestamp normalization
- **image_path**: String validation and trimming
- **user_id**: String validation and trimming

### Generic Collections
- Auto-detects timestamp-like fields (`*time*`, `*date*`, `*_at`)
- Applies appropriate timestamp normalization

## Timestamp Normalization

The scripts handle various timestamp formats:

| Input Type | Example | Output |
|------------|---------|---------|
| Firestore Timestamp | `Timestamp(1640995200, 0)` | Unchanged |
| JavaScript Date | `new Date()` | `Timestamp.fromDate()` |
| Milliseconds | `1640995200000` | `Timestamp.fromMillis()` |
| Seconds | `1640995200` | `Timestamp.fromMillis(s * 1000)` |
| ISO String | `"2022-01-01T00:00:00Z"` | Parsed and converted |
| Invalid/Missing | `null`, `undefined` | `FieldValue.serverTimestamp()` |

## Safety Features

### Backup Protection
The Node.js script can create automatic backups:
```bash
node advanced_normalizer.js captures --backup
```

### Dry Run Mode
Preview changes before applying:
```bash
node advanced_normalizer.js captures --dry-run
```

### Batch Processing
Both scripts process documents in batches to avoid timeout issues:
- Default batch size: 500 documents
- Configurable in Node.js script: `--batch-size=N`

## Error Handling

- Invalid documents are logged but don't stop processing
- Detailed error reporting with document IDs
- Failed batches are retried automatically (Node.js)
- Comprehensive statistics at completion

## Best Practices

1. **Always test first:**
   ```bash
   # Use dry-run to see what will change
   node advanced_normalizer.js captures --dry-run
   ```

2. **Create backups for important data:**
   ```bash
   node advanced_normalizer.js captures --backup
   ```

3. **Start with small collections:**
   - Test on development data first
   - Verify results before processing production data

4. **Monitor progress:**
   ```bash
   # Use verbose mode for detailed logging
   node advanced_normalizer.js captures --verbose
   ```

## Troubleshooting

### Firebase Authentication Issues
```bash
# Ensure credentials are set
echo %GOOGLE_APPLICATION_CREDENTIALS%

# Or pass credentials explicitly
node advanced_normalizer.js captures C:\path\to\service-account.json
```

### Permission Issues
Ensure your service account has:
- `Cloud Datastore User` role (minimum)
- `Cloud Datastore Owner` role (for backups)

### Large Collections
For very large collections (>10,000 documents):
```bash
# Use smaller batch sizes
node advanced_normalizer.js large_collection --batch-size=100

# Consider running during off-peak hours
```

## Firebase Security Rules

Ensure your Firestore security rules allow the normalization operations:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow read/write for authenticated admin operations
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

For more specific rules, ensure the service account has appropriate permissions on the collections being normalized.