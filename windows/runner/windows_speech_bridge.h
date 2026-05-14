#ifndef RUNNER_WINDOWS_SPEECH_BRIDGE_H_
#define RUNNER_WINDOWS_SPEECH_BRIDGE_H_

#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <sapi.h>
#include <wrl/client.h>
#include <mmdeviceapi.h>
#include <audioclient.h>

#include <atomic>
#include <functional>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

class LoopbackAudioStream;
class PlatformThreadDispatcher;

class WindowsSpeechBridge {
 public:
  using EncodableValue = flutter::EncodableValue;
  using EventSink = flutter::EventSink<EncodableValue>;

  explicit WindowsSpeechBridge(flutter::BinaryMessenger* messenger);
  ~WindowsSpeechBridge();

  WindowsSpeechBridge(const WindowsSpeechBridge&) = delete;
  WindowsSpeechBridge& operator=(const WindowsSpeechBridge&) = delete;

  void SetEventSink(std::unique_ptr<EventSink> sink);
  void ClearEventSink();
  void SetPcmEventSink(std::unique_ptr<EventSink> sink);
  void ClearPcmEventSink();

 private:
  using MethodCall = flutter::MethodCall<EncodableValue>;
  using MethodResult = flutter::MethodResult<EncodableValue>;

  void HandleMethodCall(const MethodCall& call, std::unique_ptr<MethodResult> result);
  std::vector<flutter::EncodableMap> ListAudioDevices();
  bool StartListeningOnDevice(const std::string& requested_device_id, std::string* error);
  bool StartListeningOnSystemAudio(std::string* error);
  bool StartLoopbackPcm(std::string* error);
  void StopLoopbackPcmOnly();
  void StopListening();

  void RecognitionLoop();
  void LoopbackCaptureLoop();
  void LoopbackCapturePcmOnlyLoop();
  bool ConfigureRecognizerForDevice(const std::string& requested_device_id, std::string* error);
  bool ConfigureRecognizerForLoopbackStream(std::string* error);
  void EmitTranscript(const std::string& type, const std::string& text, double confidence);
  void EmitPcmChunk(std::vector<uint8_t> bytes);
  void EmitPcmStreamError(const std::string& message);

  std::unique_ptr<flutter::MethodChannel<EncodableValue>> method_channel_;
  std::unique_ptr<flutter::EventChannel<EncodableValue>> event_channel_;
  std::unique_ptr<flutter::EventChannel<EncodableValue>> pcm_event_channel_;
  std::shared_ptr<EventSink> event_sink_;
  std::shared_ptr<EventSink> pcm_event_sink_;

  std::mutex state_mutex_;
  std::atomic<bool> is_listening_{false};
  std::atomic<bool> is_loopback_active_{false};
  std::atomic<bool> is_pcm_forward_active_{false};
  std::thread recognition_thread_;
  std::thread capture_thread_;
  std::thread pcm_forward_thread_;

  Microsoft::WRL::ComPtr<ISpRecognizer> recognizer_;
  Microsoft::WRL::ComPtr<ISpRecoContext> reco_context_;
  Microsoft::WRL::ComPtr<ISpRecoGrammar> grammar_;
  Microsoft::WRL::ComPtr<ISpStream> sapi_stream_;
  Microsoft::WRL::ComPtr<LoopbackAudioStream> loopback_stream_;
  HANDLE reco_event_ = nullptr;

  std::unique_ptr<PlatformThreadDispatcher> platform_dispatcher_;
};

#endif  // RUNNER_WINDOWS_SPEECH_BRIDGE_H_
