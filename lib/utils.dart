// ignore_for_file: public_member_api_docs

import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart';
import 'package:path/path.dart' as path;

import 'custom_exceptions.dart';

Image createResizedImage(int iconSize, Image image) {
  if (image.width >= iconSize) {
    return copyResize(
      image,
      width: iconSize,
      height: iconSize,
      interpolation: Interpolation.average,
    );
  } else {
    return copyResize(
      image,
      width: iconSize,
      height: iconSize,
      interpolation: Interpolation.linear,
    );
  }
}

String generateError(Exception e, String? error) {
  final errorOutput = error == null ? '' : ' \n$error';
  return '\n✕ ERROR: ${(e).runtimeType.toString()}$errorOutput';
}

/// Decodes an image file at [filePath].
///
/// Throws [NoDecoderForImageFormatException] if the file's format is not
/// recognized by `package:image`. SVG sources raise an
/// [InvalidConfigException] with a clear "not yet supported" message
/// (upstream #020) — full SVG rasterization is a future feature gated
/// on a vector renderer dependency.
Future<Image> decodeImageFile(String filePath) async {
  if (filePath.toLowerCase().endsWith('.svg')) {
    throw InvalidConfigException(
      "'$filePath' is an SVG. SVG sources are not yet supported; please "
      'convert to PNG. Tracked as upstream #020.',
    );
  }
  final image = decodeImage(await File(filePath).readAsBytes());
  if (image == null) {
    throw NoDecoderForImageFormatException(filePath);
  }
  return image;
}

/// Creates [File] in the given [filePath] if not exists
Future<File> createFileIfNotExist(String filePath) async {
  final file = File(path.joinAll(path.split(filePath)));
  // existsSync is intentional: this is on the CLI startup path where blocking
  // briefly is preferable to the overhead of a microtask. Image I/O hot paths
  // use the async equivalents.
  if (!file.existsSync()) {
    await file.create(recursive: true);
  }
  return file;
}

/// Creates [Directory] in the given [dirPath] if not exists
Future<Directory> createDirIfNotExist(String dirPath) async {
  final dir = Directory(path.joinAll(path.split(dirPath)));
  // existsSync is intentional: this is on the CLI startup path where blocking
  // briefly is preferable to the overhead of a microtask. Image I/O hot paths
  // use the async equivalents.
  if (!dir.existsSync()) {
    await dir.create(recursive: true);
  }
  return dir;
}

/// Returns a prettified json string
String prettifyJsonEncode(Object? map) =>
    JsonEncoder.withIndent(' ' * 4).convert(map);

/// Check if given [File] or [Directory] exists at the given [paths],
/// if not returns the failed [FileSystemEntity] path
String? areFSEntitiesExist(List<String> paths) {
  for (final path in paths) {
    // Using the sync method here due to `avoid_slow_async_io` lint suggestion.
    final fsType = FileSystemEntity.typeSync(path);
    if (![
      FileSystemEntityType.directory,
      FileSystemEntityType.file,
    ].contains(fsType)) {
      return path;
    }
  }
  return null;
}

String flavorConfigFile(String flavor) => 'flutter_launcher_icons-$flavor.yaml';

/// PNG encoder honoring the `optimize_png` opt-in (upstream #139 / #199).
/// When [optimize] is true, the `image` package's max-compression level (9)
/// is used; otherwise its default (level 6) preserves the existing fast
/// generate behavior. Lossless either way.
List<int> encodePngOptimized(Image image, {required bool optimize}) {
  return encodePng(image, level: optimize ? 9 : 6);
}

/// True if [image] is not square (`width != height`). Used by doctor /
/// strict mode to warn about non-square sources, which the resize step
/// silently squishes today (upstream #214).
bool isNonSquare(Image image) => image.width != image.height;

/// True if the decoded [image] has at least one non-opaque pixel.
/// Short-circuits on the first match. Used by doctor / strict mode for
/// the iOS App Store alpha-rejection rule (upstream #172).
bool imageHasAlphaPixel(Image image) {
  if (!image.hasAlpha) {
    return false;
  }
  for (final px in image) {
    if (px.a != 255) {
      return true;
    }
  }
  return false;
}
