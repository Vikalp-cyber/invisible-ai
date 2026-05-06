import 'dart:io';

import 'package:flutter/foundation.dart';

/// Provides practical setup helpers for virtual audio cable routing on Windows.
class VirtualAudioCableService {
  /// Opens Windows classic sound panel (`mmsys.cpl`) where users can:
  /// - verify CABLE Input/CABLE Output devices
  /// - enable "Listen to this device" for monitoring
  Future<bool> openSoundControlPanel() async {
    if (!Platform.isWindows) {
      return false;
    }
    try {
      final result = await Process.run('control.exe', <String>['mmsys.cpl']);
      return result.exitCode == 0;
    } catch (e) {
      debugPrint('VirtualAudioCableService: Failed to open sound panel: $e');
      return false;
    }
  }

  String buildGoogleMeetSetupGuide() {
    return '''
Google Meet Auto-Question Capture Setup (VB-CABLE)

1) Install VB-CABLE (Virtual Audio Cable).
2) In Google Meet (or Windows app sound), set output device to "CABLE Input".
3) In this app's transcription input, select "CABLE Output" (it appears as a microphone/input device).
4) Optional monitoring:
   - Open Windows Sound -> Recording -> CABLE Output -> Properties -> Listen
   - Enable "Listen to this device" and choose your headphones/speakers.

Result: interviewer voice -> virtual cable -> app transcription -> auto chat.
''';
  }
}
