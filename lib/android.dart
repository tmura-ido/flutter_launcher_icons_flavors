// ignore_for_file: public_member_api_docs

import 'dart:io';

import 'package:flutter_launcher_icons_flavors/config/config.dart';
import 'package:flutter_launcher_icons_flavors/constants.dart' as constants;
import 'package:flutter_launcher_icons_flavors/constants.dart';
import 'package:flutter_launcher_icons_flavors/custom_exceptions.dart';
import 'package:flutter_launcher_icons_flavors/logger.dart';
import 'package:flutter_launcher_icons_flavors/src/min_sdk_patterns.dart';
import 'package:flutter_launcher_icons_flavors/utils.dart' as utils;
import 'package:flutter_launcher_icons_flavors/xml_templates.dart'
    as xml_template;
import 'package:image/image.dart';
import 'package:path/path.dart' as path;

class AndroidIconTemplate {
  AndroidIconTemplate({required this.size, required this.directoryName});

  final String directoryName;
  final int size;
}

final List<AndroidIconTemplate> adaptiveForegroundIcons = <AndroidIconTemplate>[
  AndroidIconTemplate(directoryName: 'drawable-mdpi', size: 108),
  AndroidIconTemplate(directoryName: 'drawable-hdpi', size: 162),
  AndroidIconTemplate(directoryName: 'drawable-xhdpi', size: 216),
  AndroidIconTemplate(directoryName: 'drawable-xxhdpi', size: 324),
  AndroidIconTemplate(directoryName: 'drawable-xxxhdpi', size: 432),
];

List<AndroidIconTemplate> androidIcons = <AndroidIconTemplate>[
  AndroidIconTemplate(directoryName: 'mipmap-mdpi', size: 48),
  AndroidIconTemplate(directoryName: 'mipmap-hdpi', size: 72),
  AndroidIconTemplate(directoryName: 'mipmap-xhdpi', size: 96),
  AndroidIconTemplate(directoryName: 'mipmap-xxhdpi', size: 144),
  AndroidIconTemplate(directoryName: 'mipmap-xxxhdpi', size: 192),
];

Future<void> createDefaultIcons(
  Config config,
  String? flavor, {
  String prefixPath = '.',
}) async {
  utils.printStatus('Creating default icons Android');
  final String? relativeImagePath = config.getImagePathAndroid();
  if (relativeImagePath == null) {
    throw const InvalidConfigException(errorMissingImagePath);
  }
  final String filePath = path.join(prefixPath, relativeImagePath);
  final Image image = await utils.decodeImageFile(filePath);
  final File androidManifestFile = File(
    path.join(prefixPath, constants.androidManifestFile),
  );
  final concurrentIconUpdates = <Future<void>>[];
  if (config.isCustomAndroidFile) {
    utils.printStatus('Adding a new Android launcher icon');
    final String iconName = config.androidIconName;
    isAndroidIconNameCorrectFormat(iconName);
    final String iconPath = '$iconName.png';
    for (AndroidIconTemplate template in androidIcons) {
      concurrentIconUpdates.add(
        _saveNewImages(template, image, iconPath, flavor, prefixPath),
      );
    }
    await overwriteAndroidManifestWithNewLauncherIcon(
      iconName,
      androidManifestFile,
    );
  } else {
    utils.printStatus(
      'Overwriting the default Android launcher icon with a new icon',
    );
    for (AndroidIconTemplate template in androidIcons) {
      concurrentIconUpdates.add(
        overwriteExistingIcons(
          template,
          image,
          constants.androidFileName,
          flavor,
          prefixPath: prefixPath,
        ),
      );
    }
    await overwriteAndroidManifestWithNewLauncherIcon(
      constants.androidDefaultIconName,
      androidManifestFile,
    );
  }
  await Future.wait(concurrentIconUpdates);
}

/// Ensures that the Android icon name is in the correct format
bool isAndroidIconNameCorrectFormat(String iconName) {
  // assure the icon only consists of lowercase letters, numbers and underscore
  if (!RegExp(r'^[a-z0-9_]+$').hasMatch(iconName)) {
    throw const InvalidAndroidIconNameException(
      constants.errorIncorrectIconName,
    );
  }
  return true;
}

Future<void> createAdaptiveIcons(
  Config config,
  String? flavor, {
  String prefixPath = '.',
}) async {
  utils.printStatus('Creating adaptive icons Android');

  // Retrieve the necessary Flutter Launcher Icons configuration from the pubspec.yaml file
  final String? backgroundConfig = config.adaptiveIconBackground;
  final String? foregroundImagePath = config.adaptiveIconForeground;
  if (backgroundConfig == null || foregroundImagePath == null) {
    throw const InvalidConfigException(errorMissingImagePath);
  }
  final Image foregroundImage = await utils.decodeImageFile(
    path.join(prefixPath, foregroundImagePath),
  );

  final concurrentImageUpdates = <Future<void>>[];
  // Create adaptive icon foreground images
  for (AndroidIconTemplate androidIcon in adaptiveForegroundIcons) {
    concurrentImageUpdates.add(
      overwriteExistingIcons(
        androidIcon,
        foregroundImage,
        constants.androidAdaptiveForegroundFileName,
        flavor,
        prefixPath: prefixPath,
      ),
    );
  }

  // Create adaptive icon background
  if (isAdaptiveIconConfigPngFile(backgroundConfig)) {
    concurrentImageUpdates.add(
      _createAdaptiveBackgrounds(
        config,
        backgroundConfig,
        flavor,
        prefixPath: prefixPath,
      ),
    );
  } else {
    await updateColorsXmlFile(backgroundConfig, flavor, prefixPath: prefixPath);
  }
  await Future.wait(concurrentImageUpdates);
}

Future<void> createAdaptiveMonochromeIcons(
  Config config,
  String? flavor, {
  String prefixPath = '.',
}) async {
  utils.printStatus('Creating adaptive monochrome icons Android');

  // Retrieve the necessary Flutter Launcher Icons configuration from the pubspec.yaml file
  final String? monochromeImagePath = config.adaptiveIconMonochrome;
  if (monochromeImagePath == null) {
    throw const InvalidConfigException(errorMissingImagePath);
  }
  final Image monochromeImage = await utils.decodeImageFile(
    path.join(prefixPath, monochromeImagePath),
  );

  final concurrentIconUpdates = <Future<void>>[];
  // Create adaptive icon monochrome images
  for (AndroidIconTemplate androidIcon in adaptiveForegroundIcons) {
    concurrentIconUpdates.add(
      overwriteExistingIcons(
        androidIcon,
        monochromeImage,
        constants.androidAdaptiveMonochromeFileName,
        flavor,
        prefixPath: prefixPath,
      ),
    );
  }
  await Future.wait(concurrentIconUpdates);
}

Future<void> createMipmapXmlFile(
  Config config,
  String? flavor, {
  String prefixPath = '.',
}) async {
  // Note: Adaptive Icons will only be used when both
  // `adaptive_icon_background` and `adaptive_icon_foreground` or
  // `adaptive_icon_monochrome` are specified (The `image_path` is not
  // automatically taken as foreground)
  if (!config.hasAndroidAdaptiveConfig &&
      !config.hasAndroidAdaptiveMonochromeConfig) {
    return;
  }

  utils.printStatus('Creating mipmap xml file Android');

  String xmlContent = '';

  if (config.hasAndroidAdaptiveConfig) {
    if (isAdaptiveIconConfigPngFile(config.adaptiveIconBackground!)) {
      xmlContent +=
          '  <background android:drawable="@drawable/ic_launcher_background"/>\n';
    } else {
      xmlContent +=
          '  <background android:drawable="@color/ic_launcher_background"/>\n';
    }

    xmlContent +=
        '''
  <foreground>
      <inset
          android:drawable="@drawable/ic_launcher_foreground"
          android:inset="${config.adaptiveIconForegroundInset}%" />
  </foreground>
''';
  }

  if (config.hasAndroidAdaptiveMonochromeConfig) {
    xmlContent +=
        '''
  <monochrome>
      <inset
          android:drawable="@drawable/ic_launcher_monochrome"
          android:inset="${config.adaptiveIconForegroundInset}%" />
  </monochrome>
''';
  }

  final String iconBaseName = config.isCustomAndroidFile
      ? config.androidIconName
      : constants.androidDefaultIconName;
  final File mipmapXmlFile = File(
    path.join(
      prefixPath,
      constants.androidAdaptiveXmlFolder(flavor),
      '$iconBaseName.xml',
    ),
  );

  await mipmapXmlFile.create(recursive: true);
  await mipmapXmlFile.writeAsString(
    xml_template.mipmapXmlFile.replaceAll('{{CONTENT}}', xmlContent),
  );
}

/// Retrieves the colors.xml file for the project.
///
/// If the colors.xml file is found, it is updated with a new color item for the
/// adaptive icon background.
///
/// If not, the colors.xml file is created and a color item for the adaptive icon
/// background is included in the new colors.xml file.
Future<void> updateColorsXmlFile(
  String backgroundConfig,
  String? flavor, {
  String prefixPath = '.',
}) async {
  final File colorsXml = File(
    path.join(prefixPath, constants.androidColorsFile(flavor)),
  );
  // existsSync is intentional here: a single bool probe before deciding
  // whether to update or create the file. Async I/O is reserved for the
  // image read/encode/write hot paths.
  if (colorsXml.existsSync()) {
    utils.printStatus(
      'Updating colors.xml with color for adaptive icon background',
    );
    await updateColorsFile(colorsXml, backgroundConfig);
  } else {
    utils.printStatus('No colors.xml file found in your Android project');
    utils.printStatus(
      'Creating colors.xml file and adding it to your Android project',
    );
    await createNewColorsFile(backgroundConfig, flavor, prefixPath: prefixPath);
  }
}

/// creates adaptive background using png image
Future<void> _createAdaptiveBackgrounds(
  Config config,
  String adaptiveIconBackgroundImagePath,
  String? flavor, {
  required String prefixPath,
}) async {
  final String filePath = path.join(
    prefixPath,
    adaptiveIconBackgroundImagePath,
  );
  final Image image = await utils.decodeImageFile(filePath);

  final concurrentImageUpdates = <Future<void>>[];
  // creates a png image (ic_adaptive_background.png) for the adaptive icon background in each of the locations
  // it is required
  for (AndroidIconTemplate androidIcon in adaptiveForegroundIcons) {
    concurrentImageUpdates.add(
      _saveNewImages(
        androidIcon,
        image,
        constants.androidAdaptiveBackgroundFileName,
        flavor,
        prefixPath,
      ),
    );
  }
  await Future.wait(concurrentImageUpdates);
}

/// Creates a colors.xml file if it was missing from android/app/src/main/res/values/colors.xml
Future<void> createNewColorsFile(
  String backgroundColor,
  String? flavor, {
  String prefixPath = '.',
}) async {
  final colorsFile = await File(
    path.join(prefixPath, constants.androidColorsFile(flavor)),
  ).create(recursive: true);
  await colorsFile.writeAsString(xml_template.colorsXml);
  await updateColorsFile(colorsFile, backgroundColor);
}

/// Updates the colors.xml with the new adaptive launcher icon color
Future<void> updateColorsFile(File colorsFile, String backgroundColor) async {
  // Write foreground color
  final List<String> lines = await colorsFile.readAsLines();
  bool foundExisting = false;
  for (int x = 0; x < lines.length; x++) {
    String line = lines[x];
    if (line.contains('name="ic_launcher_background"')) {
      foundExisting = true;
      // replace anything between tags which does not contain another tag
      line = line.replaceAll(RegExp(r'>([^><]*)<'), '>$backgroundColor<');
      lines[x] = line;
      break;
    }
  }

  // Add new line if we didn't find an existing value
  if (!foundExisting) {
    lines.insert(
      lines.length - 1,
      '\t<color name="ic_launcher_background">$backgroundColor</color>',
    );
  }

  await colorsFile.writeAsString(lines.join('\n'));
}

/// Overrides the existing launcher icons in the project
/// Note: Do not change interpolation unless you end up with better results (see issue for result when using cubic
/// interpolation)
/// https://github.com/fluttercommunity/flutter_launcher_icons/issues/101#issuecomment-495528733
Future<void> overwriteExistingIcons(
  AndroidIconTemplate template,
  Image image,
  String filename,
  String? flavor, {
  String prefixPath = '.',
}) async {
  final Image newFile = utils.createResizedImage(template.size, image);
  final pngFile = await File(
    path.join(
      prefixPath,
      constants.androidResFolder(flavor),
      template.directoryName,
      filename,
    ),
  ).create(recursive: true);
  await pngFile.writeAsBytes(encodePng(newFile));
}

/// Saves new launcher icons to the project, keeping the old launcher icons.
/// Note: Do not change interpolation unless you end up with better results
/// https://github.com/fluttercommunity/flutter_launcher_icons/issues/101#issuecomment-495528733
Future<void> _saveNewImages(
  AndroidIconTemplate template,
  Image image,
  String iconFilePath,
  String? flavor,
  String prefixPath,
) async {
  final Image newImage = utils.createResizedImage(template.size, image);
  final newFile = await File(
    path.join(
      prefixPath,
      constants.androidResFolder(flavor),
      template.directoryName,
      iconFilePath,
    ),
  ).create(recursive: true);
  await newFile.writeAsBytes(encodePng(newImage));
}

/// Updates the line which specifies the launcher icon within the AndroidManifest.xml
/// with the new icon name (only if it has changed)
///
/// Note: default iconName = "ic_launcher"
Future<void> overwriteAndroidManifestWithNewLauncherIcon(
  String iconName,
  File androidManifestFile,
) async {
  // we do not use `file.readAsLines()` here because that always gets rid of the last empty newline
  final List<String> oldManifestLines =
      (await androidManifestFile.readAsString()).split('\n');
  final List<String> transformedLines =
      _transformAndroidManifestWithNewLauncherIcon(oldManifestLines, iconName);
  await androidManifestFile.writeAsString(transformedLines.join('\n'));
}

/// Updates only the line containing android:icon with the specified iconName
List<String> _transformAndroidManifestWithNewLauncherIcon(
  List<String> oldManifestLines,
  String iconName,
) {
  return oldManifestLines.map((String line) {
    if (line.contains('android:icon')) {
      // Using RegExp replace the value of android:icon to point to the new icon
      // anything but a quote of any length: [^"]*
      // an escaped quote: \\" (escape slash, because it exists regex)
      // quote, no quote / quote with things behind : \"[^"]*
      // repeat as often as wanted with no quote at start: [^"]*(\"[^"]*)*
      // escaping the slash to place in string: [^"]*(\\"[^"]*)*"
      // result: any string which does only include escaped quotes
      return line.replaceAll(
        RegExp(r'android:icon="[^"]*(\\"[^"]*)*"'),
        'android:icon="@mipmap/$iconName"',
      );
    } else {
      return line;
    }
  }).toList();
}

/// Probes for the app-level Android gradle build file inside [prefixPath].
///
/// Probes (in order):
///   1. `<prefix>/android/app/build.gradle.kts` (Kotlin DSL)
///   2. `<prefix>/android/app/build.gradle`     (Groovy DSL)
///
/// Returns `null` when neither file exists. Kotlin DSL wins when both are
/// present.
///
/// Known limitations (caller must request `min_sdk_android` explicitly):
///   * Version catalogs (`libs.versions.toml`) are not parsed.
///   * Convention plugins are not parsed.
Future<File?> findAndroidGradleFile(String prefixPath) async {
  final kts = File(path.join(prefixPath, constants.androidAppGradleKts));
  if (kts.existsSync()) {
    return kts;
  }
  final groovy = File(path.join(prefixPath, constants.androidAppGradleGroovy));
  if (groovy.existsSync()) {
    return groovy;
  }
  return null;
}

/// Probes the Flutter SDK gradle helper file given a [flutterRoot].
///
/// Returns the first existing of:
///   1. `<flutterRoot>/packages/flutter_tools/gradle/flutter.gradle.kts`
///   2. `<flutterRoot>/packages/flutter_tools/gradle/flutter.gradle`
///
/// Returns `null` when neither exists.
Future<File?> _findFlutterSdkGradle(String flutterRoot) async {
  final kts = File(path.join(flutterRoot, constants.androidFlutterGradleKts));
  if (kts.existsSync()) {
    return kts;
  }
  final groovy = File(
    path.join(flutterRoot, constants.androidFlutterGradleGroovy),
  );
  if (groovy.existsSync()) {
    return groovy;
  }
  return null;
}

// Patterns used to extract `minSdk` / `minSdkVersion` from a gradle file.
//
// The actual table now lives in `lib/src/min_sdk_patterns.dart` so that
// `doctor` reports exactly what `generate` resolves. We keep these
// local aliases for diff-friendliness.
final List<MinSdkPattern> _groovyMinSdkPatterns = groovyMinSdkPatterns;

final List<MinSdkPattern> _ktsMinSdkPatterns = ktsMinSdkPatterns;

/// Retrieves the minSdk value for the project rooted at [prefixPath].
///
/// Probes, in order:
///   1. App-level gradle file via [findAndroidGradleFile] (KTS preferred over
///      Groovy). Tries multiple `minSdk` regex patterns appropriate for the
///      detected DSL.
///   2. If a `flutter.minSdkVersion` indirection is detected, recurses into
///      the Flutter SDK gradle file located via `flutter.sdk` in
///      `local.properties`.
///   3. Falls back to a `flutter.minSdkVersion=...` line in `local.properties`.
///
/// Returns `null` when none of the probes yield a value (caller falls back to
/// [constants.androidDefaultAndroidMinSDK]).
///
/// Known limitations (return `null` → user must specify `min_sdk_android`):
///   * Version catalogs (`libs.versions.toml` references like
///     `libs.versions.minSdk.get().toInt()`).
///   * Convention plugin delegation.
Future<int?> minSdk({String prefixPath = '.'}) async {
  final detection = await detectMinSdkAndroid(prefixPath: prefixPath);
  return detection.value;
}

/// The result of [detectMinSdkAndroid].
///
/// [value] is the resolved integer (or `null` if every probe failed).
/// [matchedLabel] is the human-readable label of the matching pattern
/// (e.g. `'minSdk = N (KTS)'`), or `null` if no app-level gradle pattern
/// matched (the value, if non-null, then came from `local.properties`).
class MinSdkDetection {
  /// Creates a detection result.
  const MinSdkDetection({required this.value, required this.matchedLabel});

  /// Detected minSdk integer, or `null` when undetectable.
  final int? value;

  /// Label of the pattern that matched the app-level gradle file, or
  /// `null` (no gradle pattern matched, or value came from
  /// `local.properties` fallback).
  final String? matchedLabel;
}

/// Like [minSdk] but additionally returns the human-readable label of
/// the pattern that matched. Used by `doctor` to keep its report aligned
/// with the generation pipeline's actual detection logic.
Future<MinSdkDetection> detectMinSdkAndroid({String prefixPath = '.'}) async {
  final gradleFile = await findAndroidGradleFile(prefixPath);
  final localPropertiesFile = File(
    path.join(prefixPath, constants.androidLocalPropertiesFile),
  );

  if (gradleFile == null) {
    final fromLocalProps = await _getMinSdkFromLocalProperties(
      localPropertiesFile,
    );
    return MinSdkDetection(value: fromLocalProps, matchedLabel: null);
  }

  final isKts = gradleFile.path.endsWith('.kts');
  final patterns = isKts ? _ktsMinSdkPatterns : _groovyMinSdkPatterns;
  final content = await gradleFile.readAsString();

  for (final p in patterns) {
    final match = p.regex.firstMatch(content);
    if (match == null) {
      continue;
    }
    if (p.recurseToFlutter) {
      final fromFlutterGradle = await _getMinSdkFromFlutterSdkGradle(
        localPropertiesFile,
      );
      if (fromFlutterGradle != null) {
        return MinSdkDetection(value: fromFlutterGradle, matchedLabel: p.label);
      }
      final fromLocalProps = await _getMinSdkFromLocalProperties(
        localPropertiesFile,
      );
      // Even if the recurse failed to land a value, the pattern *did*
      // match; preserve the label so doctor can report the indirection.
      return MinSdkDetection(value: fromLocalProps, matchedLabel: p.label);
    }
    final captured = match.group(1);
    if (captured == null) {
      continue;
    }
    final parsed = int.tryParse(captured);
    if (parsed != null) {
      return MinSdkDetection(value: parsed, matchedLabel: p.label);
    }
  }

  // No app-level pattern matched. Try local.properties as a last-ditch
  // effort. No `matchedLabel` because no gradle pattern matched.
  final fromLocalProps = await _getMinSdkFromLocalProperties(
    localPropertiesFile,
  );
  return MinSdkDetection(value: fromLocalProps, matchedLabel: null);
}

/// Reads `flutter.minSdkVersion=<int>` (or `flutter.minSdkVersion <int>`) from
/// `local.properties`. Returns `null` if absent or unparseable.
Future<int?> _getMinSdkFromLocalProperties(File file) async {
  if (!file.existsSync()) {
    return null;
  }
  final content = await file.readAsString();
  final match = RegExp(
    r'^\s*flutter\.minSdkVersion\s*[=:]?\s*(\d+)\s*$',
    multiLine: true,
  ).firstMatch(content);
  if (match == null) {
    return null;
  }
  return int.tryParse(match.group(1)!);
}

/// A helper which retrieves the value of `flutter.sdk` from the
/// `local.properties` file.
Future<String?> _getFlutterSdkPathFromLocalProperties(File file) async {
  if (!file.existsSync()) {
    return null;
  }
  final List<String> lines = await file.readAsLines();
  for (String line in lines) {
    if (!line.contains('flutter.sdk=')) {
      continue;
    }
    if (line.contains('#') &&
        line.indexOf('#') < line.indexOf('flutter.sdk=')) {
      continue;
    }
    final flutterSdkPath = line.split('=').last.trim();
    if (flutterSdkPath.isEmpty) {
      return null;
    }
    return flutterSdkPath;
  }
  return null;
}

/// Resolves `flutter.minSdkVersion` by recursing into the Flutter SDK gradle
/// file (`flutter.gradle.kts` first, then `flutter.gradle`).
Future<int?> _getMinSdkFromFlutterSdkGradle(File localPropertiesFile) async {
  final flutterRoot = await _getFlutterSdkPathFromLocalProperties(
    localPropertiesFile,
  );
  if (flutterRoot == null) {
    return null;
  }

  final flutterGradleFile = await _findFlutterSdkGradle(flutterRoot);
  if (flutterGradleFile == null) {
    return null;
  }

  final content = await flutterGradleFile.readAsString();
  final isKts = flutterGradleFile.path.endsWith('.kts');

  // Try the literal-int patterns from both DSLs (we accept `minSdk = N`,
  // `minSdkVersion = N`, `static int minSdkVersion = N`, etc.).
  final patterns = isKts ? _ktsMinSdkPatterns : _groovyMinSdkPatterns;
  for (final p in patterns) {
    if (p.recurseToFlutter) {
      continue;
    }
    final match = p.regex.firstMatch(content);
    if (match == null) {
      continue;
    }
    final captured = match.group(1);
    if (captured == null) {
      continue;
    }
    final parsed = int.tryParse(captured);
    if (parsed != null) {
      return parsed;
    }
  }

  // Legacy: `static int minSdkVersion = 21` (older Groovy flutter.gradle).
  final legacy = RegExp(
    r'static\s+int\s+minSdkVersion\s*=\s*(\d+)',
  ).firstMatch(content);
  if (legacy != null) {
    return int.tryParse(legacy.group(1)!);
  }
  return null;
}

/// Resolves the effective Android `min_sdk_android` for a generation run.
///
/// Resolution order (first non-null wins):
///   1. [explicit] — the user-supplied value from `min_sdk_android` in their
///      config (passed through verbatim).
///   2. [minSdk] — autodetected from `build.gradle[.kts]` /
///      `local.properties` rooted at [prefixPath].
///   3. [constants.androidDefaultAndroidMinSDK] (currently 24). When this
///      branch is taken, a warning is emitted via [logger] using
///      [constants.errorMissingMinSdk] so the user knows autodetection failed.
///
/// Returns the resolved integer. Never returns null.
Future<int> resolveMinSdkAndroid({
  required String prefixPath,
  required FLILogger logger,
  required int? explicit,
}) async {
  if (explicit != null) {
    logger.verbose(
      'Android min_sdk_android: using explicit user value $explicit '
      '(autodetect skipped).',
    );
    return explicit;
  }
  final detected = await minSdk(prefixPath: prefixPath);
  if (detected != null) {
    logger.verbose(
      'Android min_sdk_android: autodetected $detected from gradle.',
    );
    return detected;
  }
  logger.warn(constants.errorMissingMinSdk);
  logger.verbose(
    'Android min_sdk_android: falling back to static default '
    '${constants.androidDefaultAndroidMinSDK}.',
  );
  return constants.androidDefaultAndroidMinSDK;
}

/// Returns true if the adaptive icon configuration is a PNG image
bool isAdaptiveIconConfigPngFile(String backgroundFile) {
  return backgroundFile.endsWith('.png');
}

/// (NOTE THIS IS JUST USED FOR UNIT TEST)
/// Ensures the correct path is used for generating adaptive icons
/// "Next you must create alternative drawable resources in your app for use with
/// Android 8.0 (API level 26) in res/mipmap-anydpi/ic_launcher.xml"
/// Source: https://developer.android.com/guide/practices/ui_guidelines/icon_design_adaptive
bool isCorrectMipmapDirectoryForAdaptiveIcon(String dir) {
  return path.equals(
    path.normalize(dir),
    path.normalize(constants.androidAdaptiveXmlFolder(null)),
  );
}
