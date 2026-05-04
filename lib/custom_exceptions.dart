import 'package:flutter_launcher_icons_flavors/utils.dart';

/// Exception to be thrown whenever we have an invalid configuration
class InvalidConfigException implements Exception {
  /// Constructs instance
  const InvalidConfigException([this.message]);

  /// Message for the exception
  final String? message;

  @override
  String toString() {
    return generateError(this, message);
  }
}

/// Exception to be thrown whenever using an invalid Android icon name
class InvalidAndroidIconNameException implements Exception {
  /// Constructs instance of this exception
  const InvalidAndroidIconNameException([this.message]);

  /// Message for the exception
  final String? message;

  @override
  String toString() {
    return generateError(this, message);
  }
}

/// Exception to be thrown whenever no config is found
class NoConfigFoundException implements Exception {
  /// Constructs instance of this exception
  const NoConfigFoundException([this.message]);

  /// Message for the exception
  final String? message;

  @override
  String toString() {
    return generateError(this, message);
  }
}

/// Exception to be thrown whenever there is no decoder for the image format
class NoDecoderForImageFormatException implements Exception {
  /// Constructs instance of this exception
  const NoDecoderForImageFormatException([this.message]);

  /// Message for the exception
  final String? message;

  @override
  String toString() {
    return generateError(this, message);
  }
}

/// Exception thrown when both new (`flutter_launcher_icons_flavors.yaml`)
/// and legacy (`flutter_launcher_icons-<flavor>.yaml`) config sources
/// coexist and the user has opted into strict mode.
///
/// **Phase 3 status:** defined but never thrown — Phase 4 wires it up via
/// the `--strict` flag. Today coexistence emits a warning only.
class MixedConfigSourcesException implements Exception {
  /// Creates a new [MixedConfigSourcesException].
  const MixedConfigSourcesException(this.ignoredLegacy);

  /// The list of legacy `flutter_launcher_icons-<flavor>.yaml` paths
  /// that were detected alongside the consolidated config file.
  final List<String> ignoredLegacy;

  @override
  String toString() {
    return generateError(
      this,
      'Both flutter_launcher_icons_flavors.yaml and legacy '
      'flutter_launcher_icons-<flavor>.yaml file(s) were found:\n'
      '  ${ignoredLegacy.join('\n  ')}\n'
      'Run `dart run flutter_launcher_icons_flavors migrate` to consolidate, '
      'or remove the legacy files.',
    );
  }
}

/// Exception thrown when a requested flavor name is not found in the
/// consolidated multi-flavor config.
class UnknownFlavorException implements Exception {
  /// Creates a new [UnknownFlavorException].
  const UnknownFlavorException(this.requestedName, this.availableNames);

  /// The flavor name that was requested but not present in the file.
  final String requestedName;

  /// The list of flavor names actually defined in the file.
  final List<String> availableNames;

  @override
  String toString() {
    return generateError(
      this,
      'Unknown flavor "$requestedName". '
      'Available flavors: ${availableNames.join(', ')}',
    );
  }
}

/// Exception thrown for schema, structural, or merge errors in
/// `flutter_launcher_icons_flavors.yaml`.
class InvalidFlavorsFileException implements Exception {
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
  String toString() {
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
    return generateError(this, buf.toString());
  }
}

/// A exception to throw when given [fileName] is not found
class FileNotFoundException implements Exception {
  /// Creates a instance of [FileNotFoundException].
  const FileNotFoundException(this.fileName);

  /// Name of the file
  final String fileName;

  @override
  String toString() {
    return generateError(this, '$fileName file not found');
  }
}
