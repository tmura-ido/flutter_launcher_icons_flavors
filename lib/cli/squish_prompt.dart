import 'dart:io';

import 'package:flutter_launcher_icons_flavors/android.dart' as android;
import 'package:flutter_launcher_icons_flavors/config/config.dart';
import 'package:flutter_launcher_icons_flavors/utils.dart' as utils;
import 'package:path/path.dart' as p;

/// A single (platform, source-image) pair that would be silently squished
/// onto an N×N canvas during generation because the source is non-square
/// and the platform has no resolved background color to letter-box with.
class SquishCandidate {
  /// Creates a [SquishCandidate].
  SquishCandidate({
    required this.flavor,
    required this.platform,
    required this.imagePath,
    required this.width,
    required this.height,
  });

  /// Flavor name (empty string when single-config / not a multi-flavor run).
  final String flavor;

  /// Human-readable platform label shown in the prompt, e.g.
  /// `'Android adaptive foreground'`, `'Web'`, `'Windows'`.
  final String platform;

  /// Absolute path to the source image as it will be read at generation time.
  final String imagePath;

  /// Width of the source image
  final int width;

  /// Height of the source image
  final int height;

  @override
  String toString() {
    final flavorPrefix = flavor.isEmpty ? '' : '[$flavor] ';
    return '$flavorPrefix$platform — $imagePath ($width×$height)';
  }
}

/// Walks a resolved [config] and returns every source image that would be
/// silently squished — non-square AND no resolved background color the
/// writer can use as letter-box fill.
///
/// Resolution rules mirror the writers in `lib/android.dart`,
/// `lib/web/web_icon_generator.dart`, and `lib/ios.dart`:
///   * **Android non-adaptive mipmap** squishes when `background_color` is
///     unset.
///   * **Android adaptive foreground** squishes when `adaptive_icon_background`
///     is a PNG path AND `background_color` is unset.
///   * **Android adaptive monochrome** squishes under the same rule as the
///     foreground.
///   * **Web** squishes when both `web.background_color` and
///     `background_color` are unset.
///   * **iOS** never squishes (it always has a resolved background color,
///     defaulting to `#FFFFFF`), so it's never listed.
///   * **macOS / Windows / Linux** have no platform-specific background
///     color in the schema and squish unconditionally when [config] enables
///     them with a non-square source.
///
/// [flavor] is included in each returned candidate so a multi-flavor
/// pre-flight can surface the offending flavor in the prompt.
Future<List<SquishCandidate>> findSquishCandidates({
  required Config config,
  required String prefixPath,
  String flavor = '',
}) async {
  // Per-config opt-out: when the user has already declared "yes I know,
  // squish is fine" there's nothing to ask about.
  if (config.nonSquareImageOk) {
    return const [];
  }

  final out = <SquishCandidate>[];

  Future<void> consider({
    required String platform,
    required String? relativePath,
    required bool willLetterBox,
  }) async {
    if (willLetterBox) return;
    if (relativePath == null || relativePath.isEmpty) return;
    final full = p.join(prefixPath, relativePath);
    if (!File(full).existsSync()) return;
    // Best-effort: an unreadable / non-image file just means we can't
    // pre-detect a squish — generation will raise the same decode error.
    try {
      final img = await utils.decodeImageFile(full);
      if (utils.isNonSquare(img)) {
        out.add(
          SquishCandidate(
            flavor: flavor,
            platform: platform,
            imagePath: full,
            width: img.width,
            height: img.height,
          ),
        );
      }
    } catch (_) {
      // Swallow — the generator's own decode will surface a richer error.
    }
  }

  final topBg = config.backgroundColor;

  // ---- Android non-adaptive mipmap ----
  if (config.android.isEnabled) {
    await consider(
      platform: 'Android mipmap',
      relativePath: config.getImagePathAndroid(),
      willLetterBox: topBg != null,
    );
  }

  // ---- Android adaptive foreground / monochrome ----
  final adaptiveBg = config.adaptiveIconBackground;
  final adaptiveBgIsColor =
      adaptiveBg != null && !android.isAdaptiveIconConfigPngFile(adaptiveBg);
  final adaptiveWillLetterBox = adaptiveBgIsColor || topBg != null;
  if (config.hasAndroidAdaptiveConfig) {
    await consider(
      platform: 'Android adaptive foreground',
      relativePath: config.adaptiveIconForeground,
      willLetterBox: adaptiveWillLetterBox,
    );
  }
  if (config.hasAndroidAdaptiveMonochromeConfig) {
    await consider(
      platform: 'Android adaptive monochrome',
      relativePath: config.adaptiveIconMonochrome,
      willLetterBox: adaptiveWillLetterBox,
    );
  }

  // ---- Web ----
  final webConfig = config.webConfig;
  if (webConfig != null && webConfig.generate) {
    final webBg = webConfig.backgroundColor ?? topBg;
    await consider(
      platform: 'Web',
      relativePath: webConfig.imagePath ?? config.imagePath,
      willLetterBox: webBg != null,
    );
  }

  // ---- Windows / macOS / Linux ----
  // No platform-specific bg color in the schema today; squish is the only
  // outcome for a non-square source on these platforms.
  final windowsConfig = config.windowsConfig;
  if (windowsConfig != null && windowsConfig.generate) {
    await consider(
      platform: 'Windows',
      relativePath: windowsConfig.imagePath ?? config.imagePath,
      willLetterBox: false,
    );
  }
  final macConfig = config.macOSConfig;
  if (macConfig != null && macConfig.generate) {
    await consider(
      platform: 'macOS',
      relativePath: macConfig.imagePath ?? config.imagePath,
      willLetterBox: false,
    );
  }
  final linuxConfig = config.linuxConfig;
  if (linuxConfig != null && linuxConfig.generate) {
    await consider(
      platform: 'Linux',
      relativePath: linuxConfig.imagePath ?? config.imagePath,
      willLetterBox: false,
    );
  }

  return out;
}

/// Outcome of a squish-approval gate.
enum SquishApproval {
  /// Nothing to ask about — proceed normally.
  noCandidates,

  /// Approved (either by user `y`, `--yes`, or `non_square_image_ok`).
  approved,

  /// Declined by the user. Caller should abort generation.
  declined,
}

/// Returns `true` only when we're confident the calling process is
/// attached to an interactive terminal AND there's no environment
/// signal telling us to treat the run as headless.
///
/// Headless signals (any one is enough):
///   * `FLI_NON_INTERACTIVE` is set to any non-empty value — explicit
///     override for tests, scripts, or anyone who wants the prompt off.
///   * `CI` is set — de-facto standard set by GitHub Actions, GitLab CI,
///     CircleCI, Travis, Jenkins, etc.
///   * `stdin.hasTerminal` throws — happens in some isolate / pipe
///     configurations; treat as non-interactive.
///
/// Why not just trust `stdin.hasTerminal`? Because `dart test` running
/// from a developer's terminal inherits the parent's stdin: hasTerminal
/// returns `true` even though the test isolate has no business prompting
/// the user. The env-var checks rescue those cases.
bool _looksInteractive(Stdin input) {
  final env = Platform.environment;
  if ((env['FLI_NON_INTERACTIVE'] ?? '').isNotEmpty) return false;
  if ((env['CI'] ?? '').isNotEmpty) return false;
  try {
    return input.hasTerminal;
  } catch (_) {
    return false;
  }
}

/// Prompts the user when [candidates] is non-empty and we're attached to
/// a real terminal. Outside a TTY (CI / scripts / tests) we silently
/// approve so legacy behavior is preserved. Pass `autoYes: true` (the
/// `--yes` flag) to skip the prompt and approve unconditionally.
///
/// Reads from [stdinForTest] / writes to [stdoutForTest] when provided —
/// the tests use this to drive the prompt deterministically without
/// touching the real terminal. [hasTerminalForTest] forces the
/// interactivity branch regardless of env vars / hasTerminal, for unit
/// tests that exercise the prompt itself.
Future<SquishApproval> promptSquishApproval(
  List<SquishCandidate> candidates, {
  required bool autoYes,
  Stdin? stdinForTest,
  IOSink? stdoutForTest,
  bool? hasTerminalForTest,
}) async {
  if (candidates.isEmpty) {
    return SquishApproval.noCandidates;
  }
  if (autoYes) {
    return SquishApproval.approved;
  }
  final sink = stdoutForTest ?? stdout;
  final input = stdinForTest ?? stdin;
  final isTty = hasTerminalForTest ?? _looksInteractive(input);
  if (!isTty) {
    // Non-interactive — silently approve, matching the legacy behavior
    // for scripts and CI. Surface what we'd otherwise have asked so the
    // user can later add `background_color` or `non_square_image_ok` if
    // they want to silence the warning explicitly.
    sink.writeln(
      '⚠ Non-square source(s) will be squished — running non-interactively, '
      'auto-approving (set `background_color` or `non_square_image_ok: true` '
      'in config, or pass --yes, to skip this warning):',
    );
    for (final c in candidates) {
      sink.writeln('    - $c');
    }
    return SquishApproval.approved;
  }

  sink.writeln('');
  sink.writeln(
    'The following source image(s) will be SQUISHED onto a square canvas '
    '(no letter-box bars, aspect ratio NOT preserved):',
  );
  for (final c in candidates) {
    sink.writeln('    - $c');
  }
  sink.writeln('');
  sink.writeln(
    'To preserve aspect ratio instead, set a `background_color` (top-level '
    'or per-platform) so the writer can letter-box the non-square source.',
  );
  sink.write('Proceed with squishing all of the above? [y/N]: ');
  final line = input.readLineSync()?.trim().toLowerCase() ?? '';
  if (line == 'y' || line == 'yes') {
    sink.writeln('→ Approved. Continuing with squish.');
    return SquishApproval.approved;
  }
  sink.writeln(
    '→ Declined. Aborting. Add `background_color` to letter-box, or '
    '`non_square_image_ok: true` to suppress this prompt.',
  );
  return SquishApproval.declined;
}
