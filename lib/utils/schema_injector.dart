import 'dart:io';

import 'package:flutter_launcher_icons_flavors/logger.dart';

/// URL of the published JSON Schema. Pinned to `master` (the repo's
/// default branch): the schema only ever adds optional fields, so
/// older YAMLs always validate.
const String schemaUrl =
    'https://raw.githubusercontent.com/tmura-ido/flutter_launcher_icons_flavors/master/flutter_launcher_icons_flavors.schema.json';

/// One-line directive prepended to YAML configs so editors with a YAML
/// language server (VS Code + Red Hat YAML, JetBrains natively) pick up
/// completion + hover docs + inline validation.
String get schemaDirective => '# yaml-language-server: \$schema=$schemaUrl';

/// Match any existing `# yaml-language-server: $schema=...` line so we
/// don't double-inject and don't clobber user-set URLs (a different
/// fork, a pinned tag, a local file).
final RegExp _existingDirective =
    RegExp(r'^\s*#\s*yaml-language-server\s*:\s*\$schema\s*=', multiLine: true);

/// Add the schema directive to [file] if one isn't already present.
///
/// Idempotent: returns `false` and writes nothing when any
/// `# yaml-language-server:` line already exists in the file.
///
/// pubspec.yaml is left alone — the schema is config-file-specific and
/// would conflict with the pubspec's own schema (Dart/Flutter SDK).
///
/// Honors [skip]: when true, returns `false` without touching the file
/// (wired up to the top-level `--no-inject-schema` flag).
///
/// Returns `true` if the directive was injected, `false` otherwise.
Future<bool> ensureSchemaDirective(
  String filePath, {
  required FLILogger logger,
  bool skip = false,
}) async {
  if (skip) {
    return false;
  }

  final file = File(filePath);
  if (!file.existsSync()) {
    return false;
  }

  // Leave pubspec.yaml alone — it has its own schema.
  final lowered = filePath.replaceAll(r'\', '/').toLowerCase();
  if (lowered.endsWith('/pubspec.yaml') || lowered == 'pubspec.yaml') {
    return false;
  }

  final original = await file.readAsString();
  if (_existingDirective.hasMatch(original)) {
    return false;
  }

  final needsBlankLine = original.isNotEmpty && !original.startsWith('\n');
  final injected =
      '$schemaDirective\n${needsBlankLine ? '\n' : ''}$original';
  await file.writeAsString(injected);
  logger.verbose('Injected schema directive into $filePath');
  return true;
}
