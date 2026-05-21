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
/// recognized by `package:image`.
Future<Image> decodeImageFile(String filePath) async {
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
