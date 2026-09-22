// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

// Built and run by tool/native_tests.ps1. Each check prints what it expected
// and what it read, and the process fails on the first one that does not
// hold.

#include "flat_json.h"

#include <clocale>
#include <cstdio>
#include <cstdlib>
#include <string>

namespace {

int failures = 0;

void Check(bool holds, const char* what) {
  if (holds) return;
  std::fprintf(stderr, "FAILED: %s\n", what);
  ++failures;
}

void ReadsTheConfigTheApplicationWrites() {
  const auto config = flat_json::Object::Parse(
      R"({"processId":4242,"captureMode":"ocrAndAudio","audioSource":"process",)"
      R"("ocrSource":"screen","ocrRegionLeft":0.1,"ocrRegionTop":0.55,)"
      R"("ocrRegionRight":1,"ocrRegionBottom":0.95,"ocrLanguage":"ru",)"
      R"("captureDirectory":"C:\\Users\\Игрок\\capture"})");
  Check(config.Unsigned("processId") == 4242, "a process id");
  Check(config.String("captureMode") == "ocrAndAudio", "a capture mode");
  Check(config.Number("ocrRegionTop", 0) == 0.55, "a share of the frame");
  Check(config.Number("ocrRegionRight", 0) == 1.0, "a whole number read as a share");
  Check(config.String("captureDirectory") == "C:\\Users\\Игрок\\capture",
        "a path with a backslash and Cyrillic in it");
}

void ComparesKeysWholeRatherThanFindingThemInside() {
  // Looked up as text, "processId" answered from the first place its quoted
  // name stood, wherever that was.
  const auto config = flat_json::Object::Parse(
      R"({"note":"\"processId\":7","frameProcessId":9,"processId":4242})");
  Check(config.Unsigned("processId") == 4242, "the key itself, not text inside a value");
  Check(config.Unsigned("frameProcessId") == 9, "a key that ends like another");
  Check(config.String("note") == "\"processId\":7", "the value with its quotes");
}

void DecodesEscapesAsJsonMeansThem() {
  const auto config = flat_json::Object::Parse(
      R"({"a":"tab\there","b":"\u0416\u00e9","c":"\ud83d\ude00","d":"line\nbreak"})");
  Check(config.String("a") == "tab\there", "a tab");
  Check(config.String("b") == "Жé", "\\u escapes as UTF-8");
  Check(config.String("c") == "\xF0\x9F\x98\x80", "a surrogate pair as one character");
  Check(config.String("d") == "line\nbreak", "a line break");
}

void ReadsNumbersWhateverTheLocaleSays() {
  // A locale whose decimal point is a comma read 0.55 as 0 through stod.
  Check(std::setlocale(LC_NUMERIC, "de-DE") != nullptr, "a comma locale to read under");
  const auto config = flat_json::Object::Parse(R"({"share":0.55,"big":1e3,"negative":-2.5})");
  Check(config.Number("share", 0) == 0.55, "a decimal point under a comma locale");
  Check(config.Number("big", 0) == 1000, "an exponent");
  Check(config.Number("negative", 0) == -2.5, "a negative number");
  Check(flat_json::Number(0.55) == "0.55", "a number written with a point");
  std::setlocale(LC_NUMERIC, "C");
}

void AnswersFallbacksForWhatIsNotThere() {
  const auto config = flat_json::Object::Parse(R"({"text":"x","flag":true,"nothing":null,"n":-1,"f":2.5})");
  Check(config.String("missing").empty(), "a missing string is empty");
  Check(config.String("flag").empty(), "a string asked of a boolean is empty");
  Check(config.Number("text", 7) == 7, "a number asked of a string is the fallback");
  Check(!config.Has("nothing"), "null reads as absent");
  Check(config.Flag("flag"), "a boolean");
  Check(config.Unsigned("n", 5) == 5, "a negative number is no process id");
  Check(config.Unsigned("f", 5) == 5, "a fraction is no process id");
}

void KeepsWhatWasReadBeforeSomethingItCannotRead() {
  const auto broken = flat_json::Object::Parse(R"({"a":"kept","b":[1,2],"c":"lost"})");
  Check(broken.String("a") == "kept", "the keys before the nested value");
  Check(!broken.Has("c"), "nothing after it");
  Check(!flat_json::Object::Parse("not json").Has("a"), "text that is not an object");
  Check(!flat_json::Object::Parse(R"({"a":"unterminated)").Has("a"), "an unterminated string");
  Check(!flat_json::Object::Parse("").Has("a"), "nothing at all");
}

void EscapesWhatItWritesSoItReadsBack() {
  const std::string written = "a\"b\\c\nd\x01" "e";
  const auto read = flat_json::Object::Parse("{\"v\":\"" + flat_json::Escape(written) + "\"}");
  Check(read.String("v") == written, "an escaped string reads back as it was");
  Check(flat_json::Escape("\x01") == "\\u0001", "a control character as \\u, not ?");
}

}  // namespace

int main() {
  ReadsTheConfigTheApplicationWrites();
  ComparesKeysWholeRatherThanFindingThemInside();
  DecodesEscapesAsJsonMeansThem();
  ReadsNumbersWhateverTheLocaleSays();
  AnswersFallbacksForWhatIsNotThere();
  KeepsWhatWasReadBeforeSomethingItCannotRead();
  EscapesWhatItWritesSoItReadsBack();
  if (failures != 0) {
    std::fprintf(stderr, "%d check(s) failed\n", failures);
    return EXIT_FAILURE;
  }
  std::printf("flat_json: every check held\n");
  return EXIT_SUCCESS;
}
