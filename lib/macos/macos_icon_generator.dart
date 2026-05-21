import 'dart:convert';
import 'dart:io';

import 'package:flutter_launcher_icons_flavors/abs/icon_generator.dart';
import 'package:flutter_launcher_icons_flavors/constants.dart' as constants;
import 'package:flutter_launcher_icons_flavors/macos/macos_icon_template.dart';
import 'package:flutter_launcher_icons_flavors/utils.dart' as utils;
import 'package:image/image.dart';
import 'package:path/path.dart' as path;

/// A [IconGenerator] implementation for macos
class MacOSIconGenerator extends IconGenerator {
  static const _iconSizeTemplates = <MacOSIconTemplate>[
    MacOSIconTemplate(16, 1),
    MacOSIconTemplate(16, 2),
    MacOSIconTemplate(32, 1),
    MacOSIconTemplate(32, 2),
    MacOSIconTemplate(128, 1),
    MacOSIconTemplate(128, 2),
    MacOSIconTemplate(256, 1),
    MacOSIconTemplate(256, 2),
    MacOSIconTemplate(512, 1),
    MacOSIconTemplate(512, 2),
  ];

  /// Creates a instance of [MacOSIconGenerator]
  MacOSIconGenerator(IconGeneratorContext context) : super(context, 'MacOS');

  @override
  bool get isOptedIn => context.macOSConfig?.generate ?? false;

  String get _resolvedIconsDir =>
      constants.macOSIconsDirPathFor(context.flavor);
  String get _resolvedContentsFile =>
      constants.macOSContentsFilePathFor(context.flavor);

  @override
  Future<void> createIcons() async {
    final macOSConfig = context.config.macOSConfig!;
    final imgFilePath = path.join(
      context.prefixPath,
      macOSConfig.imagePath ?? context.config.imagePath,
    );

    context.logger.verbose(
      'Decoding and loading image file at $imgFilePath...',
    );
    var imgFile = await utils.decodeImageFile(imgFilePath);

    // Apple's macOS HIG recommends a transparent border so the visible
    // content is 824x824 inside the 1024x1024 canvas. Opt-in via
    // `macos.padding: true` (upstream #655).
    if (macOSConfig.padding) {
      imgFile = _padToEffectiveDesignArea(imgFile);
    }

    context.logger.verbose('Generating icons $imgFilePath...');
    await _generateIcons(imgFile);

    // Dark / tinted variants (upstream #660). Each gets its own slice
    // pass and contributes appearance-qualified entries to Contents.json.
    Image? darkImage;
    if (macOSConfig.darkImagePath != null) {
      darkImage = await utils.decodeImageFile(
        path.join(context.prefixPath, macOSConfig.darkImagePath!),
      );
      if (macOSConfig.padding) {
        darkImage = _padToEffectiveDesignArea(darkImage);
      }
      await _generateAppearanceIcons(darkImage, '_dark');
    }
    Image? tintedImage;
    if (macOSConfig.tintedImagePath != null) {
      tintedImage = await utils.decodeImageFile(
        path.join(context.prefixPath, macOSConfig.tintedImagePath!),
      );
      if (macOSConfig.padding) {
        tintedImage = _padToEffectiveDesignArea(tintedImage);
      }
      await _generateAppearanceIcons(tintedImage, '_tinted');
    }

    context.logger.verbose('Updating contents.json');
    _updateContentsFile(
      hasDark: darkImage != null,
      hasTinted: tintedImage != null,
    );
  }

  Future<void> _generateAppearanceIcons(Image image, String suffix) async {
    final iconsDir = await utils.createDirIfNotExist(
      path.join(context.prefixPath, _resolvedIconsDir),
    );
    for (final template in _iconSizeTemplates) {
      final resized = utils.createResizedImage(template.scaledSize, image);
      final fileName = template.iconFile.replaceFirst(
        '.png',
        '$suffix.png',
      );
      final iconFile = await utils.createFileIfNotExist(
        path.join(iconsDir.path, fileName),
      );
      await iconFile.writeAsBytes(
        utils.encodePngOptimized(
          resized,
          optimize: context.config.optimizePng,
        ),
      );
    }
  }

  /// Resizes [source] to 824×824 and composites it centered onto a 1024×1024
  /// transparent canvas (upstream #655). Caller decides whether to apply.
  Image _padToEffectiveDesignArea(Image source) {
    final resized = copyResize(
      source,
      width: 824,
      height: 824,
      interpolation: Interpolation.average,
    );
    final canvas = Image(width: 1024, height: 1024, numChannels: 4);
    // Image() initializes to (0,0,0,0); make sure all pixels start transparent.
    for (final px in canvas) {
      px.setRgba(0, 0, 0, 0);
    }
    return compositeImage(
      canvas,
      resized,
      dstX: 100,
      dstY: 100,
    );
  }

  @override
  bool validateRequirements() {
    context.logger.verbose('Checking $platformName config...');
    final macOSConfig = context.macOSConfig;

    if (macOSConfig == null || !macOSConfig.generate) {
      context.logger
        ..verbose(
          '$platformName config is missing or "flutter_icons.macos.generate" is false. Skipped...',
        )
        ..verbose(macOSConfig);
      return false;
    }

    final resolvedImagePath = macOSConfig.imagePath ?? context.config.imagePath;
    if (resolvedImagePath == null) {
      context.logger
        ..verbose({
          'flutter_launcher_icons.macos.image_path': macOSConfig.imagePath,
          'flutter_launcher_icons.image_path': context.config.imagePath,
        })
        ..error(
          'Missing image_path. Either provide "flutter_launcher_icons.macos.image_path" or "flutter_launcher_icons.image_path"',
        );

      return false;
    }

    final imageFullPath = path.join(context.prefixPath, resolvedImagePath);
    if (!File(imageFullPath).existsSync()) {
      context.logger.error('image_path "$imageFullPath" does not exist.');
      return false;
    }

    // The asset-set directory and Contents.json are flavor-aware
    // (upstream #638). The parent `macos/` dir must exist; the asset set
    // and Contents.json are auto-created (`createDirIfNotExist`) when
    // missing — they don't need to be pre-seeded for per-flavor builds.
    final entitiesToCheck = [
      path.join(context.prefixPath, constants.macOSDirPath),
    ];

    final failedEntityPath = utils.areFSEntitiesExist(entitiesToCheck);
    if (failedEntityPath != null) {
      context.logger.error(
        '$failedEntityPath this file or folder is required to generate $platformName icons',
      );
      return false;
    }

    return true;
  }

  Future<void> _generateIcons(Image image) async {
    final iconsDir = await utils.createDirIfNotExist(
      path.join(context.prefixPath, _resolvedIconsDir),
    );

    for (final template in _iconSizeTemplates) {
      final resizedImg = utils.createResizedImage(template.scaledSize, image);
      final iconFile = await utils.createFileIfNotExist(
        path.join(iconsDir.path, template.iconFile),
      );
      await iconFile.writeAsBytes(
        utils.encodePngOptimized(
          resizedImg,
          optimize: context.config.optimizePng,
        ),
      );
    }
  }

  void _updateContentsFile({bool hasDark = false, bool hasTinted = false}) {
    final contentsFilePath = File(
      path.join(context.prefixPath, _resolvedContentsFile),
    );
    // Self-check (upstream #532): if Contents.json doesn't exist yet for
    // this flavor, seed it with a minimal stub so the rest of the writer
    // can update it without crashing on read.
    if (!contentsFilePath.existsSync()) {
      contentsFilePath.createSync(recursive: true);
      contentsFilePath.writeAsStringSync(
        '{"images":[],"info":{"version":1,"author":"xcode"}}',
      );
    }
    final contentsConfig =
        jsonDecode(contentsFilePath.readAsStringSync()) as Map<String, dynamic>;
    final images = <Map<String, dynamic>>[];
    for (final t in _iconSizeTemplates) {
      images.add(t.iconContent);
      if (hasDark) {
        images.add(_appearanceEntry(t, 'dark', '_dark'));
      }
      if (hasTinted) {
        images.add(_appearanceEntry(t, 'tinted', '_tinted'));
      }
    }
    contentsConfig
      ..remove('images')
      ..['images'] = images;

    contentsFilePath.writeAsStringSync(
      utils.prettifyJsonEncode(contentsConfig),
    );
  }

  /// Builds an `images[]` entry with a `luminosity` appearance qualifier
  /// (upstream #660). Filename is the base template's filename with [suffix]
  /// inserted before the `.png` extension.
  Map<String, dynamic> _appearanceEntry(
    MacOSIconTemplate t,
    String value,
    String suffix,
  ) {
    final base = Map<String, dynamic>.from(t.iconContent);
    base['filename'] = (base['filename'] as String).replaceFirst(
      '.png',
      '$suffix.png',
    );
    base['appearances'] = [
      <String, dynamic>{'appearance': 'luminosity', 'value': value},
    ];
    return base;
  }
}
