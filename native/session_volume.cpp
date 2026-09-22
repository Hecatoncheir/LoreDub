// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

#include "session_volume.h"

#include <windows.h>
#include <audioclient.h>
#include <audiopolicy.h>
#include <mmdeviceapi.h>
#include <wrl/client.h>

#include <mutex>
#include <string>
#include <unordered_map>

namespace {

using Microsoft::WRL::ComPtr;

std::mutex volumes_mutex;

// The volume each session had before the dubbing first turned it down, by
// session instance identifier.
std::unordered_map<std::wstring, float> original_volumes;

// COM for as long as this object lives, on this thread, when it was not on
// already. Declared before any COM object, it is let go of after all of them:
// the objects used to be released once the apartment had closed.
class ComApartment {
 public:
  ComApartment() : initialized_(SUCCEEDED(CoInitializeEx(nullptr, COINIT_MULTITHREADED))) {}
  ~ComApartment() {
    if (initialized_) CoUninitialize();
  }
  ComApartment(const ComApartment&) = delete;
  ComApartment& operator=(const ComApartment&) = delete;

 private:
  const bool initialized_;
};

// Calls [visit] with every audio session of the default render endpoint --
// the process that owns it, its identifier and its volume -- and answers 0,
// or the code of the step that could not be taken.
template <typename Visit>
int32_t ForEachRenderSession(Visit visit) {
  ComApartment apartment;
  ComPtr<IMMDeviceEnumerator> enumerator;
  if (FAILED(CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL,
                              IID_PPV_ARGS(&enumerator)))) {
    return -10;
  }
  ComPtr<IMMDevice> device;
  if (FAILED(enumerator->GetDefaultAudioEndpoint(eRender, eConsole, &device))) return -11;
  ComPtr<IAudioSessionManager2> manager;
  if (FAILED(device->Activate(__uuidof(IAudioSessionManager2), CLSCTX_ALL, nullptr, &manager))) {
    return -12;
  }
  ComPtr<IAudioSessionEnumerator> sessions;
  if (FAILED(manager->GetSessionEnumerator(&sessions))) return -13;
  int count = 0;
  sessions->GetCount(&count);
  for (int index = 0; index < count; ++index) {
    ComPtr<IAudioSessionControl> control;
    if (FAILED(sessions->GetSession(index, &control))) continue;
    ComPtr<IAudioSessionControl2> control2;
    if (FAILED(control.As(&control2))) continue;
    DWORD owner = 0;
    if (FAILED(control2->GetProcessId(&owner))) continue;
    LPWSTR raw_identifier = nullptr;
    if (FAILED(control2->GetSessionInstanceIdentifier(&raw_identifier))) continue;
    const std::wstring identifier(raw_identifier);
    CoTaskMemFree(raw_identifier);
    ComPtr<ISimpleAudioVolume> volume;
    if (FAILED(control.As(&volume))) continue;
    visit(owner, identifier, volume.Get());
  }
  return 0;
}

}  // namespace

int32_t DuckProcess(uint32_t process_id, float volume, std::optional<double>* heard) {
  std::lock_guard<std::mutex> lock(volumes_mutex);
  return ForEachRenderSession([&](DWORD owner, const std::wstring& identifier,
                                  ISimpleAudioVolume* session) {
    if (owner != process_id) return;
    float current = 1.0f;
    if (SUCCEEDED(session->GetMasterVolume(&current))) {
      original_volumes.try_emplace(identifier, current);
    }
    if (FAILED(session->SetMasterVolume(volume, nullptr))) return;
    const auto was = original_volumes.find(identifier);
    const float before = was == original_volumes.end() ? 1.0f : was->second;
    *heard = before > 0.0f ? volume / before : 1.0;
  });
}

int32_t RestoreDuckedSessions() {
  std::lock_guard<std::mutex> lock(volumes_mutex);
  const int32_t result = ForEachRenderSession(
      [&](DWORD, const std::wstring& identifier, ISimpleAudioVolume* session) {
        const auto original = original_volumes.find(identifier);
        if (original != original_volumes.end()) session->SetMasterVolume(original->second, nullptr);
      });
  original_volumes.clear();
  return result;
}
