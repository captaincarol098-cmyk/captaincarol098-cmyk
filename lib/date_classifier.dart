import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;

/// Minimal, clean DateClassifier implementation used by the app.
/// Provides a stable API surface for: loadModel, isModelLoaded, labels,
/// predictFast, predictWithScores.
class DateClassifier {
  static final DateClassifier instance = DateClassifier._internal();
  factory DateClassifier() => instance;
  DateClassifier._internal() {
    _init();
  }

  Interpreter? _interpreter;
  final List<int> _inputShape = [1, 224, 224, 3];
  List<String> _labels = [];
  bool _isModelLoaded = false;

  bool get isModelLoaded => _isModelLoaded;
  List<String>? get labels => _isModelLoaded ? _labels : null;

  Future<void> _init() async {
    try {
      await loadModel();
    } catch (e) {
      debugPrint('DateClassifier initialization failed: $e');
      _isModelLoaded = false;
    }
  }

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/model_unquant.tflite', options: InterpreterOptions()..threads = 2);
      final raw = await rootBundle.loadString('assets/labels.txt');
      _labels = raw.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      _isModelLoaded = _labels.isNotEmpty;
    } catch (e) {
      _isModelLoaded = false;
      debugPrint('DateClassifier.loadModel error: $e');
      rethrow;
    }
  }

  Future<String> predict(File imageFile, {bool toBgr = false, String normMode = '-1to1', int inputSize = 224}) async {
    if (!_isModelLoaded || _interpreter == null) return 'Model not ready';
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return 'Could not decode image';

      final resized = img.copyResize(image, width: inputSize, height: inputSize);
      final inputTensor = await _prepareInputTensor(img.encodeJpg(resized), toBgr, normMode);
      final out = Float32List(_labels.length);
      _interpreter!.run(inputTensor.buffer, out.buffer);
      int top = 0;
      double best = out[0];
      for (int i = 1; i < out.length; i++) {
        if (out[i] > best) {
          best = out[i];
          top = i;
        }
      }
      return '${_labels[top]} (${(best * 100).toStringAsFixed(1)}%)';
    } catch (e) {
      debugPrint('predict error: $e');
      return 'Prediction failed';
    }
  }

  Future<String> predictFast(File imageFile, {bool toBgr = false, String normMode = '-1to1', int inputSize = 224}) async {
    return predict(imageFile, toBgr: toBgr, normMode: normMode, inputSize: inputSize);
  }

  Future<List<Map<String, dynamic>>> predictWithScores(File imageFile, {bool toBgr = false, String normMode = '-1to1', int inputSize = 224}) async {
    if (!_isModelLoaded || _interpreter == null) return [];
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return [];
      final resized = img.copyResize(image, width: inputSize, height: inputSize);
      final inputTensor = await _prepareInputTensor(img.encodeJpg(resized), toBgr, normMode);
      final out = Float32List(_labels.length);
      _interpreter!.run(inputTensor.buffer, out.buffer);
      final indices = List<int>.generate(out.length, (i) => i);
      indices.sort((a, b) => out[b].compareTo(out[a]));
      
      // Debug: Print all class confidences
      debugPrint('=== MODEL OUTPUT DEBUG ===');
      for (int i = 0; i < out.length; i++) {
        debugPrint('${_labels[i]}: ${(out[i] * 100).toStringAsFixed(2)}%');
      }
      debugPrint('========================');
      
      return indices.map((i) => {'label': _labels[i], 'confidence': out[i], 'index': i}).toList();
    } catch (e) {
      debugPrint('predictWithScores error: $e');
      return [];
    }
  }

  Future<Float32List> _prepareInputTensor(Uint8List imageBytes, bool toBgr, String normMode) async {
    final image = img.decodeImage(imageBytes);
    if (image == null) throw Exception('Failed to decode image');
    
    final height = _inputShape[1];
    final width = _inputShape[2];
    final channels = 3;
    
    final out = Float32List(1 * height * width * channels);
    var idx = 0;
    
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final pixel = image.getPixelSafe(x, y);
        var r = pixel.r;
        var g = pixel.g;
        var b = pixel.b;
        
        if (toBgr) {
          // Swap R and B channels for BGR format
          final temp = r;
          r = b;
          b = temp;
        }
        
        // Normalize pixel values based on normMode
        switch (normMode) {
          case '-1to1':
            out[idx++] = (r / 127.5) - 1;
            out[idx++] = (g / 127.5) - 1;
            out[idx++] = (b / 127.5) - 1;
            break;
          case '0to1':
            out[idx++] = r / 255.0;
            out[idx++] = g / 255.0;
            out[idx++] = b / 255.0;
            break;
          default:
            throw Exception('Unsupported normalization mode: $normMode');
        }
      }
    }
    return out;
  }
}

