/// Deep-merges two JSON-shaped maps without mutating either input.
///
/// Used by the consolidated multi-flavor config loader to layer each
/// flavor's overrides on top of the shared `defaults:` block.
///
/// Rules:
///
/// - Maps merge recursively (key-wise).
/// - Scalars and lists in [override] replace those in [base] wholesale.
///   Lists are NOT concatenated.
/// - An explicit `null` value in [override] **deletes** the key from the
///   result (this is how the YAML schema lets a flavor un-set a default).
/// - Keys present only in [base] survive unchanged.
/// - Keys present only in [override] are added — except when the value is
///   `null`, in which case they are absent from the result (consistent
///   with the deletion rule).
///
/// The function operates on raw `Map<String, dynamic>` values produced by
/// `package:yaml` / `package:checked_yaml`. Merging at the JSON layer is
/// simpler and less error-prone than trying to merge typed objects.
library;

/// Returns a new map produced by deep-merging [override] onto [base].
///
/// Neither input is mutated. See library docs for the full rule set.
Map<String, dynamic> deepMerge(
  Map<String, dynamic> base,
  Map<String, dynamic> override,
) {
  final result = <String, dynamic>{};

  // Start with a (shallow-cloned) copy of base; nested maps will be
  // recursively merged when override visits the same key.
  for (final entry in base.entries) {
    result[entry.key] = _cloneValue(entry.value);
  }

  for (final entry in override.entries) {
    final key = entry.key;
    final ov = entry.value;

    if (ov == null) {
      // Explicit null deletes.
      result.remove(key);
      continue;
    }

    final bv = result[key];
    if (bv is Map && ov is Map) {
      result[key] = deepMerge(
        Map<String, dynamic>.from(bv),
        Map<String, dynamic>.from(ov),
      );
    } else {
      result[key] = _cloneValue(ov);
    }
  }

  return result;
}

/// Deep-clone helper so the returned map does not alias inputs.
Object? _cloneValue(Object? value) {
  if (value is Map) {
    final cloned = <String, dynamic>{};
    for (final e in value.entries) {
      cloned[e.key.toString()] = _cloneValue(e.value);
    }
    return cloned;
  }
  if (value is List) {
    return value.map(_cloneValue).toList();
  }
  return value;
}
