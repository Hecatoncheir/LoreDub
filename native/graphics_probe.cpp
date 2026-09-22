// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

#include "graphics_probe.h"

#include "flat_json.h"
#include "text_encoding.h"

#include <windows.h>
#include <dxgi.h>
#include <wrl/client.h>

#include <sstream>

namespace {

using Microsoft::WRL::ComPtr;

// Whether a driver library is installed, without running its entry point.
// Loading nvcuda.dll for real spins up the display driver, which is a lot to
// ask for a question the interface only wants an answer to once.
bool HasSystemLibrary(const wchar_t* name) {
  HMODULE library = LoadLibraryExW(name, nullptr, LOAD_LIBRARY_AS_DATAFILE);
  if (library == nullptr) return false;
  FreeLibrary(library);
  return true;
}

BOOL CALLBACK AddMonitor(HMONITOR monitor, HDC, LPRECT, LPARAM data) {
  MONITORINFO info{};
  info.cbSize = sizeof(info);
  if (!GetMonitorInfoW(monitor, &info)) return TRUE;
  auto& out = *reinterpret_cast<std::ostringstream*>(data);
  if (out.tellp() > 1) out << ',';
  const RECT& area = info.rcMonitor;
  out << "{\"left\":" << area.left << ",\"top\":" << area.top << ",\"right\":" << area.right
      << ",\"bottom\":" << area.bottom
      << ",\"primary\":" << ((info.dwFlags & MONITORINFOF_PRIMARY) != 0 ? "true" : "false")
      << '}';
  return TRUE;
}

}  // namespace

// Microsoft's Basic Render Driver is reported like any other adapter and
// would make every machine look capable of Vulkan, so software adapters are
// dropped.
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
      out << "{\"name\":\"" << flat_json::Escape(encoding::Utf8(description.Description))
          << "\",\"vendorId\":" << description.VendorId << ",\"dedicatedMemory\":"
          << static_cast<uint64_t>(description.DedicatedVideoMemory) << '}';
    }
  }
  out << "],\"cudaDriver\":" << (HasSystemLibrary(L"nvcuda.dll") ? "true" : "false")
      << ",\"vulkanLoader\":" << (HasSystemLibrary(L"vulkan-1.dll") ? "true" : "false") << '}';
  return out.str();
}

// The same pixels VirtualScreen() measures, the process being aware of each
// monitor's DPI.
std::string ListMonitors() {
  std::ostringstream out;
  out << '[';
  EnumDisplayMonitors(nullptr, nullptr, AddMonitor, reinterpret_cast<LPARAM>(&out));
  out << ']';
  return out.str();
}
