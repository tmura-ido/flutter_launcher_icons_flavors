import 'package:flutter_launcher_icons_flavors/abs/icon_generator.dart';
import 'package:flutter_launcher_icons_flavors/utils.dart' as utils;
import 'package:image/image.dart';
import 'package:path/path.dart' as path;

/// Minimal Linux launcher icon writer (upstream #666 / #186 / #604 /
/// #629). Resizes the source PNG to a single configurable size and
/// writes to a known path under `linux/`. Out of scope for v1: hicolor
/// multi-size set, `.desktop` rewriting, Flatpak/Snap.
class LinuxIconGenerator extends IconGenerator {
  static const String _defaultOutputPath = 'linux/runner/resources/app_icon.png';

  /// Creates a [LinuxIconGenerator].
  LinuxIconGenerator(IconGeneratorContext context) : super(context, 'Linux');

  @override
  bool get isOptedIn => context.config.linuxConfig?.generate ?? false;

  String get _resolvedOutputPath {
    final linux = context.config.linuxConfig!;
    if (linux.outputPath != null && linux.outputPath!.isNotEmpty) {
      return linux.outputPath!;
    }
    final flavor = context.flavor;
    if (flavor != null && flavor.isNotEmpty) {
      return 'linux_$flavor/runner/resources/app_icon.png';
    }
    return _defaultOutputPath;
  }

  @override
  Future<void> createIcons() async {
    final linux = context.config.linuxConfig!;
    final imagePath = linux.imagePath ?? context.config.imagePath;
    if (imagePath == null) {
      context.logger.error(
        'linux: missing image_path (no linux.image_path or top-level image_path)',
      );
      return;
    }
    final src = await utils.decodeImageFile(
      path.join(context.prefixPath, imagePath),
    );
    final resized = utils.createResizedImage(linux.iconSize, src);
    final outFile = await utils.createFileIfNotExist(
      path.join(context.prefixPath, _resolvedOutputPath),
    );
    await outFile.writeAsBytes(
      utils.encodePngOptimized(resized, optimize: context.config.optimizePng),
    );
  }

  @override
  bool validateRequirements() {
    final linux = context.config.linuxConfig;
    if (linux == null || !linux.generate) return false;
    final imagePath = linux.imagePath ?? context.config.imagePath;
    if (imagePath == null) {
      context.logger.error(
        'Invalid config. Either provide linux.image_path or image_path',
      );
      return false;
    }
    return true;
  }
}
