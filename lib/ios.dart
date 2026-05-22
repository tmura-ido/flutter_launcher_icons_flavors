// ignore_for_file: public_member_api_docs

import 'dart:convert';
import 'dart:io';

import 'package:flutter_launcher_icons_flavors/config/config.dart';
import 'package:flutter_launcher_icons_flavors/constants.dart';
import 'package:flutter_launcher_icons_flavors/custom_exceptions.dart';
import 'package:flutter_launcher_icons_flavors/logger.dart';
import 'package:flutter_launcher_icons_flavors/utils.dart';
import 'package:flutter_launcher_icons_flavors/utils/color_utils.dart';
import 'package:image/image.dart' hide decodeImageFile;
import 'package:path/path.dart' as path;

/// File to handle the creation of icons for iOS platform
class IosIconTemplate {
  /// constructs an instance of [IosIconTemplate]
  IosIconTemplate({required this.size, required this.name});

  /// suffix of the icon name
  final String name;

  /// the size of the icon
  final int size;
}

/// details of the ios icons which need to be generated
List<IosIconTemplate> legacyIosIcons = <IosIconTemplate>[
  IosIconTemplate(name: '-20x20@1x', size: 20),
  IosIconTemplate(name: '-20x20@2x', size: 40),
  IosIconTemplate(name: '-20x20@3x', size: 60),
  IosIconTemplate(name: '-29x29@1x', size: 29),
  IosIconTemplate(name: '-29x29@2x', size: 58),
  IosIconTemplate(name: '-29x29@3x', size: 87),
  IosIconTemplate(name: '-40x40@1x', size: 40),
  IosIconTemplate(name: '-40x40@2x', size: 80),
  IosIconTemplate(name: '-40x40@3x', size: 120),
  IosIconTemplate(name: '-50x50@1x', size: 50),
  IosIconTemplate(name: '-50x50@2x', size: 100),
  IosIconTemplate(name: '-57x57@1x', size: 57),
  IosIconTemplate(name: '-57x57@2x', size: 114),
  IosIconTemplate(name: '-60x60@2x', size: 120),
  IosIconTemplate(name: '-60x60@3x', size: 180),
  IosIconTemplate(name: '-72x72@1x', size: 72),
  IosIconTemplate(name: '-72x72@2x', size: 144),
  IosIconTemplate(name: '-76x76@1x', size: 76),
  IosIconTemplate(name: '-76x76@2x', size: 152),
  IosIconTemplate(name: '-83.5x83.5@2x', size: 167),
  IosIconTemplate(name: '-1024x1024@1x', size: 1024),
];

List<IosIconTemplate> iosIcons = <IosIconTemplate>[
  IosIconTemplate(name: '-20x20@2x', size: 40),
  IosIconTemplate(name: '-20x20@3x', size: 60),
  IosIconTemplate(name: '-29x29@2x', size: 58),
  IosIconTemplate(name: '-29x29@3x', size: 87),
  IosIconTemplate(name: '-38x38@2x', size: 76),
  IosIconTemplate(name: '-38x38@3x', size: 114),
  IosIconTemplate(name: '-40x40@2x', size: 80),
  IosIconTemplate(name: '-40x40@3x', size: 120),
  IosIconTemplate(name: '-60x60@2x', size: 120),
  IosIconTemplate(name: '-60x60@3x', size: 180),
  IosIconTemplate(name: '-64x64@2x', size: 128),
  IosIconTemplate(name: '-64x64@3x', size: 192),
  IosIconTemplate(name: '-68x68@2x', size: 136),
  IosIconTemplate(name: '-76x76@2x', size: 152),
  IosIconTemplate(name: '-83.5x83.5@2x', size: 167),
  IosIconTemplate(name: '-1024x1024@1x', size: 1024),
];

/// create the ios icons
Future<void> createIcons(
  Config config,
  String? flavor, {
  required FLILogger logger,
  String prefixPath = '.',
}) async {
  final String? relativeFilePath = config.getImagePathIOS();
  final String? darkRelativeFilePath = config.imagePathIOSDarkTransparent;
  final String? tintedRelativeFilePath = config.imagePathIOSTintedGrayscale;

  if (relativeFilePath == null) {
    throw const InvalidConfigException(errorMissingImagePath);
  }

  final String filePath = path.join(prefixPath, relativeFilePath);
  final String? darkFilePath = darkRelativeFilePath == null
      ? null
      : path.join(prefixPath, darkRelativeFilePath);
  final String? tintedFilePath = tintedRelativeFilePath == null
      ? null
      : path.join(prefixPath, tintedRelativeFilePath);

  // decodeImageFile throws if the file's format is unrecognized.
  Image image = await decodeImageFile(filePath);

  // For dark and tinted images, decode if path was specified.
  Image? darkImage;
  if (darkFilePath != null) {
    darkImage = await decodeImageFile(darkFilePath);
  }

  Image? tintedImage;
  if (tintedFilePath != null) {
    tintedImage = await decodeImageFile(tintedFilePath);
    if (config.desaturateTintedToGrayscaleIOS) {
      logger.info('Desaturating iOS tinted image to grayscale');
      tintedImage = grayscale(tintedImage);
    } else {
      // Check if the image is already grayscale
      final pixel = tintedImage.getPixel(0, 0);
      do {
        if (pixel.r != pixel.g || pixel.g != pixel.b) {
          logger.warn(
            'Tinted iOS image is not grayscale. '
            'Set "desaturate_tinted_to_grayscale_ios: true" to desaturate it.',
          );
          break;
        }
      } while (pixel.moveNext());
    }
  }

  // Letter-box non-square sources once with the resolved iOS background
  // color so every generated template size preserves the source's aspect
  // ratio instead of being squished (upstream #214). No-op when the source
  // is already square. Dark / tinted variants are intentionally letter-
  // boxed too — iOS still expects the same canvas geometry per template
  // slot — but they keep their transparency below (see comment on the
  // remove-alpha block).
  final iosBackgroundColor = _getBackgroundColor(config);
  image = letterBoxToSquare(image, iosBackgroundColor);
  if (darkImage != null) {
    darkImage = letterBoxToSquare(darkImage, iosBackgroundColor);
  }
  if (tintedImage != null) {
    tintedImage = letterBoxToSquare(tintedImage, iosBackgroundColor);
  }

  // remove_alpha_ios is applied AFTER letter-boxing so that any
  // translucent or fully-transparent bars introduced by the letter-box
  // step (e.g. when `background_color: "#00FFFFFF"`) are also alpha-
  // blended and stripped. Doing it the other way around (the previous
  // order) left those bars transparent in the final PNG and got the
  // App Store marketing icon rejected. Dark / tinted variants are
  // intentionally left transparent — iOS composites them over the
  // system background.
  if (config.removeAlphaIOS && image.hasAlpha) {
    var backgroundColor = _getBackgroundColor(config);
    // if the background color has an alpha value less than 255, we need to blend it with white before removing the alpha channel
    if (backgroundColor.a != 255) {
      backgroundColor = ColorUtils.makeOpaque(
        backgroundColor,
        background: _hexToColor(Config.defaultBackgroundColorIOS),
      );
    }
    final pixel = image.getPixel(0, 0);
    do {
      pixel.set(_alphaBlend(pixel, backgroundColor));
    } while (pixel.moveNext());

    image = image.convert(numChannels: 3);
  }
  if (image.hasAlpha) {
    logger.warn(
      'Icons with alpha channel are not allowed in the Apple App Store. '
      'Set "remove_alpha_ios: true" to remove it.',
    );
  }
  String iconName;
  String? darkIconName;
  String? tintedIconName;
  // Resolve the iOS template list:
  // * `ios_single_size: true` → only the 1024 marketing slot (Xcode 14+
  //   "single size" mode, upstream #592). Overrides every other flag.
  // * `ios_legacy_sizes: true` → union of legacy + modern, so the app
  //   switcher's 1x assets are present (upstream #661).
  // * Otherwise: legacy when no dark/tinted; modern when dark/tinted set.
  final List<IosIconTemplate> generateIosIcons;
  if (config.iosSingleSize) {
    // Marketing slot only.
    generateIosIcons = [IosIconTemplate(name: '-1024x1024@1x', size: 1024)];
  } else if (config.iosLegacySizes) {
    final seen = <String>{};
    final union = <IosIconTemplate>[];
    for (final t in [...legacyIosIcons, ...iosIcons]) {
      if (seen.add(t.name)) union.add(t);
    }
    generateIosIcons = union;
  } else {
    generateIosIcons = (darkImage == null && tintedImage == null)
        ? legacyIosIcons
        : iosIcons;
  }
  final concurrentIconUpdates = <Future<void>>[];
  if (flavor != null) {
    final String catalogName = 'AppIcon-$flavor';

    logger.info('Building iOS launcher icon for $flavor');
    for (IosIconTemplate template in generateIosIcons) {
      concurrentIconUpdates.add(
        saveNewIcons(
          template: template,
          image: image,
          catalogName: catalogName,
          // Since this is the base icon name we are using the same name for the icon as the catalog name
          iconName: catalogName,
          prefixPath: prefixPath,
        ),
      );
    }

    if (darkImage != null) {
      darkIconName = 'AppIcon-$flavor-Dark';
      logger.info('Building iOS dark launcher icon for $flavor');
      for (IosIconTemplate template in generateIosIcons) {
        concurrentIconUpdates.add(
          saveNewIcons(
            template: template,
            image: darkImage,
            catalogName: catalogName,
            iconName: darkIconName,
            prefixPath: prefixPath,
          ),
        );
      }
    }
    if (tintedImage != null) {
      tintedIconName = 'AppIcon-$flavor-Tinted';
      logger.info('Building iOS tinted launcher icon for $flavor');
      for (IosIconTemplate template in generateIosIcons) {
        concurrentIconUpdates.add(
          saveNewIcons(
            template: template,
            image: tintedImage,
            catalogName: catalogName,
            iconName: tintedIconName,
            prefixPath: prefixPath,
          ),
        );
      }
    }
    iconName = iosDefaultIconName;
    await changeIosLauncherIcon(
      catalogName,
      flavor,
      prefixPath: prefixPath,
      xcodeprojPath: config.xcodeprojPath,
      logger: logger,
    );
    await modifyContentsFile(
      catalogName,
      darkIconName,
      tintedIconName,
      prefixPath: prefixPath,
    );
  } else if (config.isCustomIOSFile) {
    // If the IOS configuration is a string then the user has specified a new icon to be created
    // and for the old icon file to be kept
    final String newIconName = config.iosIconName;
    logger.info('Adding new iOS launcher icon');
    for (IosIconTemplate template in generateIosIcons) {
      concurrentIconUpdates.add(
        saveNewIcons(
          template: template,
          image: image,
          catalogName: 'AppIcon',
          iconName: newIconName,
          prefixPath: prefixPath,
        ),
      );
    }
    if (darkImage != null) {
      darkIconName = '$newIconName-Dark';
      logger.info('Adding new iOS dark launcher icon');
      for (IosIconTemplate template in generateIosIcons) {
        concurrentIconUpdates.add(
          saveNewIcons(
            template: template,
            image: darkImage,
            catalogName: 'AppIcon',
            iconName: darkIconName,
            prefixPath: prefixPath,
          ),
        );
      }
    }
    if (tintedImage != null) {
      tintedIconName = '$newIconName-Tinted';
      logger.info('Adding new iOS tinted launcher icon');
      for (IosIconTemplate template in generateIosIcons) {
        concurrentIconUpdates.add(
          saveNewIcons(
            template: template,
            image: tintedImage,
            catalogName: 'AppIcon',
            iconName: tintedIconName,
            prefixPath: prefixPath,
          ),
        );
      }
    }
    iconName = newIconName;
    await changeIosLauncherIcon(
      iconName,
      flavor,
      prefixPath: prefixPath,
      xcodeprojPath: config.xcodeprojPath,
      logger: logger,
    );
    await modifyContentsFile(
      iconName,
      darkIconName,
      tintedIconName,
      prefixPath: prefixPath,
    );
  }
  // Otherwise the user wants the new icon to use the default icons name and
  // update config file to use it
  else {
    logger.info('Overwriting default iOS launcher icon with new icon');
    for (IosIconTemplate template in generateIosIcons) {
      concurrentIconUpdates.add(
        overwriteDefaultIcons(template, image, '', prefixPath),
      );
    }
    if (darkImage != null) {
      logger.info('Overwriting default iOS dark launcher icon with new icon');
      for (IosIconTemplate template in generateIosIcons) {
        concurrentIconUpdates.add(
          overwriteDefaultIcons(template, darkImage, '-Dark', prefixPath),
        );
      }
      darkIconName = '$iosDefaultIconName-Dark';
    }
    if (tintedImage != null) {
      logger.info('Overwriting default iOS tinted launcher icon with new icon');
      for (IosIconTemplate template in generateIosIcons) {
        concurrentIconUpdates.add(
          overwriteDefaultIcons(template, tintedImage, '-Tinted', prefixPath),
        );
      }
      tintedIconName = '$iosDefaultIconName-Tinted';
    }
    iconName = iosDefaultIconName;
    await changeIosLauncherIcon(
      'AppIcon',
      flavor,
      prefixPath: prefixPath,
      xcodeprojPath: config.xcodeprojPath,
      logger: logger,
    );
    // Still need to modify the Contents.json file
    // since the user could have added dark and tinted icons
    await modifyDefaultContentsFile(
      iconName,
      darkIconName,
      tintedIconName,
      prefixPath: prefixPath,
    );
  }
  await Future.wait(concurrentIconUpdates);
}

/// Note: Do not change interpolation unless you end up with better results (see issue for result when using cubic
/// interpolation)
/// https://github.com/fluttercommunity/flutter_launcher_icons/issues/101#issuecomment-495528733
Future<void> overwriteDefaultIcons(
  IosIconTemplate template,
  Image image, [
  String iconNameSuffix = '',
  String prefixPath = '.',
]) async {
  final dir = Directory(path.join(prefixPath, iosDefaultIconFolder));
  if (!dir.existsSync()) {
    // Friendly error replacing the previous opaque `FileSystemException`
    // when the default `AppIcon.appiconset/` directory is missing
    // (upstream #161).
    throw InvalidConfigException(
      'Expected iOS asset catalog at ${dir.path} but the directory was '
      'not found. Run `flutter create .` in the project root to '
      'regenerate the iOS asset catalog, then re-run.',
    );
  }
  final Image newImage = createResizedImage(template, image);
  await File(
    path.join(
      prefixPath,
      iosDefaultIconFolder,
      '$iosDefaultIconName$iconNameSuffix${template.name}.png',
    ),
  ).writeAsBytes(encodePng(newImage));
}

/// Note: Do not change interpolation unless you end up with better results (see issue for result when using cubic
/// interpolation)
/// https://github.com/fluttercommunity/flutter_launcher_icons/issues/101#issuecomment-495528733
Future<void> saveNewIcons({
  required IosIconTemplate template,
  required Image image,
  required String catalogName,
  required String iconName,
  String prefixPath = '.',
}) async {
  final String newIconFolder = path.join(
    prefixPath,
    iosAssetFolder,
    '$catalogName.appiconset',
  );
  final Image newImage = createResizedImage(template, image);
  final newFile = await File(
    path.join(newIconFolder, '$iconName${template.name}.png'),
  ).create(recursive: true);
  await newFile.writeAsBytes(encodePng(newImage));
}

/// create resized icon image
Image createResizedImage(IosIconTemplate template, Image image) {
  if (image.width >= template.size) {
    return copyResize(
      image,
      width: template.size,
      height: template.size,
      interpolation: Interpolation.average,
    );
  } else {
    return copyResize(
      image,
      width: template.size,
      height: template.size,
      interpolation: Interpolation.linear,
    );
  }
}

/// Resolves the iOS `project.pbxproj` path honoring (in order):
/// 1. explicit `xcodeproj_path` config override (upstream #637),
/// 2. auto-detect by globbing `ios/*.xcodeproj` (upstream #543),
/// 3. fall back to `ios/Runner.xcodeproj/project.pbxproj`.
///
/// Throws an [InvalidConfigException] when multiple `*.xcodeproj` dirs
/// exist and no explicit override was given.
String resolveIosPbxprojPath({required String prefixPath, String? explicit}) {
  if (explicit != null && explicit.isNotEmpty) {
    // Accept either a directory (`ios/MyApp.xcodeproj`) or a full file
    // path; if directory, append `project.pbxproj`.
    if (explicit.endsWith('project.pbxproj')) {
      return explicit;
    }
    return path.join(explicit, 'project.pbxproj');
  }
  final iosDir = Directory(path.join(prefixPath, 'ios'));
  if (iosDir.existsSync()) {
    final candidates = iosDir
        .listSync()
        .whereType<Directory>()
        .where((d) => d.path.endsWith('.xcodeproj'))
        .toList();
    if (candidates.length == 1) {
      return path.join(
        'ios',
        path.basename(candidates.single.path),
        'project.pbxproj',
      );
    }
    if (candidates.length > 1) {
      final names = candidates.map((d) => path.basename(d.path)).toList()
        ..sort();
      throw InvalidConfigException(
        'Multiple .xcodeproj directories found under ios/: '
        '${names.join(', ')}. Set `xcodeproj_path` explicitly to '
        'disambiguate.',
      );
    }
  }
  return iosConfigFile;
}

/// Change the iOS launcher icon
Future<void> changeIosLauncherIcon(
  String iconName,
  String? flavor, {
  String prefixPath = '.',
  String? xcodeprojPath,
  FLILogger? logger,
}) async {
  final resolved = resolveIosPbxprojPath(
    prefixPath: prefixPath,
    explicit: xcodeprojPath,
  );
  final File iOSConfigFile = File(path.join(prefixPath, resolved));
  final List<String> lines;
  try {
    lines = await iOSConfigFile.readAsLines();
  } on FileSystemException catch (e) {
    // Windows file-lock guard: if another process (typically Xcode) has
    // the pbxproj open, opening for read/write fails with errno 1224
    // ("user-mapped section open"). On *nix the EBUSY / EACCES cases land
    // here too. The pbxproj update is non-critical to icon emission —
    // warn and skip rather than fail the whole run.
    final isLocked =
        e.osError?.errorCode == 1224 ||
        e.osError?.errorCode == 16 || // EBUSY
        e.osError?.errorCode == 13; // EACCES
    if (isLocked) {
      (logger ?? FLILogger(false)).warn(
        'iOS pbxproj is locked by another process (likely Xcode): '
        '${iOSConfigFile.path}. Skipping the AppIcon-name update. Close '
        'Xcode and re-run to update the pbxproj.',
      );
      return;
    }
    rethrow;
  }

  bool onConfigurationSection = false;
  String? currentConfig;

  for (int x = 0; x < lines.length; x++) {
    final String line = lines[x];
    if (line.contains('/* Begin XCBuildConfiguration section */')) {
      onConfigurationSection = true;
    }
    if (line.contains('/* End XCBuildConfiguration section */')) {
      onConfigurationSection = false;
    }
    if (onConfigurationSection) {
      final match = RegExp('.*/\\* (.*).xcconfig \\*/;').firstMatch(line);
      if (match != null) {
        currentConfig = match.group(1);
      }

      // Anchor the flavor match on a delimiter so `style1` does not also
      // match `-style10.xcconfig` (upstream #612). The flavor token must
      // either end the string, or be followed by a non-word character
      // (typically `.`, `-`, or `/`).
      bool flavorMatches() {
        if (flavor == null) return true;
        final cc = currentConfig!;
        final marker = '-$flavor';
        final idx = cc.indexOf(marker);
        if (idx < 0) return false;
        final end = idx + marker.length;
        if (end == cc.length) return true;
        final next = cc.codeUnitAt(end);
        // Word characters [0-9A-Za-z_] are NOT acceptable boundaries.
        final isWord =
            (next >= 0x30 && next <= 0x39) || // 0-9
            (next >= 0x41 && next <= 0x5A) || // A-Z
            (next >= 0x61 && next <= 0x7A) || // a-z
            next == 0x5F; // _
        return !isWord;
      }

      if (currentConfig != null &&
          flavorMatches() &&
          line.contains('ASSETCATALOG_COMPILER_APPICON_NAME')) {
        lines[x] = line.replaceAll(RegExp('=(.*);'), '= $iconName;');
      }
    }
  }

  final String entireFile = '${lines.join('\n')}\n';
  try {
    await iOSConfigFile.writeAsString(entireFile);
  } on FileSystemException catch (e) {
    final isLocked =
        e.osError?.errorCode == 1224 ||
        e.osError?.errorCode == 16 || // EBUSY
        e.osError?.errorCode == 13; // EACCES
    if (isLocked) {
      (logger ?? FLILogger(false)).warn(
        'iOS pbxproj is locked by another process (likely Xcode): '
        '${iOSConfigFile.path}. Skipping the AppIcon-name update. Close '
        'Xcode and re-run to update the pbxproj.',
      );
      return;
    }
    rethrow;
  }
}

/// Create the Contents.json file
Future<void> modifyContentsFile(
  String newIconName,
  String? darkIconName,
  String? tintedIconName, {
  String prefixPath = '.',
}) async {
  final String newContentsFilename = path.join(
    prefixPath,
    iosAssetFolder,
    '$newIconName.appiconset',
    'Contents.json',
  );
  final contentsJsonFile = await File(
    newContentsFilename,
  ).create(recursive: true);
  final String contentsFileContent = generateContentsFileAsString(
    newIconName,
    darkIconName,
    tintedIconName,
  );
  await contentsJsonFile.writeAsString(contentsFileContent);
}

/// Modify default Contents.json file
Future<void> modifyDefaultContentsFile(
  String newIconName,
  String? darkIconName,
  String? tintedIconName, {
  String prefixPath = '.',
}) async {
  final String newIconFolder = path.join(
    prefixPath,
    iosAssetFolder,
    'AppIcon.appiconset',
    'Contents.json',
  );
  final contentsJsonFile = await File(newIconFolder).create(recursive: true);
  final String contentsFileContent = generateContentsFileAsString(
    newIconName,
    darkIconName,
    tintedIconName,
  );
  await contentsJsonFile.writeAsString(contentsFileContent);
}

String generateContentsFileAsString(
  String newIconName,
  String? darkIconName,
  String? tintedIconName,
) {
  final List<Map<String, dynamic>> imageList;
  if (darkIconName == null && tintedIconName == null) {
    imageList = createLegacyImageList(newIconName);
  } else {
    imageList = createImageList(newIconName, darkIconName, tintedIconName);
  }
  final Map<String, dynamic> contentJson = <String, dynamic>{
    'images': imageList,
    'info': ContentsInfoObject(version: 1, author: 'xcode').toJson(),
  };
  return json.encode(contentJson);
}

class ContentsImageAppearanceObject {
  ContentsImageAppearanceObject({
    required this.appearance,
    required this.value,
  });

  final String appearance;
  final String value;

  Map<String, String> toJson() {
    return <String, String>{'appearance': appearance, 'value': value};
  }
}

class ContentsImageObject {
  ContentsImageObject({
    required this.size,
    required this.idiom,
    required this.filename,
    required this.scale,
    this.platform,
    this.appearances,
  });

  final String size;
  final String idiom;
  final String filename;
  final String scale;
  final String? platform;
  final List<ContentsImageAppearanceObject>? appearances;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'size': size,
      'idiom': idiom,
      'filename': filename,
      'scale': scale,
      if (platform != null) 'platform': platform,
      if (appearances != null)
        'appearances': appearances!.map((e) => e.toJson()).toList(),
    };
  }
}

class ContentsInfoObject {
  ContentsInfoObject({required this.version, required this.author});

  final int version;
  final String author;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'version': version, 'author': author};
  }
}

/// Create the image list for the Contents.json file for Xcode versions below Xcode 14
List<Map<String, dynamic>> createLegacyImageList(String fileNamePrefix) {
  const List<Map<String, dynamic>> imageConfigurations = [
    {
      'size': '20x20',
      'idiom': 'iphone',
      'scales': ['2x', '3x'],
    },
    {
      'size': '29x29',
      'idiom': 'iphone',
      'scales': ['1x', '2x', '3x'],
    },
    {
      'size': '40x40',
      'idiom': 'iphone',
      'scales': ['2x', '3x'],
    },
    {
      'size': '57x57',
      'idiom': 'iphone',
      'scales': ['1x', '2x'],
    },
    {
      'size': '60x60',
      'idiom': 'iphone',
      'scales': ['2x', '3x'],
    },
    {
      'size': '20x20',
      'idiom': 'ipad',
      'scales': ['1x', '2x'],
    },
    {
      'size': '29x29',
      'idiom': 'ipad',
      'scales': ['1x', '2x'],
    },
    {
      'size': '40x40',
      'idiom': 'ipad',
      'scales': ['1x', '2x'],
    },
    {
      'size': '50x50',
      'idiom': 'ipad',
      'scales': ['1x', '2x'],
    },
    {
      'size': '72x72',
      'idiom': 'ipad',
      'scales': ['1x', '2x'],
    },
    {
      'size': '76x76',
      'idiom': 'ipad',
      'scales': ['1x', '2x'],
    },
    {
      'size': '83.5x83.5',
      'idiom': 'ipad',
      'scales': ['2x'],
    },
    {
      'size': '1024x1024',
      'idiom': 'ios-marketing',
      'scales': ['1x'],
    },
  ];

  final List<Map<String, dynamic>> imageList = <Map<String, dynamic>>[];

  for (final config in imageConfigurations) {
    final size = config['size']!;
    final idiom = config['idiom']!;
    final List<String> scales = config['scales'];

    for (final scale in scales) {
      final filename = '$fileNamePrefix-$size@$scale.png';
      imageList.add(
        ContentsImageObject(
          size: size,
          idiom: idiom,
          filename: filename,
          scale: scale,
        ).toJson(),
      );
    }
  }

  return imageList;
}

/// Create the image list for the Contents.json file for Xcode versions Xcode 14 and above
List<Map<String, dynamic>> createImageList(
  String fileNamePrefix,
  String? darkFileNamePrefix,
  String? tintedFileNamePrefix,
) {
  const List<Map<String, dynamic>> imageConfigurations = [
    {
      'size': '20x20',
      'idiom': 'universal',
      'platform': 'ios',
      'scales': ['2x', '3x'],
    },
    {
      'size': '29x29',
      'idiom': 'universal',
      'platform': 'ios',
      'scales': ['2x', '3x'],
    },
    {
      'size': '38x38',
      'idiom': 'universal',
      'platform': 'ios',
      'scales': ['2x', '3x'],
    },
    {
      'size': '40x40',
      'idiom': 'universal',
      'platform': 'ios',
      'scales': ['2x', '3x'],
    },
    {
      'size': '60x60',
      'idiom': 'universal',
      'platform': 'ios',
      'scales': ['2x', '3x'],
    },
    {
      'size': '64x64',
      'idiom': 'universal',
      'platform': 'ios',
      'scales': ['2x', '3x'],
    },
    {
      'size': '68x68',
      'idiom': 'universal',
      'platform': 'ios',
      'scales': ['2x'],
    },
    {
      'size': '76x76',
      'idiom': 'universal',
      'platform': 'ios',
      'scales': ['2x'],
    },
    {
      'size': '83.5x83.5',
      'idiom': 'universal',
      'platform': 'ios',
      'scales': ['2x'],
    },
    {
      'size': '1024x1024',
      'idiom': 'universal',
      'platform': 'ios',
      'scales': ['1x'],
    },
    {
      'size': '1024x1024',
      'idiom': 'ios-marketing',
      'scales': ['1x'],
    },
  ];

  final List<Map<String, dynamic>> imageList = <Map<String, dynamic>>[];

  for (final config in imageConfigurations) {
    final size = config['size']!;
    final idiom = config['idiom']!;
    final platform = config['platform'];
    final List<String> scales = config['scales'];

    for (final scale in scales) {
      final filename = '$fileNamePrefix-$size@$scale.png';
      imageList.add(
        ContentsImageObject(
          size: size,
          idiom: idiom,
          filename: filename,
          platform: platform,
          scale: scale,
        ).toJson(),
      );
    }
  }

  // Prevent ios-marketing icon from being tinted or dark

  if (darkFileNamePrefix != null) {
    for (final config in imageConfigurations.where(
      (e) => e['idiom'] == 'universal',
    )) {
      final size = config['size']!;
      final idiom = config['idiom']!;
      final platform = config['platform'];
      final List<String> scales = config['scales'];

      for (final scale in scales) {
        final filename = '$darkFileNamePrefix-$size@$scale.png';
        imageList.add(
          ContentsImageObject(
            size: size,
            idiom: idiom,
            filename: filename,
            platform: platform,
            scale: scale,
            appearances: <ContentsImageAppearanceObject>[
              ContentsImageAppearanceObject(
                appearance: 'luminosity',
                value: 'dark',
              ),
            ],
          ).toJson(),
        );
      }
    }
  }

  if (tintedFileNamePrefix != null) {
    for (final config in imageConfigurations.where(
      (e) => e['idiom'] == 'universal',
    )) {
      final size = config['size']!;
      final idiom = config['idiom']!;
      final platform = config['platform'];
      final List<String> scales = config['scales'];

      for (final scale in scales) {
        final filename = '$tintedFileNamePrefix-$size@$scale.png';
        imageList.add(
          ContentsImageObject(
            size: size,
            idiom: idiom,
            filename: filename,
            platform: platform,
            scale: scale,
            appearances: <ContentsImageAppearanceObject>[
              ContentsImageAppearanceObject(
                appearance: 'luminosity',
                value: 'tinted',
              ),
            ],
          ).toJson(),
        );
      }
    }
  }

  return imageList;
}

/// Returns the resolved iOS alpha-flatten hex color string. Useful for
/// tests/doctor that want the literal hex value without decoding to a
/// `Color` (upstream #432).
String resolveIosAlphaFlattenHex(Config config) {
  final explicit = config.backgroundColorIOS;
  if (_isHexColorLiteral(explicit) &&
      explicit.toLowerCase() != Config.defaultBackgroundColorIOS) {
    return explicit;
  }
  final adaptive = config.adaptiveIconBackground;
  if (adaptive != null && _isHexColorLiteral(adaptive)) {
    return adaptive;
  }
  return Config.defaultBackgroundColorIOS;
}

/// Resolves the fill color used by the iOS alpha-flatten path. Precedence
/// (upstream #432):
///   1. `background_color_ios` if explicitly set (non-default),
///   2. `adaptive_icon_background` if a hex literal (not a file path),
///   3. white (`#FFFFFF`) as the final fallback.
///
/// White is the less-surprising default for App Store-bound icons.
ColorUint8 _getBackgroundColor(Config config) {
  final explicit = config.backgroundColorIOS;
  if (_isHexColorLiteral(explicit) &&
      explicit.toLowerCase() != Config.defaultBackgroundColorIOS) {
    return _hexToColor(explicit);
  }
  final adaptive = config.adaptiveIconBackground;
  if (adaptive != null && _isHexColorLiteral(adaptive)) {
    return _hexToColor(adaptive);
  }
  return _hexToColor(Config.defaultBackgroundColorIOS);
}

bool _isHexColorLiteral(String value) =>
    RegExp(r'^#?[0-9A-Fa-f]{3,8}$').hasMatch(value);

ColorUint8 _hexToColor(String value) => parseHexColor(value);

Color _alphaBlend(Color fg, ColorUint8 bg) {
  if (fg.format != Format.uint8) {
    fg = fg.convert(format: Format.uint8);
  }
  if (fg.a == 0) {
    return bg;
  } else {
    final invAlpha = 0xff - fg.a;
    return ColorUint8.rgba(
      (fg.a * fg.r + invAlpha * bg.r) ~/ 0xff,
      (fg.a * fg.g + invAlpha * bg.g) ~/ 0xff,
      (fg.a * fg.b + invAlpha * bg.b) ~/ 0xff,
      0xff,
    );
  }
}
