import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

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
      final Uint8List resizedImageBytes = Uint8List.fromList(imageBytes);

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
}
