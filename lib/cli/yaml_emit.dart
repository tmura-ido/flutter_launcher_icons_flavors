/// Deterministic YAML emitter scoped to the shapes produced by
/// [MigrateCommand].
///
/// We intentionally do not depend on a third-party emitter: the surface
/// area we serialize (a top-level map containing `version`, `defaults`,
/// `flavors`, with scalar leaves: `String`, `int`, `bool`, `null` and
/// `Map<String, dynamic>`) is small enough that a hand-rolled emitter is
/// both auditable and trivial to keep stable.
///
/// Stability rules:
///   * Map keys are emitted alphabetically inside every block.
///   * Strings are always double-quoted with `"` and `\` escaped (the
///     only two characters that can break a double-quoted YAML scalar
///     for our value space). This avoids ambiguity with strings that
///     look like booleans/numbers (`"true"`, `"123"`).
///   * Booleans are `true` / `false`.
///   * Integers are decimal literals.
///   * `null` collapses to no value (`key:`).
///   * Empty maps render as `{}` so the structure is unambiguous.
///   * Indentation is two spaces; no trailing whitespace; final newline
///     on the document.
library;

/// Emits [data] as a deterministic YAML document.
///
/// [data] must be a JSON-shaped tree (`Map<String, dynamic>`,
/// `List<dynamic>`, `String`, `num`, `bool`, or `null`).
String emitYaml(Map<String, dynamic> data) {
  final buf = StringBuffer();
  _emitMap(buf, data, indent: 0);
  // Ensure exactly one trailing newline.
  final out = buf.toString();
  if (out.endsWith('\n')) {
    return out;
  }
  return '$out\n';
}

void _emitMap(
  StringBuffer buf,
  Map<String, dynamic> map, {
  required int indent,
}) {
  if (map.isEmpty) {
    // The caller is responsible for the inline `{}` (block mappings can't
    // be empty in YAML; flow style is the standard way to disambiguate).
    // This branch only fires when called for a non-top-level empty map
    // via `_emitValue` — handled there. Unreachable here in practice.
    buf.write('{}\n');
    return;
  }
  final keys = map.keys.toList()..sort();
  final pad = ' ' * indent;
  for (final key in keys) {
    final value = map[key];
    final encodedKey = _encodeKey(key);
    if (value == null) {
      buf.writeln('$pad$encodedKey:');
      continue;
    }
    if (value is Map<String, dynamic>) {
      if (value.isEmpty) {
        buf.writeln('$pad$encodedKey: {}');
      } else {
        buf.writeln('$pad$encodedKey:');
        _emitMap(buf, value, indent: indent + 2);
      }
      continue;
    }
    if (value is List) {
      if (value.isEmpty) {
        buf.writeln('$pad$encodedKey: []');
      } else {
        buf.writeln('$pad$encodedKey:');
        for (final item in value) {
          _emitListItem(buf, item, indent: indent + 2);
        }
      }
      continue;
    }
    buf.writeln('$pad$encodedKey: ${_encodeScalar(value)}');
  }
}

void _emitListItem(StringBuffer buf, Object? item, {required int indent}) {
  final pad = ' ' * indent;
  if (item == null) {
    buf.writeln('$pad-');
    return;
  }
  if (item is Map<String, dynamic>) {
    if (item.isEmpty) {
      buf.writeln('$pad- {}');
      return;
    }
    final keys = item.keys.toList()..sort();
    var first = true;
    for (final k in keys) {
      final v = item[k];
      final encodedKey = _encodeKey(k);
      final marker = first ? '- ' : '  ';
      if (v == null) {
        buf.writeln('$pad$marker$encodedKey:');
      } else if (v is Map<String, dynamic>) {
        if (v.isEmpty) {
          buf.writeln('$pad$marker$encodedKey: {}');
        } else {
          buf.writeln('$pad$marker$encodedKey:');
          _emitMap(buf, v, indent: indent + 4);
        }
      } else if (v is List) {
        if (v.isEmpty) {
          buf.writeln('$pad$marker$encodedKey: []');
        } else {
          buf.writeln('$pad$marker$encodedKey:');
          for (final inner in v) {
            _emitListItem(buf, inner, indent: indent + 4);
          }
        }
      } else {
        buf.writeln('$pad$marker$encodedKey: ${_encodeScalar(v)}');
      }
      first = false;
    }
    return;
  }
  if (item is List) {
    buf.writeln('$pad-');
    for (final inner in item) {
      _emitListItem(buf, inner, indent: indent + 2);
    }
    return;
  }
  buf.writeln('$pad- ${_encodeScalar(item)}');
}

/// Returns a YAML-safe representation of a scalar leaf.
///
/// All strings are double-quoted to make round-tripping unambiguous and
/// keep the output independent of how YAML 1.1/1.2 interpret unquoted
/// tokens (`yes`/`no`/`on`/`off`/`null`/etc.).
String _encodeScalar(Object? value) {
  if (value == null) {
    return '';
  }
  if (value is bool) {
    return value ? 'true' : 'false';
  }
  if (value is int) {
    return value.toString();
  }
  if (value is double) {
    return value.toString();
  }
  return _encodeString(value.toString());
}

String _encodeString(String s) {
  final escaped = s.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
  return '"$escaped"';
}

/// Map keys in our value space are always plain identifiers
/// (`flavor_name`, `image_path`, etc.). We still defensively quote any
/// key that contains a character that would require quoting.
String _encodeKey(String key) {
  final safe = RegExp(r'^[A-Za-z_][A-Za-z0-9_-]*$');
  if (safe.hasMatch(key)) {
    return key;
  }
  return _encodeString(key);
}
