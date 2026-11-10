#include "desktop_clipboard_reader.h"

#include <flutter/standard_method_codec.h>
#include <shellapi.h>
#include <shlobj.h>

#include <cstdint>
#include <cstring>
#include <cwchar>
#include <limits>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

namespace {

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;

class ClipboardScope {
 public:
  explicit ClipboardScope(HWND window) {
    if (!OpenClipboard(window)) {
      throw std::runtime_error("The clipboard is busy. Try pasting again.");
    }
  }
  ~ClipboardScope() { CloseClipboard(); }
  ClipboardScope(const ClipboardScope&) = delete;
  ClipboardScope& operator=(const ClipboardScope&) = delete;
};

class ClipboardData {
 public:
  explicit ClipboardData(UINT format)
      : handle_(GetClipboardData(format)), size_(GlobalSize(handle_)) {
    if (!handle_ || size_ == 0) {
      throw std::runtime_error("Clipboard data is unavailable.");
    }
    data_ = static_cast<const uint8_t*>(GlobalLock(handle_));
    if (!data_) throw std::runtime_error("Cannot lock clipboard data.");
  }
  ~ClipboardData() { GlobalUnlock(handle_); }
  ClipboardData(const ClipboardData&) = delete;
  ClipboardData& operator=(const ClipboardData&) = delete;

  HANDLE handle() const { return handle_; }
  const uint8_t* data() const { return data_; }
  size_t size() const { return size_; }

 private:
  HANDLE handle_;
  size_t size_;
  const uint8_t* data_ = nullptr;
};

std::string Utf8(const wchar_t* data, size_t length) {
  if (length == 0) return {};
  if (length > static_cast<size_t>(std::numeric_limits<int>::max())) {
    throw std::runtime_error("Clipboard text cannot be represented.");
  }
  const auto count = static_cast<int>(length);
  const auto size = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, data,
      count, nullptr, 0, nullptr, nullptr);
  if (!size) throw std::runtime_error("Clipboard text is invalid Unicode.");
  std::string text(static_cast<size_t>(size), '\0');
  if (WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, data, count,
      text.data(), size, nullptr, nullptr) != size) {
    throw std::runtime_error("Cannot read clipboard text.");
  }
  return text;
}

// Validate the packed list before shell32 reads its NUL-terminated names.
void ValidateFileList(const ClipboardData& data) {
  DROPFILES header{};
  if (data.size() < sizeof(header)) {
    throw std::runtime_error("Clipboard file list is incomplete.");
  }
  std::memcpy(&header, data.data(), sizeof(header));
  if (header.pFiles < sizeof(header) || header.pFiles >= data.size()) {
    throw std::runtime_error("Clipboard file list offset is invalid.");
  }
  const size_t unit = header.fWide ? sizeof(wchar_t) : sizeof(char);
  if (header.fWide && header.pFiles % sizeof(wchar_t) != 0) {
    throw std::runtime_error("Clipboard file list alignment is invalid.");
  }
  bool previous_zero = false;
  for (size_t offset = header.pFiles; unit <= data.size() - offset;
       offset += unit) {
    wchar_t character = 0;
    std::memcpy(&character, data.data() + offset, unit);
    if (character == 0 && previous_zero) return;
    previous_zero = character == 0;
  }
  throw std::runtime_error("Clipboard file list is not terminated.");
}

EncodableList ReadFiles() {
  const ClipboardData data(CF_HDROP);
  ValidateFileList(data);
  const auto drop = static_cast<HDROP>(data.handle());
  const auto count = DragQueryFileW(drop, 0xffffffff, nullptr, 0);
  EncodableList files;
  files.reserve(count);
  for (UINT index = 0; index < count; ++index) {
    const auto length = DragQueryFileW(drop, index, nullptr, 0);
    if (length == 0 || length == std::numeric_limits<UINT>::max()) {
      throw std::runtime_error("Clipboard filename is invalid.");
    }
    std::vector<wchar_t> name(static_cast<size_t>(length) + 1, L'\0');
    if (DragQueryFileW(drop, index, name.data(), length + 1) != length) {
      throw std::runtime_error("Cannot read the complete clipboard filename.");
    }
    files.emplace_back(Utf8(name.data(), length));
  }
  return files;
}

std::vector<uint8_t> ReadPng(UINT format) {
  const ClipboardData data(format);
  return {data.data(), data.data() + data.size()};
}

// A clipboard DIB has no BITMAPFILEHEADER. Preserve its pixels and profile,
// validate all packed ranges, then add the header consumed by Flutter's codec.
std::vector<uint8_t> ReadBitmap(UINT format) {
  const ClipboardData data(format);
  BITMAPINFOHEADER info{};
  if (data.size() < sizeof(info)) {
    throw std::runtime_error("Clipboard bitmap header is incomplete.");
  }
  std::memcpy(&info, data.data(), sizeof(info));
  if ((info.biSize != 40 && info.biSize != 52 && info.biSize != 56 &&
       info.biSize != 108 && info.biSize != 124) ||
      info.biSize > data.size() || info.biPlanes != 1 || info.biWidth <= 0 ||
      info.biHeight == 0 || info.biHeight == std::numeric_limits<LONG>::min()) {
    throw std::runtime_error("Clipboard bitmap geometry is invalid.");
  }
  switch (info.biBitCount) {
    case 1: case 4: case 8: case 16: case 24: case 32: break;
    default: throw std::runtime_error("Clipboard bitmap depth is unsupported.");
  }
  constexpr DWORD kAlphaBitfields = 6;
  if (info.biCompression != BI_RGB && info.biCompression != BI_BITFIELDS &&
      info.biCompression != kAlphaBitfields) {
    throw std::runtime_error("Clipboard bitmap compression is unsupported.");
  }
  if (info.biCompression != BI_RGB &&
      (info.biBitCount != 16 && info.biBitCount != 32)) {
    throw std::runtime_error("Clipboard bitmap masks are invalid.");
  }
  if (info.biCompression == kAlphaBitfields && info.biSize == 52) {
    throw std::runtime_error("Clipboard alpha mask is incomplete.");
  }

  uint64_t offset = info.biSize;
  if (info.biSize == sizeof(BITMAPINFOHEADER)) {
    if (info.biCompression == BI_BITFIELDS) offset += 3 * sizeof(DWORD);
    if (info.biCompression == kAlphaBitfields) offset += 4 * sizeof(DWORD);
  }
  const uint64_t colors = info.biClrUsed != 0 ? info.biClrUsed
      : (info.biBitCount <= 8 ? uint64_t{1} << info.biBitCount : 0);
  if (info.biBitCount <= 8 && colors > (uint64_t{1} << info.biBitCount)) {
    throw std::runtime_error("Clipboard bitmap palette is invalid.");
  }
  offset += colors * sizeof(RGBQUAD);
  const auto width = static_cast<uint64_t>(info.biWidth);
  const auto height = static_cast<uint64_t>(info.biHeight < 0
      ? -static_cast<int64_t>(info.biHeight) : info.biHeight);
  const uint64_t stride = ((width * info.biBitCount + 31) / 32) * 4;
  const uint64_t pixels = stride * height;
  if (offset > data.size() || pixels > data.size() - offset) {
    throw std::runtime_error("Clipboard bitmap data is incomplete.");
  }
  if (info.biSize == sizeof(BITMAPV5HEADER)) {
    BITMAPV5HEADER version5{};
    std::memcpy(&version5, data.data(), sizeof(version5));
    if (version5.bV5ProfileSize != 0) {
      const uint64_t profile = version5.bV5ProfileData;
      const uint64_t profile_end = profile + version5.bV5ProfileSize;
      if (profile < offset || profile_end > data.size()) {
        throw std::runtime_error("Clipboard bitmap profile is invalid.");
      }
      if (profile == offset) {
        offset = profile_end;
      } else if (profile < offset + pixels) {
        throw std::runtime_error("Clipboard bitmap profile overlaps pixels.");
      }
    }
  }
  if (pixels > data.size() - offset) {
    throw std::runtime_error("Clipboard bitmap pixels are incomplete.");
  }
  constexpr size_t header_size = sizeof(BITMAPFILEHEADER);
  if (data.size() > std::numeric_limits<DWORD>::max() - header_size) {
    throw std::runtime_error("Clipboard bitmap exceeds the BMP format size.");
  }
  BITMAPFILEHEADER header{};
  header.bfType = 0x4d42;
  header.bfSize = static_cast<DWORD>(header_size + data.size());
  header.bfOffBits = static_cast<DWORD>(header_size + offset);
  std::vector<uint8_t> bytes(header.bfSize);
  std::memcpy(bytes.data(), &header, header_size);
  std::memcpy(bytes.data() + header_size, data.data(), data.size());
  return bytes;
}

std::string ReadText() {
  const ClipboardData data(CF_UNICODETEXT);
  const auto text = reinterpret_cast<const wchar_t*>(data.data());
  const auto length = data.size() / sizeof(wchar_t);
  const auto end = std::wmemchr(text, L'\0', length);
  if (!end) throw std::runtime_error("Clipboard text is not terminated.");
  return Utf8(text, static_cast<size_t>(end - text));
}

EncodableValue ReadClipboard(HWND window) {
  const ClipboardScope clipboard(window);
  if (IsClipboardFormatAvailable(CF_HDROP)) {
    auto files = ReadFiles();
    if (!files.empty()) {
      return EncodableValue(EncodableMap{
          {EncodableValue("files"), EncodableValue(std::move(files))}});
    }
  }
  const UINT png = RegisterClipboardFormatW(L"PNG");
  if (png != 0 && IsClipboardFormatAvailable(png)) {
    return EncodableValue(EncodableMap{
        {EncodableValue("image"), EncodableValue(ReadPng(png))}});
  }
  const UINT bitmap = IsClipboardFormatAvailable(CF_DIB) ? CF_DIB
      : IsClipboardFormatAvailable(CF_DIBV5) ? CF_DIBV5 : 0;
  if (bitmap != 0) {
    return EncodableValue(EncodableMap{
        {EncodableValue("image"), EncodableValue(ReadBitmap(bitmap))}});
  }
  if (IsClipboardFormatAvailable(CF_UNICODETEXT)) {
    return EncodableValue(EncodableMap{
        {EncodableValue("text"), EncodableValue(ReadText())}});
  }
  return EncodableValue(EncodableMap{});
}

}  // namespace

DesktopClipboardReader::DesktopClipboardReader(HWND window,
    flutter::BinaryMessenger* messenger) {
  channel_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, "sked/desktop_clipboard",
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler([window](const auto& call, auto result) {
    if (call.method_name() != "read") {
      result->NotImplemented();
      return;
    }
    try {
      result->Success(ReadClipboard(window));
    } catch (const std::exception& error) {
      result->Error("clipboard_unavailable", error.what());
    }
  });
}

DesktopClipboardReader::~DesktopClipboardReader() {
  channel_->SetMethodCallHandler(nullptr);
}
