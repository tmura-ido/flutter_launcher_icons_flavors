import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

/// Drift guard for `flutter_launcher_icons_flavors.schema.json`.
///
/// Asserts that every `@JsonKey(name: '...')` in `lib/config/*.dart` is
/// represented somewhere in the published schema. Catches the common
/// failure mode: someone adds a field to a `@JsonSerializable` class
/// and forgets to regenerate the schema.
///
/// To regenerate after intentionally adding a field:
///     dart run tool/generate_schema.dart
void main() {
  test('every @JsonKey name appears in the schema', () {
    final schemaText =
        File('flutter_launcher_icons_flavors.schema.json').readAsStringSync();
    final keys = _collectJsonKeys(Directory('lib/config'));

    expect(
      keys,
      isNotEmpty,
      reason: 'should discover at least one @JsonKey in lib/config/',
    );

    final missing = <String>[];
    for (final key in keys) {
      // Permissive: substring match is enough — the schema embeds the
      // key as `"<name>":` in property maps.
      if (!schemaText.contains('"$key":')) {
        missing.add(key);
      }
    }

    expect(
      missing,
      isEmpty,
      reason:
          'Schema missing keys $missing — run `dart run tool/generate_schema.dart`.',
    );
  });

  test('schema is well-formed JSON with the expected shape', () {
    final schemaText =
        File('flutter_launcher_icons_flavors.schema.json').readAsStringSync();
    final schema = jsonDecode(schemaText) as Map<String, dynamic>;

    expect(schema[r'$schema'], contains('json-schema.org'));
    expect(schema[r'$id'], contains('flutter_launcher_icons_flavors.schema'));
    expect(schema['oneOf'], isA<List>());
    expect((schema['oneOf'] as List).length, 3,
        reason: 'consolidated + single-file + pubspec-inline shapes');
    expect(schema[r'$defs'], isA<Map>());
  });
}

/// Walks every `.dart` file under [dir] and returns the union of every
/// `@JsonKey(name: '...')` value found.
Set<String> _collectJsonKeys(Directory dir) {
  final out = <String>{};
  final pattern = RegExp(r"@JsonKey\(name:\s*'([^']+)'");
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) {
      continue;
    }
    if (entity.path.endsWith('.g.dart')) {
      continue;
    }
    final text = entity.readAsStringSync();
    for (final m in pattern.allMatches(text)) {
      out.add(m.group(1)!);
    }
  }
  return out;
}
