// ignore_for_file: public_member_api_docs

import 'dart:io';

import 'package:args/args.dart';
import 'package:flutter_launcher_icons_flavored/abs/icon_generator.dart';
import 'package:flutter_launcher_icons_flavored/android.dart'
    as android_launcher_icons;
import 'package:flutter_launcher_icons_flavored/cli/command_runner.dart';
import 'package:flutter_launcher_icons_flavored/config/config.dart';
import 'package:flutter_launcher_icons_flavored/constants.dart';
import 'package:flutter_launcher_icons_flavored/custom_exceptions.dart';
import 'package:flutter_launcher_icons_flavored/ios.dart' as ios_launcher_icons;
import 'package:flutter_launcher_icons_flavored/logger.dart';
import 'package:flutter_launcher_icons_flavored/macos/macos_icon_generator.dart';
import 'package:flutter_launcher_icons_flavored/web/web_icon_generator.dart';
import 'package:flutter_launcher_icons_flavored/windows/windows_icon_generator.dart';
import 'package:path/path.dart' as path;

const String fileOption = 'file';
const String helpFlag = 'help';
const String verboseFlag = 'verbose';
const String prefixOption = 'prefix';
const String defaultConfigFile = 'flutter_launcher_icons.yaml';
const String flavorConfigFilePattern = r'^flutter_launcher_icons-(.*).yaml$';

Future<List<String>> getFlavors(String prefixPath) async {
  final List<String> flavors = [];
  await for (var item in Directory(prefixPath).list()) {
    if (item is File) {
      final name = path.basename(item.path);
      final match = RegExp(flavorConfigFilePattern).firstMatch(name);
      if (match != null) {
        flavors.add(match.group(1)!);
      }
    }
  }
  return flavors;
}

/// Backward-compat shim. Phase 4 routes everything through the
/// `CommandRunner` in `lib/cli/command_runner.dart`. This entry point
/// is preserved for callers that imported it before 0.15.0 (notably
/// `bin/flutter_launcher_icons.dart` historically and the integration
/// test in `test/main_consolidated_flow_test.dart`).
///
/// Behavior parity: when the runner returns a non-zero exit code, we
/// terminate the current isolate via `exit(code)` exactly as the old
/// implementation did. On success we return normally so test harnesses
/// can continue to make assertions afterwards.
Future<void> createIconsFromArguments(List<String> arguments) async {
  final runner = buildCommandRunner();
  final code = await runner.run(effectiveArgs(arguments)) ?? 0;
  if (code != 0) {
    exit(code);
  }
}

Future<void> createIconsFromConfig(
  Config flutterConfigs,
  FLILogger logger,
  String prefixPath, [
  String? flavor,
]) async {
  if (!flutterConfigs.hasPlatformConfig) {
    throw const InvalidConfigException(errorMissingPlatform);
  }

  // Resolve the effective Android min_sdk_android (explicit → autodetect →
  // static default) up-front so a warning surfaces early on autodetect
  // failure. Currently the resolved value is logged for visibility; future
  // phases may consume it for adaptive-icon gating.
  if (flutterConfigs.isNeedingNewAndroidIcon) {
    final resolvedMinSdk = await android_launcher_icons.resolveMinSdkAndroid(
      prefixPath: prefixPath,
      logger: logger,
      explicit: flutterConfigs.minSdkAndroid,
    );
    logger.verbose(
      'Resolved Android min_sdk_android = $resolvedMinSdk for this run.',
    );
  }

  final concurrentIconCreation = <Future<void>>[];
  if (flutterConfigs.isNeedingNewAndroidIcon) {
    concurrentIconCreation.add(
      android_launcher_icons.createDefaultIcons(
        flutterConfigs,
        flavor,
        prefixPath: prefixPath,
      ),
    );
  }
  if (flutterConfigs.hasAndroidAdaptiveConfig) {
    concurrentIconCreation.add(
      android_launcher_icons.createAdaptiveIcons(
        flutterConfigs,
        flavor,
        prefixPath: prefixPath,
      ),
    );
  }
  if (flutterConfigs.hasAndroidAdaptiveMonochromeConfig) {
    concurrentIconCreation.add(
      android_launcher_icons.createAdaptiveMonochromeIcons(
        flutterConfigs,
        flavor,
        prefixPath: prefixPath,
      ),
    );
  }
  await Future.wait(concurrentIconCreation);
  if (flutterConfigs.isNeedingNewAndroidIcon) {
    await android_launcher_icons.createMipmapXmlFile(
      flutterConfigs,
      flavor,
      prefixPath: prefixPath,
    );
  }
  if (flutterConfigs.isNeedingNewIOSIcon) {
    await ios_launcher_icons.createIcons(
      flutterConfigs,
      flavor,
      prefixPath: prefixPath,
    );
  }

  // Generates Icons for given platform
  await generateIconsFor(
    config: flutterConfigs,
    logger: logger,
    prefixPath: prefixPath,
    flavor: flavor,
    platforms: (context) {
      final platforms = <IconGenerator>[];
      if (flutterConfigs.hasWebConfig) {
        platforms.add(WebIconGenerator(context));
      }
      if (flutterConfigs.hasWindowsConfig) {
        platforms.add(WindowsIconGenerator(context));
      }
      if (flutterConfigs.hasMacOSConfig) {
        platforms.add(MacOSIconGenerator(context));
      }
      return platforms;
    },
  );
}

/// Backward-compat shim used by `test/main_test.dart`.
///
/// Mirrors the legacy behavior: explicit `--file` → that file; else the
/// default `flutter_launcher_icons.yaml`; else `pubspec.yaml`. Returns
/// `null` when nothing is found.
Config? loadConfigFileFromArgResults(ArgResults argResults) {
  final String prefixPath = argResults[prefixOption];
  final filePath = (argResults[fileOption] as String?) ?? defaultConfigFile;
  return Config.loadConfigFromPath(filePath, prefixPath) ??
      Config.loadConfigFromPubSpec(prefixPath);
}
