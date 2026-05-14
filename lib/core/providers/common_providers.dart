import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'deepgram_runtime_provider.dart';
import '../../../services/preference_service.dart';
import '../../../services/secure_storage_service.dart';
import '../../../services/window_service.dart';
import '../../../services/hotkey_service.dart';
import '../../../services/tray_service.dart';
import '../../../services/virtual_audio_cable_service.dart';
import '../../../services/interview_audio_copilot_service.dart';
import '../../../services/screen_capture_service.dart';

/// Singleton provider for the PreferenceService.
final preferenceServiceProvider = Provider<PreferenceService>((ref) {
  return PreferenceService();
});

/// Singleton provider for the SecureStorageService.
final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

/// Singleton provider for the ScreenCaptureService.
final screenCaptureServiceProvider = Provider<ScreenCaptureService>((ref) {
  return ScreenCaptureService();
});

/// Singleton provider for virtual audio cable setup helpers.
final virtualAudioCableServiceProvider = Provider<VirtualAudioCableService>((ref) {
  return VirtualAudioCableService();
});

/// Singleton provider for the InterviewAudioCopilotService.
final interviewAudioCopilotServiceProvider = Provider<InterviewAudioCopilotService>((ref) {
  final service = InterviewAudioCopilotService(
    resolveDeepgramHolder: () => ref.read(deepgramRuntimeHolderProvider),
    resolveDeepgramListenBaseUrl: () =>
        ref.read(deepgramRuntimeHolderProvider).listenBaseUrl,
  );
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

/// Singleton provider for the WindowService.
/// Depends on PreferenceService for state persistence.
final windowServiceProvider = Provider<WindowService>((ref) {
  final prefs = ref.watch(preferenceServiceProvider);
  return WindowService(prefs);
});

/// Provider for the HotkeyService. Overridden in main.dart with callbacks.
final hotkeyServiceProvider = Provider<HotkeyService>((ref) {
  return HotkeyService();
});

/// Provider for the TrayService. Overridden in main.dart with callbacks.
final trayServiceProvider = Provider<TrayService>((ref) {
  return TrayService();
});
