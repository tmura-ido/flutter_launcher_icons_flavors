import 'package:test/test.dart';

import 'abs/icon_generator_test.dart' as icon_generator_test;
import 'android_gradle_test.dart' as android_gradle_test;
import 'android_min_sdk_default_test.dart' as android_min_sdk_default_test;
import 'android_test.dart' as android_test;
import 'cli/all_flavors_test.dart' as all_flavors_test;
import 'cli/continue_on_error_test.dart' as continue_on_error_test;
import 'cli/doctor_command_test.dart' as doctor_command_test;
import 'cli/exit_codes_test.dart' as exit_codes_test;
import 'cli/generate_command_test.dart' as generate_command_test;
import 'cli/migrate_command_test.dart' as migrate_command_test;
import 'cli/strict_test.dart' as strict_test;
import 'config/flavors_config_test.dart' as flavors_config_test;
import 'config/flavors_file_test.dart' as flavors_file_test;
import 'config/merge_test.dart' as merge_test;
import 'config/partial_config_test.dart' as partial_config_test;
import 'config/platform_toggle_test.dart' as platform_toggle_test;
import 'config/source_resolver_test.dart' as source_resolver_test;
import 'config_test.dart' as fli_config;
import 'macos/macos_icon_generator_test.dart' as macos_icons_gen_test;
import 'macos/macos_icon_template_test.dart' as macos_template_test;
import 'main_consolidated_flow_test.dart' as main_consolidated_flow_test;
import 'main_imports_test.dart' as main_imports_test;
import 'main_test.dart' as main_test;
import 'utils/decode_image_file_test.dart' as decode_image_file_test;
import 'utils/no_double_prefix_test.dart' as no_double_prefix_test;
import 'utils/path_join_test.dart' as path_join_test;
import 'utils/prefix_threading_test.dart' as prefix_threading_test;
import 'utils_test.dart' as utils_test;
import 'web/web_icon_generator_test.dart' as web_icon_gen_test;
import 'web/web_template_test.dart' as web_template_test;
import 'windows/windows_icon_generator_test.dart' as windows_icon_gen_test;

void main() {
  group('Flutter launcher icons', () {
    // others
    utils_test.main();
    fli_config.main();
    icon_generator_test.main();
    main_imports_test.main();

    main_test.main();
    // android
    android_test.main();
    android_gradle_test.main();
    android_min_sdk_default_test.main();
    // config
    partial_config_test.main();
    platform_toggle_test.main();
    // config (Phase 3 — consolidated multi-flavor)
    merge_test.main();
    flavors_file_test.main();
    flavors_config_test.main();
    source_resolver_test.main();
    main_consolidated_flow_test.main();
    // CLI (Phase 4)
    generate_command_test.main();
    migrate_command_test.main();
    doctor_command_test.main();
    exit_codes_test.main();
    strict_test.main();
    all_flavors_test.main();
    continue_on_error_test.main();
    // utils (Phase 1)
    path_join_test.main();
    decode_image_file_test.main();
    prefix_threading_test.main();
    no_double_prefix_test.main();
    // web
    web_template_test.main();
    web_icon_gen_test.main();
    // windows
    windows_icon_gen_test.main();
    // macos
    macos_template_test.main();
    macos_icons_gen_test.main();
  });
}
