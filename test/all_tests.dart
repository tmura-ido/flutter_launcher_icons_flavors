import 'package:test/test.dart';

import 'abs/icon_generator_test.dart' as icon_generator_test;
import 'android_gradle_test.dart' as android_gradle_test;
import 'android_min_sdk_default_test.dart' as android_min_sdk_default_test;
import 'android_test.dart' as android_test;
import 'changelog_test.dart' as changelog_test;
import 'cli/all_flavors_test.dart' as all_flavors_test;
import 'cli/continue_on_error_test.dart' as continue_on_error_test;
import 'cli/doctor_command_test.dart' as doctor_command_test;
import 'cli/exit_codes_test.dart' as exit_codes_test;
import 'cli/generate_command_test.dart' as generate_command_test;
import 'cli/migrate_command_test.dart' as migrate_command_test;
import 'cli/squish_prompt_test.dart' as squish_prompt_test;
import 'cli/strict_test.dart' as strict_test;
import 'cli/unknown_args_test.dart' as unknown_args_test;
import 'config/flavors_config_test.dart' as flavors_config_test;
import 'config/flavors_file_test.dart' as flavors_file_test;
import 'config/merge_test.dart' as merge_test;
import 'config/partial_config_test.dart' as partial_config_test;
import 'config/platform_toggle_test.dart' as platform_toggle_test;
import 'config/source_resolver_test.dart' as source_resolver_test;
import 'config_test.dart' as fli_config;
import 'issues/issue_020_svg_clear_error_test.dart' as issue_020_test;
import 'issues/issue_091_android_xml_foreground_clear_error_test.dart'
    as issue_091_test;
import 'issues/issue_092_ios_alternate_icons_test.dart' as issue_092_test;
import 'issues/issue_110_ios_app_store_marketing_icon_test.dart'
    as issue_110_test;
import 'issues/issue_132_adaptive_background_invalid_color_test.dart'
    as issue_132_test;
import 'issues/issue_139_optimize_png_test.dart' as issue_139_test;
import 'issues/issue_153_ios_unassigned_children_test.dart' as issue_153_test;
import 'issues/issue_161_ios_missing_appiconset_test.dart' as issue_161_test;
import 'issues/issue_166_unquoted_hex_background_test.dart' as issue_166_test;
import 'issues/issue_172_ios_alpha_detected_test.dart' as issue_172_test;
import 'issues/issue_175_hex_literal_as_foreground_test.dart' as issue_175_test;
import 'issues/issue_196_undecodable_source_format_test.dart' as issue_196_test;
import 'issues/issue_198_base_yaml_with_flavor_test.dart' as issue_198_test;
import 'issues/issue_201_only_flavor_yaml_test.dart' as issue_201_test;
import 'issues/issue_214_background_color_default_test.dart'
    as issue_214_bg_default_test;
import 'issues/issue_214_ios_remove_alpha_after_letterbox_test.dart'
    as issue_214_ios_alpha_order_test;
import 'issues/issue_214_letter_box_integration_test.dart'
    as issue_214_letter_box_test;
import 'issues/issue_214_non_square_doctor_strict_test.dart'
    as issue_214_doctor_test;
import 'issues/issue_214_non_square_images_squished_test.dart'
    as issue_214_test;
import 'issues/issue_279_flavor_siblings_listed_test.dart' as issue_279_test;
import 'issues/issue_312_config_files_in_subfolder_test.dart' as issue_312_test;
import 'issues/issue_337_pbxproj_hyphen_flavor_test.dart' as issue_337_test;
import 'issues/issue_378_fli_exception_hierarchy_test.dart' as issue_378_test;
import 'issues/issue_385_android_flavor_res_path_test.dart' as issue_385_test;
import 'issues/issue_414_manifest_merger_custom_name_test.dart'
    as issue_414_test;
import 'issues/issue_423_web_package_image_path_test.dart' as issue_423_test;
import 'issues/issue_426_web_output_path_test.dart' as issue_426_test;
import 'issues/issue_432_remove_alpha_ios_use_bg_fallback_test.dart'
    as issue_432_test;
import 'issues/issue_443_android_output_path_test.dart' as issue_443_test;
import 'issues/issue_462_remove_alpha_ios_test.dart' as issue_462_test;
import 'issues/issue_476_skip_unconfigured_platform_header_test.dart'
    as issue_476_test;
import 'issues/issue_490_flavor_config_non_root_test.dart' as issue_490_test;
import 'issues/issue_491_ios_per_flavor_preserved_test.dart' as issue_491_test;
import 'issues/issue_506_pbxproj_no_extra_chars_test.dart' as issue_506_test;
import 'issues/issue_510_tray_icons_test.dart' as issue_510_test;
import 'issues/issue_514_ios_background_color_pixels_test.dart'
    as issue_514_test;
import 'issues/issue_516_android_mipmap_stride_test.dart' as issue_516_test;
import 'issues/issue_530_archive_safe_version_test.dart' as issue_530_test;
import 'issues/issue_535_transparent_adaptive_background_test.dart'
    as issue_535_test;
import 'issues/issue_540_favicon_ico_emitted_test.dart' as issue_540_test;
import 'issues/issue_543_renamed_xcodeproj_test.dart' as issue_543_test;
import 'issues/issue_550_futures_awaited_test.dart' as issue_550_test;
import 'issues/issue_552_noop_logger_test.dart' as issue_552_test;
import 'issues/issue_553_android14_colors_xml_written_test.dart'
    as issue_553_test;
import 'issues/issue_565_pbxproj_flavor_idempotency_test.dart'
    as issue_565_test;
import 'issues/issue_573_windows_ico_multisize_test.dart' as issue_573_test;
import 'issues/issue_587_tinted_only_single_catalog_test.dart'
    as issue_587_test;
import 'issues/issue_592_ios_single_size_test.dart' as issue_592_test;
import 'issues/issue_612_pbxproj_race_prefix_match_test.dart' as issue_612_test;
import 'issues/issue_614_favicon_size_test.dart' as issue_614_test;
import 'issues/issue_615_indexed_color_png_test.dart' as issue_615_test;
import 'issues/issue_619_archive_4_compat_test.dart' as issue_619_test;
import 'issues/issue_622_badge_per_flavor_test.dart' as issue_622_test;
import 'issues/issue_627_flavor_outputs_use_flavor_folder_test.dart'
    as issue_627_test;
import 'issues/issue_632_android_icon_name_respected_test.dart'
    as issue_632_test;
import 'issues/issue_633_web_falls_back_to_top_level_image_path_test.dart'
    as issue_633_test;
import 'issues/issue_634_pbxproj_only_appicon_name_test.dart' as issue_634_test;
import 'issues/issue_637_xcodeproj_path_ignored_test.dart' as issue_637_test;
import 'issues/issue_638_macos_flavor_aware_path_test.dart' as issue_638_test;
import 'issues/issue_648_flavor_path_recursive_test.dart' as issue_648_test;
import 'issues/issue_655_macos_padding_test.dart' as issue_655_test;
import 'issues/issue_657_ios_liquid_glass_opt_out_test.dart' as issue_657_test;
import 'issues/issue_658_flavor_race_regression_test.dart' as issue_658_test;
import 'issues/issue_660_macos_themed_backgrounds_test.dart' as issue_660_test;
import 'issues/issue_661_ios_legacy_1x_sizes_test.dart' as issue_661_test;
import 'issues/issue_662_ios_dark_appearances_test.dart' as issue_662_test;
import 'issues/issue_665_adaptive_bg_non_png_test.dart' as issue_665_test;
import 'issues/issue_666_linux_minimal_png_test.dart' as issue_666_test;
import 'issues/issue_pbxproj_locked_warning_test.dart'
    as issue_pbxproj_locked_test;
import 'macos/macos_icon_generator_test.dart' as macos_icons_gen_test;
import 'macos/macos_icon_template_test.dart' as macos_template_test;
import 'main_consolidated_flow_test.dart' as main_consolidated_flow_test;
import 'main_imports_test.dart' as main_imports_test;
import 'main_test.dart' as main_test;
import 'permutations/adaptive_icon_matrix_test.dart' as perm_adaptive_icon_test;
import 'permutations/boolean_options_matrix_test.dart'
    as perm_boolean_options_test;
import 'permutations/cli_flag_matrix_test.dart' as perm_cli_flag_test;
import 'permutations/color_utils_matrix_test.dart' as perm_color_utils_test;
import 'permutations/config_validation_matrix_test.dart'
    as perm_config_validation_test;
import 'permutations/deep_merge_matrix_test.dart' as perm_deep_merge_test;
import 'permutations/hex_color_matrix_test.dart' as perm_hex_color_test;
import 'permutations/ios_contents_spec_test.dart' as perm_ios_contents_test;
import 'permutations/legacy_discovery_matrix_test.dart'
    as perm_legacy_discovery_test;
import 'permutations/platform_subconfig_keys_test.dart'
    as perm_subconfig_keys_test;
import 'permutations/platform_toggle_matrix_test.dart'
    as perm_platform_toggle_test;
import 'permutations/serialization_roundtrip_test.dart' as perm_roundtrip_test;
import 'permutations/template_geometry_test.dart' as perm_geometry_test;
import 'permutations/yaml_convert_matrix_test.dart' as perm_yaml_convert_test;
import 'permutations/yaml_emit_matrix_test.dart' as perm_yaml_emit_test;
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
    changelog_test.main();

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
    squish_prompt_test.main();
    unknown_args_test.main();
    // permutations (option-permutation matrices)
    perm_config_validation_test.main();
    perm_adaptive_icon_test.main();
    perm_subconfig_keys_test.main();
    perm_boolean_options_test.main();
    perm_cli_flag_test.main();
    perm_hex_color_test.main();
    perm_geometry_test.main();
    perm_ios_contents_test.main();
    perm_roundtrip_test.main();
    perm_platform_toggle_test.main();
    perm_deep_merge_test.main();
    perm_color_utils_test.main();
    perm_yaml_convert_test.main();
    perm_yaml_emit_test.main();
    perm_legacy_discovery_test.main();
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
    // issues (regression / behavior)
    issue_020_test.main();
    issue_091_test.main();
    issue_092_test.main();
    issue_110_test.main();
    issue_132_test.main();
    issue_139_test.main();
    issue_153_test.main();
    issue_161_test.main();
    issue_166_test.main();
    issue_175_test.main();
    issue_196_test.main();
    issue_198_test.main();
    issue_172_test.main();
    issue_201_test.main();
    issue_214_test.main();
    issue_214_doctor_test.main();
    issue_214_letter_box_test.main();
    issue_214_bg_default_test.main();
    issue_214_ios_alpha_order_test.main();
    issue_279_test.main();
    issue_312_test.main();
    issue_337_test.main();
    issue_378_test.main();
    issue_385_test.main();
    issue_414_test.main();
    issue_423_test.main();
    issue_426_test.main();
    issue_432_test.main();
    issue_443_test.main();
    issue_462_test.main();
    issue_476_test.main();
    issue_490_test.main();
    issue_491_test.main();
    issue_510_test.main();
    issue_552_test.main();
    issue_506_test.main();
    issue_514_test.main();
    issue_516_test.main();
    issue_530_test.main();
    issue_535_test.main();
    issue_540_test.main();
    issue_543_test.main();
    issue_550_test.main();
    issue_553_test.main();
    issue_565_test.main();
    issue_573_test.main();
    issue_587_test.main();
    issue_592_test.main();
    issue_612_test.main();
    issue_614_test.main();
    issue_615_test.main();
    issue_619_test.main();
    issue_622_test.main();
    issue_627_test.main();
    issue_632_test.main();
    issue_633_test.main();
    issue_634_test.main();
    issue_637_test.main();
    issue_638_test.main();
    issue_648_test.main();
    issue_655_test.main();
    issue_658_test.main();
    issue_657_test.main();
    issue_660_test.main();
    issue_661_test.main();
    issue_662_test.main();
    issue_665_test.main();
    issue_666_test.main();
    issue_pbxproj_locked_test.main();
  });
}
