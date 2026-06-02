import 'dart:io';

import 'package:flutter_launcher_icons_flavors/android.dart' as android;
import 'package:flutter_launcher_icons_flavors/config/config.dart';
import 'package:flutter_launcher_icons_flavors/constants.dart' as constants;
import 'package:flutter_launcher_icons_flavors/logger.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

/// When a flavor already ships an adaptive-icon XML, `createMipmapXmlFile`
/// edits the background color in place (first finding: `adaptive_icon_background`
/// hex -> general `background_color` hex) instead of overwriting the file from
/// the template. Authored structure (`<shape>`, `<foreground>`, `<monochrome>`)
/// is preserved.
void main() {
  final logger = FLILogger(false);

  /// Writes an adaptive-icon XML at the default location inside a fresh sandbox
  /// and returns the project prefix + the XML File.
  Future<(String, File)> seedAdaptiveXml(String xml, {String? flavor}) async {
    await d.dir('proj').create();
    final prefix = p.join(d.sandbox, 'proj');
    final file = File(
      p.join(
        prefix,
        constants.androidAdaptiveXmlFolder(flavor),
        '${constants.androidDefaultIconName}.xml',
      ),
    );
    await file.create(recursive: true);
    await file.writeAsString(xml);
    return (prefix, file);
  }

  Config androidConfigWith(Map<String, dynamic> extra) => Config.fromJson(<String, dynamic>{
    'image_path': 'assets/icon/icon.png',
    'android': true,
    'ios': false,
    ...extra,
  });

  group('createMipmapXmlFile edits an existing adaptive-icon XML in place', () {
    test('inline <shape><solid> color is rewritten; structure preserved', () async {
      const xml = '''
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background>
        <shape android:shape="oval">
            <solid android:color="#FFFFFF" />
        </shape>
    </background>
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />
</adaptive-icon>
''';
      final (prefix, file) = await seedAdaptiveXml(xml);
      final config = androidConfigWith({'background_color': '#1f1d1e'});

      await android.createMipmapXmlFile(
        config,
        null,
        logger: logger,
        prefixPath: prefix,
      );

      final body = await file.readAsString();
      expect(body, contains('<solid android:color="#1f1d1e" />'));
      expect(body, isNot(contains('#FFFFFF')));
      // Authored structure untouched.
      expect(body, contains('android:shape="oval"'));
      expect(body, contains('@mipmap/ic_launcher_foreground'));
      expect(body, contains('@mipmap/ic_launcher_monochrome'));
    });

    test('direct <background android:color> literal is rewritten', () async {
      const xml = '''
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:color="#FFFFFF" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
''';
      final (prefix, file) = await seedAdaptiveXml(xml);
      final config = androidConfigWith({'background_color': '#1f1d1e'});

      await android.createMipmapXmlFile(
        config,
        null,
        logger: logger,
        prefixPath: prefix,
      );

      final body = await file.readAsString();
      expect(body, contains('<background android:color="#1f1d1e" />'));
      expect(body, isNot(contains('#FFFFFF')));
    });

    test('adaptive_icon_background hex wins over general background_color', () async {
      const xml = '''
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background>
        <shape android:shape="oval">
            <solid android:color="#000000" />
        </shape>
    </background>
</adaptive-icon>
''';
      final (prefix, file) = await seedAdaptiveXml(xml);
      final config = androidConfigWith({
        'adaptive_icon_foreground': 'assets/icon/fg.png',
        'adaptive_icon_background': '#0175C2',
        'background_color': '#1f1d1e',
      });

      await android.createMipmapXmlFile(
        config,
        null,
        logger: logger,
        prefixPath: prefix,
      );

      final body = await file.readAsString();
      expect(body, contains('android:color="#0175C2"'));
    });

    test('@color reference updates colors.xml, leaves XML untouched', () async {
      const xml = '''
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
''';
      final (prefix, file) = await seedAdaptiveXml(xml);
      final config = androidConfigWith({'background_color': '#1f1d1e'});

      await android.createMipmapXmlFile(
        config,
        null,
        logger: logger,
        prefixPath: prefix,
      );

      // XML byte-identical.
      expect(await file.readAsString(), equals(xml));
      // colors.xml carries the resolved color.
      final colorsXml = File(p.join(prefix, constants.androidColorsFile(null)));
      expect(colorsXml.existsSync(), isTrue);
      final colors = await colorsXml.readAsString();
      expect(colors, contains('ic_launcher_background'));
      expect(colors, contains('#1f1d1e'));
    });

    test('@drawable PNG background is left untouched (PNG wins)', () async {
      const xml = '''
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
''';
      final (prefix, file) = await seedAdaptiveXml(xml);
      final config = androidConfigWith({'background_color': '#1f1d1e'});

      await android.createMipmapXmlFile(
        config,
        null,
        logger: logger,
        prefixPath: prefix,
      );

      expect(await file.readAsString(), equals(xml));
    });

    test('no resolved color leaves the file untouched', () async {
      const xml = '''
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background>
        <shape android:shape="oval">
            <solid android:color="#FFFFFF" />
        </shape>
    </background>
</adaptive-icon>
''';
      final (prefix, file) = await seedAdaptiveXml(xml);
      // No adaptive_icon_background, no background_color.
      final config = androidConfigWith({});

      await android.createMipmapXmlFile(
        config,
        null,
        logger: logger,
        prefixPath: prefix,
      );

      expect(await file.readAsString(), equals(xml));
    });
  });

  group('Config.resolvedAdaptiveBackgroundColor (first finding)', () {
    test('adaptive hex wins', () {
      final config = androidConfigWith({
        'adaptive_icon_background': '#0175C2',
        'background_color': '#1f1d1e',
      });
      expect(config.resolvedAdaptiveBackgroundColor, '#0175C2');
    });

    test('falls back to general background_color when adaptive is not a hex', () {
      final config = androidConfigWith({
        'adaptive_icon_background': 'assets/icon/bg.png',
        'background_color': '#1f1d1e',
      });
      expect(config.resolvedAdaptiveBackgroundColor, '#1f1d1e');
    });

    test('uses general background_color when adaptive is unset', () {
      final config = androidConfigWith({'background_color': '#1f1d1e'});
      expect(config.resolvedAdaptiveBackgroundColor, '#1f1d1e');
    });

    test('null when neither is a hex literal', () {
      final config = androidConfigWith({
        'adaptive_icon_background': 'assets/icon/bg.png',
      });
      expect(config.resolvedAdaptiveBackgroundColor, isNull);
    });
  });
}
