import 'package:flutter/foundation.dart';

class ReaderEditModeProvider extends ChangeNotifier {
  bool _isEditMode = false;

  bool get isEditMode => _isEditMode;

  void toggleEditMode() {
    _isEditMode = !_isEditMode;
    notifyListeners();
  }

  void enableEditMode() {
    if (!_isEditMode) {
      _isEditMode = true;
      notifyListeners();
    }
  }

  void disableEditMode() {
    if (_isEditMode) {
      _isEditMode = false;
      notifyListeners();
    }
  }
}