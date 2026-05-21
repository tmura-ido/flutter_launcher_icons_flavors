import 'package:flutter_launcher_icons_flavors/utils.dart';

/// Common base for every fork-thrown exception. Lets CLI entry points
/// (`generate`, `migrate`, `doctor`) catch a single type and decide how to
/// surface it (info vs. verbose). Library consumers can also `catch
/// (FLIException e)` once instead of listing every subtype (upstream #378).
abstract class FLIException implements Exception {
  /// Short, user-facing message. Printed unconditionally on error.
  String get info;

  /// Longer remediation / context, printed under `-v`/`--verbose`. May be
  /// `null` when there is nothing extra to add beyond [info].
  String? get verbose => null;

  @override
  String toString() => info;
}

/// Exception to be thrown whenever we have an invalid configuration
class InvalidConfigException implements FLIException {
  /// Constructs instance
  const InvalidConfigException([this.message]);

  /// Message for the exception
  final String? message;

  @override
  String get info => message ?? 'invalid configuration';

  @override
  String? get verbose => null;

  @override
  String toString() {
    return generateError(this, message);
  }
}

/// Exception to be thrown whenever using an invalid Android icon name
class InvalidAndroidIconNameException implements FLIException {
  /// Constructs instance of this exception
  const InvalidAndroidIconNameException([this.message]);

  /// Message for the exception
  final String? message;

  @override
  String get info => message ?? 'invalid Android icon name';

  @override
  String? get verbose => null;

  @override
  String toString() {
    return generateError(this, message);
  }
}

/// Exception to be thrown whenever no config is found
class NoConfigFoundException implements FLIException {
  /// Constructs instance of this exception
  const NoConfigFoundException([this.message]);

  /// Message for the exception
  final String? message;

  @override
  String get info => message ?? 'no config found';

  @override
  String? get verbose => null;

  @override
  String toString() {
    return generateError(this, message);
  }
}

/// Exception to be thrown whenever there is no decoder for the image format
class NoDecoderForImageFormatException implements FLIException {
  /// Constructs instance of this exception
  const NoDecoderForImageFormatException([this.message]);

  /// Message for the exception
  final String? message;

  @override
  String get info => message ?? 'no decoder for image format';

  @override
  String? get verbose => null;

  @override
  String toString() {
    return generateError(this, message);
  }
}

/// Exception thrown when both new (`flutter_launcher_icons_flavors.yaml`)
/// and legacy (`flutter_launcher_icons-<flavor>.yaml`) config sources
/// coexist and the user has opted into strict mode (`--strict`).
class MixedConfigSourcesException implements FLIException {
  /// Creates a new [MixedConfigSourcesException].
  const MixedConfigSourcesException(this.ignoredLegacy);

  /// The list of legacy `flutter_launcher_icons-<flavor>.yaml` paths
  /// that were detected alongside the consolidated config file.
  final List<String> ignoredLegacy;

  @override
  String get info =>
      'Both flutter_launcher_icons_flavors.yaml and legacy '
      'flutter_launcher_icons-<flavor>.yaml file(s) were found:\n'
      '  ${ignoredLegacy.join('\n  ')}\n'
      'Run `dart run flutter_launcher_icons_flavors migrate` to consolidate, '
      'or remove the legacy files.';

  @override
  String? get verbose => null;

  @override
  String toString() => generateError(this, info);
}

/// Exception thrown when a requested flavor name is not found in the
/// consolidated multi-flavor config.
class UnknownFlavorException implements FLIException {
  /// Creates a new [UnknownFlavorException].
  const UnknownFlavorException(this.requestedName, this.availableNames);

  /// The flavor name that was requested but not present in the file.
  final String requestedName;

  /// The list of flavor names actually defined in the file.
  final List<String> availableNames;

  @override
  String get info =>
      'Unknown flavor "$requestedName". '
      'Available flavors: ${availableNames.join(', ')}';

  @override
  String? get verbose => null;

  @override
  String toString() => generateError(this, info);
}

/// Exception thrown for schema, structural, or merge errors in
/// `flutter_launcher_icons_flavors.yaml`.
class InvalidFlavorsFileException implements FLIException {
  /// Creates a new [InvalidFlavorsFileException].
  const InvalidFlavorsFileException(
    this.message, {
    this.path,
    this.flavor,
    this.keyPath,
  });

  /// Human-readable message describing the failure.
  final String message;

  /// Absolute path of the offending file, when known.
  final String? path;

  /// Name of the offending flavor, when applicable.
  final String? flavor;

  /// Dotted key path inside the YAML where the failure was detected,
  /// e.g. `flavors.dev.web.unknown_key`.
  final String? keyPath;

  @override
  String get info {
    final buf = StringBuffer(message);
    if (path != null) {
      buf.write(' [file: $path]');
    }
    if (flavor != null) {
      buf.write(' [flavor: $flavor]');
    }
    if (keyPath != null) {
      buf.write(' [at: $keyPath]');
    }
    return buf.toString();
  }

  @override
  String? get verbose => null;

  @override
  String toString() => generateError(this, info);
}
