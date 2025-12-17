import 'package:cloud_firestore/cloud_firestore.dart';

class Prediction {
  final String variety;
  final DateTime timestamp;
  final double accuracy;
  final String description;
  final String? imagePath;

  Prediction({
    required this.variety,
    required this.timestamp,
    required this.accuracy,
    required this.description,
    this.imagePath,
  });

  factory Prediction.fromMap(Map<String, dynamic> map) {
    final timestampValue = map['timestamp'];
    DateTime resolvedTimestamp;
    if (timestampValue is Timestamp) {
      resolvedTimestamp = timestampValue.toDate();
    } else if (timestampValue is DateTime) {
      resolvedTimestamp = timestampValue;
    } else if (timestampValue is int) {
      // assume milliseconds since epoch
      resolvedTimestamp = DateTime.fromMillisecondsSinceEpoch(timestampValue);
    } else if (timestampValue is double) {
      resolvedTimestamp = DateTime.fromMillisecondsSinceEpoch(timestampValue.toInt());
    } else if (timestampValue is String) {
      // try ISO, otherwise try parse as int millis
      final parsed = DateTime.tryParse(timestampValue);
      if (parsed != null) {
        resolvedTimestamp = parsed;
      } else {
        final asInt = int.tryParse(timestampValue);
        if (asInt != null) {
          resolvedTimestamp = DateTime.fromMillisecondsSinceEpoch(asInt);
        } else {
          resolvedTimestamp = DateTime.now();
        }
      }
    } else {
      resolvedTimestamp = DateTime.now();
    }
    return Prediction(
      variety: map['variety'] as String? ?? 'Unknown',
      timestamp: resolvedTimestamp,
      accuracy: (map['accuracy'] as num?)?.toDouble() ?? 0.0,
      description: map['description'] as String? ?? '',
      imagePath: map['imagePath'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'variety': variety,
      'accuracy': accuracy,
      // store as Firestore Timestamp for consistent reads
      'timestamp': Timestamp.fromDate(timestamp),
      'description': description,
      'imagePath': imagePath,
    };
  }
}
