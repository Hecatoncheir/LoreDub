// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

#include "ocr_capture.h"

#include <algorithm>
#include <utility>

#if defined(_WIN32)

#define NOMINMAX
#include <windows.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Globalization.h>
#include <winrt/Windows.Graphics.Imaging.h>
#include <winrt/Windows.Media.Ocr.h>
#include <winrt/Windows.Security.Cryptography.h>

#include <algorithm>
#include <chrono>
#include <cctype>
#include <vector>

namespace {

struct WindowSearch {
  DWORD process_id;
  HWND best = nullptr;
  long long best_area = 0;
};

BOOL CALLBACK FindWindowCallback(HWND window, LPARAM parameter) {
  auto* search = reinterpret_cast<WindowSearch*>(parameter);
  DWORD owner_process = 0;
  GetWindowThreadProcessId(window, &owner_process);
  if (owner_process != search->process_id || !IsWindowVisible(window) ||
      GetWindow(window, GW_OWNER) != nullptr || IsIconic(window)) {
    return TRUE;
  }
  RECT client{};
  if (!GetClientRect(window, &client)) return TRUE;
  const long long area = static_cast<long long>(client.right) * client.bottom;
  if (area > search->best_area) {
    search->best = window;
    search->best_area = area;
  }
  return TRUE;
}

HWND FindProcessWindow(DWORD process_id) {
  WindowSearch search{process_id};
  EnumWindows(FindWindowCallback, reinterpret_cast<LPARAM>(&search));
  return search.best;
}

// Copies [crop_width] by [crop_height] screen pixels from ([x], [y]), scaled
// by [scale], as top-down BGRA.
bool CaptureScreen(int x, int y, int crop_width, int crop_height, double scale,
                   std::vector<uint8_t>* pixels, int32_t* output_width,
                   int32_t* output_height) {
  const int width = std::max(1, static_cast<int>(crop_width * scale));
  const int height = std::max(1, static_cast<int>(crop_height * scale));
  HDC screen = GetDC(nullptr);
  HDC memory = CreateCompatibleDC(screen);
  BITMAPINFO info{};
  info.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  info.bmiHeader.biWidth = width;
  info.bmiHeader.biHeight = -height;
  info.bmiHeader.biPlanes = 1;
  info.bmiHeader.biBitCount = 32;
  info.bmiHeader.biCompression = BI_RGB;
  void* bitmap_pixels = nullptr;
  HBITMAP bitmap = CreateDIBSection(screen, &info, DIB_RGB_COLORS, &bitmap_pixels,
                                    nullptr, 0);
  if (screen == nullptr || memory == nullptr || bitmap == nullptr) {
    if (bitmap != nullptr) DeleteObject(bitmap);
    if (memory != nullptr) DeleteDC(memory);
    if (screen != nullptr) ReleaseDC(nullptr, screen);
    return false;
  }
  const HGDIOBJ previous = SelectObject(memory, bitmap);
  SetStretchBltMode(memory, HALFTONE);
  const BOOL copied = StretchBlt(memory, 0, 0, width, height, screen, x, y, crop_width,
                                 crop_height, SRCCOPY | CAPTUREBLT);
  if (copied) {
    const auto* begin = static_cast<const uint8_t*>(bitmap_pixels);
    pixels->assign(begin, begin + static_cast<size_t>(width) * height * 4);
    *output_width = width;
    *output_height = height;
  }
  SelectObject(memory, previous);
  DeleteObject(bitmap);
  DeleteDC(memory);
  ReleaseDC(nullptr, screen);
  return copied == TRUE;
}

bool CaptureRegion(HWND window, const OcrRegion& region, std::vector<uint8_t>* pixels,
                   int32_t* output_width, int32_t* output_height) {
  RECT client{};
  if (!GetClientRect(window, &client)) return false;
  POINT origin{};
  if (!ClientToScreen(window, &origin)) return false;
  const int source_width = client.right - client.left;
  const int source_height = client.bottom - client.top;
  const int source_x = std::clamp(static_cast<int>(source_width * region.left), 0,
                                  std::max(0, source_width - 1));
  const int source_y = std::clamp(static_cast<int>(source_height * region.top), 0,
                                  std::max(0, source_height - 1));
  const int crop_width =
      std::clamp(static_cast<int>(source_width * region.right), source_x, source_width) - source_x;
  const int crop_height =
      std::clamp(static_cast<int>(source_height * region.bottom), source_y, source_height) -
      source_y;
  if (crop_width < 32 || crop_height < 16) return false;

  // Windows OCR refuses images beyond OcrEngine::MaxImageDimension.
  const double scale = std::min(1.0, 2400.0 / std::max(crop_width, crop_height));
  return CaptureScreen(origin.x + source_x, origin.y + source_y, crop_width, crop_height, scale,
                       pixels, output_width, output_height);
}

std::string Utf8(const winrt::hstring& input) {
  if (input.empty()) return {};
  const int size = WideCharToMultiByte(CP_UTF8, 0, input.c_str(),
                                       static_cast<int>(input.size()), nullptr,
                                       0, nullptr, nullptr);
  std::string output(static_cast<size_t>(size), '\0');
  WideCharToMultiByte(CP_UTF8, 0, input.c_str(), static_cast<int>(input.size()),
                      output.data(), size, nullptr, nullptr);
  return output;
}

std::string NormalizeText(std::string text) {
  std::string output;
  output.reserve(text.size());
  bool previous_space = true;
  for (const unsigned char character : text) {
    const bool space = std::isspace(character) != 0;
    if (space) {
      if (!previous_space) output.push_back(' ');
    } else {
      output.push_back(static_cast<char>(character));
    }
    previous_space = space;
  }
  while (!output.empty() && output.back() == ' ') output.pop_back();
  return output;
}

std::string Recognize(const winrt::Windows::Media::Ocr::OcrEngine& engine,
                      const std::vector<uint8_t>& pixels, int32_t width, int32_t height) {
  const auto buffer =
      winrt::Windows::Security::Cryptography::CryptographicBuffer::CreateFromByteArray(pixels);
  const auto bitmap = winrt::Windows::Graphics::Imaging::SoftwareBitmap::CreateCopyFromBuffer(
      buffer, winrt::Windows::Graphics::Imaging::BitmapPixelFormat::Bgra8, width, height,
      winrt::Windows::Graphics::Imaging::BitmapAlphaMode::Ignore);
  return NormalizeText(Utf8(engine.RecognizeAsync(bitmap).get().Text()));
}

// The installed recognizer whose primary subtag is [code] — "en" finds
// "en-US", "ru" finds "ru-RU" — or null when Windows has none for it.
winrt::Windows::Globalization::Language FindOcrLanguage(const std::string& code) {
  for (const auto& language : winrt::Windows::Media::Ocr::OcrEngine::AvailableRecognizerLanguages()) {
    std::string primary = Utf8(language.LanguageTag());
    primary = primary.substr(0, primary.find('-'));
    std::transform(primary.begin(), primary.end(), primary.begin(),
                   [](unsigned char character) { return static_cast<char>(std::tolower(character)); });
    if (primary == code) return language;
  }
  return nullptr;
}

// Keeps the Windows Runtime initialized for as long as it is in scope.
struct Apartment {
  Apartment() { winrt::init_apartment(winrt::apartment_type::multi_threaded); }
  ~Apartment() { winrt::uninit_apartment(); }
};

}  // namespace

#endif

namespace {

// The interface already keeps the frame valid; this guards the ABI against a
// config written by hand, falling back to the default band rather than
// scanning a sliver or nothing.
OcrRegion SanitizeRegion(OcrRegion region) {
  const double left = std::clamp(std::min(region.left, region.right), 0.0, 1.0);
  const double right = std::clamp(std::max(region.left, region.right), 0.0, 1.0);
  const double top = std::clamp(std::min(region.top, region.bottom), 0.0, 1.0);
  const double bottom = std::clamp(std::max(region.top, region.bottom), 0.0, 1.0);
  if (right - left < 0.02 || bottom - top < 0.02) return OcrRegion{};
  return OcrRegion{left, top, right, bottom};
}

}  // namespace

bool RecognizeScreenArea(ScreenArea area, const std::string& language, std::string* text,
                         std::string* error) {
#if !defined(_WIN32)
  (void)area;
  (void)language;
  (void)text;
  *error = "Windows OCR is only available on Windows";
  return false;
#else
  text->clear();
  const int width = area.right - area.left;
  const int height = area.bottom - area.top;
  if (width < 8 || height < 8) return true;
  try {
    const Apartment apartment;
    const auto recognizer = FindOcrLanguage(language);
    if (!recognizer) {
      *error = kOcrLanguageMissing;
      return false;
    }
    const auto engine = winrt::Windows::Media::Ocr::OcrEngine::TryCreateFromLanguage(recognizer);
    // A small area is enlarged: Windows OCR misses text only a few pixels
    // tall, and a line picked out of a game is often that small.
    const double scale = std::min(2.0, 2400.0 / std::max(width, height));
    std::vector<uint8_t> pixels;
    int32_t output_width = 0;
    int32_t output_height = 0;
    if (!CaptureScreen(area.left, area.top, width, height, scale, &pixels, &output_width,
                       &output_height)) {
      *error = "The selected part of the screen could not be copied";
      return false;
    }
    *text = Recognize(engine, pixels, output_width, output_height);
    return true;
  } catch (const winrt::hresult_error& failure) {
    *error = Utf8(failure.message());
  } catch (const std::exception& failure) {
    *error = failure.what();
  }
  return false;
#endif
}

OcrCapture::OcrCapture() = default;
OcrCapture::~OcrCapture() { Stop(); }

bool OcrCapture::Start(uint32_t process_id, OcrRegion region, std::string language,
                       TextCallback on_text, ErrorCallback on_error) {
  if (thread_.joinable()) return false;
  stopping_ = false;
  thread_ = std::thread(&OcrCapture::CaptureThread, this, process_id,
                        SanitizeRegion(region), std::move(language), std::move(on_text),
                        std::move(on_error));
  return true;
}

void OcrCapture::Stop() {
  stopping_ = true;
  if (thread_.joinable()) thread_.join();
}

void OcrCapture::CaptureThread(uint32_t process_id, OcrRegion region, std::string language,
                               TextCallback on_text, ErrorCallback on_error) {
#if !defined(_WIN32)
  (void)process_id;
  (void)region;
  (void)language;
  (void)on_text;
  on_error("Windows OCR is only available on Windows");
#else
  try {
    winrt::init_apartment(winrt::apartment_type::multi_threaded);
    const auto recognizer = FindOcrLanguage(language);
    if (!recognizer) {
      on_error(kOcrLanguageMissing);
      return;
    }
    const auto engine =
        winrt::Windows::Media::Ocr::OcrEngine::TryCreateFromLanguage(recognizer);
    std::string candidate;
    std::string emitted;
    int stable_scans = 0;
    int empty_scans = 0;
    while (!stopping_) {
      const HWND window = FindProcessWindow(process_id);
      std::vector<uint8_t> pixels;
      int32_t width = 0;
      int32_t height = 0;
      std::string text;
      if (window != nullptr && window == GetForegroundWindow() &&
          CaptureRegion(window, region, &pixels, &width, &height)) {
        text = Recognize(engine, pixels, width, height);
      }
      if (text.empty()) {
        candidate.clear();
        stable_scans = 0;
        if (++empty_scans >= 6) emitted.clear();
      } else {
        empty_scans = 0;
        if (text == candidate) {
          ++stable_scans;
        } else {
          candidate = text;
          stable_scans = 1;
        }
        if (stable_scans >= 2 && candidate != emitted) {
          emitted = candidate;
          on_text(emitted);
        }
      }
      for (int tick = 0; tick < 13 && !stopping_; ++tick) {
        std::this_thread::sleep_for(std::chrono::milliseconds(50));
      }
    }
  } catch (const winrt::hresult_error& error) {
    on_error(Utf8(error.message()));
  } catch (const std::exception& error) {
    on_error(error.what());
  }
#endif
}
