import 'package:flutter_launcher_icons_flavors/abs/icon_generator.dart';
import 'package:flutter_launcher_icons_flavors/config/config.dart';
import 'package:flutter_launcher_icons_flavors/logger.dart';
import 'package:test/test.dart';

/// Regression for upstream issue #476.
/// See: issues/approved/issue-476-misleading-platform-log.md
///
/// `Creating Icons for X` used to print for every platform whether or not the
/// user actually enabled it. The new `isOptedIn` gate skips the header for
/// platforms with `generate: false` (or no config block at all). This test
/// asserts the gate via the in-memory mock generator. The visible-output
/// behavior is exercised end-to-end by the existing CLI integration tests.
void main() {
  group('issue #476: unconfigured platforms are skipped silently', () {
    test(
      'non-opted-in platform is iterated but createIcons is not called',
      () async {
        var createIconsCalled = false;
        var validateCalled = false;

        final platform = _FakeGenerator(
          platformName: 'Web',
          isOptedIn: false,
          onValidate: () => validateCalled = true,
          onCreate: () => createIconsCalled = true,
        );

        await generateIconsFor(
          config: Config.fromJson(<String, dynamic>{
            'image_path': 'assets/x.png',
            'android': true,
          }),
          flavor: null,
          prefixPath: '.',
          logger: FLILogger(false),
          platforms: (_) => [platform],
        );

        expect(createIconsCalled, isFalse);
        expect(
          validateCalled,
          isFalse,
          reason: 'should short-circuit before validateRequirements',
        );
      },
    );

    test(
      'opted-in platform with passing validation runs createIcons',
      () async {
        var createIconsCalled = false;
        final platform = _FakeGenerator(
          platformName: 'Web',
          isOptedIn: true,
          onValidate: () {},
          onCreate: () => createIconsCalled = true,
          validateResult: true,
        );

        await generateIconsFor(
          config: Config.fromJson(<String, dynamic>{
            'image_path': 'assets/x.png',
            'android': true,
          }),
          flavor: null,
          prefixPath: '.',
          logger: FLILogger(false),
          platforms: (_) => [platform],
        );

        expect(createIconsCalled, isTrue);
      },
    );
  });
}

class _FakeGenerator extends IconGenerator {
  _FakeGenerator({
    required String platformName,
    required this.isOptedIn,
    required this.onValidate,
    required this.onCreate,
    this.validateResult = true,
  }) : super(_dummyContext(), platformName);

  @override
  final bool isOptedIn;
  final void Function() onValidate;
  final void Function() onCreate;
  final bool validateResult;

  @override
  bool validateRequirements() {
    onValidate();
    return validateResult;
  }

  @override
  Future<void> createIcons() async {
    onCreate();
  }
}

IconGeneratorContext _dummyContext() {
  return IconGeneratorContext(
    config: Config(),
    prefixPath: '.',
    logger: FLILogger(false),
  );
}
