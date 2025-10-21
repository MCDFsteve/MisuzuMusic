import 'dart:convert';
import 'dart:io';

const String kOutputPath = 'lib/data/services/generated_japanese_dictionary.dart';
const String kDictionaryCsv = 'tools/japanese_dictionary/base_dictionary.csv';
const String kCharactersCsv = 'tools/japanese_dictionary/base_characters.csv';

void main(List<String> args) {
  final Map<String, String> wordDictionary = _loadCsv(kDictionaryCsv);
  final Map<String, String> charDictionary = _loadCsv(kCharactersCsv);

  if (wordDictionary.isEmpty && charDictionary.isEmpty) {
    stderr.writeln('No entries found. Aborting.');
    exitCode = 1;
    return;
  }

  final List<String> sortedKeys = wordDictionary.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));

  final buffer = StringBuffer()
    ..writeln("// GENERATED CODE - DO NOT MODIFY BY HAND")
    ..writeln("// ignore_for_file: constant_identifier_names")
    ..writeln()
    ..writeln("/// Generated Japanese annotation dictionary.")
    ..writeln("///")
    ..writeln("/// To update the data edit the CSV files in")
    ..writeln("/// `tools/japanese_dictionary/` and re-run:\n" "///   dart run tools/japanese_dictionary/generate_dictionary.dart\n")
    ..writeln('const Map<String, String> kJapaneseWordDictionary = {');

  for (final entry in sortedKeys) {
    final reading = wordDictionary[entry]!;
    buffer.writeln("  '${_escape(entry)}': '${_escape(reading)}',");
  }
  buffer.writeln('};\n');

  buffer.writeln('const Map<String, String> kJapaneseCharFallback = {');
  for (final entry in charDictionary.entries.sortByKey()) {
    buffer.writeln("  '${_escape(entry.key)}': '${_escape(entry.value)}',");
  }
  buffer.writeln('};\n');

  buffer.writeln('const List<String> kJapaneseDictionarySortedKeys = [');
  for (final key in sortedKeys) {
    buffer.writeln("  '${_escape(key)}',");
  }
  buffer.writeln('];');

  File(kOutputPath)
    ..createSync(recursive: true)
    ..writeAsStringSync(buffer.toString());

  stdout.writeln('Generated $kOutputPath with ${wordDictionary.length} phrases and ${charDictionary.length} characters.');
}

Map<String, String> _loadCsv(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('Missing CSV file: $path');
    return {};
  }

  final Map<String, String> result = {};
  for (final rawLine in file.readAsLinesSync()) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) {
      continue;
    }
    final parts = line.split(',');
    if (parts.length < 2) {
      continue;
    }
    final key = parts[0].trim();
    final value = parts[1].trim();
    if (key.isEmpty || value.isEmpty) {
      continue;
    }
    result[key] = value;
  }
  return result;
}

String _escape(String input) => jsonEncode(input).substring(1, jsonEncode(input).length - 1);

extension on Iterable<MapEntry<String, String>> {
  Iterable<MapEntry<String, String>> sortByKey() {
    final list = toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return list;
  }
}
