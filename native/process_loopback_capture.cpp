// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

#include "process_loopback_capture.h"

#include "phrase_segmenter.h"
#include "wave_file.h"

#include <audioclient.h>
#include <audioclientactivationparams.h>
#include <mmdeviceapi.h>
#include <roapi.h>
#include <windows.h>
#include <wrl.h>

#include <cstdio>
#include <vector>

namespace {

using Microsoft::WRL::ComPtr;
using Microsoft::WRL::FtmBase;
using Microsoft::WRL::MakeAndInitialize;
using Microsoft::WRL::RuntimeClass;
using Microsoft::WRL::RuntimeClassFlags;
using Microsoft::WRL::ClassicCom;

using capture::kSampleRate;

constexpr uint16_t kChannels = 1;
constexpr uint16_t kBitsPerSample = 16;

// A handle closed when it goes out of scope, so an early return cannot leak
// one -- the thread below used to close its two in three places.
class UniqueHandle {
 public:
  explicit UniqueHandle(HANDLE handle) : handle_(handle) {}
  ~UniqueHandle() {
    if (handle_ != nullptr) CloseHandle(handle_);
  }
  UniqueHandle(const UniqueHandle&) = delete;
  UniqueHandle& operator=(const UniqueHandle&) = delete;

  HANDLE get() const { return handle_; }
  explicit operator bool() const { return handle_ != nullptr; }

 private:
  HANDLE handle_;
};

// The Windows Runtime on this thread for as long as this object lives, when
// it was not on already. Declared before any COM object, it is let go of
// after all of them.
class RoApartment {
 public:
  RoApartment() : result_(RoInitialize(RO_INIT_MULTITHREADED)) {}
  ~RoApartment() {
    if (SUCCEEDED(result_)) RoUninitialize();
  }
  RoApartment(const RoApartment&) = delete;
  RoApartment& operator=(const RoApartment&) = delete;

  // A thread already in another apartment is still one COM can be used on.
  bool failed() const { return FAILED(result_) && result_ != RPC_E_CHANGED_MODE; }
  HRESULT result() const { return result_; }

 private:
  const HRESULT result_;
};

/// A path for the next captured phrase, named by this process and a number
/// that only grows, so two segments can never share a file.
std::wstring SegmentPath(const std::wstring& directory, uint64_t sequence) {
  return directory + L"\\segment-" + std::to_wstring(GetCurrentProcessId()) + L"-" +
         std::to_wstring(sequence) + L".wav";
}

/// A wide Windows path as the UTF-8 the Dart side reads.
std::string Utf8Path(const std::wstring& path) {
  const int size =
      WideCharToMultiByte(CP_UTF8, 0, path.c_str(), -1, nullptr, 0, nullptr, nullptr);
  if (size <= 0) return {};
  std::string utf8(static_cast<size_t>(size), '\0');
  WideCharToMultiByte(CP_UTF8, 0, path.c_str(), -1, utf8.data(), size, nullptr, nullptr);
  utf8.pop_back();  // The terminator WideCharToMultiByte counted in.
  return utf8;
}

std::string WindowsError(HRESULT result) {
  char* message = nullptr;
  FormatMessageA(FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM |
                     FORMAT_MESSAGE_IGNORE_INSERTS,
                 nullptr, static_cast<DWORD>(result), 0,
                 reinterpret_cast<char*>(&message), 0, nullptr);
  std::string value = message == nullptr ? "Unknown Windows audio error" : message;
  if (message != nullptr) LocalFree(message);
  while (!value.empty() && (value.back() == '\r' || value.back() == '\n')) value.pop_back();
  return value;
}

// Answers the asynchronous activation. It owns the event it sets: the
// operation holds the handler for as long as it may still call back, so the
// event cannot be closed under a completion that arrives after the wait gave
// up on it.
class ActivationHandler final
    : public RuntimeClass<RuntimeClassFlags<ClassicCom>, FtmBase,
                          IActivateAudioInterfaceCompletionHandler> {
 public:
  HRESULT RuntimeClassInitialize() {
    completed_ = CreateEventW(nullptr, TRUE, FALSE, nullptr);
    return completed_ == nullptr ? HRESULT_FROM_WIN32(GetLastError()) : S_OK;
  }
  ~ActivationHandler() override {
    if (completed_ != nullptr) CloseHandle(completed_);
  }

  IFACEMETHODIMP ActivateCompleted(IActivateAudioInterfaceAsyncOperation* operation) override {
    ComPtr<IUnknown> unknown;
    result_ = E_FAIL;
    const HRESULT call_result = operation->GetActivateResult(&result_, &unknown);
    if (SUCCEEDED(call_result) && SUCCEEDED(result_)) {
      result_ = unknown.As(&client_);
    } else if (FAILED(call_result)) {
      result_ = call_result;
    }
    SetEvent(completed_);
    return S_OK;
  }

  // Waits for the activation, and answers how it went.
  HRESULT Wait(DWORD milliseconds) const {
    WaitForSingleObject(completed_, milliseconds);
    return result_;
  }
  ComPtr<IAudioClient> client() const { return client_; }

 private:
  HANDLE completed_ = nullptr;
  HRESULT result_ = E_PENDING;
  ComPtr<IAudioClient> client_;
};

// Activates the loopback of [process_id] -- its own sound, or everything but
// its own with [exclude_process_tree] -- as 16 kHz mono PCM that signals
// [sample_ready] when a packet is waiting, and starts it.
HRESULT ActivateLoopbackClient(uint32_t process_id, bool exclude_process_tree,
                               HANDLE sample_ready, ComPtr<IAudioClient>& client,
                               ComPtr<IAudioCaptureClient>& capture) {
  ComPtr<ActivationHandler> handler;
  HRESULT result = MakeAndInitialize<ActivationHandler>(&handler);
  if (FAILED(result)) return result;
  AUDIOCLIENT_ACTIVATION_PARAMS parameters{};
  parameters.ActivationType = AUDIOCLIENT_ACTIVATION_TYPE_PROCESS_LOOPBACK;
  parameters.ProcessLoopbackParams.TargetProcessId = process_id;
  parameters.ProcessLoopbackParams.ProcessLoopbackMode = exclude_process_tree
      ? PROCESS_LOOPBACK_MODE_EXCLUDE_TARGET_PROCESS_TREE
      : PROCESS_LOOPBACK_MODE_INCLUDE_TARGET_PROCESS_TREE;
  PROPVARIANT variant{};
  variant.vt = VT_BLOB;
  variant.blob.cbSize = sizeof(parameters);
  variant.blob.pBlobData = reinterpret_cast<BYTE*>(&parameters);
  ComPtr<IActivateAudioInterfaceAsyncOperation> operation;
  result = ActivateAudioInterfaceAsync(VIRTUAL_AUDIO_DEVICE_PROCESS_LOOPBACK,
                                       __uuidof(IAudioClient), &variant, handler.Get(),
                                       &operation);
  if (FAILED(result)) return result;
  result = handler->Wait(10000);
  if (FAILED(result)) return result;

  client = handler->client();
  WAVEFORMATEX format{};
  format.wFormatTag = WAVE_FORMAT_PCM;
  format.nChannels = kChannels;
  format.nSamplesPerSec = kSampleRate;
  format.wBitsPerSample = kBitsPerSample;
  format.nBlockAlign = kChannels * kBitsPerSample / 8;
  format.nAvgBytesPerSec = kSampleRate * format.nBlockAlign;
  result = client->Initialize(AUDCLNT_SHAREMODE_SHARED,
                              AUDCLNT_STREAMFLAGS_LOOPBACK | AUDCLNT_STREAMFLAGS_EVENTCALLBACK |
                                  AUDCLNT_STREAMFLAGS_AUTOCONVERTPCM |
                                  AUDCLNT_STREAMFLAGS_SRC_DEFAULT_QUALITY,
                              0, 0, &format, nullptr);
  if (SUCCEEDED(result)) result = client->SetEventHandle(sample_ready);
  if (SUCCEEDED(result)) result = client->GetService(IID_PPV_ARGS(&capture));
  if (SUCCEEDED(result)) result = client->Start();
  return result;
}

// Hands every packet waiting in [capture] to [segmenter], and answers the
// error a client that has gone -- the device unplugged, the game's audio
// session torn down -- answers every call with from then on. Passed over,
// the capture went on "listening" to nothing, and the player heard the
// dubbing go quiet with nothing to say why.
HRESULT DrainPackets(IAudioCaptureClient* capture, capture::PhraseSegmenter& segmenter,
                     const std::atomic<double>& attenuation) {
  HRESULT result = S_OK;
  UINT32 packet_frames = 0;
  while (SUCCEEDED(result = capture->GetNextPacketSize(&packet_frames)) && packet_frames > 0) {
    BYTE* bytes = nullptr;
    DWORD flags = 0;
    UINT32 frames = 0;
    if (FAILED(result = capture->GetBuffer(&bytes, &frames, &flags, nullptr, nullptr))) break;
    const auto* input = reinterpret_cast<const int16_t*>(bytes);
    // A packet Windows marks as silent is a run of zeroes the audio engine
    // did not bother to write out.
    const bool silent = (flags & AUDCLNT_BUFFERFLAGS_SILENT) != 0;
    // The threshold follows the game down: what reaches the tap is the
    // game's own sound times whatever it has been turned down to.
    const bool voiced = capture::PacketRms(input, frames, silent) >=
                        capture::kSpeechRms * attenuation.load(std::memory_order_relaxed);
    segmenter.Feed(input, frames, silent, voiced, capture::Clock::now());
    capture->ReleaseBuffer(frames);
  }
  return result;
}

bool WriteWave(const std::wstring& filename, std::vector<int16_t> samples) {
  return wave_file::WriteMono(filename, std::move(samples), kSampleRate);
}

}  // namespace

ProcessLoopbackCapture::ProcessLoopbackCapture() = default;
ProcessLoopbackCapture::~ProcessLoopbackCapture() { Stop(); }

bool ProcessLoopbackCapture::Start(uint32_t process_id, bool exclude_process_tree,
                                   std::wstring output_directory,
                                   SegmentCallback on_segment, ErrorCallback on_error) {
  if (thread_.joinable()) return false;
  stopping_ = false;
  // Nothing has turned the game down yet.
  attenuation_ = 1.0;
  thread_ = std::thread(&ProcessLoopbackCapture::CaptureThread, this, process_id,
                        exclude_process_tree,
                        std::move(output_directory), std::move(on_segment), std::move(on_error));
  return true;
}

void ProcessLoopbackCapture::SetHoldingTake(bool holding) {
  if (holding) held_samples_.store(0, std::memory_order_relaxed);
  holding_.store(holding, std::memory_order_relaxed);
}

size_t ProcessLoopbackCapture::HeldSamples() const {
  // Too short to be kept is nothing gathered: the loop below throws such a
  // take away as a door or a footstep, and a caller told it had gathered
  // something waited ninety seconds for a recording that never came.
  const size_t held = held_samples_.load(std::memory_order_relaxed);
  return held >= capture::kMinimumSpeechSamples ? held : 0;
}

void ProcessLoopbackCapture::SetSpeechAttenuation(double factor) {
  // Silence carries no speech to find, and nothing above the volume the
  // process had is ever asked for.
  attenuation_ = factor > 0.0 && factor < 1.0 ? factor : 1.0;
}

void ProcessLoopbackCapture::Stop() {
  stopping_ = true;
  if (thread_.joinable()) thread_.join();
}

void ProcessLoopbackCapture::CaptureThread(uint32_t process_id, bool exclude_process_tree,
                                           std::wstring output_directory,
                                           SegmentCallback on_segment, ErrorCallback on_error) {
  RoApartment apartment;
  if (apartment.failed()) {
    on_error(WindowsError(apartment.result()));
    return;
  }
  const UniqueHandle sample_ready(CreateEventW(nullptr, FALSE, FALSE, nullptr));
  if (!sample_ready) {
    on_error("Cannot create WASAPI synchronization events");
    return;
  }
  ComPtr<IAudioClient> client;
  ComPtr<IAudioCaptureClient> capture;
  const HRESULT result = ActivateLoopbackClient(process_id, exclude_process_tree,
                                                sample_ready.get(), client, capture);
  if (FAILED(result)) {
    on_error(WindowsError(result));
    return;
  }

  CreateDirectoryW(output_directory.c_str(), nullptr);
  capture::PhraseSegmenter segmenter;
  uint64_t sequence = 0;
  while (!stopping_) {
    // At most 100 ms, so letting go of a held take lands the recording
    // promptly and a phrase ends on the clock when no packets come at all.
    WaitForSingleObject(sample_ready.get(), 100);
    const HRESULT failure = DrainPackets(capture.Get(), segmenter, attenuation_);
    if (FAILED(failure)) {
      on_error(WindowsError(failure));
      break;
    }
    const bool holding = holding_.load(std::memory_order_relaxed);
    if (holding) held_samples_.store(segmenter.Gathered(), std::memory_order_relaxed);
    if (auto phrase = segmenter.Finish(holding, capture::Clock::now())) {
      const std::wstring filename = SegmentPath(output_directory, ++sequence);
      if (WriteWave(filename, std::move(*phrase))) on_segment(Utf8Path(filename));
    }
  }
  client->Stop();
}
