/// Helpers for converting `package:yaml` `YamlMap` / `YamlList` trees into
/// plain `Map<String, dynamic>` / `List<dynamic>` trees with `String` keys.
///
/// `package:yaml` produces `YamlMap` (a `Map` with `dynamic` keys) and
/// `YamlList`. The rest of the pipeline — `deepMerge`, `PartialConfig.fromJson`,
/// `emitYaml`, etc. — expects ordinary JSON-shaped structures with `String`
/// keys. Converting once at the boundary keeps every downstream consumer
/// simple and free of `YamlMap` checks.
library;

/// Recursively converts [raw] (typically a `YamlMap` from `loadYaml`) into a
/// plain `Map<String, dynamic>` with `String` keys. Nested maps are converted
/// recursively; lists have their elements converted by [yamlToPlainValue].
///
/// Returns `null` when [raw] is `null` or is not a `Map`. This matches the
/// permissive contract used at every existing call site.
Map<String, dynamic>? yamlToPlainMap(Object? raw) {
  if (raw == null || raw is! Map) {
    return null;
  }
  final out = <String, dynamic>{};
  raw.forEach((k, v) {
    out[k.toString()] = yamlToPlainValue(v);
  });
  return out;
}

/// Recursively converts a single YAML value to a plain Dart value. Maps go
/// through [yamlToPlainMap], lists are mapped element-by-element, and scalars
/// (including `null`) pass through unchanged.
Object? yamlToPlainValue(Object? v) {
  if (v == null) {
    return null;
  }
  if (v is Map) {
    return yamlToPlainMap(v);
  }
  if (v is List) {
    return v.map(yamlToPlainValue).toList();
  }
  return v;
}
