import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';
import 'models/prediction.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Prediction> _predictions = [];
  List<Prediction> _filteredPredictions = [];
  bool _isLoading = true;
  String _selectedMonth = 'All';

  // Gamification data
  String _expertiseLevel = 'Beginner';
  int _totalDetections = 0;
  double _averageAccuracy = 0.0;
  int _uniqueVarieties = 0;
  int _detectionStreak = 0;
  List<String> _achievements = [];
  List<String> _missingVarieties = [];

  // Consistent color mapping with camera_gallery_screen.dart
  static const Map<String, Color> _varietyColors = {
    'Sagai': Color(0xFFFFD700),
    'Amber': Color(0xFFFF8C00),
    'Sukkari': Color(0xFFD2B48C),
    'Barhi': Color(0xFF66BB6A),
    'Mabroom': Color(0xFF8B4513),
    'Safawi': Color(0xFFB22222),
    'Zahidi': Color(0xFFF0E68C),
    'Helwa': Color(0xFFA0522D),
    'Ajwa': Color(0xFF4B0082),
    'Mazafati': Color(0xFF800020),
  };

  // Helper function to canonicalize variety names (from camera_gallery_screen.dart)
  String _canonicalizeVarietyName(String variety) {
    // Remove common suffixes and normalize
    String normalized = variety.toLowerCase().trim();
    
    // Remove "dates" suffix if present
    if (normalized.endsWith(' dates')) {
      normalized = normalized.substring(0, normalized.length - 6);
    }
    
    // Capitalize first letter
    normalized = normalized.split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
    
    return normalized;
  }

  // Helper function to get variety description (from camera_gallery_screen.dart)
  String _getVarietyDescription(String variety) {
    const descriptions = {
      'Sagai Dates': 'Soft and juicy with a sweet flavor, reddish-brown skin.',
      'Amber Dates': 'Semi-dry, sweet, golden-yellow color, chewy texture.',
      'Sukkari Dates': 'Dry and sweet, ideal for baking, light brown skin.',
      'Barhi Dates': 'Soft and sweet, yellow skin when ripe, known as "king of dates".',
      'Mabroom Dates': 'Semi-dry, sweet, brown skin, firm texture.',
      'Safawi Dates': 'Semi-dry, sweet, reddish-brown skin, crunchy texture.',
      'Zahidi Dates': 'Dry, sweet, light brown skin, used in snacks.',
      'Helwa Dates': 'Soft, sweet, dark brown skin, moist flesh.',
      'Ajwa Dates': 'Soft, sweet, black skin, high nutritional value.',
      'Mazafati Dates': 'Soft, sweet, dark brown skin, elongated shape, high moisture content.',
    };
    final canonical = _canonicalizeVarietyName(variety);
    return descriptions[canonical] ?? canonical;
  }

  // Helper function to resolve variety color
  Color _resolveVarietyColor(String variety) {
    final canonical = _canonicalizeVarietyName(variety);
    return _varietyColors[canonical] ?? Colors.brown;
  }

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      debugPrint('🔍 Analytics - Current user: ${user?.uid}');
      
      if (user == null) {
        debugPrint('❌ No user authenticated for analytics');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      Query query = _firestore
          .collection('Lorenzo-SaudinianDatesdb')
          .where('userId', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true);

      debugPrint('Loading personal data for user: ${user.uid}');

      final snapshot = await query.get();
      debugPrint('📊 Analytics Query executed successfully');
      debugPrint('📊 Analytics Found ${snapshot.docs.length} documents');

      final predictions = snapshot.docs
          .map((doc) {
            try {
              final data = doc.data();
              debugPrint('📄 Analytics Document data: $data');
              final prediction = Prediction.fromMap(data as Map<String, dynamic>);
              debugPrint('✅ Analytics Successfully parsed prediction: ${prediction.variety}');
              return prediction;
            } catch (e) {
              debugPrint('❌ Analytics Error parsing document ${doc.id}: $e');
              return null;
            }
          })
          .where((prediction) => prediction != null)
          .cast<Prediction>()
          .toList();

      if (mounted) {
        setState(() {
          _predictions = predictions;
          _filteredPredictions = predictions;
          _isLoading = false;
        });
        _calculateGamificationStats();
      }
    } catch (e) {
      debugPrint('Error loading analytics: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _calculateGamificationStats() {
    if (_filteredPredictions.isEmpty) return;

    // Calculate basic stats
    _totalDetections = _filteredPredictions.length;
    _averageAccuracy = _filteredPredictions
        .map((p) => p.accuracy)
        .reduce((a, b) => a + b) / _totalDetections;
    
    // Calculate unique varieties detected
    final varieties = _filteredPredictions.map((p) => p.variety).toSet();
    _uniqueVarieties = varieties.length;
    
    // Calculate detection streak (consecutive days)
    _detectionStreak = _calculateDetectionStreak();
    
    // Determine expertise level
    _expertiseLevel = _calculateExpertiseLevel();
    
    // Calculate achievements
    _achievements = _calculateAchievements();
    
    // Find missing varieties
    _missingVarieties = _getMissingVarieties();
  }

  String _calculateExpertiseLevel() {
    final accuracy = _averageAccuracy;
    final varietyCount = _uniqueVarieties;
    final totalDetections = _totalDetections;
    
    if (accuracy >= 90 && varietyCount >= 8 && totalDetections >= 20) {
      return 'Master Date Expert';
    } else if (accuracy >= 85 && varietyCount >= 6 && totalDetections >= 15) {
      return 'Advanced Detector';
    } else if (accuracy >= 80 && varietyCount >= 4 && totalDetections >= 10) {
      return 'Skilled Identifier';
    } else if (accuracy >= 75 && varietyCount >= 3 && totalDetections >= 5) {
      return 'Learning Enthusiast';
    } else if (totalDetections >= 3) {
      return 'Beginner Explorer';
    } else {
      return 'Newcomer';
    }
  }

  int _calculateDetectionStreak() {
    if (_filteredPredictions.isEmpty) return 0;
    
    final sortedPredictions = List<Prediction>.from(_filteredPredictions)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    int streak = 1;
    DateTime currentDate = sortedPredictions.first.timestamp;
    
    for (int i = 1; i < sortedPredictions.length; i++) {
      final predictionDate = sortedPredictions[i].timestamp;
      final difference = currentDate.difference(predictionDate).inDays;
      
      if (difference <= 1) {
        streak++;
        currentDate = predictionDate;
      } else {
        break;
      }
    }
    
    return streak;
  }

  List<String> _calculateAchievements() {
    final achievements = <String>[];
    
    // Detection achievements
    if (_totalDetections >= 1) achievements.add('🎯 First Detection');
    if (_totalDetections >= 5) achievements.add('📊 5 Detections');
    if (_totalDetections >= 10) achievements.add('📈 10 Detections');
    if (_totalDetections >= 25) achievements.add('🏆 25 Detections');
    if (_totalDetections >= 50) achievements.add('💎 50 Detections');
    
    // Accuracy achievements
    if (_averageAccuracy >= 70) achievements.add('🎯 70%+ Average');
    if (_averageAccuracy >= 80) achievements.add('🌟 80%+ Average');
    if (_averageAccuracy >= 90) achievements.add('⭐ 90%+ Average');
    if (_averageAccuracy >= 95) achievements.add('👑 95%+ Average');
    
    // Variety achievements
    if (_uniqueVarieties >= 3) achievements.add('🌰 3 Varieties');
    if (_uniqueVarieties >= 5) achievements.add('🌴 5 Varieties');
    if (_uniqueVarieties >= 8) achievements.add('🌵 8 Varieties');
    if (_uniqueVarieties >= 10) achievements.add('🏅 All Varieties');
    
    // Streak achievements
    if (_detectionStreak >= 3) achievements.add('🔥 3 Day Streak');
    if (_detectionStreak >= 7) achievements.add('💥 7 Day Streak');
    if (_detectionStreak >= 14) achievements.add('⚡ 14 Day Streak');
    
    // Special achievements
    if (_hasPerfectDetection()) achievements.add('💯 Perfect Detection');
    if (_hasAllPremiumVarieties()) achievements.add('👑 Premium Collector');
    
    return achievements;
  }

  bool _hasPerfectDetection() {
    return _filteredPredictions.any((p) => p.accuracy >= 99.0);
  }

  bool _hasAllPremiumVarieties() {
    final premiumVarieties = ['Ajwa', 'Amber', 'Sukkari', 'Safawi'];
    final detected = _filteredPredictions.map((p) => p.variety).toSet();
    return premiumVarieties.every((variety) => detected.contains(variety));
  }

  List<String> _getMissingVarieties() {
    final allVarieties = [
      'Sagai', 'Amber', 'Sukkari', 'Barhi', 'Mabroom',
      'Safawi', 'Zahidi', 'Helwa', 'Ajwa', 'Mazafati'
    ];
    final detected = _filteredPredictions.map((p) => p.variety).toSet();
    return allVarieties.where((v) => !detected.contains(v)).toList();
  }

  Map<String, int> _getVarietyCounts() {
    final Map<String, int> counts = {};
    for (final prediction in _filteredPredictions) {
      final variety = prediction.variety;
      counts[variety] = (counts[variety] ?? 0) + 1;
    }
    return counts;
  }

  Map<String, double> _getVarietyAccuracy() {
    final Map<String, List<double>> accuracyMap = {};
    for (final prediction in _filteredPredictions) {
      final variety = prediction.variety;
      accuracyMap.putIfAbsent(variety, () => []).add(prediction.accuracy);
    }
    
    final Map<String, double> avgAccuracy = {};
    accuracyMap.forEach((variety, accuracies) {
      final sum = accuracies.reduce((a, b) => a + b);
      avgAccuracy[variety] = sum / accuracies.length;
    });
    
    return avgAccuracy;
  }

  List<FlSpot> _getTimelineData() {
    if (_filteredPredictions.isEmpty) {
      debugPrint('No predictions for timeline data');
      return [];
    }
    
    final Map<DateTime, int> dailyCounts = {};
    for (final prediction in _filteredPredictions) {
      final date = DateTime(
        prediction.timestamp.year,
        prediction.timestamp.month,
        prediction.timestamp.day,
      );
      dailyCounts[date] = (dailyCounts[date] ?? 0) + 1;
    }
    
    debugPrint('Daily counts: $dailyCounts');
    
    final sortedDates = dailyCounts.keys.toList()..sort();
    final List<FlSpot> spots = [];
    
    for (int i = 0; i < sortedDates.length; i++) {
      final date = sortedDates[i];
      final count = dailyCounts[date]!;
      spots.add(FlSpot(i.toDouble(), count.toDouble()));
    }
    
    debugPrint('Timeline spots: $spots');
    return spots;
  }

  Map<String, List<FlSpot>> _getVarietyTimelineData() {
    if (_filteredPredictions.isEmpty) {
      debugPrint('No predictions for variety timeline data');
      return {};
    }
    
    final Map<String, Map<DateTime, int>> varietyDailyCounts = {};
    final Set<DateTime> allDates = {};
    
    // Collect all dates and organize counts by variety
    for (final prediction in _filteredPredictions) {
      final date = DateTime(
        prediction.timestamp.year,
        prediction.timestamp.month,
        prediction.timestamp.day,
      );
      
      allDates.add(date);
      
      final variety = prediction.variety;
      varietyDailyCounts.putIfAbsent(variety, () => {});
      varietyDailyCounts[variety]![date] = (varietyDailyCounts[variety]![date] ?? 0) + 1;
    }
    
    final sortedDates = allDates.toList()..sort();
    final Map<String, List<FlSpot>> varietySpots = {};
    
    // Create stacked arrangement to prevent intersections
    final List<String> varieties = varietyDailyCounts.keys.toList();
    final Map<String, double> varietyOffsets = {};
    
    // Assign vertical offsets to each variety
    for (int i = 0; i < varieties.length; i++) {
      varietyOffsets[varieties[i]] = (i * 3.0); // 3 units spacing between each line
    }
    
    for (final variety in varieties) {
      final List<FlSpot> spots = [];
      final offset = varietyOffsets[variety]!;
      
      for (int i = 0; i < sortedDates.length; i++) {
        final date = sortedDates[i];
        final count = varietyDailyCounts[variety]![date] ?? 0;
        // Stack the count on top of the offset
        spots.add(FlSpot(i.toDouble(), offset + count.toDouble()));
      }
      varietySpots[variety] = spots;
    }
    
    debugPrint('Stacked variety timeline spots: $varietySpots');
    return varietySpots;
  }

  List<DateTime> _getSortedDates() {
    final Map<DateTime, int> dailyCounts = {};
    for (final prediction in _filteredPredictions) {
      final date = DateTime(
        prediction.timestamp.year,
        prediction.timestamp.month,
        prediction.timestamp.day,
      );
      dailyCounts[date] = (dailyCounts[date] ?? 0) + 1;
    }
    
    return dailyCounts.keys.toList()..sort();
  }

  List<LineChartBarData> _buildVarietyTimelineLines() {
    final varietyTimelineData = _getVarietyTimelineData();

    final List<LineChartBarData> lines = [];

    for (final variety in varietyTimelineData.keys) {
      final spots = varietyTimelineData[variety]!;
      // Use consistent color mapping instead of sequential colors
      final color = _resolveVarietyColor(variety);

      lines.add(LineChartBarData(
        spots: spots,
        isCurved: true,
        color: color,
        barWidth: 2,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, barData, index) {
            return FlDotCirclePainter(
              radius: 4,
              color: color,
              strokeWidth: 1,
              strokeColor: Colors.white,
            );
          },
        ),
        belowBarData: BarAreaData(
          show: true,
          color: color.withOpacity(0.1),
        ),
      ));
    }

    return lines;
  }

  double _getVarietyTimelineMax() {
    final varietyTimelineData = _getVarietyTimelineData();
    final varieties = varietyTimelineData.keys.toList();
    
    if (varieties.isEmpty) return 1.0;
    
    // Calculate max Y based on stacked arrangement
    double maxY = 0.0;
    for (int i = 0; i < varieties.length; i++) {
      final variety = varieties[i];
      final spots = varietyTimelineData[variety]!;
      final offset = (i * 3.0); // Same offset as in data generation
      
      for (final spot in spots) {
        final effectiveY = spot.y; // Already includes offset
        if (effectiveY > maxY) {
          maxY = effectiveY;
        }
      }
    }
    
    return maxY + 2.0; // Add padding at top
  }

  Widget _buildTimelineLegend() {
    final varietyTimelineData = _getVarietyTimelineData();
    if (varietyTimelineData.isEmpty) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.legend_toggle,
                size: 16,
                color: const Color(0xFF8B4513),
              ),
              const SizedBox(width: 6),
              Text(
                'Date Varieties (Stacked)',
                style: GoogleFonts.roboto(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF8B4513),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Lines are arranged vertically to prevent overlap',
            style: GoogleFonts.roboto(
              fontSize: 11,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: varietyTimelineData.keys.map((variety) {
              // Use consistent color mapping instead of sequential colors
              final color = _resolveVarietyColor(variety);
              
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    variety,
                    style: GoogleFonts.roboto(
                      fontSize: 12,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  List<BarChartGroupData> _getAccuracyBars() {
    final accuracyMap = _getVarietyAccuracy();
    
    int colorIndex = 0;
    return accuracyMap.entries.map((entry) {
      // Use consistent color mapping instead of sequential colors
      final color = _resolveVarietyColor(entry.key);
      colorIndex++;
      
      return BarChartGroupData(
        x: colorIndex - 1,
        barRods: [
          BarChartRodData(
            toY: entry.value,
            color: color,
            width: 16, // Reduced width to prevent overflow
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    }).toList();
  }

  List<PieChartSectionData> _getPieSectionsWithoutLabels() {
    final counts = _getVarietyCounts();
    final total = counts.values.fold(0, (sum, count) => sum + count);
    
    if (total == 0) return [];

    int colorIndex = 0;
    return counts.entries.map((entry) {
      // Use consistent color mapping instead of sequential colors
      final color = _resolveVarietyColor(entry.key);
      colorIndex++;

      return PieChartSectionData(
        value: entry.value.toDouble(),
        title: '', // Remove labels
        radius: 80,
        color: color,
        badgeWidget: _Badge(entry.key, color),
        badgePositionPercentageOffset: .98,
      );
    }).toList();
  }

  void _showAccuracyBarDetails(Offset position) {
    final accuracyMap = _getVarietyAccuracy();
    if (accuracyMap.isEmpty) return;
    
    // Calculate which bar was tapped based on position
    final chartWidth = 200.0;
    final chartPadding = 60.0; // Bottom padding for labels
    final availableWidth = chartWidth - chartPadding;
    
    final barWidth = availableWidth / accuracyMap.length;
    final tappedIndex = (position.dx / barWidth).floor();
    
    if (tappedIndex < 0 || tappedIndex >= accuracyMap.length) return;
    
    final varieties = accuracyMap.keys.toList();
    final tappedVariety = varieties[tappedIndex];
    final accuracy = accuracyMap[tappedVariety]!;
    
    _showVarietyDetails(tappedVariety, _getVarietyCounts()[tappedVariety] ?? 0);
  }

  List<PieChartSectionData> _getPieSections() {
    final counts = _getVarietyCounts();
    final total = counts.values.fold(0, (sum, count) => sum + count);
    
    if (total == 0) return [];

    int colorIndex = 0;
    return counts.entries.map((entry) {
      final percentage = (entry.value / total) * 100;
      // Use consistent color mapping instead of sequential colors
      final color = _resolveVarietyColor(entry.key);
      colorIndex++;

      return PieChartSectionData(
        value: entry.value.toDouble(),
        title: '${percentage.toStringAsFixed(1)}%',
        radius: 80,
        titleStyle: GoogleFonts.roboto(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        color: color,
        badgeWidget: _Badge(entry.key, color),
        badgePositionPercentageOffset: .98,
      );
    }).toList();
  }

  Prediction? _getHighestAccuracyPrediction() {
    if (_filteredPredictions.isEmpty) return null;
    return _filteredPredictions.reduce((a, b) => a.accuracy > b.accuracy ? a : b);
  }

  Prediction? _getLowestAccuracyPrediction() {
    if (_filteredPredictions.isEmpty) return null;
    return _filteredPredictions.reduce((a, b) => a.accuracy < b.accuracy ? a : b);
  }

Widget _buildLegend() {
    final counts = _getVarietyCounts();
    if (counts.isEmpty) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.legend_toggle,
                size: 16,
                color: const Color(0xFF8B4513),
              ),
              const SizedBox(width: 6),
              Text(
                'Legend',
                style: GoogleFonts.roboto(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF8B4513),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...counts.entries.map((entry) {
            // Use consistent color mapping instead of sequential colors
            final color = _resolveVarietyColor(entry.key);
            final percentage = (entry.value / counts.values.fold(0, (sum, count) => sum + count)) * 100;
            
            return GestureDetector(
              onTap: () => _showVarietyDetails(entry.key, entry.value),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            entry.key,
                            style: GoogleFonts.roboto(
                              fontSize: 12,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${entry.value} (${percentage.toStringAsFixed(1)}%)',
                            style: GoogleFonts.roboto(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
          const SizedBox(height: 8),
          Text(
            '💡 Tap any variety for details',
            style: GoogleFonts.roboto(
              fontSize: 10,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  List<String> _getAvailableMonths() {
    final Set<String> months = {'All'};
    months.add('October 2025');
    months.add('November 2025');
    return months.toList()..sort((a, b) {
      if (a == 'All') return -1;
      if (b == 'All') return 1;
      return b.compareTo(a);
    });
  }

  String _formatMonth(DateTime date) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  void _filterPredictions() {
    setState(() {
      if (_selectedMonth == 'All') {
        _filteredPredictions = _predictions;
      } else {
        _filteredPredictions = _predictions.where((prediction) {
          final predictionMonth = _formatMonth(DateTime(
            prediction.timestamp.year,
            prediction.timestamp.month,
            1,
          ));
          return predictionMonth == _selectedMonth;
        }).toList();
      }
      _calculateGamificationStats();
    });
  }

  Widget _buildExpertiseCard() {
    final levelColor = _getExpertiseColor(_expertiseLevel);
    final progress = _calculateLevelProgress();
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: levelColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: levelColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getExpertiseIcon(_expertiseLevel),
                  size: 28,
                  color: levelColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Expertise Level',
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    Text(
                      _expertiseLevel,
                      style: GoogleFonts.playfair(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Progress bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progress to Next Level',
                    style: GoogleFonts.roboto(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: GoogleFonts.roboto(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.white.withOpacity(0.3),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: levelColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Stats row
          Row(
            children: [
              _buildMiniStat('📊', _totalDetections.toString(), 'Detections'),
              const SizedBox(width: 16),
              _buildMiniStat('🎯', '${_averageAccuracy.toStringAsFixed(1)}%', 'Avg Accuracy'),
              const SizedBox(width: 16),
              _buildMiniStat('🌰', '$_uniqueVarieties/10', 'Varieties'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String emoji, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.roboto(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF8B4513),
              ),
            ),
            Text(
              label,
              style: GoogleFonts.roboto(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementHighlights() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.emoji_events,
                  color: const Color(0xFFD4AF37),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Achievements',
                  style: GoogleFonts.playfair(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF8B4513),
                  ),
                ),
                const Spacer(),
                Text(
                  '${_achievements.length} earned',
                  style: GoogleFonts.roboto(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            if (_achievements.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Start detecting dates to earn achievements!',
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _achievements.take(6).map((achievement) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFD4AF37).withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      achievement,
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF8B4513),
                      ),
                    ),
                  );
                }).toList(),
              ),
            
            if (_achievements.length > 6) ...[
              const SizedBox(height: 8),
              Text(
                '+${_achievements.length - 6} more achievements',
                style: GoogleFonts.roboto(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
            
            // Missing varieties section
            if (_missingVarieties.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B4513).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF8B4513).withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.explore,
                          size: 16,
                          color: const Color(0xFF8B4513),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Still to Discover',
                          style: GoogleFonts.roboto(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF8B4513),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _missingVarieties.map((variety) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            variety,
                            style: GoogleFonts.roboto(
                              fontSize: 11,
                              color: Colors.black87,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getExpertiseColor(String level) {
    switch (level) {
      case 'Master Date Expert':
        return const Color(0xFFD4AF37); // Gold
      case 'Advanced Detector':
        return const Color(0xFFC0C0C0); // Silver
      case 'Skilled Identifier':
        return const Color(0xFFCD7F32); // Bronze
      case 'Learning Enthusiast':
        return const Color(0xFF5A2D0C); // Dark Brown
      case 'Beginner Explorer':
        return const Color(0xFF2196F3); // Blue
      default:
        return const Color(0xFF9E9E9E); // Grey
    }
  }

  IconData _getExpertiseIcon(String level) {
    switch (level) {
      case 'Master Date Expert':
        return Icons.workspace_premium;
      case 'Advanced Detector':
        return Icons.military_tech;
      case 'Skilled Identifier':
        return Icons.stars;
      case 'Learning Enthusiast':
        return Icons.trending_up;
      case 'Beginner Explorer':
        return Icons.explore;
      default:
        return Icons.person;
    }
  }

  double _calculateLevelProgress() {
    double progress;
    switch (_expertiseLevel) {
      case 'Newcomer':
        progress = _totalDetections / 3.0;
        break;
      case 'Beginner Explorer':
        progress = (_averageAccuracy - 75) / 5.0; // 75-80%
        break;
      case 'Learning Enthusiast':
        progress = (_averageAccuracy - 80) / 5.0; // 80-85%
        break;
      case 'Skilled Identifier':
        progress = (_averageAccuracy - 85) / 5.0; // 85-90%
        break;
      case 'Advanced Detector':
        progress = (_averageAccuracy - 90) / 5.0; // 90-95%
        break;
      case 'Master Date Expert':
        progress = 1.0;
        break;
      default:
        progress = 0.0;
    }
    return progress.clamp(0.0, 1.0);
  }

  double _getAverageAccuracy() {
    if (_filteredPredictions.isEmpty) return 0.0;
    final totalAccuracy = _filteredPredictions
        .map((p) => p.accuracy)
        .fold(0.0, (sum, acc) => sum + acc);
    return totalAccuracy / _filteredPredictions.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/bg.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 3.0, sigmaY: 3.0),
          child: Container(
            color: Colors.black.withOpacity(0.4),
            child: Column(
          children: [
            // Custom AppBar
            Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top,
                left: 16,
                right: 16,
                bottom: 16,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    'Analytics',
                    style: GoogleFonts.playfair(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        _isLoading = true;
                        _predictions = [];
              });
                      _loadAnalytics();
                    },
                  ),
                ],
              ),
            ),
            // Body content
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                ),
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                        ),
                      )
                    : _predictions.isEmpty
                        ? _buildEmptyState()
                        : _buildAnalyticsContent(),
              ),
            ),
          ],
        ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 80,
              color: Colors.white.withOpacity(0.7),
            ),
            const SizedBox(height: 16),
            Text(
              'No analytics data yet',
              style: GoogleFonts.playfair(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start detecting dates to see your analytics here',
              style: GoogleFonts.roboto(
                fontSize: 16,
                color: Colors.white.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showPieChartDetails(Offset position) {
    debugPrint('=== PIE CHART TAP DEBUG ===');
    debugPrint('Tap position: $position');
    
    final counts = _getVarietyCounts();
    if (counts.isEmpty) {
      debugPrint('No counts data available');
      return;
    }
    
    debugPrint('Variety counts: $counts');
    
    // Calculate which section was tapped based on angle
    final center = Offset(100, 100); // Center of 200x200 container
    final dx = position.dx - center.dx;
    final dy = position.dy - center.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    
    debugPrint('Center: $center, DX: $dx, DY: $dy, Distance: $distance');
    
    if (distance < 40 || distance > 80) {
      debugPrint('Tap outside pie chart range (40-80)');
      return;
    }
    
    final angle = math.atan2(dy, dx);
    final normalizedAngle = (angle + math.pi / 2) % (2 * math.pi);
    
    debugPrint('Raw angle: $angle, Normalized angle: $normalizedAngle');
    
    final total = counts.values.fold(0, (sum, count) => sum + count);
    double currentAngle = 0;
    
    debugPrint('Total count: $total');
    
    for (final entry in counts.entries) {
      final sectionAngle = (entry.value / total) * 2 * math.pi;
      debugPrint('Variety: ${entry.key}, Count: ${entry.value}, Section angle: $sectionAngle, Current angle range: $currentAngle to ${currentAngle + sectionAngle}');
      
      if (normalizedAngle >= currentAngle && normalizedAngle < currentAngle + sectionAngle) {
        debugPrint('MATCH FOUND! Showing details for: ${entry.key}');
        _showVarietyCountDetails(entry.key, entry.value, total);
        break;
      }
      currentAngle += sectionAngle;
    }
    
    debugPrint('No variety matched for this tap');
    debugPrint('=== END PIE CHART DEBUG ===');
  }

  // Build invisible tap areas for pie chart sections
  Widget _buildPieTapAreas() {
    final counts = _getVarietyCounts();
    if (counts.isEmpty) return const SizedBox.shrink();
    
    final total = counts.values.fold(0, (sum, count) => sum + count);
    final center = Offset(100, 100);
    final outerRadius = 80.0;
    final innerRadius = 40.0;
    
    double currentAngle = -math.pi / 2; // Start from top
    
    List<Widget> tapAreas = [];
    
    for (final entry in counts.entries) {
      final sectionAngle = (entry.value / total) * 2 * math.pi;
      final sweepAngle = sectionAngle;
      
      // Create a custom pie slice tap area
      tapAreas.add(
        Positioned(
          left: 0,
          top: 0,
          child: GestureDetector(
            onTap: () {
              debugPrint('=== TAP ON PIE SECTION ===');
              debugPrint('Tapped on: ${entry.key}');
              _showVarietyCountDetails(entry.key, entry.value, total);
            },
            child: CustomPaint(
              size: const Size(200, 200),
              painter: _PieSlicePainter(
                center: center,
                innerRadius: innerRadius,
                outerRadius: outerRadius,
                startAngle: currentAngle,
                sweepAngle: sweepAngle,
                color: Colors.transparent, // Invisible
              ),
            ),
          ),
        ),
      );
      
      currentAngle += sweepAngle;
    }
    
    return Stack(children: tapAreas);
  }

  void _showVarietyCountDetails(String variety, int count, int total) {
    debugPrint('=== SHOWING VARIETY DIALOG ===');
    debugPrint('Variety: $variety, Count: $count, Total: $total');
    
    final percentage = ((count / total) * 100).toStringAsFixed(1);
    final varietyPredictions = _filteredPredictions.where((p) => p.variety == variety).toList();
    
    debugPrint('Found ${varietyPredictions.length} predictions for $variety');
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        'assets/app_icon_80.png',
                        width: 40,
                        height: 40,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          variety,
                          style: GoogleFonts.playfair(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF8B4513),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B4513).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.pie_chart, color: const Color(0xFF8B4513)),
                            const SizedBox(width: 8),
                            Text(
                              'Variety Distribution',
                              style: GoogleFonts.roboto(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF8B4513),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total Detections',
                                  style: GoogleFonts.roboto(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  count.toString(),
                                  style: GoogleFonts.roboto(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Percentage',
                                  style: GoogleFonts.roboto(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  '$percentage%',
                                  style: GoogleFonts.roboto(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Rank',
                                  style: GoogleFonts.roboto(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF8B4513).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _getVarietyRank(variety, count),
                                    style: GoogleFonts.roboto(
                                      fontSize: 12,
                                      color: const Color(0xFF8B4513),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Text(
                    'Detection Frequency:',
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getVarietyFrequencyInterpretation(variety, count, total),
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Average Accuracy Section
                  Text(
                    'Average Accuracy:',
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.trending_up, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '${varietyPredictions.isEmpty ? 0.0 : (varietyPredictions.map((p) => p.accuracy).reduce((a, b) => a + b) / varietyPredictions.length).toStringAsFixed(1)}%',
                          style: GoogleFonts.roboto(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Confidence Level',
                          style: GoogleFonts.roboto(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Text(
                    'Recent Detections:',
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  ...varietyPredictions.take(5).map((prediction) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${prediction.timestamp.day}/${prediction.timestamp.month}',
                              style: GoogleFonts.roboto(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${prediction.accuracy.toStringAsFixed(1)}% accuracy',
                              style: GoogleFonts.roboto(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        if (prediction.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            prediction.description,
                            style: GoogleFonts.roboto(
                              fontSize: 11,
                              color: Colors.grey[700],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _getVarietyRank(String variety, int count) {
    final counts = _getVarietyCounts();
    final sortedVarieties = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final rank = sortedVarieties.indexWhere((entry) => entry.key == variety) + 1;
    
    switch (rank) {
      case 1:
        return 'Most Detected';
      case 2:
        return '2nd Most';
      case 3:
        return '3rd Most';
      default:
        return '${rank}th';
    }
  }

  String _getVarietyFrequencyInterpretation(String variety, int count, int total) {
    final percentage = (count / total) * 100;
    
    if (percentage >= 25) {
      return '$variety is your most frequently detected date variety, representing ${percentage.toStringAsFixed(1)}% of all detections. This indicates strong familiarity and consistent practice with this type.';
    } else if (percentage >= 15) {
      return '$variety appears frequently in your detection history (${percentage.toStringAsFixed(1)}% of total). You have good experience with this variety and can likely identify it reliably.';
    } else if (percentage >= 5) {
      return '$variety appears moderately in your detections (${percentage.toStringAsFixed(1)}% of total). You have some experience with this variety but could benefit from more practice.';
    } else {
      return '$variety appears rarely in your detection history (${percentage.toStringAsFixed(1)}% of total). Consider focusing on this variety to build your comprehensive date identification skills.';
    }
  }

  void _showVarietyDetails(String variety, int count) {
    final varietyPredictions = _filteredPredictions.where((p) => p.variety == variety).toList();
    final avgAccuracy = varietyPredictions.isEmpty ? 0.0 : 
        varietyPredictions.map((p) => p.accuracy).reduce((a, b) => a + b) / varietyPredictions.length;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        'assets/app_icon_80.png',
                        width: 40,
                        height: 40,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          variety,
                          style: GoogleFonts.playfair(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF8B4513),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B4513).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.analytics, color: const Color(0xFF8B4513)),
                            const SizedBox(width: 8),
                            Text(
                              'Statistics',
                              style: GoogleFonts.roboto(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF8B4513),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total Detections',
                                  style: GoogleFonts.roboto(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  count.toString(),
                                  style: GoogleFonts.roboto(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Avg Accuracy',
                                  style: GoogleFonts.roboto(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  '${avgAccuracy.toStringAsFixed(1)}%',
                                  style: GoogleFonts.roboto(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Performance',
                                  style: GoogleFonts.roboto(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getAccuracyColor(avgAccuracy).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _getAccuracyLabel(avgAccuracy),
                                    style: GoogleFonts.roboto(
                                      fontSize: 12,
                                      color: _getAccuracyColor(avgAccuracy),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Description section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B4513).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: const Color(0xFF8B4513)),
                            const SizedBox(width: 8),
                            Text(
                              'Description',
                              style: GoogleFonts.roboto(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF8B4513),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _getVarietyDescription(variety),
                          style: GoogleFonts.roboto(
                            fontSize: 14,
                            color: Colors.black87,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Text(
                    'Recent Detections:',
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  ...varietyPredictions.take(5).map((prediction) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${prediction.timestamp.day}/${prediction.timestamp.month}',
                          style: GoogleFonts.roboto(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${prediction.accuracy.toStringAsFixed(1)}%',
                          style: GoogleFonts.roboto(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _getAccuracyColor(prediction.accuracy),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showTimelineDetails(Offset position) {
    final spots = _getTimelineData();
    if (spots.isEmpty) return;
    
    // Find the closest spot to the touch position
    final chartWidth = 200.0; // Container height
    final chartPadding = 40.0; // Approximate padding
    final availableWidth = chartWidth - chartPadding * 2;
    
    int closestIndex = 0;
    double minDistance = double.infinity;
    
    for (int i = 0; i < spots.length; i++) {
      final spotX = (i / (spots.length - 1)) * availableWidth + chartPadding;
      final distance = (position.dx - spotX).abs();
      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
      }
    }
    
    if (minDistance > 20) return; // Too far from any dot
    
    final spot = spots[closestIndex];
    final day = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt() * 86400000);
    
    // Get predictions for this day
    final dayPredictions = _filteredPredictions.where((p) {
      final predDate = DateTime(
        p.timestamp.year,
        p.timestamp.month,
        p.timestamp.day,
      );
      final spotDate = DateTime(
        day.year,
        day.month,
        day.day,
      );
      return predDate.isAtSameMomentAs(spotDate);
    }).toList();
    
    if (dayPredictions.isEmpty) return;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '📅 ${day.day}/${day.month}/${day.year}',
                        style: GoogleFonts.playfair(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF8B4513),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  Text(
                    'Total Detections: ${dayPredictions.length}',
                    style: GoogleFonts.roboto(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  ...dayPredictions.map((prediction) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      children: [
                        Image.asset(
                          'assets/app_icon_80.png',
                          width: 20,
                          height: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                prediction.variety,
                                style: GoogleFonts.roboto(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                'Accuracy: ${prediction.accuracy.toStringAsFixed(1)}%',
                                style: GoogleFonts.roboto(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getAccuracyColor(prediction.accuracy).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getAccuracyLabel(prediction.accuracy),
                            style: GoogleFonts.roboto(
                              fontSize: 10,
                              color: _getAccuracyColor(prediction.accuracy),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getAccuracyColor(double accuracy) {
    if (accuracy >= 90) return Colors.green;
    if (accuracy >= 75) return Colors.orange;
    return Colors.red;
  }

  String _getAccuracyLabel(double accuracy) {
    if (accuracy >= 90) return 'Excellent';
    if (accuracy >= 75) return 'Good';
    return 'Poor';
  }

  void _showChartInfo(String chartType) {
    String title, description, interpretation;
    List<String> insights = [];
    
    switch (chartType) {
      case 'timeline':
        title = '📈 Detection Timeline';
        description = 'This chart shows your daily detection activity over time.';
        interpretation = 'The timeline helps you understand your usage patterns and consistency in date detection.';
        insights = [
          '• Higher peaks indicate more active detection days',
          '• Consistent daily activity shows regular app usage',
          '• Gaps in the timeline may indicate periods of inactivity',
          '• Use this data to maintain consistent detection habits',
          '• Track your progress in building a comprehensive date detection database'
        ];
        break;
      case 'accuracy':
        title = '📊 Accuracy Rate by Variety';
        description = 'This chart displays the average accuracy percentage for each date variety you\'ve detected.';
        interpretation = 'Different date varieties may have varying detection accuracy based on their unique characteristics.';
        insights = [
          '• Higher accuracy indicates better model performance for that variety',
          '• Lower accuracy may suggest need for better image quality',
          '• Some varieties are easier to distinguish due to unique features',
          '• Use this insight to focus on improving detection techniques',
          '• Track which varieties need more training samples'
        ];
        break;
      case 'distribution':
        title = '🥧 Variety Distribution';
        description = 'This pie chart shows the proportion of each date variety in your detection history.';
        interpretation = 'The distribution reveals your detection preferences and the diversity of dates you\'ve analyzed.';
        insights = [
          '• Larger sections indicate frequently detected varieties',
          '• Balanced distribution shows diverse detection practice',
          '• Focus on underrepresented varieties to improve skills',
          '• Understanding distribution helps in comprehensive learning',
          '• Use this to ensure you\'re familiar with all date types'
        ];
        break;
      default:
        return;
    }
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.playfair(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF8B4513),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B4513).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'What this chart shows:',
                          style: GoogleFonts.roboto(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF8B4513),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: GoogleFonts.roboto(
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Interpretation:',
                          style: GoogleFonts.roboto(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          interpretation,
                          style: GoogleFonts.roboto(
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Text(
                    'Key Insights:',
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...insights.map((insight) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      insight,
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                  )),
                  const SizedBox(height: 16),
                  
                  Center(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B4513),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Got it!',
                        style: GoogleFonts.roboto(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnalyticsContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month Filter
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filter by Month',
                    style: GoogleFonts.playfair(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF8B4513),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedMonth,
                        isExpanded: true,
                        items: _getAvailableMonths().map((month) {
                          return DropdownMenuItem<String>(
                            value: month,
                            child: Text(
                              month,
                              style: GoogleFonts.roboto(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedMonth = value;
                              _filterPredictions();
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Summary Cards
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  title: 'Total Detections',
                  value: _filteredPredictions.length.toString(),
                  icon: Icons.visibility,
                  color: const Color(0xFF8B4513),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryCard(
                  title: 'Avg Accuracy',
                  value: '${_getAverageAccuracy().toStringAsFixed(1)}%',
                  icon: Icons.trending_up,
                  color: const Color(0xFFD2691E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Highest & Lowest Accuracy Cards
          Row(
            children: [
              Expanded(
                child: _AccuracyCard(
                  title: 'Highest Accuracy',
                  prediction: _getHighestAccuracyPrediction(),
                  icon: Icons.arrow_upward,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AccuracyCard(
                  title: 'Lowest Accuracy',
                  prediction: _getLowestAccuracyPrediction(),
                  icon: Icons.arrow_downward,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Line Chart - Timeline
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Detection Timeline',
                          style: GoogleFonts.playfair(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF8B4513),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap dots for daily details',
                    style: GoogleFonts.roboto(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Shows detection timeline for each date variety (arranged to prevent overlap)',
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => _showChartInfo('timeline'),
                    onTapDown: (details) {
                      final RenderBox box = context.findRenderObject() as RenderBox;
                      final Offset localPosition = box.globalToLocal(details.globalPosition);
                      _showTimelineDetails(localPosition);
                    },
                    child: Container(
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!.withOpacity(0.3)),
                      ),
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            drawHorizontalLine: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (value) => FlLine(
                              color: Colors.grey[300],
                              strokeWidth: 1,
                            ),
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 50,
                                interval: 3,
                                getTitlesWidget: (value, meta) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Text(
                                      value.toInt().toString(),
                                      style: GoogleFonts.roboto(
                                        fontSize: 10,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              axisNameWidget: Text(
                                'Count',
                                style: GoogleFonts.roboto(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              axisNameSize: 20,
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                getTitlesWidget: (value, meta) {
                                  final sortedDates = _getSortedDates();
                                  if (value.toInt() >= 0 && value.toInt() < sortedDates.length) {
                                    final date = sortedDates[value.toInt()];
                                    return Transform.rotate(
                                      angle: -0.3,
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          '${date.day}/${date.month}',
                                          style: GoogleFonts.roboto(
                                            fontSize: 9,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  return const Text('');
                                },
                              ),
                              axisNameWidget: Text(
                                'Date',
                                style: GoogleFonts.roboto(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              axisNameSize: 20,
                            ),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: _buildVarietyTimelineLines(),
                          minY: 0,
                          maxY: _getVarietyTimelineMax(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildTimelineLegend(),
          const SizedBox(height: 24),

          // Accuracy Bar Chart
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Accuracy Rate by Variety',
                          style: GoogleFonts.playfair(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF8B4513),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap bars for variety details',
                    style: GoogleFonts.roboto(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Shows the average accuracy percentage for each date variety',
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => _showChartInfo('accuracy'),
                    child: Container(
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!.withOpacity(0.3)),
                      ),
                      child: BarChart(
                        BarChartData(
                          gridData: FlGridData(
                            drawHorizontalLine: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (value) => FlLine(
                              color: Colors.grey[300],
                              strokeWidth: 1,
                            ),
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                interval: 20,
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    '${value.toInt()}%',
                                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                                  );
                                },
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 80,
                                getTitlesWidget: (value, meta) {
                                  final accuracyMap = _getVarietyAccuracy();
                                  final varieties = accuracyMap.keys.toList();
                                  if (value.toInt() >= 0 && value.toInt() < varieties.length) {
                                    final variety = varieties[value.toInt()];
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: SizedBox(
                                        width: 60,
                                        child: Text(
                                          variety.length > 8
                                              ? '${variety.substring(0, 6)}...'
                                              : variety,
                                          style: const TextStyle(fontSize: 9, color: Colors.grey),
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: false),
                          barGroups: _getAccuracyBars(),
                          barTouchData: BarTouchData(
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipColor: (group) => Colors.black87,
                              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                final accuracyMap = _getVarietyAccuracy();
                                final varieties = accuracyMap.keys.toList();
                                if (group.x.toInt() >= 0 && group.x.toInt() < varieties.length) {
                                  final variety = varieties[group.x.toInt()];
                                  final accuracy = accuracyMap[variety]!;
                                  return BarTooltipItem(
                                    '$variety\n${accuracy.toStringAsFixed(1)}%',
                                    const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                }
                                return null;
                              },
                            ),
                          ),
                          maxY: 100,
                          minY: 0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Pie Chart
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Variety Distribution',
                          style: GoogleFonts.playfair(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF8B4513),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap sections for variety details',
                    style: GoogleFonts.roboto(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Shows the proportion of each date variety detected',
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => _showChartInfo('distribution'),
                    onTapDown: (details) {
                      final RenderBox box = context.findRenderObject() as RenderBox;
                      final Offset localPosition = box.globalToLocal(details.globalPosition);
                      debugPrint('=== CONTAINER TAP ===');
                      debugPrint('Container tap position: $localPosition');
                      _showPieChartDetails(localPosition);
                    },
                    child: Container(
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!.withOpacity(0.3)),
                      ),
                      child: Stack(
                        children: [
                          // Background pie chart (visual only)
                          PieChart(
                            PieChartData(
                              sections: _getPieSectionsWithoutLabels(),
                              centerSpaceRadius: 40,
                              centerSpaceColor: const Color(0xFFFFF8DC),
                              sectionsSpace: 2,
                            ),
                          ),
                          // Invisible tap areas for each section
                          _buildPieTapAreas(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildLegend(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Recent Activity
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Recent Activity',
                        style: GoogleFonts.playfair(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF8B4513),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap any activity for variety details',
                    style: GoogleFonts.roboto(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._filteredPredictions.take(5).map((prediction) => _ActivityItem(prediction: prediction)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.roboto(
              fontSize: 12,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.playfair(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _VarietyItem extends StatelessWidget {
  final String variety;
  final int count;

  const _VarietyItem({
    required this.variety,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: const Color(0xFF8B4513),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              variety,
              style: GoogleFonts.roboto(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
          Text(
            '$count detections',
            style: GoogleFonts.roboto(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF8B4513),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccuracyCard extends StatelessWidget {
  final String title;
  final Prediction? prediction;
  final IconData icon;
  final Color color;

  const _AccuracyCard({
    required this.title,
    required this.prediction,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.roboto(
              fontSize: 12,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 4),
          if (prediction != null) ...[
            Text(
              prediction!.variety,
              style: GoogleFonts.playfair(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              '${prediction!.accuracy.toStringAsFixed(1)}%',
              style: GoogleFonts.roboto(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ] else ...[
            Text(
              'No data',
              style: GoogleFonts.roboto(
                fontSize: 14,
                color: color.withOpacity(0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final Prediction prediction;

  const _ActivityItem({required this.prediction});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showVarietyActivityDetails(context, prediction.variety),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF8B4513).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Image.asset(
                'assets/app_icon_80.png',
                width: 16,
                height: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prediction.variety,
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    '${prediction.accuracy.toStringAsFixed(1)}% accuracy',
                    style: GoogleFonts.roboto(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _formatTime(prediction.timestamp),
              style: GoogleFonts.roboto(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(dateTime.hour)}:${twoDigits(dateTime.minute)}';
  }

  void _showVarietyActivityDetails(BuildContext context, String variety) {
    final varietyPredictions = context.findAncestorStateOfType<_AnalyticsScreenState>()?._filteredPredictions
        .where((p) => p.variety == variety).toList() ?? [];
    
    if (varietyPredictions.isEmpty) return;
    
    final count = varietyPredictions.length;
    final avgAccuracy = varietyPredictions.map((p) => p.accuracy).reduce((a, b) => a + b) / count;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        'assets/app_icon_80.png',
                        width: 40,
                        height: 40,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          variety,
                          style: GoogleFonts.playfair(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF8B4513),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B4513).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.analytics, color: const Color(0xFF8B4513)),
                            const SizedBox(width: 8),
                            Text(
                              'Activity Statistics',
                              style: GoogleFonts.roboto(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF8B4513),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total Detections',
                                  style: GoogleFonts.roboto(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  count.toString(),
                                  style: GoogleFonts.roboto(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Avg Accuracy',
                                  style: GoogleFonts.roboto(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  '${avgAccuracy.toStringAsFixed(1)}%',
                                  style: GoogleFonts.roboto(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Performance',
                                  style: GoogleFonts.roboto(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getAccuracyColor(avgAccuracy).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _getAccuracyLabel(avgAccuracy),
                                    style: GoogleFonts.roboto(
                                      fontSize: 12,
                                      color: _getAccuracyColor(avgAccuracy),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Text(
                    'Interpretation:',
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getVarietyInterpretation(variety, count, avgAccuracy),
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Text(
                    'Recent Activity:',
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  ...varietyPredictions.take(5).map((prediction) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${prediction.timestamp.day}/${prediction.timestamp.month}',
                          style: GoogleFonts.roboto(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${prediction.accuracy.toStringAsFixed(1)}%',
                          style: GoogleFonts.roboto(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _getAccuracyColor(prediction.accuracy),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getAccuracyColor(double accuracy) {
    if (accuracy >= 90) return Colors.green;
    if (accuracy >= 75) return Colors.orange;
    return Colors.red;
  }

  String _getAccuracyLabel(double accuracy) {
    if (accuracy >= 90) return 'Excellent';
    if (accuracy >= 75) return 'Good';
    return 'Poor';
  }

  String _getVarietyInterpretation(String variety, int count, double avgAccuracy) {
    if (count >= 10 && avgAccuracy >= 85) {
      return 'You have excellent mastery of $variety dates with high accuracy and extensive practice.';
    } else if (count >= 5 && avgAccuracy >= 75) {
      return 'Good progress with $variety dates. Keep practicing to improve both accuracy and recognition speed.';
    } else if (count < 3) {
      return 'Limited experience with $variety dates. Focus on detecting more samples to build familiarity.';
    } else if (avgAccuracy < 70) {
      return 'Accuracy needs improvement for $variety dates. Study the distinguishing features more carefully.';
    } else {
      return 'Developing skills with $variety dates. Continue practicing to achieve consistent results.';
    }
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;

  const _Badge(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

// Custom painter to create invisible pie slice tap areas
class _PieSlicePainter extends CustomPainter {
  final Offset center;
  final double innerRadius;
  final double outerRadius;
  final double startAngle;
  final double sweepAngle;
  final Color color;

  _PieSlicePainter({
    required this.center,
    required this.innerRadius,
    required this.outerRadius,
    required this.startAngle,
    required this.sweepAngle,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    
    // Create pie slice path
    path.addArc(
      Rect.fromCircle(center: center, radius: outerRadius),
      startAngle,
      sweepAngle,
    );
    
    if (innerRadius > 0) {
      // Create inner circle path (for donut chart)
      path.addArc(
        Rect.fromCircle(center: center, radius: innerRadius),
        startAngle + sweepAngle,
        -sweepAngle,
      );
    }
    
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
