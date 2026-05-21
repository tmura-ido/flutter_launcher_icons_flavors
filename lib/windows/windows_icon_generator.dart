import 'package:flutter_launcher_icons_flavors/abs/icon_generator.dart';
import 'package:flutter_launcher_icons_flavors/constants.dart' as constants;
import 'package:flutter_launcher_icons_flavors/utils.dart' as utils;
import 'package:image/image.dart';
import 'package:path/path.dart' as path;

/// A Implementation of [IconGenerator] for Windows
class WindowsIconGenerator extends IconGenerator {
  /// Creates a instance of [WindowsIconGenerator]
  WindowsIconGenerator(IconGeneratorContext context)
    : super(context, 'Windows');

  @override
  bool get isOptedIn => context.windowsConfig?.generate ?? false;

  @override
  Future<void> createIcons() async {
    final imgFilePath = path.join(
      context.prefixPath,
      context.windowsConfig!.imagePath ?? context.config.imagePath,
    );

    context.logger.verbose(
      'Decoding and loading image file from $imgFilePath...',
    );
    final imgFile = await utils.decodeImageFile(imgFilePath);

    context.logger.verbose('Generating icon from $imgFilePath...');
    await _generateIcon(imgFile);
  }

  @override
  bool validateRequirements() {
    context.logger.verbose('Validating windows config...');
    final windowsConfig = context.windowsConfig;
    if (windowsConfig == null || !windowsConfig.generate) {
      context.logger.verbose(
        'Windows config is not provided or windows.generate is false. Skipped...',
      );
      return false;
    }

    if (windowsConfig.imagePath == null && context.config.imagePath == null) {
      context.logger.error(
        'Invalid config. Either provide windows.image_path or image_path',
      );
      return false;
    }

    // if icon_size is given it should be between 48<=icon_size<=256
    // because .ico only supports this size
    if (windowsConfig.iconSize != null &&
        (windowsConfig.iconSize! < 48 || windowsConfig.iconSize! > 256)) {
      context.logger.error(
        'Invalid windows.icon_size=${windowsConfig.iconSize}. Icon size should be between 48<=icon_size<=256',
      );
      return false;
    }
    final entitiesToCheck = [
      path.join(context.prefixPath, constants.windowsDirPath),
      path.join(
        context.prefixPath,
        windowsConfig.imagePath ?? context.config.imagePath,
      ),
    ];

    final failedEntityPath = utils.areFSEntitiesExist(entitiesToCheck);
    if (failedEntityPath != null) {
      context.logger.error(
        '$failedEntityPath this file or folder is required to generate windows icons',
      );
      return false;
    }

    return true;
  }

  /// Standard Windows shell-icon ladder. The OS picks the closest size at
  /// the runtime DPI; embedding the full pyramid avoids the blurry
  /// rescaling of a single embedded image (upstream #573).
  static const List<int> _icoPyramid = [16, 24, 32, 48, 64, 128, 256];

  Future<void> _generateIcon(Image image) async {
    final cap =
        context.windowsConfig!.iconSize ?? constants.windowsDefaultIconSize;
    // Embed every standard size up to (and including) the cap.
    final sizes = _icoPyramid.where((s) => s <= cap).toList();
    if (sizes.isEmpty || sizes.last != cap) {
      // Honor the cap even if it falls between standard sizes.
      sizes.add(cap);
    }
    final frames = sizes
        .map((s) => utils.createResizedImage(s, image))
        .toList();
    final favIconFile = await utils.createFileIfNotExist(
      path.join(context.prefixPath, constants.windowsIconFilePath),
    );
    await favIconFile.writeAsBytes(IcoEncoder().encodeImages(frames));
  }
}
