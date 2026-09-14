// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

#include "audio_decoder.h"

#if defined(_WIN32)

// windows.h brings min and max as macros, which would swallow the std ones
// wave_file.h calls.
#define NOMINMAX
#include <windows.h>

#include <mfapi.h>
#include <mferror.h>
#include <mfidl.h>
#include <mfreadwrite.h>
#include <wrl.h>

#include <vector>

#include "wave_file.h"

namespace {

using Microsoft::WRL::ComPtr;

// What the pipeline hears everywhere else. A fingerprint measured at another
// rate is not the same fingerprint: the same clip read at 48 kHz and at
// 16 kHz meets itself at a cosine of 0.5 to 0.86, which is under the 0.80 a
// character is recognized by. So a file is brought to the rate the capture
// works at before the converter is ever shown it.
constexpr uint32_t kSampleRate = 16000;

// Media Foundation is started once and left running: the decoder is asked
// for a file at a time, and paying for the startup each time would show.
struct MediaFoundation {
  MediaFoundation() { ok = SUCCEEDED(MFStartup(MF_VERSION, MFSTARTUP_LITE)); }
  ~MediaFoundation() {
    if (ok) MFShutdown();
  }
  bool ok = false;
};

bool StartMediaFoundation() {
  static MediaFoundation started;
  return started.ok;
}

}  // namespace

int32_t DecodeAudioFile(const std::wstring& input, const std::wstring& output, double* seconds) {
  if (seconds != nullptr) *seconds = 0;
  if (!StartMediaFoundation()) return kDecodeUnavailable;

  // Windows brings its own decoders: wav, mp3, flac, m4a and wma always, ogg
  // and opus through the Web Media Extensions that ship with Windows 10 and
  // later. Anything it cannot read comes back as "unsupported" rather than
  // as a half-written file.
  ComPtr<IMFSourceReader> reader;
  ComPtr<IMFAttributes> attributes;
  if (FAILED(MFCreateAttributes(&attributes, 1))) return kDecodeUnavailable;
  attributes->SetUINT32(MF_SOURCE_READER_ENABLE_ADVANCED_VIDEO_PROCESSING, FALSE);
  if (FAILED(MFCreateSourceReaderFromURL(input.c_str(), attributes.Get(), &reader))) {
    return kDecodeUnsupported;
  }

  reader->SetStreamSelection(MF_SOURCE_READER_ALL_STREAMS, FALSE);
  if (FAILED(reader->SetStreamSelection(MF_SOURCE_READER_FIRST_AUDIO_STREAM, TRUE))) {
    return kDecodeNoAudio;
  }

  // Asking for PCM at one rate is what puts the decoder and the resampler in
  // front of us: the reader builds the chain it needs to answer in this
  // shape, or refuses the file.
  ComPtr<IMFMediaType> wanted;
  if (FAILED(MFCreateMediaType(&wanted))) return kDecodeUnavailable;
  wanted->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Audio);
  wanted->SetGUID(MF_MT_SUBTYPE, MFAudioFormat_PCM);
  wanted->SetUINT32(MF_MT_AUDIO_BITS_PER_SAMPLE, 16);
  wanted->SetUINT32(MF_MT_AUDIO_SAMPLES_PER_SECOND, kSampleRate);
  wanted->SetUINT32(MF_MT_AUDIO_NUM_CHANNELS, 1);
  if (FAILED(reader->SetCurrentMediaType(MF_SOURCE_READER_FIRST_AUDIO_STREAM, nullptr,
                                         wanted.Get()))) {
    return kDecodeUnsupported;
  }

  std::vector<int16_t> samples;
  while (true) {
    DWORD flags = 0;
    ComPtr<IMFSample> sample;
    const HRESULT read = reader->ReadSample(MF_SOURCE_READER_FIRST_AUDIO_STREAM, 0, nullptr,
                                            &flags, nullptr, &sample);
    if (FAILED(read)) return kDecodeUnsupported;
    if ((flags & MF_SOURCE_READERF_ENDOFSTREAM) != 0) break;
    // A stream whose type changes mid-file is one we asked to be converted,
    // so the reader has already put it back into the shape above.
    if (sample == nullptr) continue;

    ComPtr<IMFMediaBuffer> buffer;
    if (FAILED(sample->ConvertToContiguousBuffer(&buffer))) return kDecodeUnsupported;
    BYTE* bytes = nullptr;
    DWORD length = 0;
    if (FAILED(buffer->Lock(&bytes, nullptr, &length))) return kDecodeUnsupported;
    const size_t count = length / sizeof(int16_t);
    const int16_t* pcm = reinterpret_cast<const int16_t*>(bytes);
    samples.insert(samples.end(), pcm, pcm + count);
    buffer->Unlock();

    // A file far longer than anybody needs for a fingerprint is cut rather
    // than read whole: ten minutes of one voice says no more than one does.
    if (samples.size() > static_cast<size_t>(kSampleRate) * 600) break;
  }

  if (samples.empty()) return kDecodeNoAudio;
  if (seconds != nullptr) *seconds = static_cast<double>(samples.size()) / kSampleRate;
  return wave_file::WriteMono(output, std::move(samples), kSampleRate) ? 0 : kDecodeNotWritten;
}

#else

int32_t DecodeAudioFile(const std::wstring&, const std::wstring&, double* seconds) {
  if (seconds != nullptr) *seconds = 0;
  return kDecodeUnavailable;
}

#endif
