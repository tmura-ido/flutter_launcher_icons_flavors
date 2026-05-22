import 'dart:io';

import 'package:flutter_launcher_icons_flavors/android.dart' as android;
import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

/// Regression test for upstream issue #414.
/// See: issues/issue-414-manifest-merger-duplicate-icon.md
///
/// When the user picks a custom Android icon name (e.g.
/// `android: "launcher_icon"`), the generator must rewrite
/// `android:icon` in `AndroidManifest.xml` to point at the new mipmap.
/// Otherwise the manifest merger errors out on debug builds with a
/// `duplicate-attribute application@icon` failure (the original
/// `@mipmap/ic_launcher` reference is still present alongside the new
/// one).
void main() {
  group('issue #414: custom icon name updates AndroidManifest.xml', () {
    const baselineManifest = '''
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.example.myapplication">
    <application
        android:label="example"
        android:icon="@mipmap/ic_launcher">
        <activity android:name=".MainActivity"/>
    </application>
</manifest>
''';

    test(
      'overwriteAndroidManifestWithNewLauncherIcon rewrites @mipmap/ic_launcher → custom name',
      () async {
        await d.file('AndroidManifest.xml', baselineManifest).create();
        final manifestFile = File(path.join(d.sandbox, 'AndroidManifest.xml'));

        await android.overwriteAndroidManifestWithNewLauncherIcon(
          'launcher_icon',
          manifestFile,
        );

        final updated = await manifestFile.readAsString();
        expect(updated, contains('android:icon="@mipmap/launcher_icon"'));
        expect(
          updated,
          isNot(contains('android:icon="@mipmap/ic_launcher"')),
          reason: 'old reference must be gone to avoid manifest merger clash',
        );
      },
    );

    test(
      'second rewrite is idempotent (no duplicate attributes accumulate)',
      () async {
        await d.file('AndroidManifest2.xml', baselineManifest).create();
        final manifestFile = File(path.join(d.sandbox, 'AndroidManifest2.xml'));

        await android.overwriteAndroidManifestWithNewLauncherIcon(
          'launcher_icon',
          manifestFile,
        );
        await android.overwriteAndroidManifestWithNewLauncherIcon(
          'launcher_icon',
          manifestFile,
        );

        final updated = await manifestFile.readAsString();
        // Exactly one android:icon attribute remains.
        final iconCount = 'android:icon='.allMatches(updated).length;
        expect(iconCount, equals(1));
        expect(updated, contains('android:icon="@mipmap/launcher_icon"'));
      },
    );
  });
}
