// ignore_for_file: public_member_api_docs

import 'package:path/path.dart' as path;

/// Filename of the consolidated multi-flavor config introduced in 0.15.0.
///
/// Top-level layout: `version: 1`, optional `defaults:`, required
/// non-empty `flavors:` map. See plan Phase 3.
const String consolidatedFlavorsFileName =
    'flutter_launcher_icons_flavors.yaml';

/// Filename of the single-config file (used by single-flavor projects).
const String singleConfigFileName = 'flutter_launcher_icons.yaml';

/// Regex matching legacy per-flavor config filenames
/// (`flutter_launcher_icons-<flavor>.yaml`). The captured group is the
/// flavor name.
const String legacyFlavorConfigFilePattern =
    r'^flutter_launcher_icons-(.*)\.yaml$';

/// Regex enforcing valid flavor names: letters/digits start, then
/// letters/digits/underscore/hyphen. Case-sensitive.
const String flavorNamePattern = r'^[A-Za-z0-9][A-Za-z0-9_-]*$';

/// Relative path to android resource folder
String androidResFolder(String? flavor) =>
    path.join('android', 'app', 'src', flavor ?? 'main', 'res');

/// Relative path to android colors.xml file
String androidColorsFile(String? flavor) =>
    path.join(androidResFolder(flavor), 'values', 'colors.xml');

const String androidManifestFile = 'android/app/src/main/AndroidManifest.xml';
const String androidLocalPropertiesFile = 'android/local.properties';

/// Relative app-level gradle file name (Groovy DSL).
const String androidAppGradleGroovy = 'android/app/build.gradle';

/// Relative app-level gradle file name (Kotlin DSL).
const String androidAppGradleKts = 'android/app/build.gradle.kts';

/// Relative path to flutter.gradle from flutter sdk path (Groovy DSL).
const String androidFlutterGradleGroovy =
    'packages/flutter_tools/gradle/flutter.gradle';

/// Relative path to flutter.gradle.kts from flutter sdk path (Kotlin DSL).
const String androidFlutterGradleKts =
    'packages/flutter_tools/gradle/flutter.gradle.kts';

/// BREAKING (0.15.0): bumped from 21 to 24 to match modern Flutter project
/// defaults. See plan §6.9 / Phase 2 §1.2. Users targeting lower API levels
/// must specify `min_sdk_android` explicitly in their config.
const int androidDefaultAndroidMinSDK = 24;
const String androidFileName = 'ic_launcher.png';
const String androidAdaptiveForegroundFileName = 'ic_launcher_foreground.png';
const String androidAdaptiveBackgroundFileName = 'ic_launcher_background.png';
const String androidAdaptiveMonochromeFileName = 'ic_launcher_monochrome.png';

/// Relative path to the android adaptive-icon XML folder
/// (`<res>/mipmap-anydpi-v26`).
String androidAdaptiveXmlFolder(String? flavor) =>
    path.join(androidResFolder(flavor), 'mipmap-anydpi-v26');
const String androidDefaultIconName = 'ic_launcher';

const String iosDefaultIconFolder =
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/';
const String iosAssetFolder = 'ios/Runner/Assets.xcassets/';
const String iosConfigFile = 'ios/Runner.xcodeproj/project.pbxproj';
const String iosDefaultIconName = 'Icon-App';

// web
/// favicon.ico size
const int kFaviconSize = 16;

/// Relative web direcotry path
String webDirPath = path.join('web');

/// Relative web icons directory path
String webIconsDirPath = path.join(webDirPath, 'icons');

/// Relative web manifest.json file path
String webManifestFilePath = path.join(webDirPath, 'manifest.json');
// TODO(RatakondalaArun): support for other images formats
/// Relative favicon.png path
String webFaviconFilePath = path.join(webDirPath, 'favicon.png');

/// Relative index.html file path
String webIndexFilePath = path.join(webDirPath, 'index.html');

/// Relative pubspec.yaml path
String pubspecFilePath = path.join('pubspec.yaml');

// Windows
/// Relative path to windows directory
String windowsDirPath = path.join('windows');

/// Relative path to windows resources directory
String windowsResourcesDirPath = path.join(
  windowsDirPath,
  'runner',
  'resources',
);

/// Relative path to windows icon file path
String windowsIconFilePath = path.join(windowsResourcesDirPath, 'app_icon.ico');

/// Default windows icon size for flutter
///
const int windowsDefaultIconSize = 48;

// MacOS

/// Relative path to macos folder
final macOSDirPath = path.join('macos');

/// Relative path to macos icons folder
final macOSIconsDirPath = path.join(
  macOSDirPath,
  'Runner',
  'Assets.xcassets',
  'AppIcon.appiconset',
);

/// Relative path to macos contents.json
final macOSContentsFilePath = path.join(macOSIconsDirPath, 'Contents.json');

const String errorMissingImagePath =
    'Missing "image_path" or "image_path_android" + "image_path_ios" within configuration';
const String errorMissingPlatform =
    'No platform specified within config to generate icons for.';
const String errorMissingRegularAndroid =
    'Adaptive icon config found but no regular Android config. '
    'Below API 26 the regular Android config is required';
const String errorMissingMinSdk =
    'could not auto-detect min_sdk_android from build.gradle/build.gradle.kts; '
    'specify min_sdk_android in your config';
const String errorIncorrectIconName =
    'The icon name must contain only lowercase a-z, 0-9, or underscore: '
    'E.g. "ic_my_new_icon"';

String introMessage(String currentVersion) =>
    '''
  ════════════════════════════════════════════
     FLUTTER LAUNCHER ICONS (v$currentVersion)                               
  ════════════════════════════════════════════
  ''';
