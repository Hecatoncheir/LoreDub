// Copyright (c) 2026 GameLingo contributors.
// SPDX-License-Identifier: MIT

#include "process_loopback_capture.h"

#if defined(_WIN32)

#define NOMINMAX
#include <audioclient.h>
#include <audioclientactivationparams.h>
#include <mmdeviceapi.h>
#include <roapi.h>
#include <windows.h>
#include <wrl.h>

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <deque>
#include <fstream>
#include <vector>

namespace {

using Microsoft::WRL::ComPtr;
using Microsoft::WRL::FtmBase;
using Microsoft::WRL::Make;
using Microsoft::WRL::RuntimeClass;
using Microsoft::WRL::RuntimeClassFlags;
using Microsoft::WRL::ClassicCom;

constexpr uint32_t kSampleRate = 16000;
constexpr uint16_t kChannels = 1;
constexpr uint16_t kBitsPerSample = 16;
constexpr size_t kPreRollSamples = kSampleRate / 4;
constexpr size_t kEndSilenceSamples = kSampleRate * 7 / 10;
constexpr size_t kMinimumSpeechSamples = kSampleRate * 35 / 100;
constexpr size_t kMaximumSegmentSamples = kSampleRate * 12;
constexpr double kSpeechRms = 180.0;

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

class ActivationHandler final
    : public RuntimeClass<RuntimeClassFlags<ClassicCom>, FtmBase,
                          IActivateAudioInterfaceCompletionHandler> {
 public:
  HRESULT RuntimeClassInitialize(HANDLE completed) {
    completed_ = completed;
    return S_OK;
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

  HRESULT result() const { return result_; }
  ComPtr<IAudioClient> client() const { return client_; }

 private:
  HANDLE completed_ = nullptr;
  HRESULT result_ = E_PENDING;
  ComPtr<IAudioClient> client_;
};

bool WriteWave(const std::wstring& filename, std::vector<int16_t> samples) {
  if (samples.empty()) return false;
  int peak = 1;
  for (const int16_t sample : samples) peak = std::max(peak, std::abs(static_cast<int>(sample)));
  const double gain = std::min(8.0, 28000.0 / static_cast<double>(peak));
  for (int16_t& sample : samples) {
    sample = static_cast<int16_t>(std::clamp(std::lround(sample * gain), -32768L, 32767L));
  }

  std::ofstream output(filename, std::ios::binary);
  if (!output) return false;
  const uint32_t data_size = static_cast<uint32_t>(samples.size() * sizeof(int16_t));
  const uint32_t riff_size = 36 + data_size;
  const uint32_t byte_rate = kSampleRate * kChannels * kBitsPerSample / 8;
  const uint16_t block_align = kChannels * kBitsPerSample / 8;
  const uint32_t fmt_size = 16;
  const uint16_t pcm = 1;
  output.write("RIFF", 4);
  output.write(reinterpret_cast<const char*>(&riff_size), sizeof(riff_size));
  output.write("WAVEfmt ", 8);
  output.write(reinterpret_cast<const char*>(&fmt_size), sizeof(fmt_size));
  output.write(reinterpret_cast<const char*>(&pcm), sizeof(pcm));
  output.write(reinterpret_cast<const char*>(&kChannels), sizeof(kChannels));
  output.write(reinterpret_cast<const char*>(&kSampleRate), sizeof(kSampleRate));
  output.write(reinterpret_cast<const char*>(&byte_rate), sizeof(byte_rate));
  output.write(reinterpret_cast<const char*>(&block_align), sizeof(block_align));
  output.write(reinterpret_cast<const char*>(&kBitsPerSample), sizeof(kBitsPerSample));
  output.write("data", 4);
  output.write(reinterpret_cast<const char*>(&data_size), sizeof(data_size));
  output.write(reinterpret_cast<const char*>(samples.data()), data_size);
  return output.good();
}

}  // namespace

#endif

ProcessLoopbackCapture::ProcessLoopbackCapture() = default;
ProcessLoopbackCapture::~ProcessLoopbackCapture() { Stop(); }

bool ProcessLoopbackCapture::Start(uint32_t process_id, std::wstring output_directory,
                                   SegmentCallback on_segment, ErrorCallback on_error) {
  if (thread_.joinable()) return false;
  stopping_ = false;
  thread_ = std::thread(&ProcessLoopbackCapture::CaptureThread, this, process_id,
                        std::move(output_directory), std::move(on_segment), std::move(on_error));
  return true;
}

void ProcessLoopbackCapture::Stop() {
  stopping_ = true;
  if (thread_.joinable()) thread_.join();
}

void ProcessLoopbackCapture::CaptureThread(uint32_t process_id, std::wstring output_directory,
                                           SegmentCallback on_segment, ErrorCallback on_error) {
#if !defined(_WIN32)
  (void)process_id;
  (void)output_directory;
  (void)on_segment;
  on_error("Process loopback is only available on Windows");
#else
  const HRESULT ro_result = RoInitialize(RO_INIT_MULTITHREADED);
  const bool uninitialize = SUCCEEDED(ro_result);
  if (FAILED(ro_result) && ro_result != RPC_E_CHANGED_MODE) {
    on_error(WindowsError(ro_result));
    return;
  }

  HANDLE completed = CreateEventW(nullptr, TRUE, FALSE, nullptr);
  HANDLE sample_ready = CreateEventW(nullptr, FALSE, FALSE, nullptr);
  if (completed == nullptr || sample_ready == nullptr) {
    on_error("Cannot create WASAPI synchronization events");
    if (completed != nullptr) CloseHandle(completed);
    if (sample_ready != nullptr) CloseHandle(sample_ready);
    if (uninitialize) RoUninitialize();
    return;
  }

  auto handler = Make<ActivationHandler>();
  handler->RuntimeClassInitialize(completed);
  AUDIOCLIENT_ACTIVATION_PARAMS parameters{};
  parameters.ActivationType = AUDIOCLIENT_ACTIVATION_TYPE_PROCESS_LOOPBACK;
  parameters.ProcessLoopbackParams.TargetProcessId = process_id;
  parameters.ProcessLoopbackParams.ProcessLoopbackMode = PROCESS_LOOPBACK_MODE_INCLUDE_TARGET_PROCESS_TREE;
  PROPVARIANT variant{};
  variant.vt = VT_BLOB;
  variant.blob.cbSize = sizeof(parameters);
  variant.blob.pBlobData = reinterpret_cast<BYTE*>(&parameters);
  ComPtr<IActivateAudioInterfaceAsyncOperation> operation;
  HRESULT result = ActivateAudioInterfaceAsync(VIRTUAL_AUDIO_DEVICE_PROCESS_LOOPBACK,
                                                __uuidof(IAudioClient), &variant,
                                                handler.Get(), &operation);
  if (SUCCEEDED(result)) {
    WaitForSingleObject(completed, 10000);
    result = handler->result();
  }

  ComPtr<IAudioClient> client = handler->client();
  WAVEFORMATEX format{};
  format.wFormatTag = WAVE_FORMAT_PCM;
  format.nChannels = kChannels;
  format.nSamplesPerSec = kSampleRate;
  format.wBitsPerSample = kBitsPerSample;
  format.nBlockAlign = kChannels * kBitsPerSample / 8;
  format.nAvgBytesPerSec = kSampleRate * format.nBlockAlign;
  if (SUCCEEDED(result)) {
    result = client->Initialize(AUDCLNT_SHAREMODE_SHARED,
                                AUDCLNT_STREAMFLAGS_LOOPBACK | AUDCLNT_STREAMFLAGS_EVENTCALLBACK |
                                    AUDCLNT_STREAMFLAGS_AUTOCONVERTPCM |
                                    AUDCLNT_STREAMFLAGS_SRC_DEFAULT_QUALITY,
                                0, 0, &format, nullptr);
  }
  if (SUCCEEDED(result)) result = client->SetEventHandle(sample_ready);
  ComPtr<IAudioCaptureClient> capture;
  if (SUCCEEDED(result)) result = client->GetService(IID_PPV_ARGS(&capture));
  if (SUCCEEDED(result)) result = client->Start();
  if (FAILED(result)) {
    on_error(WindowsError(result));
    CloseHandle(completed);
    CloseHandle(sample_ready);
    if (uninitialize) RoUninitialize();
    return;
  }

  CreateDirectoryW(output_directory.c_str(), nullptr);
  std::deque<int16_t> pre_roll;
  std::vector<int16_t> segment;
  size_t silence_samples = 0;
  bool speaking = false;
  uint64_t sequence = 0;
  while (!stopping_) {
    WaitForSingleObject(sample_ready, 100);
    UINT32 packet_frames = 0;
    while (SUCCEEDED(capture->GetNextPacketSize(&packet_frames)) && packet_frames > 0) {
      BYTE* bytes = nullptr;
      DWORD flags = 0;
      UINT32 frames = 0;
      if (FAILED(capture->GetBuffer(&bytes, &frames, &flags, nullptr, nullptr))) break;
      const auto* input = reinterpret_cast<const int16_t*>(bytes);
      double square_sum = 0;
      if ((flags & AUDCLNT_BUFFERFLAGS_SILENT) == 0) {
        for (UINT32 index = 0; index < frames; ++index) {
          const double value = input[index];
          square_sum += value * value;
        }
      }
      const double rms = frames == 0 ? 0 : std::sqrt(square_sum / frames);
      const bool voiced = rms >= kSpeechRms;
      if (!speaking) {
        for (UINT32 index = 0; index < frames; ++index) {
          pre_roll.push_back((flags & AUDCLNT_BUFFERFLAGS_SILENT) == 0 ? input[index] : 0);
        }
        while (pre_roll.size() > kPreRollSamples) pre_roll.pop_front();
        if (voiced) {
          speaking = true;
          segment.assign(pre_roll.begin(), pre_roll.end());
          pre_roll.clear();
        }
      } else {
        const size_t old_size = segment.size();
        segment.resize(old_size + frames, 0);
        if ((flags & AUDCLNT_BUFFERFLAGS_SILENT) == 0) {
          std::copy(input, input + frames, segment.begin() + static_cast<std::ptrdiff_t>(old_size));
        }
        silence_samples = voiced ? 0 : silence_samples + frames;
      }
      capture->ReleaseBuffer(frames);

      const bool end_segment = speaking &&
          (silence_samples >= kEndSilenceSamples || segment.size() >= kMaximumSegmentSamples);
      if (end_segment) {
        if (segment.size() >= kMinimumSpeechSamples) {
          const std::wstring filename = output_directory + L"\\segment-" +
                                        std::to_wstring(GetCurrentProcessId()) + L"-" +
                                        std::to_wstring(++sequence) + L".wav";
          if (WriteWave(filename, std::move(segment))) {
            const int utf8_size = WideCharToMultiByte(CP_UTF8, 0, filename.c_str(), -1,
                                                       nullptr, 0, nullptr, nullptr);
            std::string utf8(static_cast<size_t>(utf8_size), '\0');
            WideCharToMultiByte(CP_UTF8, 0, filename.c_str(), -1, utf8.data(),
                                utf8_size, nullptr, nullptr);
            utf8.pop_back();
            on_segment(utf8);
          }
        }
        segment.clear();
        silence_samples = 0;
        speaking = false;
      }
    }
  }
  client->Stop();
  CloseHandle(completed);
  CloseHandle(sample_ready);
  if (uninitialize) RoUninitialize();
#endif
}
