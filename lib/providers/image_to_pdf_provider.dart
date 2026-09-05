import 'package:flutter/foundation.dart';

import '../models/selected_image.dart';
import '../services/image_to_pdf_service.dart';

/// Holds the mutable state for the Images-to-PDF conversion screen.
///
/// Created locally inside [ImageToPdfScreen] via `ChangeNotifierProvider`
/// (not in the global MultiProvider) because the state is only needed while
/// that screen is active. Each new session starts fresh.
class ImageToPdfProvider extends ChangeNotifier {
  List<SelectedImage> _selectedImages = [];
  bool _isConverting = false;
  String? _generatedPdfPath;
  String? _errorMessage;

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  List<SelectedImage> get selectedImages => List.unmodifiable(_selectedImages);
  bool get isConverting => _isConverting;
  String? get generatedPdfPath => _generatedPdfPath;
  String? get errorMessage => _errorMessage;
  bool get hasImages => _selectedImages.isNotEmpty;
  bool get hasGeneratedPdf => _generatedPdfPath != null;

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  /// Pick multiple images from the gallery and append them to the list.
  Future<void> pickFromGallery() async {
    try {
      final images = await ImageToPdfService.pickImagesFromGallery();
      if (images.isNotEmpty) {
        _selectedImages.addAll(images);
        _errorMessage = null;
        notifyListeners();
      }
    } on ImageConversionException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
    }
  }

  /// Capture a single image from the camera and append it to the list.
  Future<void> pickFromCamera() async {
    try {
      final image = await ImageToPdfService.pickImageFromCamera();
      if (image != null) {
        _selectedImages.add(image);
        _errorMessage = null;
        notifyListeners();
      }
    } on ImageConversionException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
    }
  }

  /// Remove a single image by its unique [imageId].
  void removeImage(String imageId) {
    _selectedImages.removeWhere((img) => img.id == imageId);
    // A PDF built from a now-empty or different list is stale — clear it.
    if (_selectedImages.isEmpty) {
      _generatedPdfPath = null;
    }
    notifyListeners();
  }

  /// Convert the current image list to a PDF file.
  Future<void> convertToPdf() async {
    if (_selectedImages.isEmpty) return;

    _isConverting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _generatedPdfPath =
          await ImageToPdfService.generatePdf(_selectedImages);
      _errorMessage = null;
    } on ImageConversionException catch (e) {
      _errorMessage = e.message;
    } catch (_) {
      _errorMessage = 'An unexpected error occurred. Please try again.';
    }

    _isConverting = false;
    notifyListeners();
  }

  /// Reset all state back to the initial empty state.
  void reset() {
    _selectedImages = [];
    _isConverting = false;
    _generatedPdfPath = null;
    _errorMessage = null;
    notifyListeners();
  }
}
