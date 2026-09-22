// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

#include "wave_player.h"

#include <windows.h>
#include <mmsystem.h>

#include <algorithm>
#include <cstring>
#include <mutex>
#include <vector>

namespace {

// How much longer than its own length a clip may take to be reported done.
constexpr ULONGLONG kPlaybackGraceMilliseconds = 5000;

// A PCM WAV file's format and samples, as far as playback needs them.
struct WaveClip {
  WAVEFORMATEX format{};
  std::vector<char> samples;
};

bool ReadWaveClip(const std::wstring& path, WaveClip& clip) {
  HANDLE file = CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr,
                            OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
  if (file == INVALID_HANDLE_VALUE) return false;
  LARGE_INTEGER size{};
  std::vector<char> bytes;
  bool ok = GetFileSizeEx(file, &size) && size.QuadPart > 12 && size.QuadPart < (1LL << 30);
  if (ok) {
    bytes.resize(static_cast<size_t>(size.QuadPart));
    DWORD read = 0;
    ok = ReadFile(file, bytes.data(), static_cast<DWORD>(bytes.size()), &read, nullptr) &&
         read == bytes.size();
  }
  CloseHandle(file);
  if (!ok || std::memcmp(bytes.data(), "RIFF", 4) != 0 ||
      std::memcmp(bytes.data() + 8, "WAVE", 4) != 0) {
    return false;
  }
  bool has_format = false;
  size_t offset = 12;
  while (offset + 8 <= bytes.size()) {
    uint32_t length = 0;
    std::memcpy(&length, bytes.data() + offset + 4, sizeof(length));
    const size_t body = offset + 8;
    const size_t available = std::min<size_t>(length, bytes.size() - body);
    if (std::memcmp(bytes.data() + offset, "fmt ", 4) == 0 && available >= 16) {
      // The first 16 bytes of the chunk are WAVEFORMATEX without cbSize.
      std::memcpy(&clip.format, bytes.data() + body, 16);
      clip.format.cbSize = 0;
      has_format = true;
    } else if (std::memcmp(bytes.data() + offset, "data", 4) == 0) {
      clip.samples.assign(bytes.data() + body, bytes.data() + body + available);
    }
    offset = body + static_cast<size_t>(length) + (length & 1);
  }
  return has_format && clip.format.wFormatTag == WAVE_FORMAT_PCM && !clip.samples.empty();
}

// Every clip sounding right now. A card's recording may run for three
// minutes, so what was started has to be stoppable; the list is what
// StopWaves reaches for.
std::mutex sounding_mutex;
std::vector<HWAVEOUT> sounding_devices;

// Writes [clip] to [device] and waits for it, for no longer than the clip
// lasts and a little more: a device pulled out mid-line may never say it is
// done, and the thread that plays the line -- and the place it holds among
// the voices that may sound at once -- was held for good.
int32_t PlayOn(HWAVEOUT device, HANDLE done, WaveClip& clip) {
  WAVEHDR header{};
  header.lpData = clip.samples.data();
  header.dwBufferLength = static_cast<DWORD>(clip.samples.size());
  if (waveOutPrepareHeader(device, &header, sizeof(header)) != MMSYSERR_NOERROR) return -21;
  int32_t result = -21;
  if (waveOutWrite(device, &header, sizeof(header)) == MMSYSERR_NOERROR) {
    // The event also fires when the device opens and closes, so the flag the
    // driver sets is what says the clip is over.
    const volatile DWORD& flags = header.dwFlags;
    const ULONGLONG bytes_per_second =
        clip.format.nAvgBytesPerSec != 0 ? clip.format.nAvgBytesPerSec : 1;
    const ULONGLONG deadline = GetTickCount64() +
                               clip.samples.size() * 1000 / bytes_per_second +
                               kPlaybackGraceMilliseconds;
    while ((flags & WHDR_DONE) == 0 && GetTickCount64() < deadline) {
      WaitForSingleObject(done, 1000);
    }
    if ((flags & WHDR_DONE) != 0) {
      result = 0;
    } else {
      // Handed back by the device, so the header can be let go of.
      waveOutReset(device);
      result = -22;
    }
  }
  waveOutUnprepareHeader(device, &header, sizeof(header));
  return result;
}

}  // namespace

int32_t PlayWave(const std::wstring& path) {
  WaveClip clip;
  if (!ReadWaveClip(path, clip)) return -21;
  HANDLE done = CreateEventW(nullptr, FALSE, FALSE, nullptr);
  if (done == nullptr) return -21;
  HWAVEOUT device = nullptr;
  if (waveOutOpen(&device, WAVE_MAPPER, &clip.format, reinterpret_cast<DWORD_PTR>(done), 0,
                  CALLBACK_EVENT) != MMSYSERR_NOERROR) {
    CloseHandle(done);
    return -21;
  }
  {
    std::lock_guard<std::mutex> lock(sounding_mutex);
    sounding_devices.push_back(device);
  }
  const int32_t result = PlayOn(device, done, clip);
  {
    // Taken off the list before the handle is closed: whoever stops a clip
    // must not be left holding a device that no longer exists.
    std::lock_guard<std::mutex> lock(sounding_mutex);
    sounding_devices.erase(
        std::remove(sounding_devices.begin(), sounding_devices.end(), device),
        sounding_devices.end());
  }
  waveOutClose(device);
  CloseHandle(done);
  return result;
}

// Resetting the device marks its buffer done, so the call playing it returns
// as if the clip had finished.
int32_t StopWaves() {
  std::lock_guard<std::mutex> lock(sounding_mutex);
  for (const HWAVEOUT device : sounding_devices) waveOutReset(device);
  return static_cast<int32_t>(sounding_devices.size());
}
