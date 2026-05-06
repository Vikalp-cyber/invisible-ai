#include "windows_speech_bridge.h"

#include <flutter/standard_method_codec.h>
#include <sapi.h>
#include <mmdeviceapi.h>
#include <audioclient.h>
#include <Functiondiscoverykeys_devpkey.h>
#include <ks.h>
#include <ksmedia.h>

#include <algorithm>
#include <chrono>
#include <condition_variable>
#include <cstring>
#include <functional>
#include <vector>

namespace {
constexpr char kMethodChannelName[] = "invisible_ai_assistant/windows_speech_method";
constexpr char kEventChannelName[] = "invisible_ai_assistant/windows_speech_events";

constexpr WORD kTargetChannels = 1;
constexpr DWORD kTargetSampleRate = 16000;
constexpr WORD kTargetBitsPerSample = 16;

std::wstring Utf8ToWide(const std::string& value) {
  if (value.empty()) {
    return L"";
  }
  const int size = MultiByteToWideChar(CP_UTF8, 0, value.c_str(), -1, nullptr, 0);
  if (size <= 0) {
    return L"";
  }
  std::wstring output(size, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, value.c_str(), -1, output.data(), size);
  if (!output.empty() && output.back() == L'\0') {
    output.pop_back();
  }
  return output;
}

std::string WideToUtf8(const std::wstring& value) {
  if (value.empty()) {
    return "";
  }
  const int size = WideCharToMultiByte(CP_UTF8, 0, value.c_str(), -1, nullptr, 0, nullptr, nullptr);
  if (size <= 0) {
    return "";
  }
  std::string output(size, '\0');
  WideCharToMultiByte(CP_UTF8, 0, value.c_str(), -1, output.data(), size, nullptr, nullptr);
  if (!output.empty() && output.back() == '\0') {
    output.pop_back();
  }
  return output;
}

std::string CoTaskMemWideToUtf8(WCHAR* raw) {
  if (raw == nullptr) {
    return "";
  }
  std::wstring value(raw);
  ::CoTaskMemFree(raw);
  return WideToUtf8(value);
}
}  // namespace

// ── PlatformThreadDispatcher ──────────────────────────────────────────────────
//
// Marshals callbacks from background threads onto the platform thread by
// posting messages to a hidden message-only window owned by this dispatcher.
// Required because Flutter EventChannel sinks must be invoked on the platform
// thread.
class PlatformThreadDispatcher {
 public:
  PlatformThreadDispatcher() {
    static const wchar_t kClassName[] = L"InvisibleAIWindowsSpeechDispatcher";
    HINSTANCE module = ::GetModuleHandleW(nullptr);

    WNDCLASSEXW wc = {};
    wc.cbSize = sizeof(WNDCLASSEXW);
    wc.lpfnWndProc = &PlatformThreadDispatcher::WindowProcStatic;
    wc.hInstance = module;
    wc.lpszClassName = kClassName;
    ::RegisterClassExW(&wc);  // ignore failure (class may already exist)

    hwnd_ = ::CreateWindowExW(0, kClassName, L"", 0, 0, 0, 0, 0, HWND_MESSAGE,
                              nullptr, module, nullptr);
  }

  ~PlatformThreadDispatcher() {
    if (hwnd_ != nullptr) {
      ::DestroyWindow(hwnd_);
      hwnd_ = nullptr;
    }
  }

  PlatformThreadDispatcher(const PlatformThreadDispatcher&) = delete;
  PlatformThreadDispatcher& operator=(const PlatformThreadDispatcher&) = delete;

  void Post(std::function<void()> task) {
    if (hwnd_ == nullptr) {
      return;
    }
    auto* heap_task = new std::function<void()>(std::move(task));
    if (!::PostMessageW(hwnd_, kDispatchMessage, 0,
                        reinterpret_cast<LPARAM>(heap_task))) {
      delete heap_task;
    }
  }

 private:
  static constexpr UINT kDispatchMessage = WM_USER + 1;

  static LRESULT CALLBACK WindowProcStatic(HWND hwnd, UINT msg, WPARAM wp,
                                            LPARAM lp) {
    if (msg == kDispatchMessage) {
      auto* task = reinterpret_cast<std::function<void()>*>(lp);
      if (task != nullptr) {
        (*task)();
        delete task;
      }
      return 0;
    }
    return ::DefWindowProcW(hwnd, msg, wp, lp);
  }

  HWND hwnd_ = nullptr;
};

// ── LoopbackAudioStream ────────────────────────────────────────────────────────
//
// A thread-safe blocking IStream that pipes WASAPI loopback PCM into SAPI.
// SAPI consumes audio by calling Read(), which blocks until data is available.
class LoopbackAudioStream : public IStream {
 public:
  LoopbackAudioStream() = default;

  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void** ppv) override {
    if (ppv == nullptr) {
      return E_POINTER;
    }
    if (riid == IID_IUnknown || riid == IID_ISequentialStream || riid == IID_IStream) {
      *ppv = static_cast<IStream*>(this);
      AddRef();
      return S_OK;
    }
    *ppv = nullptr;
    return E_NOINTERFACE;
  }

  ULONG STDMETHODCALLTYPE AddRef() override {
    return ++ref_count_;
  }

  ULONG STDMETHODCALLTYPE Release() override {
    const ULONG remaining = --ref_count_;
    if (remaining == 0) {
      delete this;
    }
    return remaining;
  }

  HRESULT STDMETHODCALLTYPE Read(void* pv, ULONG cb, ULONG* pcbRead) override {
    if (pv == nullptr) {
      return STG_E_INVALIDPOINTER;
    }
    std::unique_lock<std::mutex> lock(mutex_);
    cv_.wait(lock, [this] { return shutdown_ || !buffer_.empty(); });
    if (shutdown_ && buffer_.empty()) {
      if (pcbRead != nullptr) {
        *pcbRead = 0;
      }
      return S_FALSE;
    }
    const ULONG actual = static_cast<ULONG>(
        std::min<size_t>(buffer_.size(), static_cast<size_t>(cb)));
    std::memcpy(pv, buffer_.data(), actual);
    buffer_.erase(buffer_.begin(), buffer_.begin() + actual);
    if (pcbRead != nullptr) {
      *pcbRead = actual;
    }
    return S_OK;
  }

  HRESULT STDMETHODCALLTYPE Write(const void*, ULONG, ULONG*) override {
    return STG_E_ACCESSDENIED;
  }

  HRESULT STDMETHODCALLTYPE Seek(LARGE_INTEGER, DWORD, ULARGE_INTEGER* pNewPosition) override {
    if (pNewPosition != nullptr) {
      pNewPosition->QuadPart = 0;
    }
    return E_NOTIMPL;
  }

  HRESULT STDMETHODCALLTYPE SetSize(ULARGE_INTEGER) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE CopyTo(IStream*, ULARGE_INTEGER, ULARGE_INTEGER*, ULARGE_INTEGER*) override {
    return E_NOTIMPL;
  }
  HRESULT STDMETHODCALLTYPE Commit(DWORD) override { return S_OK; }
  HRESULT STDMETHODCALLTYPE Revert() override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE LockRegion(ULARGE_INTEGER, ULARGE_INTEGER, DWORD) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE UnlockRegion(ULARGE_INTEGER, ULARGE_INTEGER, DWORD) override { return E_NOTIMPL; }

  HRESULT STDMETHODCALLTYPE Stat(STATSTG* pstg, DWORD) override {
    if (pstg == nullptr) {
      return STG_E_INVALIDPOINTER;
    }
    std::memset(pstg, 0, sizeof(STATSTG));
    pstg->type = STGTY_STREAM;
    return S_OK;
  }

  HRESULT STDMETHODCALLTYPE Clone(IStream**) override { return E_NOTIMPL; }

  void PushAudio(const uint8_t* data, size_t length) {
    {
      std::lock_guard<std::mutex> lock(mutex_);
      if (shutdown_) {
        return;
      }
      buffer_.insert(buffer_.end(), data, data + length);
    }
    cv_.notify_all();
  }

  void Shutdown() {
    {
      std::lock_guard<std::mutex> lock(mutex_);
      shutdown_ = true;
    }
    cv_.notify_all();
  }

 private:
  std::atomic<ULONG> ref_count_{1};
  std::mutex mutex_;
  std::condition_variable cv_;
  std::vector<uint8_t> buffer_;
  bool shutdown_ = false;
};

namespace {
class SinkForwardingStreamHandler : public flutter::StreamHandler<WindowsSpeechBridge::EncodableValue> {
 public:
  explicit SinkForwardingStreamHandler(WindowsSpeechBridge* owner) : owner_(owner) {}

 protected:
  std::unique_ptr<flutter::StreamHandlerError<WindowsSpeechBridge::EncodableValue>> OnListenInternal(
      const WindowsSpeechBridge::EncodableValue*,
      std::unique_ptr<flutter::EventSink<WindowsSpeechBridge::EncodableValue>>&& sink) override {
    owner_->SetEventSink(std::move(sink));
    return nullptr;
  }

  std::unique_ptr<flutter::StreamHandlerError<WindowsSpeechBridge::EncodableValue>> OnCancelInternal(
      const WindowsSpeechBridge::EncodableValue*) override {
    owner_->ClearEventSink();
    return nullptr;
  }

 private:
  WindowsSpeechBridge* owner_;
};
}  // namespace

WindowsSpeechBridge::WindowsSpeechBridge(flutter::BinaryMessenger* messenger) {
  platform_dispatcher_ = std::make_unique<PlatformThreadDispatcher>();

  method_channel_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, kMethodChannelName, &flutter::StandardMethodCodec::GetInstance());
  event_channel_ = std::make_unique<flutter::EventChannel<EncodableValue>>(
      messenger, kEventChannelName, &flutter::StandardMethodCodec::GetInstance());

  method_channel_->SetMethodCallHandler(
      [this](const MethodCall& call, std::unique_ptr<MethodResult> result) {
        HandleMethodCall(call, std::move(result));
      });

  event_channel_->SetStreamHandler(std::make_unique<SinkForwardingStreamHandler>(this));
}

WindowsSpeechBridge::~WindowsSpeechBridge() {
  StopListening();
}

void WindowsSpeechBridge::SetEventSink(std::unique_ptr<EventSink> sink) {
  std::lock_guard<std::mutex> lock(state_mutex_);
  event_sink_ = std::shared_ptr<EventSink>(std::move(sink));
}

void WindowsSpeechBridge::ClearEventSink() {
  std::lock_guard<std::mutex> lock(state_mutex_);
  event_sink_.reset();
}

void WindowsSpeechBridge::HandleMethodCall(const MethodCall& call,
                                           std::unique_ptr<MethodResult> result) {
  if (call.method_name() == "listAudioDevices") {
    flutter::EncodableList devices;
    for (const auto& item : ListAudioDevices()) {
      devices.emplace_back(item);
    }
    result->Success(EncodableValue(devices));
    return;
  }

  if (call.method_name() == "startListening") {
    std::string device_id;
    if (call.arguments() != nullptr && std::holds_alternative<flutter::EncodableMap>(*call.arguments())) {
      const auto& args = std::get<flutter::EncodableMap>(*call.arguments());
      auto it = args.find(EncodableValue("deviceId"));
      if (it != args.end() && std::holds_alternative<std::string>(it->second)) {
        device_id = std::get<std::string>(it->second);
      }
    }
    std::string error;
    if (!StartListeningOnDevice(device_id, &error)) {
      result->Error("start_failed", error);
      return;
    }
    result->Success();
    return;
  }

  if (call.method_name() == "startSystemAudioListening") {
    std::string error;
    if (!StartListeningOnSystemAudio(&error)) {
      result->Error("start_failed", error);
      return;
    }
    result->Success();
    return;
  }

  if (call.method_name() == "stopListening") {
    StopListening();
    result->Success();
    return;
  }

  result->NotImplemented();
}

std::vector<flutter::EncodableMap> WindowsSpeechBridge::ListAudioDevices() {
  std::vector<flutter::EncodableMap> devices;
  Microsoft::WRL::ComPtr<ISpObjectTokenCategory> category;
  HRESULT hr = ::CoCreateInstance(CLSID_SpObjectTokenCategory, nullptr, CLSCTX_ALL, IID_PPV_ARGS(&category));
  if (FAILED(hr)) {
    return devices;
  }
  hr = category->SetId(SPCAT_AUDIOIN, FALSE);
  if (FAILED(hr)) {
    return devices;
  }

  Microsoft::WRL::ComPtr<IEnumSpObjectTokens> tokens;
  hr = category->EnumTokens(nullptr, nullptr, &tokens);
  if (FAILED(hr) || !tokens) {
    return devices;
  }

  ULONG count = 0;
  if (FAILED(tokens->GetCount(&count))) {
    return devices;
  }

  for (ULONG i = 0; i < count; ++i) {
    Microsoft::WRL::ComPtr<ISpObjectToken> token;
    if (FAILED(tokens->Item(i, &token)) || !token) {
      continue;
    }
    WCHAR* id_w = nullptr;
    WCHAR* desc_w = nullptr;
    if (FAILED(token->GetId(&id_w))) {
      continue;
    }
    if (FAILED(token->GetStringValue(L"Description", &desc_w))) {
      ::CoTaskMemFree(id_w);
      continue;
    }
    flutter::EncodableMap entry;
    entry[EncodableValue("id")] = EncodableValue(CoTaskMemWideToUtf8(id_w));
    entry[EncodableValue("label")] = EncodableValue(CoTaskMemWideToUtf8(desc_w));
    devices.push_back(std::move(entry));
  }
  return devices;
}

bool WindowsSpeechBridge::ConfigureRecognizerForDevice(const std::string& requested_device_id,
                                                       std::string* error) {
  recognizer_.Reset();
  reco_context_.Reset();
  grammar_.Reset();
  sapi_stream_.Reset();
  reco_event_ = nullptr;

  HRESULT hr = ::CoCreateInstance(CLSID_SpInprocRecognizer, nullptr, CLSCTX_ALL,
                                  IID_PPV_ARGS(&recognizer_));
  if (FAILED(hr) || !recognizer_) {
    *error = "Unable to create SAPI in-process recognizer.";
    return false;
  }

  if (!requested_device_id.empty()) {
    Microsoft::WRL::ComPtr<ISpObjectTokenCategory> category;
    hr = ::CoCreateInstance(CLSID_SpObjectTokenCategory, nullptr, CLSCTX_ALL, IID_PPV_ARGS(&category));
    if (FAILED(hr) || !category || FAILED(category->SetId(SPCAT_AUDIOIN, FALSE))) {
      *error = "Failed to enumerate audio input devices.";
      return false;
    }
    Microsoft::WRL::ComPtr<IEnumSpObjectTokens> tokens;
    hr = category->EnumTokens(nullptr, nullptr, &tokens);
    if (FAILED(hr) || !tokens) {
      *error = "Failed to enumerate audio input devices.";
      return false;
    }
    ULONG count = 0;
    tokens->GetCount(&count);
    Microsoft::WRL::ComPtr<ISpObjectToken> device_token;
    for (ULONG i = 0; i < count; ++i) {
      Microsoft::WRL::ComPtr<ISpObjectToken> current;
      if (FAILED(tokens->Item(i, &current)) || !current) {
        continue;
      }
      WCHAR* id_w = nullptr;
      if (FAILED(current->GetId(&id_w)) || id_w == nullptr) {
        continue;
      }
      const std::string current_id = CoTaskMemWideToUtf8(id_w);
      if (current_id == requested_device_id) {
        device_token = current;
        break;
      }
    }
    if (!device_token) {
      *error = "Selected audio input device is unavailable.";
      return false;
    }
    hr = recognizer_->SetInput(device_token.Get(), TRUE);
    if (FAILED(hr)) {
      *error = "Failed to bind selected audio input device.";
      return false;
    }
  } else {
    hr = recognizer_->SetInput(nullptr, TRUE);
    if (FAILED(hr)) {
      *error = "Failed to bind default audio input device.";
      return false;
    }
  }

  hr = recognizer_->CreateRecoContext(&reco_context_);
  if (FAILED(hr) || !reco_context_) {
    *error = "Failed to create recognition context.";
    return false;
  }

  hr = reco_context_->SetNotifyWin32Event();
  if (FAILED(hr)) {
    *error = "Failed to configure recognition event notifications.";
    return false;
  }

  reco_event_ = reco_context_->GetNotifyEventHandle();
  if (reco_event_ == nullptr || reco_event_ == INVALID_HANDLE_VALUE) {
    *error = "Failed to acquire recognition event handle.";
    return false;
  }

  ULONGLONG interest =
      SPFEI(SPEI_HYPOTHESIS) | SPFEI(SPEI_RECOGNITION) | SPFEI(SPEI_FALSE_RECOGNITION);
  hr = reco_context_->SetInterest(interest, interest);
  if (FAILED(hr)) {
    *error = "Failed to configure recognition events.";
    return false;
  }

  hr = reco_context_->CreateGrammar(1, &grammar_);
  if (FAILED(hr) || !grammar_) {
    *error = "Failed to create dictation grammar.";
    return false;
  }

  hr = recognizer_->SetRecoState(SPRST_ACTIVE_ALWAYS);
  if (FAILED(hr)) {
    *error = "Failed to start recognition state.";
    return false;
  }

  hr = grammar_->LoadDictation(nullptr, SPLO_DYNAMIC);
  if (FAILED(hr)) {
    *error = "Failed to load dictation grammar.";
    return false;
  }

  hr = E_FAIL;
  for (int attempt = 0; attempt < 8 && FAILED(hr); ++attempt) {
    hr = grammar_->SetDictationState(SPRS_ACTIVE);
    if (FAILED(hr)) {
      ::Sleep(75);
    }
  }
  if (FAILED(hr)) {
    *error = "Failed to activate dictation grammar.";
    return false;
  }

  return true;
}

bool WindowsSpeechBridge::ConfigureRecognizerForLoopbackStream(std::string* error) {
  recognizer_.Reset();
  reco_context_.Reset();
  grammar_.Reset();
  sapi_stream_.Reset();
  reco_event_ = nullptr;

  if (!loopback_stream_) {
    *error = "Loopback audio stream is not initialized.";
    return false;
  }

  HRESULT hr = ::CoCreateInstance(CLSID_SpInprocRecognizer, nullptr, CLSCTX_ALL,
                                  IID_PPV_ARGS(&recognizer_));
  if (FAILED(hr) || !recognizer_) {
    *error = "Unable to create SAPI in-process recognizer.";
    return false;
  }

  hr = ::CoCreateInstance(CLSID_SpStream, nullptr, CLSCTX_ALL, IID_PPV_ARGS(&sapi_stream_));
  if (FAILED(hr) || !sapi_stream_) {
    *error = "Unable to create SAPI stream wrapper.";
    return false;
  }

  WAVEFORMATEX target_format = {};
  target_format.wFormatTag = WAVE_FORMAT_PCM;
  target_format.nChannels = kTargetChannels;
  target_format.nSamplesPerSec = kTargetSampleRate;
  target_format.wBitsPerSample = kTargetBitsPerSample;
  target_format.nBlockAlign = (target_format.nChannels * target_format.wBitsPerSample) / 8;
  target_format.nAvgBytesPerSec = target_format.nSamplesPerSec * target_format.nBlockAlign;
  target_format.cbSize = 0;

  hr = sapi_stream_->SetBaseStream(loopback_stream_.Get(), SPDFID_WaveFormatEx, &target_format);
  if (FAILED(hr)) {
    *error = "Failed to bind loopback audio stream to SAPI.";
    return false;
  }

  hr = recognizer_->SetInput(sapi_stream_.Get(), TRUE);
  if (FAILED(hr)) {
    *error = "Failed to bind loopback stream as recognizer input.";
    return false;
  }

  hr = recognizer_->CreateRecoContext(&reco_context_);
  if (FAILED(hr) || !reco_context_) {
    *error = "Failed to create recognition context.";
    return false;
  }

  hr = reco_context_->SetNotifyWin32Event();
  if (FAILED(hr)) {
    *error = "Failed to configure recognition event notifications.";
    return false;
  }

  reco_event_ = reco_context_->GetNotifyEventHandle();
  if (reco_event_ == nullptr || reco_event_ == INVALID_HANDLE_VALUE) {
    *error = "Failed to acquire recognition event handle.";
    return false;
  }

  ULONGLONG interest =
      SPFEI(SPEI_HYPOTHESIS) | SPFEI(SPEI_RECOGNITION) | SPFEI(SPEI_FALSE_RECOGNITION);
  hr = reco_context_->SetInterest(interest, interest);
  if (FAILED(hr)) {
    *error = "Failed to configure recognition events.";
    return false;
  }

  hr = reco_context_->CreateGrammar(1, &grammar_);
  if (FAILED(hr) || !grammar_) {
    *error = "Failed to create dictation grammar.";
    return false;
  }

  // For stream-based input, the dictation engine needs the recognizer to be
  // running and audio to be flowing before SetDictationState can succeed.
  // Activate the recognizer first, load dictation as dynamic, then activate.
  hr = recognizer_->SetRecoState(SPRST_ACTIVE_ALWAYS);
  if (FAILED(hr)) {
    *error = "Failed to start recognition state.";
    return false;
  }

  hr = grammar_->LoadDictation(nullptr, SPLO_DYNAMIC);
  if (FAILED(hr)) {
    *error = "Failed to load dictation grammar.";
    return false;
  }

  // Try a few times: dictation engine warm-up can briefly fail while waiting
  // for the first audio packets to be observed.
  hr = E_FAIL;
  for (int attempt = 0; attempt < 8 && FAILED(hr); ++attempt) {
    hr = grammar_->SetDictationState(SPRS_ACTIVE);
    if (FAILED(hr)) {
      ::Sleep(75);
    }
  }
  if (FAILED(hr)) {
    *error = "Failed to activate dictation grammar.";
    return false;
  }

  return true;
}

bool WindowsSpeechBridge::StartListeningOnDevice(const std::string& requested_device_id,
                                                  std::string* error) {
  StopListening();
  is_listening_ = true;
  recognition_thread_ = std::thread([this, requested_device_id]() {
    HRESULT init_hr = ::CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    if (FAILED(init_hr) && init_hr != RPC_E_CHANGED_MODE) {
      EmitTranscript("error", "Failed to initialize COM on recognition thread.", 0.0);
      is_listening_ = false;
      return;
    }

    std::string setup_error;
    if (!ConfigureRecognizerForDevice(requested_device_id, &setup_error)) {
      EmitTranscript("error", setup_error, 0.0);
      is_listening_ = false;
      ::CoUninitialize();
      return;
    }

    RecognitionLoop();
    ::CoUninitialize();
  });

  (void)error;
  return true;
}

bool WindowsSpeechBridge::StartListeningOnSystemAudio(std::string* error) {
  StopListening();

  // Create the loopback stream up-front and pre-fill it with silence so that
  // SAPI's dictation engine has audio to consume the moment we activate it.
  Microsoft::WRL::ComPtr<LoopbackAudioStream> stream(new LoopbackAudioStream());
  loopback_stream_ = stream;
  {
    const size_t silence_samples = (kTargetSampleRate * 400) / 1000;  // 400 ms
    std::vector<int16_t> silence(silence_samples, 0);
    stream->PushAudio(reinterpret_cast<const uint8_t*>(silence.data()),
                      silence.size() * sizeof(int16_t));
  }

  is_listening_ = true;
  is_loopback_active_ = true;

  // Start the WASAPI capture thread first so audio is actively flowing into
  // the loopback stream before SAPI tries to engage the dictation engine.
  capture_thread_ = std::thread([this]() {
    HRESULT init_hr = ::CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    LoopbackCaptureLoop();
    if (init_hr == S_OK || init_hr == S_FALSE) {
      ::CoUninitialize();
    }
  });

  // Give WASAPI a brief moment to deliver its first packet(s).
  ::Sleep(150);

  recognition_thread_ = std::thread([this]() {
    HRESULT init_hr = ::CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    if (FAILED(init_hr) && init_hr != RPC_E_CHANGED_MODE) {
      EmitTranscript("error", "Failed to initialize COM on recognition thread.", 0.0);
      is_listening_ = false;
      is_loopback_active_ = false;
      return;
    }

    std::string setup_error;
    if (!ConfigureRecognizerForLoopbackStream(&setup_error)) {
      EmitTranscript("error", setup_error, 0.0);
      is_listening_ = false;
      is_loopback_active_ = false;
      if (init_hr == S_OK || init_hr == S_FALSE) {
        ::CoUninitialize();
      }
      return;
    }

    RecognitionLoop();

    is_loopback_active_ = false;
    if (loopback_stream_) {
      loopback_stream_->Shutdown();
    }
    if (init_hr == S_OK || init_hr == S_FALSE) {
      ::CoUninitialize();
    }
  });

  (void)error;
  return true;
}

void WindowsSpeechBridge::StopListening() {
  is_listening_ = false;
  is_loopback_active_ = false;

  // Wake any blocked Read() in our IStream so the SAPI engine releases.
  auto local_stream = loopback_stream_;
  if (local_stream) {
    local_stream->Shutdown();
  }

  if (grammar_) {
    grammar_->SetDictationState(SPRS_INACTIVE);
  }
  if (recognizer_) {
    recognizer_->SetRecoState(SPRST_INACTIVE);
  }

  // Join worker threads BEFORE releasing any COM objects they may still use.
  if (recognition_thread_.joinable()) {
    recognition_thread_.join();
  }
  if (capture_thread_.joinable()) {
    capture_thread_.join();
  }

  recognizer_.Reset();
  reco_context_.Reset();
  grammar_.Reset();
  sapi_stream_.Reset();
  loopback_stream_.Reset();
  reco_event_ = nullptr;
}

void WindowsSpeechBridge::RecognitionLoop() {
  while (is_listening_) {
    if (reco_event_ == nullptr || reco_event_ == INVALID_HANDLE_VALUE) {
      Sleep(100);
      continue;
    }
    DWORD wait_res = ::WaitForSingleObject(reco_event_, 150);
    if (wait_res != WAIT_OBJECT_0) {
      continue;
    }

    while (true) {
      SPEVENT event_item = {};
      ULONG fetched = 0;
      HRESULT hr = reco_context_->GetEvents(1, &event_item, &fetched);
      if (FAILED(hr) || fetched == 0) {
        break;
      }

      if (event_item.eEventId != SPEI_HYPOTHESIS && event_item.eEventId != SPEI_RECOGNITION) {
        continue;
      }

      auto* reco_result = reinterpret_cast<ISpRecoResult*>(event_item.lParam);
      if (reco_result == nullptr) {
        continue;
      }

      WCHAR* text_w = nullptr;
      if (FAILED(reco_result->GetText(0, ULONG_MAX, TRUE, &text_w, nullptr)) ||
          text_w == nullptr) {
        continue;
      }

      std::string text = CoTaskMemWideToUtf8(text_w);
      if (text.empty()) {
        continue;
      }

      SPPHRASE* phrase = nullptr;
      double confidence = 0.0;
      if (SUCCEEDED(reco_result->GetPhrase(&phrase)) && phrase != nullptr) {
        confidence = static_cast<double>(phrase->Rule.Confidence + 1) / 2.0;
        ::CoTaskMemFree(phrase);
      }

      EmitTranscript(event_item.eEventId == SPEI_RECOGNITION ? "final" : "partial",
                     text, confidence);
    }
  }
}

void WindowsSpeechBridge::LoopbackCaptureLoop() {
  Microsoft::WRL::ComPtr<IMMDeviceEnumerator> enumerator;
  HRESULT hr = ::CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL,
                                  IID_PPV_ARGS(&enumerator));
  if (FAILED(hr) || !enumerator) {
    EmitTranscript("error", "Failed to create audio device enumerator.", 0.0);
    return;
  }

  Microsoft::WRL::ComPtr<IMMDevice> device;
  hr = enumerator->GetDefaultAudioEndpoint(eRender, eConsole, &device);
  if (FAILED(hr) || !device) {
    EmitTranscript("error", "No default audio output device is available.", 0.0);
    return;
  }

  Microsoft::WRL::ComPtr<IAudioClient> audio_client;
  hr = device->Activate(__uuidof(IAudioClient), CLSCTX_ALL, nullptr, &audio_client);
  if (FAILED(hr) || !audio_client) {
    EmitTranscript("error", "Failed to activate audio client.", 0.0);
    return;
  }

  WAVEFORMATEX* mix_format = nullptr;
  hr = audio_client->GetMixFormat(&mix_format);
  if (FAILED(hr) || mix_format == nullptr) {
    EmitTranscript("error", "Failed to query speaker mix format.", 0.0);
    return;
  }

  // 1-second buffer (in 100-nanosecond units) — generous for loopback latency.
  REFERENCE_TIME buffer_duration = 10000000;
  hr = audio_client->Initialize(AUDCLNT_SHAREMODE_SHARED, AUDCLNT_STREAMFLAGS_LOOPBACK,
                                buffer_duration, 0, mix_format, nullptr);
  if (FAILED(hr)) {
    ::CoTaskMemFree(mix_format);
    EmitTranscript("error", "Failed to initialize loopback capture.", 0.0);
    return;
  }

  Microsoft::WRL::ComPtr<IAudioCaptureClient> capture_client;
  hr = audio_client->GetService(IID_PPV_ARGS(&capture_client));
  if (FAILED(hr) || !capture_client) {
    ::CoTaskMemFree(mix_format);
    EmitTranscript("error", "Failed to obtain capture client.", 0.0);
    return;
  }

  hr = audio_client->Start();
  if (FAILED(hr)) {
    ::CoTaskMemFree(mix_format);
    EmitTranscript("error", "Failed to start loopback capture.", 0.0);
    return;
  }

  // Detect source format properties.
  const WORD source_channels = mix_format->nChannels;
  const DWORD source_rate = mix_format->nSamplesPerSec;
  const WORD source_bits = mix_format->wBitsPerSample;
  const WORD source_block = mix_format->nBlockAlign;

  bool source_is_float = (mix_format->wFormatTag == WAVE_FORMAT_IEEE_FLOAT);
  if (mix_format->wFormatTag == WAVE_FORMAT_EXTENSIBLE && mix_format->cbSize >= 22) {
    auto* ext = reinterpret_cast<const WAVEFORMATEXTENSIBLE*>(mix_format);
    source_is_float = (ext->SubFormat == KSDATAFORMAT_SUBTYPE_IEEE_FLOAT);
  }

  const double resample_ratio = static_cast<double>(kTargetSampleRate) /
                                static_cast<double>(source_rate);
  double resample_phase = 0.0;

  auto last_audio_time = std::chrono::steady_clock::now();
  const auto silence_inject_threshold = std::chrono::milliseconds(40);

  std::vector<int16_t> output_pcm;
  output_pcm.reserve(4096);

  while (is_loopback_active_) {
    UINT32 packet_length = 0;
    if (FAILED(capture_client->GetNextPacketSize(&packet_length))) {
      Sleep(5);
      continue;
    }

    bool packet_processed = false;
    while (packet_length != 0) {
      BYTE* data = nullptr;
      UINT32 frames_available = 0;
      DWORD flags = 0;
      hr = capture_client->GetBuffer(&data, &frames_available, &flags, nullptr, nullptr);
      if (FAILED(hr) || data == nullptr) {
        break;
      }

      output_pcm.clear();

      for (UINT32 frame = 0; frame < frames_available; ++frame) {
        float mono_sample = 0.0f;
        if ((flags & AUDCLNT_BUFFERFLAGS_SILENT) == 0) {
          float channel_sum = 0.0f;
          for (WORD ch = 0; ch < source_channels; ++ch) {
            const BYTE* sample_ptr = data + (frame * source_block) + (ch * (source_bits / 8));
            float sample = 0.0f;
            if (source_is_float && source_bits == 32) {
              sample = *reinterpret_cast<const float*>(sample_ptr);
            } else if (!source_is_float && source_bits == 16) {
              sample = static_cast<float>(*reinterpret_cast<const int16_t*>(sample_ptr)) / 32768.0f;
            } else if (!source_is_float && source_bits == 32) {
              sample = static_cast<float>(*reinterpret_cast<const int32_t*>(sample_ptr)) /
                       static_cast<float>(2147483648.0);
            } else if (!source_is_float && source_bits == 24) {
              int32_t packed = (sample_ptr[0]) | (sample_ptr[1] << 8) |
                               (static_cast<int8_t>(sample_ptr[2]) << 16);
              sample = static_cast<float>(packed) / 8388608.0f;
            }
            channel_sum += sample;
          }
          mono_sample = (source_channels > 0) ? channel_sum / static_cast<float>(source_channels)
                                              : 0.0f;
        }

        resample_phase += resample_ratio;
        while (resample_phase >= 1.0) {
          float clamped = std::clamp(mono_sample, -1.0f, 1.0f);
          output_pcm.push_back(static_cast<int16_t>(clamped * 32767.0f));
          resample_phase -= 1.0;
        }
      }

      if (!output_pcm.empty() && loopback_stream_) {
        loopback_stream_->PushAudio(reinterpret_cast<const uint8_t*>(output_pcm.data()),
                                    output_pcm.size() * sizeof(int16_t));
      }

      capture_client->ReleaseBuffer(frames_available);
      packet_processed = true;

      if (FAILED(capture_client->GetNextPacketSize(&packet_length))) {
        break;
      }
    }

    if (packet_processed) {
      last_audio_time = std::chrono::steady_clock::now();
    } else {
      // Inject ~40ms of silence so SAPI's pipeline stays alive when nothing is playing.
      auto now = std::chrono::steady_clock::now();
      if (now - last_audio_time > silence_inject_threshold) {
        const size_t silence_samples = (kTargetSampleRate * 40) / 1000;
        std::vector<int16_t> silence(silence_samples, 0);
        if (loopback_stream_) {
          loopback_stream_->PushAudio(reinterpret_cast<const uint8_t*>(silence.data()),
                                      silence.size() * sizeof(int16_t));
        }
        last_audio_time = now;
      }
      Sleep(5);
    }
  }

  audio_client->Stop();
  ::CoTaskMemFree(mix_format);
}

void WindowsSpeechBridge::EmitTranscript(const std::string& type,
                                         const std::string& text,
                                         double confidence) {
  // Marshal the EventChannel sink call onto the platform thread to satisfy
  // Flutter's threading contract for platform channel messages.
  if (!platform_dispatcher_) {
    return;
  }
  std::string captured_type = type;
  std::string captured_text = text;
  double captured_confidence = confidence;

  platform_dispatcher_->Post(
      [this, captured_type, captured_text, captured_confidence]() {
        std::shared_ptr<EventSink> sink_copy;
        {
          std::lock_guard<std::mutex> lock(state_mutex_);
          sink_copy = event_sink_;
        }
        if (!sink_copy) {
          return;
        }
        flutter::EncodableMap payload;
        payload[EncodableValue("type")] = EncodableValue(captured_type);
        payload[EncodableValue("text")] = EncodableValue(captured_text);
        payload[EncodableValue("confidence")] = EncodableValue(captured_confidence);
        sink_copy->Success(EncodableValue(payload));
      });
}
