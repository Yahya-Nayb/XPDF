import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/selected_image.dart';

/// Failure with a message safe to show directly in the UI.
class ImageConversionException implements Exception {
  final String message;

  const ImageConversionException(this.message);

  @override
  String toString() => message;
}

/// Static methods for picking images and generating a PDF from them.
class ImageToPdfService {
  /// Open the system gallery and let the user pick multiple images.
  ///
  /// Returns a list of [SelectedImage] (empty if the user cancelled).
  /// Throws [ImageConversionException] if the gallery is inaccessible.
  static Future<List<SelectedImage>> pickImagesFromGallery() async {
    try {
      final picker = ImagePicker();
      final xfiles = await picker.pickMultiImage();
      if (xfiles.isEmpty) return [];

      return xfiles.asMap().entries.map((entry) {
        return SelectedImage(
          id: '${DateTime.now().millisecondsSinceEpoch}_${entry.key}',
          path: entry.value.path,
        );
      }).toList();
    } on PlatformException {
      throw const ImageConversionException(
        'Photo library access was denied. '
        'Please enable it in system Settings and try again.',
      );
    }
  }

  /// Open the camera and capture a single image.
  ///
  /// Returns a [SelectedImage] or `null` if the user cancelled.
  /// Throws [ImageConversionException] if the camera is inaccessible.
  static Future<SelectedImage?> pickImageFromCamera() async {
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(source: ImageSource.camera);
      if (xfile == null) return null;

      return SelectedImage(
        id: '${DateTime.now().millisecondsSinceEpoch}',
        path: xfile.path,
      );
    } on PlatformException {
      throw const ImageConversionException(
        'Camera access was denied. '
        'Please enable Camera for XPDF in system Settings and try again.',
      );
    }
  }

  /// Convert a list of [SelectedImage]s into a single PDF file.
  ///
  /// Each image gets its own page. The page size is derived from the image's
  /// aspect ratio so images are never stretched or distorted — we fix the
  /// width to A4 and scale the height proportionally, capping at A4 height.
  ///
  /// Returns the file path of the saved PDF.
  /// Throws [ImageConversionException] on any failure.
  static Future<String> generatePdf(List<SelectedImage> images) async {
    try {
      final pdf = pw.Document();

      for (final selected in images) {
        final file = File(selected.path);
        if (!await file.exists()) {
          throw ImageConversionException(
            'Image file not found: ${selected.path.split('/').last}',
          );
        }

        final bytes = await file.readAsBytes();

        // Decode the image to read its natural width/height.
        // This lets us compute the correct aspect ratio for the PDF page.
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final imgWidth = frame.image.width;
        final imgHeight = frame.image.height;
        frame.image.dispose();

        // Fix the page width to A4, scale height by the image's aspect ratio.
        // Why: if we used a fixed A4 page for every image, landscape photos
        // would shrink to fit the narrow A4 width, and portrait images would
        // get pillarboxed. By sizing each page to the image, every photo
        // fills its page edge-to-edge.
        final pageWidth = PdfPageFormat.a4.width;
        double pageHeight;
        if (imgWidth > 0 && imgHeight > 0) {
          pageHeight = pageWidth * (imgHeight / imgWidth);
          // Cap at A4 height so very tall panoramas don't become unwieldy.
          if (pageHeight > PdfPageFormat.a4.height) {
            pageHeight = PdfPageFormat.a4.height;
          }
        } else {
          pageHeight = PdfPageFormat.a4.height;
        }

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(pageWidth, pageHeight),
            build: (pw.Context context) {
              return pw.Center(
                child: pw.Image(
                  pw.MemoryImage(bytes),
                  fit: pw.BoxFit.contain,
                ),
              );
            },
          ),
        );
      }

      final dir = await getApplicationDocumentsDirectory();
      final fileName =
          'converted_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final filePath = '${dir.path}/$fileName';

      final output = await pdf.save();
      await File(filePath).writeAsBytes(output);

      return filePath;
    } on ImageConversionException {
      rethrow;
    } catch (e) {
      throw ImageConversionException('Failed to generate PDF: $e');
    }
  }
}
