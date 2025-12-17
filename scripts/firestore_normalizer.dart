#!/usr/bin/env dart

import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// Firestore Data Normalization Script
/// 
/// This script normalizes documents in Firestore collections by:
/// - Converting timestamp fields to proper Firestore Timestamps
/// - Standardizing data types across documents
/// - Cleaning up inconsistent field formats
/// 
/// Usage:
/// 1. Ensure Firebase is configured in your project
/// 2. Run: dart scripts/firestore_normalizer.dart [collection_name]
/// 
/// Example:
/// dart scripts/firestore_normalizer.dart captures
/// dart scripts/firestore_normalizer.dart predictions

class FirestoreNormalizer {
  static const int batchSize = 500;
  
  final FirebaseFirestore _firestore;
  
  FirestoreNormalizer(this._firestore);
  
  /// Normalize timestamp values to Firestore Timestamp objects
  dynamic normalizeTimestamp(dynamic value) {
    if (value == null) return FieldValue.serverTimestamp();
    
    // Already a Firestore Timestamp
    if (value is Timestamp) return value;
    
    // DateTime object
    if (value is DateTime) return Timestamp.fromDate(value);
    
    // Number (seconds or milliseconds)
    if (value is num) {
      final intValue = value.toInt();
      // Heuristic: values > 1e10 are likely milliseconds, otherwise seconds
      if (intValue > 1e10) {
        return Timestamp.fromMillisecondsSinceEpoch(intValue);
      } else {
        return Timestamp.fromMillisecondsSinceEpoch(intValue * 1000);
      }
    }
    
    // String
    if (value is String) {
      // Try parsing as ISO date
      final dateTime = DateTime.tryParse(value);
      if (dateTime != null) {
        return Timestamp.fromDate(dateTime);
      }
      
      // Try parsing as integer
      final intValue = int.tryParse(value);
      if (intValue != null) {
        if (intValue > 1e10) {
          return Timestamp.fromMillisecondsSinceEpoch(intValue);
        } else {
          return Timestamp.fromMillisecondsSinceEpoch(intValue * 1000);
        }
      }
    }
    
    // Fallback to server timestamp
    return FieldValue.serverTimestamp();
  }
  
  /// Normalize prediction documents specifically
  Map<String, dynamic> normalizePredictionDocument(Map<String, dynamic> data) {
    final normalized = Map<String, dynamic>.from(data);
    
    // Normalize timestamp
    if (data.containsKey('timestamp')) {
      normalized['timestamp'] = normalizeTimestamp(data['timestamp']);
    }
    
    // Ensure variety is a string
    if (data.containsKey('variety')) {
      normalized['variety'] = data['variety']?.toString() ?? 'Unknown';
    }
    
    // Ensure accuracy is a double between 0 and 1
    if (data.containsKey('accuracy')) {
      final accuracy = data['accuracy'];
      if (accuracy is num) {
        double normalizedAccuracy = accuracy.toDouble();
        // If accuracy > 1, assume it's a percentage and convert
        if (normalizedAccuracy > 1) {
          normalizedAccuracy = normalizedAccuracy / 100;
        }
        normalized['accuracy'] = normalizedAccuracy.clamp(0.0, 1.0);
      }
    }
    
    // Ensure description is a string
    if (data.containsKey('description')) {
      normalized['description'] = data['description']?.toString() ?? '';
    }
    
    return normalized;
  }
  
  /// Normalize capture documents specifically
  Map<String, dynamic> normalizeCaptureDocument(Map<String, dynamic> data) {
    final normalized = Map<String, dynamic>.from(data);
    
    // Normalize timestamp
    if (data.containsKey('timestamp')) {
      normalized['timestamp'] = normalizeTimestamp(data['timestamp']);
    }
    
    // Normalize created_at if present
    if (data.containsKey('created_at')) {
      normalized['created_at'] = normalizeTimestamp(data['created_at']);
    }
    
    // Normalize updated_at if present
    if (data.containsKey('updated_at')) {
      normalized['updated_at'] = normalizeTimestamp(data['updated_at']);
    }
    
    return normalized;
  }
  
  /// Generic document normalizer
  Map<String, dynamic> normalizeGenericDocument(Map<String, dynamic> data) {
    final normalized = Map<String, dynamic>.from(data);
    
    // Look for timestamp-like fields and normalize them
    for (final key in data.keys) {
      if (key.toLowerCase().contains('timestamp') || 
          key.toLowerCase().contains('time') ||
          key.toLowerCase().contains('date') ||
          key.toLowerCase().endsWith('_at')) {
        normalized[key] = normalizeTimestamp(data[key]);
      }
    }
    
    return normalized;
  }
  
  /// Normalize a collection of documents
  Future<void> normalizeCollection(String collectionName) async {
    print('Starting normalization of collection: $collectionName');
    
    final collection = _firestore.collection(collectionName);
    final snapshot = await collection.get();
    
    print('Found ${snapshot.docs.length} documents');
    
    if (snapshot.docs.isEmpty) {
      print('No documents found in collection $collectionName');
      return;
    }
    
    int updated = 0;
    int unchanged = 0;
    int failed = 0;
    
    final batches = <WriteBatch>[];
    WriteBatch currentBatch = _firestore.batch();
    int operationsInBatch = 0;
    
    for (final doc in snapshot.docs) {
      try {
        final data = doc.data();
        Map<String, dynamic> normalizedData;
        
        // Apply collection-specific normalization
        switch (collectionName.toLowerCase()) {
          case 'predictions':
            normalizedData = normalizePredictionDocument(data);
            break;
          case 'captures':
            normalizedData = normalizeCaptureDocument(data);
            break;
          default:
            normalizedData = normalizeGenericDocument(data);
        }
        
        // Check if normalization changed anything
        final hasChanges = !_mapEquals(data, normalizedData);
        
        if (hasChanges) {
          currentBatch.update(doc.reference, normalizedData);
          operationsInBatch++;
          updated++;
          
          // Create new batch if current one is full
          if (operationsInBatch >= batchSize) {
            batches.add(currentBatch);
            currentBatch = _firestore.batch();
            operationsInBatch = 0;
          }
        } else {
          unchanged++;
        }
        
      } catch (e) {
        print('Error processing document ${doc.id}: $e');
        failed++;
      }
    }
    
    // Add the last batch if it has operations
    if (operationsInBatch > 0) {
      batches.add(currentBatch);
    }
    
    // Execute all batches
    print('Executing ${batches.length} batches...');
    for (int i = 0; i < batches.length; i++) {
      try {
        await batches[i].commit();
        print('Committed batch ${i + 1}/${batches.length}');
      } catch (e) {
        print('Failed to commit batch ${i + 1}: $e');
        failed++;
      }
    }
    
    print('\nNormalization Summary for $collectionName:');
    print('  Documents scanned: ${snapshot.docs.length}');
    print('  Documents updated: $updated');
    print('  Documents unchanged: $unchanged');
    print('  Documents failed: $failed');
  }
  
  /// Check if two maps are equal (shallow comparison)
  bool _mapEquals(Map<String, dynamic> map1, Map<String, dynamic> map2) {
    if (map1.length != map2.length) return false;
    
    for (final key in map1.keys) {
      if (!map2.containsKey(key)) return false;
      
      final val1 = map1[key];
      final val2 = map2[key];
      
      // Special handling for FieldValue objects
      if (val1 is FieldValue || val2 is FieldValue) {
        if (val1.runtimeType != val2.runtimeType) return false;
        continue;
      }
      
      if (val1 != val2) return false;
    }
    
    return true;
  }
  
  /// List all collections and their document counts
  Future<void> listCollections() async {
    print('Available collections:');
    
    // Note: This requires admin SDK or specific setup to list collections
    // For now, we'll check common collections
    final commonCollections = ['captures', 'predictions', 'users', 'settings'];
    
    for (final collectionName in commonCollections) {
      try {
        final snapshot = await _firestore.collection(collectionName).get();
        if (snapshot.docs.isNotEmpty) {
          print('  $collectionName: ${snapshot.docs.length} documents');
        }
      } catch (e) {
        // Collection doesn't exist or no access
      }
    }
  }
}

/// Initialize Firebase and return Firestore instance
Future<FirebaseFirestore> initializeFirestore() async {
  await Firebase.initializeApp();
  return FirebaseFirestore.instance;
}

/// Main entry point
Future<void> main(List<String> arguments) async {
  try {
    print('Initializing Firebase...');
    final firestore = await initializeFirestore();
    final normalizer = FirestoreNormalizer(firestore);
    
    if (arguments.isEmpty) {
      print('Usage: dart firestore_normalizer.dart <collection_name>');
      print('       dart firestore_normalizer.dart --list');
      print('\nExamples:');
      print('  dart firestore_normalizer.dart captures');
      print('  dart firestore_normalizer.dart predictions');
      print('  dart firestore_normalizer.dart --list');
      await normalizer.listCollections();
      return;
    }
    
    final command = arguments[0];
    
    if (command == '--list' || command == '-l') {
      await normalizer.listCollections();
      return;
    }
    
    // Confirm before proceeding
    stdout.write('Normalize collection "$command"? This will modify existing documents. (y/N): ');
    final confirmation = stdin.readLineSync()?.toLowerCase();
    
    if (confirmation != 'y' && confirmation != 'yes') {
      print('Operation cancelled.');
      return;
    }
    
    await normalizer.normalizeCollection(command);
    print('\nNormalization completed successfully!');
    
  } catch (e) {
    print('Error: $e');
    exit(1);
  }
}