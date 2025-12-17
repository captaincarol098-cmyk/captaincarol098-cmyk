import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'dart:ui';
import 'models/prediction.dart';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Prediction>> _getPredictions() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      debugPrint('🔍 Current user: ${user?.uid}');
      
      if (user == null) {
        debugPrint('❌ No user authenticated');
        return [];
      }

      Query query = _firestore
          .collection('Lorenzo-SaudinianDatesdb')
          .where('userId', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true);

      debugPrint('Loading personal data for user: ${user.uid}');

      final snapshot = await query.get();
      debugPrint('📊 Query executed successfully');
      debugPrint('📊 Found ${snapshot.docs.length} documents');
      
      final predictions = snapshot.docs
          .map((doc) {
            try {
              final prediction = Prediction.fromMap(doc.data() as Map<String, dynamic>);
              debugPrint('✅ Successfully parsed prediction: ${prediction.variety}');
              return prediction;
            } catch (e) {
              debugPrint('❌ Error parsing document ${doc.id}: $e');
              return null;
            }
          })
          .where((prediction) => prediction != null)
          .cast<Prediction>()
          .toList();
      
      return predictions;
    } catch (e) {
      debugPrint('Error fetching predictions: $e');
      return [];
    }
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
                    'Detection Records',
                    style: GoogleFonts.playfair(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
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
                child: FutureBuilder<List<Prediction>>(
        future: _getPredictions(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF8B4513),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading records',
                    style: GoogleFonts.roboto(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          final predictions = snapshot.data ?? [];

          if (predictions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No detection records yet',
                    style: GoogleFonts.playfair(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start detecting dates to see your history here',
                    style: GoogleFonts.roboto(
                      fontSize: 16,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Summary Card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.history,
                      color: const Color(0xFF8B4513),
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Records',
                            style: GoogleFonts.roboto(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '${predictions.length} Detections',
                            style: GoogleFonts.playfair(
                              color: const Color(0xFF8B4513),
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Records List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: predictions.length,
                  itemBuilder: (context, index) {
                    final prediction = predictions[index];
                    return _PredictionCard(prediction: prediction);
                  },
                ),
              ),
            ],
          );
        },
      ),
              ),
            ),
          ],
        ),
          ),
        ),
      ),
    );
  }
}

class _PredictionCard extends StatelessWidget {
  final Prediction prediction;

  const _PredictionCard({required this.prediction});

  Color _getAccuracyColor(double accuracy) {
    if (accuracy >= 90) return const Color(0xFF4CAF50); // Green
    if (accuracy >= 70) return const Color(0xFFFF9800); // Orange
    return const Color(0xFFF44336); // Red
  }

  String _getQualityAssessment(double accuracy) {
    if (accuracy >= 90) return "Excellent Detection";
    if (accuracy >= 70) return "Good Detection";
    return "Fair Detection";
  }

  String _getQualityMessage(double accuracy) {
    if (accuracy >= 90) return "Perfect match! AI is very confident";
    if (accuracy >= 70) return "Confident result with good accuracy";
    return "Consider retaking photo for better results";
  }

  Map<String, String> _getDateCharacteristics(String variety) {
    final characteristics = {
      'Sagai': 'Sweet & honey-like flavor with soft, chewy texture. Perfect for everyday snacking.',
      'Amber': 'Rich, caramel-like taste with firm meaty texture. Great for gourmet presentations.',
      'Sukkari': 'Extremely sweet with melt-in-mouth texture. The "sugar date" of Saudi Arabia.',
      'Barhi': 'Unique dual variety - crunchy when fresh, soft when ripe. Mild, pleasant flavor.',
      'Mabroom': 'Balanced sweetness with firm texture. Distinctive elongated appearance.',
      'Safawi': 'Rich, complex sweetness with soft tender flesh. Premium dark date variety.',
      'Zahidi': 'Milder sweetness with firm texture. Large size makes it perfect for stuffing.',
      'Helwa': 'Delicate, subtle sweetness with soft texture. "Sweet" in Arabic for a reason.',
      'Ajwa': 'Spiritually significant with unique rich flavor. Soft texture from holy Madinah.',
      'Mazafati': 'Fresh, tender taste with high moisture. Less intense sweetness, very juicy.',
    };
    
    return {
      'taste': characteristics[variety] ?? 'Distinctive Saudi date variety with unique flavor profile.',
      'bestUse': _getBestUse(variety),
      'season': _getSeasonality(variety),
    };
  }

  String _getBestUse(String variety) {
    final uses = {
      'Sagai': 'Perfect for snacking and breaking fast during Ramadan',
      'Amber': 'Ideal for gourmet dishes and premium gift presentations',
      'Sukkari': 'Great for natural sweetening in recipes and energy bars',
      'Barhi': 'Versatile - fresh for salads, ripe for baking and smoothies',
      'Mabroom': 'Excellent for stuffing with nuts and serving with Arabic coffee',
      'Safawi': 'Perfect for date paste and traditional Saudi desserts',
      'Zahidi': 'Best for baking, stuffing, and decorative arrangements',
      'Helwa': 'Elegant choice for special occasions and refined presentations',
      'Ajwa': 'Traditionally eaten in pairs for spiritual and health benefits',
      'Mazafati': 'Perfect for fresh eating, date milk, and smoothies',
    };
    return uses[variety] ?? 'Versatile date suitable for various culinary uses';
  }

  String _getSeasonality(String variety) {
    final seasons = {
      'Sagai': 'Peak season: Sep-Oct - Best quality available now',
      'Amber': 'Peak season: Aug-Sep - Premium harvest time',
      'Sukkari': 'Peak season: Aug-Oct - Sweetest during this period',
      'Barhi': 'Peak season: Sep-Nov - Available in both fresh and ripe stages',
      'Mabroom': 'Peak season: Aug-Sep - Traditional harvest period',
      'Safawi': 'Peak season: Aug-Sep - Prime Madinah harvest',
      'Zahidi': 'Peak season: Sep-Oct - Excellent availability',
      'Helwa': 'Peak season: Aug-Sep - Limited availability, premium quality',
      'Ajwa': 'Peak season: Aug-Sep - Blessed harvest season',
      'Mazafati': 'Peak season: Sep-Oct - Fresh harvest period',
    };
    return seasons[variety] ?? 'Seasonal availability varies';
  }

  Map<String, String> _getHealthInsights(String variety) {
    final insights = {
      'Sagai': {
        'sugar': 'High natural sugars for quick energy boost',
        'nutrition': 'Rich in potassium and magnesium for heart health',
        'benefits': 'Great for post-workout recovery and maintaining healthy blood pressure',
      },
      'Amber': {
        'sugar': 'Moderate sweetness with complex carbohydrates',
        'nutrition': 'High in iron and calcium for bone health',
        'benefits': 'Excellent for energy maintenance and supporting immune function',
      },
      'Sukkari': {
        'sugar': 'Very high natural sugars - immediate energy source',
        'nutrition': 'Rich in vitamins A and K for vision and blood health',
        'benefits': 'Perfect for instant energy and supporting healthy vision',
      },
      'Barhi': {
        'sugar': 'Low glycemic index when ripe - steady energy',
        'nutrition': 'High in vitamin C when fresh, antioxidants when ripe',
        'benefits': 'Supports immune system and provides sustained energy',
      },
      'Mabroom': {
        'sugar': 'Balanced sugar content for steady energy release',
        'nutrition': 'Excellent source of B vitamins and dietary fiber',
        'benefits': 'Supports energy metabolism and digestive health',
      },
      'Safawi': {
        'sugar': 'Rich in natural sugars with antioxidant benefits',
        'nutrition': 'High in flavonoids and beneficial phytonutrients',
        'benefits': 'Anti-inflammatory properties and heart health support',
      },
      'Zahidi': {
        'sugar': 'Moderate sweetness - gentler energy source',
        'nutrition': 'Good source of copper and magnesium',
        'benefits': 'Supports nervous system health and energy production',
      },
      'Helwa': {
        'sugar': 'Delicate sweetness - lighter energy profile',
        'nutrition': 'Contains vitamin C and essential minerals',
        'benefits': 'Supports immune function and provides gentle energy',
      },
      'Ajwa': {
        'sugar': 'Natural sugars with low glycemic impact',
        'nutrition': 'Rich in unique phytonutrients and antioxidants',
        'benefits': 'Traditionally believed to have healing and protective properties',
      },
      'Mazafati': {
        'sugar': 'Mild sweetness with high moisture content',
        'nutrition': 'Rich in B vitamins and dietary fiber',
        'benefits': 'Provides gentle hydration and sustained energy',
      },
    };
    
    return insights[variety] ?? {
      'sugar': 'Natural sugars provide healthy energy',
      'nutrition': 'Contains essential vitamins and minerals',
      'benefits': 'Supports overall health and provides natural energy',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          _showImageDialog(context);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with image and basic info
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image thumbnail
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[200],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: prediction.imagePath != null
                          ? Image.file(
                              File(prediction.imagePath!),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[300],
                                  child: Icon(
                                    Icons.image_not_supported,
                                    color: Colors.grey[600],
                                    size: 32,
                                  ),
                                );
                              },
                            )
                          : Container(
                              color: Colors.grey[300],
                              child: Icon(
                                Icons.image_not_supported,
                                color: Colors.grey[600],
                                size: 32,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Main content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title and date
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                prediction.variety,
                                style: GoogleFonts.playfair(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF8B4513),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD2691E).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _formatDate(prediction.timestamp),
                                style: GoogleFonts.roboto(
                                  fontSize: 12,
                                  color: const Color(0xFFD2691E),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        
                        // Accuracy progress bar
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Accuracy: ',
                                  style: GoogleFonts.roboto(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  '${prediction.accuracy.toStringAsFixed(1)}%',
                                  style: GoogleFonts.roboto(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: _getAccuracyColor(prediction.accuracy),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Container(
                              height: 8,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color: Colors.grey[300],
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: prediction.accuracy / 100,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    color: _getAccuracyColor(prediction.accuracy),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Description and time
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prediction.description,
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  
                  // Quality Assessment Section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getAccuracyColor(prediction.accuracy).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _getAccuracyColor(prediction.accuracy).withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              prediction.accuracy >= 90 ? Icons.verified : 
                              prediction.accuracy >= 70 ? Icons.thumb_up : Icons.info,
                              size: 16,
                              color: _getAccuracyColor(prediction.accuracy),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _getQualityAssessment(prediction.accuracy),
                              style: GoogleFonts.roboto(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _getAccuracyColor(prediction.accuracy),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getQualityMessage(prediction.accuracy),
                          style: GoogleFonts.roboto(
                            fontSize: 11,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Date Characteristics Section
                  _buildInterpretationSection(
                    '🌟 Date Characteristics',
                    _getDateCharacteristics(prediction.variety),
                    Icons.food_bank,
                    const Color(0xFF8B4513),
                  ),
                  const SizedBox(height: 12),
                  
                  // Health Insights Section  
                  _buildInterpretationSection(
                    '🏥 Health Insights',
                    _getHealthInsights(prediction.variety),
                    Icons.favorite,
                    const Color(0xFFE91E63),
                  ),
                  const SizedBox(height: 8),
                  
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Detected at: ${_formatTime(prediction.timestamp)}',
                        style: GoogleFonts.roboto(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.expand_more,
                        size: 16,
                        color: Colors.grey[400],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showImageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            // Background
            Container(
              width: double.infinity,
              height: 400,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.black,
              ),
            ),
            
            // Image
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: prediction.imagePath != null
                    ? Image.file(
                        File(prediction.imagePath!),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: double.infinity,
                            height: 400,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: Colors.grey[800],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.image_not_supported,
                                  color: Colors.white,
                                  size: 64,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Image not available',
                                  style: GoogleFonts.roboto(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      )
                    : Container(
                        width: double.infinity,
                        height: 400,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.grey[800],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.image_not_supported,
                              color: Colors.white,
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Image not available',
                              style: GoogleFonts.roboto(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            
            // Close button
            Positioned(
              top: 16,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
            
            // Info overlay at bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      prediction.variety,
                      style: GoogleFonts.playfair(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getAccuracyColor(prediction.accuracy),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '${prediction.accuracy.toStringAsFixed(1)}% Accuracy',
                            style: GoogleFonts.roboto(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _formatDateTime(prediction.timestamp),
                          style: GoogleFonts.roboto(
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dateTime.month - 1]} ${dateTime.day}';
  }

  String _formatDateTime(DateTime dateTime) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${months[dateTime.month - 1]} ${dateTime.day}, ${twoDigits(dateTime.hour)}:${twoDigits(dateTime.minute)}';
  }

  String _formatTime(DateTime dateTime) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(dateTime.hour)}:${twoDigits(dateTime.minute)}';
  }

  Widget _buildInterpretationSection(String title, Map<String, String> data, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: GoogleFonts.roboto(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...data.entries.map((entry) {
            if (entry.value.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.only(top: 6, right: 8),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: GoogleFonts.roboto(
                        fontSize: 11,
                        color: Colors.black87,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
