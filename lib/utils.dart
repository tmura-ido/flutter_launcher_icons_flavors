// ignore_for_file: public_member_api_docs

import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart';
import 'package:path/path.dart' as path;

import 'custom_exceptions.dart';

Image createResizedImage(int iconSize, Image image, {Color? backgroundColor}) {
  // Letter-box non-square sources when a background color is supplied so the
  // source's aspect ratio is preserved instead of squished onto an N×N grid
  // (upstream #214). Without a background color we keep the legacy squish
  // behavior to stay compatible with existing user output.
  final src = backgroundColor != null
      ? letterBoxToSquare(image, backgroundColor)
      : image;
  if (src.width >= iconSize) {
    return copyResize(
      src,
      width: iconSize,
      height: iconSize,
      interpolation: Interpolation.average,
    );
  } else {
    return copyResize(
      src,
      width: iconSize,
      height: iconSize,
      interpolation: Interpolation.linear,
    );
  }
}

/// Pads a non-square [image] onto a square canvas of side `max(w, h)` filled
/// with [backgroundColor] and centers the source on it. Returns [image]
/// unchanged when it is already square (idempotent — safe to call multiple
/// times, e.g. by both a platform writer that pre-pads and a downstream
/// `createResizedImage` call that also has a background color).
///
/// Used by platform writers that have a configured background color so a
/// non-square source's aspect ratio is preserved across every generated
/// icon size (upstream #214). Letter-box the source ONCE per platform, then
/// hand the square result to the resize loop.
Image letterBoxToSquare(Image image, Color backgroundColor) {
  if (image.width == image.height) {
    return image;
  }
  final size = image.width > image.height ? image.width : image.height;
  final canvas = Image(width: size, height: size, numChannels: 4);
  for (final px in canvas) {
    px.setRgba(
      backgroundColor.r.toInt(),
      backgroundColor.g.toInt(),
      backgroundColor.b.toInt(),
      backgroundColor.a.toInt(),
    );
  }
  final offsetX = (size - image.width) ~/ 2;
  final offsetY = (size - image.height) ~/ 2;
  return compositeImage(canvas, image, dstX: offsetX, dstY: offsetY);
}

/// Hex color literal regex. Accepts `#RGB`, `#RGBA`, `#RRGGBB`, `#AARRGGBB`,
/// and the unhashed forms (lenient). Used to classify `adaptive_icon_*` /
/// `background_color` values as either a color or a file path.
final RegExp _hexColorLiteral = RegExp(r'^#?[0-9A-Fa-f]{3,8}$');

/// True if the value is a hex color literal (any of the forms above).
///
/// Single source of truth shared by the Android writer and the config model
/// so they classify colors identically.
bool isHexColorLiteral(String value) => _hexColorLiteral.hasMatch(value);

/// Parses a `#RRGGBB` or `#RRGGBBAA` (or unprefixed) hex string into a
/// `ColorUint8`. Throws [InvalidConfigException] for malformed input.
///
/// Single source of truth for hex → color conversion across platform
/// writers (iOS background, web background, Android adaptive background).
ColorUint8 parseHexColor(String value) {
  final hex = value.startsWith('#') ? value.substring(1) : value;
  if (hex.length != 6 && hex.length != 8) {
    throw InvalidConfigException(
      'background color hex must be 6 or 8 digits (e.g. "FFFFFF"), got '
      '"$value"',
    );
  }
  final byte = int.parse(hex, radix: 16);
  if (hex.length == 8) {
    return ColorUint8.rgba(
      (byte >> 16) & 0xff,
      (byte >> 8) & 0xff,
      byte & 0xff,
      (byte >> 24) & 0xff,
    );
  }
  return ColorUint8.rgba(
    (byte >> 16) & 0xff,
    (byte >> 8) & 0xff,
    byte & 0xff,
    0xff,
  );
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
