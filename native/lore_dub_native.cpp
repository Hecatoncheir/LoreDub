// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

#include "lore_dub_native.h"
#include "ocr_capture.h"
#include "process_loopback_capture.h"
#include "snapshot_overlay.h"

#include <algorithm>
#include <atomic>
#include <chrono>
#include <cstring>
#include <deque>
#include <future>
#include <thread>
#include <mutex>
#include <sstream>
#include <string>
#include <unordered_map>
#include <memory>
#include <vector>

#if defined(_WIN32)
#define NOMINMAX
#include <audioclient.h>
#include <audiopolicy.h>
#include <mmdeviceapi.h>
#include <windows.h>
#include <psapi.h>
#include <tlhelp32.h>
#include <wrl/client.h>
#include <mmsystem.h>
#include <dxgi.h>
#endif

namespace {

std::mutex event_mutex;
std::deque<std::string> events;
bool running = false;

// Read on the capture threads: while set, what they finish is thrown away
// instead of queued.
std::atomic<bool> paused{false};
std::unique_ptr<ProcessLoopbackCapture> loopback_capture;
std::unique_ptr<OcrCapture> ocr_capture;

void PushEvent(std::string event) {
  std::lock_guard<std::mutex> lock(event_mutex);
  if (events.size() >= 128) {
    events.pop_front();
  }
  events.push_back(std::move(event));
}

int32_t WriteString(const std::string& value, char* output, int32_t capacity) {
  const auto required = static_cast<int32_t>(value.size());
  if (output == nullptr || capacity <= required) {
    return required;
  }
  std::memcpy(output, value.data(), value.size());
  output[value.size()] = '\0';
  return required;
}

#if defined(_WIN32)
using Microsoft::WRL::ComPtr;

std::mutex volumes_mutex;
std::unordered_map<std::wstring, float> original_volumes;

std::string EscapeJson(const std::string& input) {
  std::ostringstream out;
  for (const unsigned char character : input) {
    switch (character) {
      case '\\': out << "\\\\"; break;
      case '"': out << "\\\""; break;
      case '\n': out << "\\n"; break;
      case '\r': out << "\\r"; break;
      case '\t': out << "\\t"; break;
      default:
        if (character < 0x20) {
          out << "?";
        } else {
          out << character;
        }
    }
  }
  return out.str();
}

std::string Utf8(const std::wstring& input) {
  if (input.empty()) return {};
  const int size = WideCharToMultiByte(CP_UTF8, 0, input.data(),
                                       static_cast<int>(input.size()), nullptr,
                                       0, nullptr, nullptr);
  std::string output(size, '\0');
  WideCharToMultiByte(CP_UTF8, 0, input.data(), static_cast<int>(input.size()),
                      output.data(), size, nullptr, nullptr);
  return output;
}

std::wstring Wide(const std::string& input) {
  if (input.empty()) return {};
  const int size = MultiByteToWideChar(CP_UTF8, 0, input.data(),
                                       static_cast<int>(input.size()), nullptr, 0);
  std::wstring output(size, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, input.data(), static_cast<int>(input.size()),
                      output.data(), size);
  return output;
}

uint32_t JsonUnsigned(const std::string& json, const std::string& key) {
  const std::string marker = "\"" + key + "\":";
  const auto start = json.find(marker);
  if (start == std::string::npos) return 0;
  try {
    return static_cast<uint32_t>(std::stoul(json.substr(start + marker.size())));
  } catch (...) {
    return 0;
  }
}

std::string JsonString(const std::string& json, const std::string& key) {
  const std::string marker = "\"" + key + "\":\"";
  auto cursor = json.find(marker);
  if (cursor == std::string::npos) return {};
  cursor += marker.size();
  std::string value;
  bool escaped = false;
  for (; cursor < json.size(); ++cursor) {
    const char character = json[cursor];
    if (escaped) {
      switch (character) {
        case 'n': value.push_back('\n'); break;
        case 'r': value.push_back('\r'); break;
        case 't': value.push_back('\t'); break;
        default: value.push_back(character); break;
      }
      escaped = false;
    } else if (character == '\\') {
      escaped = true;
    } else if (character == '"') {
      break;
    } else {
      value.push_back(character);
    }
  }
  return value;
}

double JsonDouble(const std::string& json, const std::string& key,
                  double fallback) {
  const std::string marker = "\"" + key + "\":";
  const auto start = json.find(marker);
  if (start == std::string::npos) return fallback;
  try {
    return std::stod(json.substr(start + marker.size()));
  } catch (...) {
    return fallback;
  }
}

std::wstring ProcessPath(DWORD process_id) {
  HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE,
                               process_id);
  if (process == nullptr) return {};
  std::wstring path(32768, L'\0');
  DWORD length = static_cast<DWORD>(path.size());
  if (!QueryFullProcessImageNameW(process, 0, path.data(), &length)) {
    CloseHandle(process);
    return {};
  }
  CloseHandle(process);
  path.resize(length);
  return path;
}

std::wstring BaseName(const std::wstring& path) {
  const auto separator = path.find_last_of(L"\\/");
  return separator == std::wstring::npos ? path : path.substr(separator + 1);
}

std::string ListProcesses() {
  HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if (snapshot == INVALID_HANDLE_VALUE) return "[]";
  PROCESSENTRY32W entry{};
  entry.dwSize = sizeof(entry);
  std::ostringstream out;
  out << '[';
  bool first = true;
  if (Process32FirstW(snapshot, &entry)) {
    do {
      const std::wstring path = ProcessPath(entry.th32ProcessID);
      if (path.empty()) continue;
      if (!first) out << ',';
      first = false;
      out << "{\"pid\":" << entry.th32ProcessID << ",\"name\":\""
          << EscapeJson(Utf8(BaseName(path))) << "\",\"path\":\""
          << EscapeJson(Utf8(path)) << "\"}";
    } while (Process32NextW(snapshot, &entry));
  }
  CloseHandle(snapshot);
  out << ']';
  return out.str();
}

// Whether a driver library is installed, without running its entry point.
// Loading nvcuda.dll for real spins up the display driver, which is a lot to
// ask for a question the interface only wants an answer to once.
bool HasSystemLibrary(const wchar_t* name) {
  HMODULE library = LoadLibraryExW(name, nullptr, LOAD_LIBRARY_AS_DATAFILE);
  if (library == nullptr) return false;
  FreeLibrary(library);
  return true;
}

// Enumerates the real graphics adapters. Microsoft's Basic Render Driver is
// reported like any other adapter and would make every machine look capable
// of Vulkan, so software adapters are dropped.
std::string ProbeGraphics() {
  std::ostringstream out;
  out << "{\"adapters\":[";
  ComPtr<IDXGIFactory1> factory;
  bool first = true;
  if (SUCCEEDED(CreateDXGIFactory1(IID_PPV_ARGS(&factory)))) {
    ComPtr<IDXGIAdapter1> adapter;
    for (UINT index = 0;
         factory->EnumAdapters1(index, adapter.ReleaseAndGetAddressOf()) != DXGI_ERROR_NOT_FOUND;
         ++index) {
      DXGI_ADAPTER_DESC1 description{};
      if (FAILED(adapter->GetDesc1(&description))) continue;
      if ((description.Flags & DXGI_ADAPTER_FLAG_SOFTWARE) != 0) continue;
      if (!first) out << ',';
      first = false;
      out << "{\"name\":\"" << EscapeJson(Utf8(description.Description))
          << "\",\"vendorId\":" << description.VendorId << ",\"dedicatedMemory\":"
          << static_cast<uint64_t>(description.DedicatedVideoMemory) << '}';
    }
  }
  out << "],\"cudaDriver\":" << (HasSystemLibrary(L"nvcuda.dll") ? "true" : "false")
      << ",\"vulkanLoader\":" << (HasSystemLibrary(L"vulkan-1.dll") ? "true" : "false") << '}';
  return out.str();
}

int32_t VisitSessions(uint32_t process_id, float volume, bool restore) {
  const HRESULT initialized = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
  const bool uninitialize = SUCCEEDED(initialized);
  ComPtr<IMMDeviceEnumerator> enumerator;
  HRESULT result = CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr,
                                    CLSCTX_ALL, IID_PPV_ARGS(&enumerator));
  if (FAILED(result)) return -10;
  ComPtr<IMMDevice> device;
  result = enumerator->GetDefaultAudioEndpoint(eRender, eConsole, &device);
  if (FAILED(result)) return -11;
  ComPtr<IAudioSessionManager2> manager;
  result = device->Activate(__uuidof(IAudioSessionManager2), CLSCTX_ALL,
                            nullptr, &manager);
  if (FAILED(result)) return -12;
  ComPtr<IAudioSessionEnumerator> sessions;
  result = manager->GetSessionEnumerator(&sessions);
  if (FAILED(result)) return -13;
  int count = 0;
  sessions->GetCount(&count);
  int changed = 0;
  std::lock_guard<std::mutex> lock(volumes_mutex);
  for (int index = 0; index < count; ++index) {
    ComPtr<IAudioSessionControl> control;
    if (FAILED(sessions->GetSession(index, &control))) continue;
    ComPtr<IAudioSessionControl2> control2;
    if (FAILED(control.As(&control2))) continue;
    DWORD session_process_id = 0;
    if (FAILED(control2->GetProcessId(&session_process_id))) continue;
    if (!restore && session_process_id != process_id) continue;
    LPWSTR raw_identifier = nullptr;
    if (FAILED(control2->GetSessionInstanceIdentifier(&raw_identifier))) {
      continue;
    }
    const std::wstring identifier(raw_identifier);
    CoTaskMemFree(raw_identifier);
    ComPtr<ISimpleAudioVolume> simple_volume;
    if (FAILED(control.As(&simple_volume))) continue;
    if (restore) {
      const auto original = original_volumes.find(identifier);
      if (original == original_volumes.end()) continue;
      if (SUCCEEDED(simple_volume->SetMasterVolume(original->second, nullptr))) {
        ++changed;
      }
    } else {
      float current = 1.0f;
      if (SUCCEEDED(simple_volume->GetMasterVolume(&current))) {
        original_volumes.try_emplace(identifier, current);
      }
      if (SUCCEEDED(simple_volume->SetMasterVolume(volume, nullptr))) ++changed;
    }
  }
  if (restore) original_volumes.clear();
  if (uninitialize) CoUninitialize();
  return 0;
}
#endif

}  // namespace

int32_t ld_abi_version(void) { return 1; }

int32_t ld_is_process_loopback_supported(void) {
#if defined(_WIN32)
  return 1;
#else
  return 0;
#endif
}

int32_t ld_list_processes_json(char* output, int32_t capacity) {
#if defined(_WIN32)
  return WriteString(ListProcesses(), output, capacity);
#else
  return WriteString("[]", output, capacity);
#endif
}

int32_t ld_probe_graphics_json(char* output, int32_t capacity) {
#if defined(_WIN32)
  return WriteString(ProbeGraphics(), output, capacity);
#else
  return WriteString("{\"adapters\":[],\"cudaDriver\":false,\"vulkanLoader\":false}", output,
                     capacity);
#endif
}

int32_t ld_set_process_volume(uint32_t process_id, float volume) {
#if defined(_WIN32)
  return VisitSessions(process_id, std::clamp(volume, 0.0f, 1.0f), false);
#else
  (void)process_id;
  (void)volume;
  return -2;
#endif
}

int32_t ld_restore_process_volumes(void) {
#if defined(_WIN32)
  return VisitSessions(0, 1.0f, true);
#else
  return -2;
#endif
}

#if defined(_WIN32)
namespace {

// RegisterHotKey delivers WM_HOTKEY to the thread that registered, so the
// hotkeys live on a thread of their own with nothing but a message loop.
std::mutex hotkey_mutex;
std::thread hotkey_thread;
std::atomic<DWORD> hotkey_thread_id{0};

// Reads the area the player selected. Only the hotkey thread starts it, and
// StopHotkeys joins it once that thread is gone.
std::thread snapshot_reader;

constexpr int kPauseHotkey = 1;
constexpr int kResumeHotkey = 2;
constexpr int kSnapshotHotkey = 3;

struct HotkeyConfig {
  uint32_t pause_key = 0;
  uint32_t pause_modifiers = 0;
  uint32_t resume_key = 0;
  uint32_t resume_modifiers = 0;
  uint32_t snapshot_key = 0;
  uint32_t snapshot_modifiers = 0;

  // The primary subtag a selected area is read in.
  std::string snapshot_language = "en";
};

// What a reader's error becomes on the event queue: the one Dart can word
// for itself, or the message as it came.
void PushOcrError(const std::string& message, const std::string& language) {
  if (message == kOcrLanguageMissing) {
    PushEvent("{\"type\":\"ocrLanguageMissing\",\"language\":\"" + EscapeJson(language) + "\"}");
  } else {
    PushEvent("{\"type\":\"error\",\"message\":\"" + EscapeJson(message) + "\"}");
  }
}

// Registers one combination, or says which action another program holds it
// for. A zero key leaves the action unbound.
bool RegisterAction(int id, uint32_t key, uint32_t modifiers, const char* action) {
  if (key == 0) return false;
  if (RegisterHotKey(nullptr, id, modifiers | MOD_NOREPEAT, key)) return true;
  PushEvent(std::string("{\"type\":\"hotkeyTaken\",\"action\":\"") + action + "\"}");
  return false;
}

void PushHotkeyPress(uintptr_t id) {
  if (id == kPauseHotkey) PushEvent("{\"type\":\"hotkey\",\"action\":\"pause\"}");
  if (id == kResumeHotkey) PushEvent("{\"type\":\"hotkey\",\"action\":\"resume\"}");
}

// Lets the player select an area while the snapshot key is held, then reads
// it on a thread of its own, so the hotkeys keep answering meanwhile.
// Returns false when a WM_QUIT arrived during the selection.
bool TakeSnapshot(uint32_t key, const std::string& language) {
  ScreenArea area;
  const auto result = SelectScreenArea(key, &area, PushHotkeyPress);
  if (result == SelectionResult::quit) return false;
  if (result == SelectionResult::cancelled) return true;
  if (snapshot_reader.joinable()) snapshot_reader.join();
  PushEvent("{\"type\":\"snapshotReading\"}");
  snapshot_reader = std::thread([area, language] {
    // The shade has to leave the screen, and a game that lost the
    // foreground to it has to draw itself again, before the area is copied.
    std::this_thread::sleep_for(std::chrono::milliseconds(150));
    std::string text;
    std::string error;
    if (RecognizeScreenArea(area, language, &text, &error)) {
      PushEvent("{\"type\":\"snapshot\",\"text\":\"" + EscapeJson(text) + "\"}");
    } else {
      PushEvent("{\"type\":\"snapshot\",\"text\":\"\",\"failed\":true}");
      PushOcrError(error, language);
    }
  });
  return true;
}

void HotkeyLoop(HotkeyConfig config, std::promise<void>* ready) {
  MSG message;
  // Creates this thread's message queue, so a WM_QUIT posted from the
  // outside cannot arrive before there is a queue to receive it.
  PeekMessageW(&message, nullptr, WM_USER, WM_USER, PM_NOREMOVE);
  hotkey_thread_id = GetCurrentThreadId();
  const bool pause_ok =
      RegisterAction(kPauseHotkey, config.pause_key, config.pause_modifiers, "pause");
  const bool resume_ok =
      RegisterAction(kResumeHotkey, config.resume_key, config.resume_modifiers, "resume");
  const bool snapshot_ok =
      RegisterAction(kSnapshotHotkey, config.snapshot_key, config.snapshot_modifiers, "snapshot");
  ready->set_value();
  while (GetMessageW(&message, nullptr, 0, 0) > 0) {
    if (message.message != WM_HOTKEY) continue;
    if (message.wParam == kSnapshotHotkey) {
      if (!TakeSnapshot(config.snapshot_key, config.snapshot_language)) break;
      continue;
    }
    PushHotkeyPress(static_cast<uintptr_t>(message.wParam));
  }
  if (pause_ok) UnregisterHotKey(nullptr, kPauseHotkey);
  if (resume_ok) UnregisterHotKey(nullptr, kResumeHotkey);
  if (snapshot_ok) UnregisterHotKey(nullptr, kSnapshotHotkey);
}

void StopHotkeys() {
  std::lock_guard<std::mutex> lock(hotkey_mutex);
  if (!hotkey_thread.joinable()) return;
  PostThreadMessageW(hotkey_thread_id.load(), WM_QUIT, 0, 0);
  hotkey_thread.join();
  hotkey_thread_id = 0;
  if (snapshot_reader.joinable()) snapshot_reader.join();
}

}  // namespace
#endif

int32_t ld_set_paused(int32_t value) {
  paused = value != 0;
  return 0;
}

int32_t ld_set_hotkeys(const char* config_json) {
#if defined(_WIN32)
  StopHotkeys();
  if (config_json == nullptr || config_json[0] == '\0') return 0;
  const std::string config(config_json);
  HotkeyConfig hotkeys{JsonUnsigned(config, "pauseKey"),
                       JsonUnsigned(config, "pauseModifiers"),
                       JsonUnsigned(config, "resumeKey"),
                       JsonUnsigned(config, "resumeModifiers"),
                       JsonUnsigned(config, "snapshotKey"),
                       JsonUnsigned(config, "snapshotModifiers")};
  if (const auto language = JsonString(config, "snapshotLanguage"); !language.empty()) {
    hotkeys.snapshot_language = language;
  }
  if (hotkeys.pause_key == 0 && hotkeys.resume_key == 0 && hotkeys.snapshot_key == 0) return 0;
  std::lock_guard<std::mutex> lock(hotkey_mutex);
  std::promise<void> ready;
  auto registered = ready.get_future();
  hotkey_thread = std::thread(HotkeyLoop, hotkeys, &ready);
  // The thread holds [ready] only until it has registered.
  registered.wait();
  return 0;
#else
  (void)config_json;
  return -2;
#endif
}

#if defined(_WIN32)
namespace {

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

}  // namespace
#endif

// Blocks until the clip has played, as PlaySound with SND_SYNC did. PlaySound
// holds one sound per process and cuts off whatever is playing, so two
// characters could never be heard at once; every call here opens a waveOut
// stream of its own instead, and Windows mixes the ones that overlap.
int32_t ld_play_wave(const char* utf8_path) {
#if defined(_WIN32)
  if (utf8_path == nullptr || utf8_path[0] == '\0') return -20;
  WaveClip clip;
  if (!ReadWaveClip(Wide(utf8_path), clip)) return -21;
  HANDLE done = CreateEventW(nullptr, FALSE, FALSE, nullptr);
  if (done == nullptr) return -21;
  HWAVEOUT device = nullptr;
  if (waveOutOpen(&device, WAVE_MAPPER, &clip.format, reinterpret_cast<DWORD_PTR>(done), 0,
                  CALLBACK_EVENT) != MMSYSERR_NOERROR) {
    CloseHandle(done);
    return -21;
  }
  WAVEHDR header{};
  header.lpData = clip.samples.data();
  header.dwBufferLength = static_cast<DWORD>(clip.samples.size());
  int32_t result = -21;
  if (waveOutPrepareHeader(device, &header, sizeof(header)) == MMSYSERR_NOERROR) {
    if (waveOutWrite(device, &header, sizeof(header)) == MMSYSERR_NOERROR) {
      // The event also fires when the device opens and closes, so the flag the
      // driver sets is what says the clip is over.
      const volatile DWORD& flags = header.dwFlags;
      while ((flags & WHDR_DONE) == 0) WaitForSingleObject(done, 1000);
      result = 0;
    }
    waveOutUnprepareHeader(device, &header, sizeof(header));
  }
  waveOutClose(device);
  CloseHandle(done);
  return result;
#else
  (void)utf8_path;
  return -2;
#endif
}

int32_t ld_start(const char* config_json) {
  if (running) return -3;
  if (config_json == nullptr || config_json[0] == '\0') return -4;
  running = true;
  paused = false;
  PushEvent("{\"type\":\"state\",\"state\":\"starting\"}");
#if defined(_WIN32)
  const std::string config(config_json);
  const uint32_t process_id = JsonUnsigned(config, "processId");
  const std::string capture_directory = JsonString(config, "captureDirectory");
  const std::string capture_mode = JsonString(config, "captureMode");
  const std::string audio_source = JsonString(config, "audioSource");
  const bool needs_process = capture_mode == "ocr" || audio_source != "system";
  if ((needs_process && process_id == 0) ||
      (capture_mode != "ocr" && capture_directory.empty())) {
    running = false;
    return -5;
  }
  if (capture_mode == "ocr") {
    ocr_capture = std::make_unique<OcrCapture>();
    const OcrRegion region{JsonDouble(config, "ocrRegionLeft", 0.0),
                           JsonDouble(config, "ocrRegionTop", 0.55),
                           JsonDouble(config, "ocrRegionRight", 1.0),
                           JsonDouble(config, "ocrRegionBottom", 1.0)};
    std::string ocr_language = JsonString(config, "ocrLanguage");
    if (ocr_language.empty()) ocr_language = "en";
    if (!ocr_capture->Start(
            process_id, region, ocr_language,
            [](const std::string& recognized_text) {
              if (paused) return;
              PushEvent("{\"type\":\"ocrText\",\"text\":\"" +
                        EscapeJson(recognized_text) + "\"}");
            },
            [ocr_language](const std::string& message) { PushOcrError(message, ocr_language); })) {
      ocr_capture.reset();
      running = false;
      return -7;
    }
  } else {
    loopback_capture = std::make_unique<ProcessLoopbackCapture>();
    const bool capture_system = audio_source == "system";
    const uint32_t capture_process_id =
        capture_system ? GetCurrentProcessId() : process_id;
    if (!loopback_capture->Start(
            capture_process_id, capture_system, Wide(capture_directory),
            [](const std::string& filename) {
              // Queued even while paused: the Dart side drops a segment that
              // arrives during the pause and deletes its file, so the native
              // library never deletes files itself.
              PushEvent("{\"type\":\"audioSegment\",\"path\":\"" +
                        EscapeJson(filename) + "\"}");
            },
            [](const std::string& message) {
              PushEvent("{\"type\":\"error\",\"message\":\"" +
                        EscapeJson(message) + "\"}");
            })) {
      loopback_capture.reset();
      running = false;
      return -6;
    }
  }
  PushEvent("{\"type\":\"state\",\"state\":\"listening\"}");
  return 0;
#else
  PushEvent("{\"type\":\"error\",\"message\":\"Process loopback is only available on Windows\"}");
  running = false;
  return -2;
#endif
}

int32_t ld_stop(void) {
  if (loopback_capture) {
    loopback_capture->Stop();
    loopback_capture.reset();
  }
  if (ocr_capture) {
    ocr_capture->Stop();
    ocr_capture.reset();
  }
  running = false;
  paused = false;
#if defined(_WIN32)
  // Nothing is left to pause or resume.
  StopHotkeys();
#endif
  PushEvent("{\"type\":\"state\",\"state\":\"idle\"}");
  ld_restore_process_volumes();
  return 0;
}

int32_t ld_poll_event_json(char* output, int32_t capacity) {
  std::lock_guard<std::mutex> lock(event_mutex);
  if (events.empty()) return 0;
  const int32_t result = WriteString(events.front(), output, capacity);
  if (output != nullptr && capacity > result) events.pop_front();
  return result;
}

const char* ld_error_message(int32_t error_code) {
  switch (error_code) {
    case 0: return "Success";
    case -2: return "Feature is unsupported on this platform";
    case -3: return "Pipeline is already running";
    case -4: return "Pipeline configuration is empty";
    case -5: return "Pipeline process or capture directory is invalid";
    case -6: return "Cannot start the Windows process loopback worker";
    case -7: return "Cannot start the Windows OCR worker";
    case -10: return "Cannot create Windows audio device enumerator";
    case -11: return "Cannot open the default render endpoint";
    case -12: return "Cannot activate the audio session manager";
    case -13: return "Cannot enumerate audio sessions";
    case -14: return "No matching active audio session was found";
    case -20: return "Playback path is empty";
    case -21: return "Windows could not play the generated wave file";
    default: return "Unknown native error";
  }
}
