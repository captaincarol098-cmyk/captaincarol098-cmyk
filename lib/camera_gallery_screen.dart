import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:image/image.dart' as img;

import 'date_classifier.dart';
import 'models/prediction.dart';

String _capitalizeWord(String word) {
  if (word.isEmpty) return word;
  final lower = word.toLowerCase();
  return lower[0].toUpperCase() + lower.substring(1);
}

String _canonicalizeVarietyName(String variety) {
  var cleaned = variety.trim();
  cleaned = cleaned.replaceAll('_', ' ');
  cleaned = cleaned.replaceAll(RegExp(r'^\d+\s*'), '');
  cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
  cleaned = cleaned.replaceAll(RegExp(r'\s*dates?$', caseSensitive: false), '');
  cleaned = cleaned.trim();
  if (cleaned.isEmpty) return variety.trim();
  final parts = cleaned.split(' ');
  return parts.map(_capitalizeWord).join(' ');
}

class CameraGalleryScreen extends StatefulWidget {
  const CameraGalleryScreen({super.key});

  @override
  State<CameraGalleryScreen> createState() => _CameraGalleryScreenState();
}

class _CameraGalleryScreenState extends State<CameraGalleryScreen> with WidgetsBindingObserver {
  static const Duration _presentationDelay = Duration(seconds: 5);

  final classifier = DateClassifier();
  final ImagePicker _imagePicker = ImagePicker();

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

  Prediction? _latestPrediction;
  bool _isProcessing = false;
  bool _showResultCard = false;
  bool _isSubmitting = false;
  bool _showTutorial = true;
  File? _galleryImage;
  Prediction? _galleryPrediction;
  bool _isCameraMode = true;

  // Dummy fields kept for legacy code (no longer used after switching to ImagePicker)
  bool _showFocusOverlay = false;
  Offset? _focusPoint;
  bool _showDetectionOverlay = false;
  bool _showGuidanceTips = false;
  String _currentGuidance = '';
  double _zoomLevel = 1.0;
  double _exposureCompensation = 0.0;
  bool _flashOn = false;
  Color _qualityColor = Colors.green;
  String _imageQuality = 'Good';
  
  // Cached Firebase user to avoid repeated anonymous sign-in
  User? _cachedUser;

  Timer? _presentationTimer;


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Auto-open camera when the screen is first shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isCameraMode) {
        _pickImageFromCamera();
      }
    });
  }


  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _presentationTimer?.cancel();
      _presentationTimer = null;
    }
  }
  
  Future<void> _pickImageFromCamera() async {
    if (_isProcessing) return;

    try {
      setState(() {
        _isProcessing = true;
      });

      final XFile? image = await _imagePicker.pickImage(source: ImageSource.camera);
      if (image == null) {
        if (!mounted) return;
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      final file = File(image.path);
      // Use the same prediction pipeline as the gallery for consistency
      final predictionText = await classifier.predict(file);

      double accuracy = 0.0;
      if (predictionText.contains('(') && predictionText.contains('%')) {
        final part = predictionText.split('(')[1].split('%').first;
        accuracy = double.tryParse(part) ?? 0.0;
      }

      final rawVariety = predictionText.split(' (').first;
      final variety = _canonicalizeVarietyName(rawVariety);
      final description = _getVarietyDescription(variety);

      final prediction = Prediction(
        variety: variety,
        timestamp: DateTime.now(),
        accuracy: accuracy,
        description: description,
        imagePath: file.path,
      );

      if (!mounted) return;
      setState(() {
        _latestPrediction = prediction;
        _showResultCard = true;
        _isProcessing = false;
      });

      debugPrint('📷 Default camera prediction: ${prediction.variety} (${prediction.accuracy}% accuracy)');

      _presentationTimer?.cancel();
      _presentationTimer = Timer(_presentationDelay, () {
        if (mounted) {
          setState(() {});
        }
      });
    } catch (e) {
      debugPrint('Default camera prediction error: $e');
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error analyzing image: $e')),
      );
    }
  }

  Future<void> _pickImageFromGallery() async {
    final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      final file = File(image.path);
      try {
        final predictionText = await classifier.predict(file);
        double accuracy = 0.0;
        if (predictionText.contains('(') && predictionText.contains('%')) {
          final part = predictionText.split('(')[1].split('%').first;
          accuracy = double.tryParse(part) ?? 0.0;
        }
        final rawVariety = predictionText.split(' (').first;
        final variety = _canonicalizeVarietyName(rawVariety);
        final description = _getVarietyDescription(variety);

        final prediction = Prediction(
          variety: variety,
          timestamp: DateTime.now(),
          accuracy: accuracy,
          description: description,
          imagePath: file.path,
        );

        setState(() {
          _galleryImage = file;
          _galleryPrediction = prediction;
        });
      } catch (e) {
        debugPrint('Gallery prediction error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error analyzing image: $e')),
        );
      }
    }
  }

  Future<void> _submitGalleryPrediction() async {
    if (_galleryPrediction == null || _isSubmitting) return;
    await _submitPrediction(_galleryPrediction!);
  }

  Future<User?> _ensureUser() async {
    if (_cachedUser != null) return _cachedUser;

    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      debugPrint('🔐 Signing in anonymously (cached)...');
      final cred = await auth.signInAnonymously();
      _cachedUser = cred.user;
    } else {
      _cachedUser = auth.currentUser;
    }

    debugPrint('👤 Current cached user: ${_cachedUser?.uid}');
    return _cachedUser;
  }

  Future<void> _submitPrediction(Prediction prediction) async {
    if (_isSubmitting) return;
    debugPrint('🔥 Submitting prediction: ${prediction.variety} with accuracy: ${prediction.accuracy}%');
    setState(() => _isSubmitting = true);
    try {
      final user = await _ensureUser();
      final map = prediction.toMap();
      if (user != null) map['userId'] = user.uid;
      debugPrint('📤 Saving to Firestore: $map');
      await FirebaseFirestore.instance.collection('Lorenzo-SaudinianDatesdb').add(map);
      debugPrint('✅ Successfully saved to Firestore!');
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Submission successful')));
      _resetForNextDetection();
    } catch (e) {
      debugPrint('❌ Submit failed: $e');
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Submit failed: $e')));
    }
  }

  Future<void> _submitLatestPrediction() async {
    if (_latestPrediction == null) return;
    await _submitPrediction(_latestPrediction!);
  }

  void _resetGallerySelection() {
    setState(() {
      _galleryImage = null;
      _galleryPrediction = null;
    });
  }

  void _resetForNextDetection() {
    _presentationTimer?.cancel();
    _presentationTimer = null;
    _latestPrediction = null;
    _showResultCard = false;
  }

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

  Color _resolveVarietyColor(String variety) {
    final canonical = _canonicalizeVarietyName(variety);
    return _varietyColors[canonical] ?? Colors.brown;
  }
  String _formatTimestamp(DateTime timestamp) {
    final local = timestamp.toLocal();
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} ${twoDigits(local.hour)}:${twoDigits(local.minute)}:${twoDigits(local.second)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
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
                // Header with dates logo
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF8B4513),
                        Color(0xFFD2691E),
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Image.asset(
                              'assets/app_icon_80.png',
                              width: 40,
                              height: 40,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            'Saudi Dates',
                            style: GoogleFonts.playfair(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Mode toggle buttons
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ModeToggleButton(
                              label: 'Camera',
                              icon: Icons.camera_alt,
                              isSelected: _isCameraMode,
                              onTap: () {
                                setState(() => _isCameraMode = true);
                                _pickImageFromCamera();
                              },
                            ),
                            _ModeToggleButton(
                              label: 'Gallery',
                              icon: Icons.photo_library,
                              isSelected: !_isCameraMode,
                              onTap: () {
                                setState(() => _isCameraMode = false);
                                _pickImageFromGallery();
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Content area
                Expanded(
                  child: _isCameraMode ? _buildCameraContent() : _buildGalleryContent(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCameraContent() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1A1A1A), Color(0xFF000000)],
            ),
          ),
        ),

        // Instructions & capture button
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.camera_alt, size: 80, color: Colors.white),
              const SizedBox(height: 16),
              Text(
                'Tap the button below to open\nyour camera and detect dates',
                textAlign: TextAlign.center,
                style: GoogleFonts.roboto(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _pickImageFromCamera,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.camera_alt),
                label: Text(_isProcessing ? 'Analyzing...' : 'Capture Image'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B4513),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ],
          ),
        ),

        if (_showResultCard && _latestPrediction != null) _buildResultCard(),
      ],
    );
  }

  Widget _buildDetectionOverlay() {
    if (_latestPrediction == null) return const SizedBox.shrink();
    
    return Positioned(
      top: 100,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _resolveVarietyColor(_latestPrediction!.variety),
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.visibility,
                  color: _resolveVarietyColor(_latestPrediction!.variety),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Detecting: ${_latestPrediction!.variety}',
                  style: GoogleFonts.roboto(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  width: 100,
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: Colors.grey[600],
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _latestPrediction!.accuracy / 100,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: _resolveVarietyColor(_latestPrediction!.variety),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_latestPrediction!.accuracy.toStringAsFixed(1)}%',
                  style: GoogleFonts.roboto(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFocusOverlay() {
    if (_focusPoint == null) return const SizedBox.shrink();
    
    return Positioned(
      left: _focusPoint!.dx - 30,
      top: _focusPoint!.dy - 30,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.yellow,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.black,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(28),
          ),
        ),
      ),
    );
  }

  Widget _buildGuidanceOverlay() {
    return Positioned(
      bottom: 200,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.lightbulb_outline,
              color: Colors.yellow,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _currentGuidance,
                style: GoogleFonts.roboto(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityIndicator() {
    return Positioned(
      top: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _qualityColor.withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              _imageQuality == "Good quality" ? Icons.check_circle : 
              _imageQuality.contains("blurry") ? Icons.blur_on : 
              Icons.warning,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              _imageQuality,
              style: GoogleFonts.roboto(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGalleryContent() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xFF3E2723).withOpacity(0.1), Colors.transparent],
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: _galleryImage != null
                ? _buildGalleryImageResult()
                : _buildGalleryPlaceholder(),
          ),
          if (_galleryImage != null) _buildGalleryActions(),
        ],
      ),
    );
  }

  Widget _buildGalleryPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Select an image from gallery',
            style: GoogleFonts.roboto(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _pickImageFromGallery,
            icon: const Icon(Icons.photo_library),
            label: const Text('Choose Image'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B4513),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGalleryImageResult() {
    return Column(
      children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                _galleryImage!,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        if (_galleryPrediction != null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detection Result',
                  style: GoogleFonts.playfair(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF8B4513),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _resolveVarietyColor(_galleryPrediction!.variety).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Image.asset(
                        'assets/app_icon_80.png',
                        width: 24,
                        height: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _galleryPrediction!.variety,
                            style: GoogleFonts.roboto(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            'Accuracy: ${_galleryPrediction!.accuracy.toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _galleryPrediction!.description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildGalleryActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _resetGallerySelection,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: const BorderSide(color: Color(0xFF8B4513)),
              ),
              child: const Text('Choose Another'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _galleryPrediction != null ? _submitGalleryPrediction : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B4513),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Submit Result'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    final prediction = _latestPrediction;
    final showResult = _showResultCard && prediction != null;
    final analyzing = prediction != null && !showResult;
    final title = showResult
        ? prediction.variety
        : analyzing
            ? 'Analyzing...'
            : 'Looking for dates...';

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF5D4037), Color(0xFF3E2723)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18, // Reduced from 24
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (showResult) ...[
            Text(
              'Accuracy: ${prediction.accuracy.toStringAsFixed(1)}%',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'Timestamp: ${_formatTimestamp(prediction.timestamp)}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 16),
            Text(
              prediction.description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
            ),
            if (prediction.accuracy < 50.0) ...[
              const SizedBox(height: 8),
              const Text(
                'If camera does not focus on dates, it may result in unable to detect dates.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ],
          ] else if (analyzing) ...[
            const SizedBox(height: 6),
            const Text(
              'Hold steady for 5 seconds to confirm prediction.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 16),
            const LinearProgressIndicator(minHeight: 4),
          ] else ...[
            const Text(
              'Position the dates within the frame to begin analysis.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'If camera does not focus on dates, it may result in unable to detect dates.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  onPressed: _isSubmitting
                      ? null
                      : () {
                          setState(() {
                            _resetForNextDetection();
                          });
                        },
                  style: FilledButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withOpacity(0.12),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    shadowColor: Colors.black.withOpacity(0.3),
                    elevation: 4,
                  ),
                  child: const Text('Reset'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: showResult && !_isSubmitting ? _submitLatestPrediction : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    shadowColor: Colors.black.withOpacity(0.3),
                    elevation: 4,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeToggleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeToggleButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.3) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.white70,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FrameCorner extends StatelessWidget {
  final Alignment alignment;

  const _FrameCorner({required this.alignment});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border.all(
            color: Colors.white,
            width: 3,
          ),
        ),
        child: _buildCornerLines(alignment),
      ),
    );
  }

  Widget _buildCornerLines(Alignment alignment) {
    switch (alignment) {
      case Alignment.topLeft:
        return CustomPaint(
          painter: _CornerPainter(position: 'topLeft'),
        );
      case Alignment.topRight:
        return CustomPaint(
          painter: _CornerPainter(position: 'topRight'),
        );
      case Alignment.bottomLeft:
        return CustomPaint(
          painter: _CornerPainter(position: 'bottomLeft'),
        );
      case Alignment.bottomRight:
        return CustomPaint(
          painter: _CornerPainter(position: 'bottomRight'),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _CornerPainter extends CustomPainter {
  final String position;

  _CornerPainter({required this.position});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final double lineLength = 15;

    switch (position) {
      case 'topLeft':
        canvas.drawLine(Offset.zero, Offset(lineLength, 0), paint);
        canvas.drawLine(Offset(0, 0), Offset(0, lineLength), paint);
        break;
      case 'topRight':
        canvas.drawLine(Offset(size.width - lineLength, 0), Offset(size.width, 0), paint);
        canvas.drawLine(Offset(size.width, 0), Offset(size.width, lineLength), paint);
        break;
      case 'bottomLeft':
        canvas.drawLine(Offset(0, size.height - lineLength), Offset(0, size.height), paint);
        canvas.drawLine(Offset(0, size.height), Offset(lineLength, size.height), paint);
        break;
      case 'bottomRight':
        canvas.drawLine(Offset(size.width - lineLength, size.height), Offset(size.width, size.height), paint);
        canvas.drawLine(Offset(size.width, size.height - lineLength), Offset(size.width, size.height), paint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
