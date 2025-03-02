import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';

/// A service to share content to Instagram stories
class InstagramShareService {
  static const MethodChannel _channel =
      MethodChannel('instagram_share_channel');

  /// Share an image to Instagram story
  ///
  /// [imageBytes] - The image bytes to share
  /// [appId] - Your Facebook App ID
  /// Returns a Future<bool> indicating success or failure
  static Future<bool> shareToInstagramStory(
      List<int> imageBytes, String appId) async {
    try {
      // Resize the image to Instagram's recommended dimensions (1080x1920)
      final Uint8List resizedImageBytes = await _resizeImage(
        Uint8List.fromList(imageBytes),
        width: 1080,
        height: 1920,
      );

      // Save the image to a temporary file
      final tempDir = await getTemporaryDirectory();
      final file = File(
          '${tempDir.path}/instagram_share_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(resizedImageBytes);

      // Call the platform-specific method
      final result = await _channel.invokeMethod('shareToInstagramStory', {
        'imagePath': file.path,
        'appId': appId,
      });

      return result == 'success';
    } catch (e) {
      return false;
    }
  }

  /// Resize an image to the specified dimensions
  ///
  /// [imageBytes] - The original image bytes
  /// [width] - The target width
  /// [height] - The target height
  /// Returns a Future<Uint8List> with the resized image bytes
  static Future<Uint8List> _resizeImage(
    Uint8List imageBytes, {
    required int width,
    required int height,
  }) async {
    // Decode the image
    final ui.Codec codec = await ui.instantiateImageCodec(imageBytes);
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    final ui.Image originalImage = frameInfo.image;

    // Calculate the aspect ratio to maintain
    final double targetAspectRatio = width / height;

    // Create a picture recorder and canvas
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    // Draw the image centered and scaled to fill the target dimensions
    // while maintaining aspect ratio (may crop if necessary)

    canvas.drawImageRect(
      originalImage,
      Rect.fromLTWH(
        (originalImage.width - (originalImage.height * targetAspectRatio)) / 2,
        0,
        originalImage.height * targetAspectRatio,
        originalImage.height.toDouble(),
      ),
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint(),
    );

    // Convert the picture to an image
    final ui.Picture picture = pictureRecorder.endRecording();
    final ui.Image resizedImage = await picture.toImage(width, height);

    // Convert the image to bytes
    final ByteData? byteData =
        await resizedImage.toByteData(format: ui.ImageByteFormat.png);

    // Dispose of the images to free up memory
    originalImage.dispose();
    resizedImage.dispose();

    return byteData!.buffer.asUint8List();
  }
}
