/// Single source of truth for the regex patterns used to extract
/// `minSdk` / `minSdkVersion` from Android Gradle files.
///
/// Both [`lib/android.dart`](../android.dart) (generation pipeline) and
/// [`lib/cli/doctor_command.dart`](../cli/doctor_command.dart)
/// (diagnostic report) consume these. Keeping the table in one place
/// guarantees that whatever `generate` resolves, `doctor` reports.
///
/// Each entry carries:
///   * `regex`        — compiled `RegExp` against the gradle file body.
///   * `label`        — human-readable description for `doctor`'s
///                      `matched pattern` line.
///   * `recurseToFlutter` — when true, the literal capture group is
///                      absent (the gradle line is `flutter.minSdkVersion`)
///                      and the caller must recurse into the Flutter SDK.
library;

/// A single `minSdk*` pattern with its diagnostic label.
class MinSdkPattern {
  /// Creates a pattern entry. [recurseToFlutter] defaults to `false`;
  /// set it on entries that match `flutter.minSdkVersion` indirection.
  const MinSdkPattern(this.regex, this.label, {this.recurseToFlutter = false});

  /// The regex applied (multi-line) to gradle file content.
  final RegExp regex;

  /// Short human label, e.g. `'minSdk = N (KTS)'`.
  final String label;

  /// When `true`, callers should recurse into the Flutter SDK gradle
  /// file (or `local.properties`) instead of using `regex.group(1)`.
  final bool recurseToFlutter;
}

/// Patterns for Groovy `build.gradle` files.
final List<MinSdkPattern> groovyMinSdkPatterns = <MinSdkPattern>[
  MinSdkPattern(
    RegExp(r'^\s*minSdkVersion\s+(\d+)\s*$', multiLine: true),
    'minSdkVersion N (Groovy)',
  ),
  MinSdkPattern(
    RegExp(r'^\s*minSdkVersion\s*=\s*(\d+)\s*$', multiLine: true),
    'minSdkVersion = N (Groovy)',
  ),
  MinSdkPattern(
    RegExp(r'^\s*minSdk\s+(\d+)\s*$', multiLine: true),
    'minSdk N (Groovy)',
  ),
  MinSdkPattern(
    RegExp(r'^\s*minSdk\s*=\s*(\d+)\s*$', multiLine: true),
    'minSdk = N (Groovy)',
  ),
  MinSdkPattern(
    RegExp(r'^\s*minSdkVersion\s+flutter\.minSdkVersion\s*$', multiLine: true),
    'minSdkVersion flutter.minSdkVersion (Groovy, indirect)',
    recurseToFlutter: true,
  ),
];

/// Patterns for Kotlin DSL `build.gradle.kts` files.
final List<MinSdkPattern> ktsMinSdkPatterns = <MinSdkPattern>[
  MinSdkPattern(
    RegExp(r'^\s*minSdk\s*=\s*(\d+)\s*$', multiLine: true),
    'minSdk = N (KTS)',
  ),
  MinSdkPattern(
    RegExp(r'^\s*minSdkVersion\s*=\s*(\d+)\s*$', multiLine: true),
    'minSdkVersion = N (KTS)',
  ),
  MinSdkPattern(
    RegExp(r'^\s*minSdk\(\s*(\d+)\s*\)\s*$', multiLine: true),
    'minSdk(N) (KTS DSL call)',
  ),
  MinSdkPattern(
    RegExp(r'^\s*minSdk\s*=\s*flutter\.minSdkVersion\s*$', multiLine: true),
    'minSdk = flutter.minSdkVersion (KTS, indirect)',
    recurseToFlutter: true,
  ),
];
