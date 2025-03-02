import 'dart:io';
import 'package:flutter/material.dart';

class AppState extends ChangeNotifier {
  File? _capturedImage;
  String _caption = '';
  bool _isEditing = false;

  File? get capturedImage => _capturedImage;
  String get caption => _caption;
  bool get isEditing => _isEditing;

  void setCapturedImage(File image) {
    _capturedImage = image;
    _isEditing = true;
    notifyListeners();
  }

  void setCaption(String caption) {
    _caption = caption;
    notifyListeners();
  }

  void clearImage() {
    _capturedImage = null;
    _caption = '';
    _isEditing = false;
    notifyListeners();
  }

  void finishEditing() {
    _isEditing = false;
    notifyListeners();
  }
}
