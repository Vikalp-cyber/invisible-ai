import 'package:flutter/foundation.dart';

/// ── Screen Capture Service ─────────────────────────────────────────────────
/// Handles triggering the native system region selector and capturing
/// the selected area as image bytes.
class ScreenCaptureService {
  /// Prompts the user to select a region on screen and returns the image bytes.
  Future<Uint8List?> captureRegion() async {
    debugPrint(
      'ScreenCaptureService: screen capture is unavailable in this build because '
      'the native screen_capturer Windows dependency requires ATL/MFC toolchain components.',
    );
    return null;
  }
}
