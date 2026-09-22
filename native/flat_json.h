// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

// The JSON that crosses the boundary: a flat object of strings, numbers and
// booleans in, and events written out.
//
// The configs the application hands over are its own and flat on purpose
// (`CapturePlan.toNativeJson`), so this reads exactly that and nothing more
// -- one pass, keys compared whole, escapes decoded, numbers read the same
// whatever the C locale says. It used to look a key up as the first place
// its quoted name appeared anywhere in the text, read `\uXXXX` as the letter
// u and four digits, and parse numbers through the locale.

#ifndef LORE_DUB_FLAT_JSON_H_
#define LORE_DUB_FLAT_JSON_H_

#include <charconv>
#include <cstdint>
#include <string>
#include <string_view>
#include <unordered_map>
#include <variant>

namespace flat_json {

// A value of the object: text, a number, or true/false. Null reads as absent.
using Value = std::variant<std::string, double, bool>;

class Object {
 public:
  // Reads [text]. What cannot be read ends the reading: the keys read before
  // it are kept, and the rest is as if absent -- a config is the
  // application's own, so this is a defect to survive rather than report.
  static Object Parse(std::string_view text) {
    Object object;
    Reader reader{text};
    reader.SkipSpace();
    if (!reader.Take('{')) return object;
    reader.SkipSpace();
    if (reader.Take('}')) return object;
    while (true) {
      reader.SkipSpace();
      std::string key;
      if (!reader.ReadString(key)) return object;
      reader.SkipSpace();
      if (!reader.Take(':')) return object;
      reader.SkipSpace();
      Value value;
      bool present = true;
      if (!reader.ReadValue(value, present)) return object;
      if (present) object.values_[key] = std::move(value);
      reader.SkipSpace();
      if (reader.Take(',')) continue;
      return object;
    }
  }

  bool Has(std::string_view key) const { return values_.count(std::string(key)) != 0; }

  // The text under [key], or empty where there is none or it is not text.
  std::string String(std::string_view key) const {
    const auto found = values_.find(std::string(key));
    if (found == values_.end()) return {};
    const auto* text = std::get_if<std::string>(&found->second);
    return text != nullptr ? *text : std::string();
  }

  double Number(std::string_view key, double fallback) const {
    const auto found = values_.find(std::string(key));
    if (found == values_.end()) return fallback;
    const auto* number = std::get_if<double>(&found->second);
    return number != nullptr ? *number : fallback;
  }

  // A whole number that fits 32 bits unsigned -- a process id, a key code --
  // or [fallback] for anything else.
  uint32_t Unsigned(std::string_view key, uint32_t fallback = 0) const {
    const double number = Number(key, -1.0);
    if (number < 0 || number > 4294967295.0 || number != static_cast<double>(static_cast<uint64_t>(number))) {
      return fallback;
    }
    return static_cast<uint32_t>(number);
  }

  bool Flag(std::string_view key, bool fallback = false) const {
    const auto found = values_.find(std::string(key));
    if (found == values_.end()) return fallback;
    const auto* flag = std::get_if<bool>(&found->second);
    return flag != nullptr ? *flag : fallback;
  }

 private:
  struct Reader {
    std::string_view text;
    size_t at = 0;

    bool AtEnd() const { return at >= text.size(); }
    char Peek() const { return AtEnd() ? '\0' : text[at]; }
    void SkipSpace() {
      while (!AtEnd() && (Peek() == ' ' || Peek() == '\t' || Peek() == '\n' || Peek() == '\r')) ++at;
    }
    bool Take(char expected) {
      if (Peek() != expected) return false;
      ++at;
      return true;
    }
    bool TakeWord(std::string_view word) {
      if (text.substr(at, word.size()) != word) return false;
      at += word.size();
      return true;
    }

    bool ReadValue(Value& value, bool& present) {
      const char first = Peek();
      if (first == '"') {
        std::string read;
        if (!ReadString(read)) return false;
        value = std::move(read);
        return true;
      }
      if (TakeWord("true")) {
        value = true;
        return true;
      }
      if (TakeWord("false")) {
        value = false;
        return true;
      }
      if (TakeWord("null")) {
        present = false;
        return true;
      }
      // Only scalars: the object is flat, and anything nested is a config
      // this build was not written for.
      double number = 0;
      const char* begin = text.data() + at;
      const auto [end, error] = std::from_chars(begin, text.data() + text.size(), number);
      if (error != std::errc() || end == begin) return false;
      at += static_cast<size_t>(end - begin);
      value = number;
      return true;
    }

    // A quoted string, its escapes decoded; \uXXXX -- surrogate pairs too --
    // written as UTF-8.
    bool ReadString(std::string& out) {
      if (!Take('"')) return false;
      while (!AtEnd()) {
        const char character = text[at++];
        if (character == '"') return true;
        if (character != '\\') {
          out.push_back(character);
          continue;
        }
        if (AtEnd()) return false;
        const char escaped = text[at++];
        switch (escaped) {
          case '"': out.push_back('"'); break;
          case '\\': out.push_back('\\'); break;
          case '/': out.push_back('/'); break;
          case 'b': out.push_back('\b'); break;
          case 'f': out.push_back('\f'); break;
          case 'n': out.push_back('\n'); break;
          case 'r': out.push_back('\r'); break;
          case 't': out.push_back('\t'); break;
          case 'u': {
            uint32_t code = 0;
            if (!ReadHex(code)) return false;
            if (code >= 0xD800 && code <= 0xDBFF) {
              uint32_t low = 0;
              if (!Take('\\') || !Take('u') || !ReadHex(low) || low < 0xDC00 || low > 0xDFFF) return false;
              code = 0x10000 + ((code - 0xD800) << 10) + (low - 0xDC00);
            }
            AppendUtf8(out, code);
            break;
          }
          default: return false;
        }
      }
      return false;
    }

    bool ReadHex(uint32_t& code) {
      if (at + 4 > text.size()) return false;
      const auto [end, error] = std::from_chars(text.data() + at, text.data() + at + 4, code, 16);
      if (error != std::errc() || end != text.data() + at + 4) return false;
      at += 4;
      return true;
    }
  };

  static void AppendUtf8(std::string& out, uint32_t code) {
    if (code < 0x80) {
      out.push_back(static_cast<char>(code));
    } else if (code < 0x800) {
      out.push_back(static_cast<char>(0xC0 | (code >> 6)));
      out.push_back(static_cast<char>(0x80 | (code & 0x3F)));
    } else if (code < 0x10000) {
      out.push_back(static_cast<char>(0xE0 | (code >> 12)));
      out.push_back(static_cast<char>(0x80 | ((code >> 6) & 0x3F)));
      out.push_back(static_cast<char>(0x80 | (code & 0x3F)));
    } else {
      out.push_back(static_cast<char>(0xF0 | (code >> 18)));
      out.push_back(static_cast<char>(0x80 | ((code >> 12) & 0x3F)));
      out.push_back(static_cast<char>(0x80 | ((code >> 6) & 0x3F)));
      out.push_back(static_cast<char>(0x80 | (code & 0x3F)));
    }
  }

  std::unordered_map<std::string, Value> values_;
};

// [input] as the inside of a JSON string. Control characters are written as
// \u00XX: they used to become "?", which a path or a line of OCR text could
// carry and the application would then read back changed.
inline std::string Escape(std::string_view input) {
  static constexpr char kHex[] = "0123456789abcdef";
  std::string out;
  out.reserve(input.size());
  for (const unsigned char character : input) {
    switch (character) {
      case '\\': out += "\\\\"; break;
      case '"': out += "\\\""; break;
      case '\n': out += "\\n"; break;
      case '\r': out += "\\r"; break;
      case '\t': out += "\\t"; break;
      default:
        if (character < 0x20) {
          out += "\\u00";
          out.push_back(kHex[character >> 4]);
          out.push_back(kHex[character & 0xF]);
        } else {
          out.push_back(static_cast<char>(character));
        }
    }
  }
  return out;
}

// [value] as the shortest JSON number that reads back as it, whatever the C
// locale says a decimal point is.
inline std::string Number(double value) {
  char buffer[32];
  const auto [end, error] = std::to_chars(buffer, buffer + sizeof(buffer), value);
  return error == std::errc() ? std::string(buffer, end) : std::string("0");
}

}  // namespace flat_json

#endif  // LORE_DUB_FLAT_JSON_H_
