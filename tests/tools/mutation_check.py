#!/usr/bin/env python3
"""Mutation test of tests/tools/check_project.gd (P01): proves the checks FAIL when the project
contract is broken, not just that they pass on the good tree.

    python3 -I tests/tools/mutation_check.py --project <CLONE> [--only <id>[,<id>]] [--workdir DIR] [--jobs N]

<CLONE> is a test copy of the repo (impl/tools/clone_run.sh or tools/dev/test_in_copy.sh). For every
mutant the script makes a copy-on-write copy of <CLONE> (cp -Rc, with its .godot cache), applies ONE
edit to a file of the copy, runs check_project.gd headless there and requires that the named check ids
FAIL (and the process exits non-zero). The mutants that touch the input map are also run through
tests/tools/print_inputmap.gd, which must exit non-zero as well. Two extra "accept" mutants append the six
feature autoloads (with stub scripts), resp. SocialManager alone, and require a fully green run. A mutant whose
edit cannot be applied (its anchor is gone from the file) is reported as wrong, not a crash. The copies live in
--workdir (default: a fresh temp dir) and are deleted afterwards. The repo itself is never touched. Exit code 0 = every mutant
behaved as expected. Only the standard library is used.
"""
import argparse
import concurrent.futures
import os
import re
import shutil
import subprocess
import sys
import tempfile

GODOT = os.environ.get("GODOT", "/Applications/Godot.app/Contents/MacOS/Godot")
ACCEPT_ID = "accept_feature_autoloads"
ACCEPT_SOCIAL_ID = "accept_social_manager_only"
ACCEPT_IDS = {ACCEPT_ID, ACCEPT_SOCIAL_ID}


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def write(path, text):
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


def sub_once(root, rel, old, new):
    path = os.path.join(root, rel)
    text = read(path)
    if old not in text:
        raise RuntimeError("mutation anchor not found in %s: %r" % (rel, old))
    write(path, text.replace(old, new, 1))


def regex_once(root, rel, pattern, repl):
    path = os.path.join(root, rel)
    text = read(path)
    new, n = re.subn(pattern, repl, text, count=1, flags=re.S)
    if n != 1:
        raise RuntimeError("mutation pattern not found in %s: %r" % (rel, pattern))
    write(path, new)


def block_edit(root, name, old, new):
    """Replace the first occurrence of `old` inside the project.godot [input] block of action `name`."""
    path = os.path.join(root, "project.godot")
    text = read(path)
    m = re.search(action_block(name), text, flags=re.S)
    if not m:
        raise RuntimeError("input block %s not found" % name)
    blk = m.group(0)
    if old not in blk:
        raise RuntimeError("mutation anchor %r not found in the %s block" % (old, name))
    write(path, text.replace(blk, blk.replace(old, new, 1), 1))


def append(root, rel, text):
    path = os.path.join(root, rel)
    write(path, read(path) + text)


def remove_file(root, rel):
    os.remove(os.path.join(root, rel))


def action_block(name):
    return r'(?m)^%s=\{\n.*?\n\}\n' % re.escape(name)


# the six feature autoloads: the five of the features addendum and SocialManager of the towns addendum (RT3)
FEATURE_LINES = [
    ("HomeManager", "scripts/home/home_manager.gd"),
    ("FurnitureManager", "scripts/furniture/furniture_manager.gd"),
    ("WardrobeManager", "scripts/wardrobe/wardrobe_manager.gd"),
    ("LootService", "scripts/loot/loot_service.gd"),
    ("CollectionLog", "scripts/collection/collection_log.gd"),
    ("SocialManager", "scripts/social/social_manager.gd"),
]
ANIMAL_LINE = 'AnimalHusbandry="*res://scripts/farm/animal_husbandry.gd"\n'


def stub_script(root, rel):
    os.makedirs(os.path.dirname(os.path.join(root, rel)), exist_ok=True)
    write(os.path.join(root, rel), "extends Node\n")


def accept_features(root):
    """Append the six feature autoloads exactly as add_autoload.py will (after AnimalHusbandry)."""
    lines = "".join('%s="*res://%s"\n' % (n, p) for n, p in FEATURE_LINES)
    sub_once(root, "project.godot", ANIMAL_LINE, ANIMAL_LINE + lines)
    for _, rel in FEATURE_LINES:
        stub_script(root, rel)


def accept_social_manager_only(root):
    """The sixth feature line alone (S-core runs add_autoload.py for it, whichever of the five exist)."""
    sub_once(root, "project.godot", ANIMAL_LINE, ANIMAL_LINE + 'SocialManager="*res://scripts/social/social_manager.gd"\n')
    stub_script(root, "scripts/social/social_manager.gd")


def social_manager_wrong_path(root):
    sub_once(root, "project.godot", ANIMAL_LINE, ANIMAL_LINE + 'SocialManager="*res://scripts/elsewhere/social.gd"\n')
    stub_script(root, "scripts/elsewhere/social.gd")


def social_manager_twice(root):
    line = 'SocialManager="*res://scripts/social/social_manager.gd"\n'
    sub_once(root, "project.godot", ANIMAL_LINE, ANIMAL_LINE + line + line)
    stub_script(root, "scripts/social/social_manager.gd")


def social_manager_before_animal(root):
    sub_once(root, "project.godot", ANIMAL_LINE, 'SocialManager="*res://scripts/social/social_manager.gd"\n' + ANIMAL_LINE)
    stub_script(root, "scripts/social/social_manager.gd")


def seventh_autoload(root):
    """All six feature lines and then a name that is on no list: the closed list stays closed."""
    accept_features(root)
    sub_once(root, "project.godot", 'SocialManager="*res://scripts/social/social_manager.gd"\n',
             'SocialManager="*res://scripts/social/social_manager.gd"\nPeopleManager="*res://scripts/social/people_manager.gd"\n')
    stub_script(root, "scripts/social/people_manager.gd")


def feature_before_animal(root):
    sub_once(root, "project.godot", ANIMAL_LINE, 'HomeManager="*res://scripts/home/home_manager.gd"\n' + ANIMAL_LINE)
    stub_script(root, "scripts/home/home_manager.gd")


def swap_autoloads(root):
    a = 'GameManager="*res://scripts/autoload/game_manager.gd"\n'
    b = 'LocalizationManager="*res://scripts/autoload/localization_manager.gd"\n'
    sub_once(root, "project.godot", a + b, b + a)


def wheel_on_rotate(root):
    block = (r'(?m)^rotate_item=\{\n.*?\n\}\n')
    wheel = ('Object(InputEventMouseButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,'
             '"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"button_mask":0,'
             '"position":Vector2(0, 0),"global_position":Vector2(0, 0),"factor":1.0,"button_index":4,"canceled":false,'
             '"pressed":false,"double_click":false,"script":null)')
    path = os.path.join(root, "project.godot")
    text = read(path)
    m = re.search(block, text, flags=re.S)
    if not m:
        raise RuntimeError("rotate_item block not found")
    blk = m.group(0)
    new_blk = blk.replace("\n]\n}\n", "\n, " + wheel + "\n]\n}\n")
    write(path, text.replace(blk, new_blk, 1))


def inventory_f10(root):
    block = r'(?m)^inventory=\{\n.*?\n\}\n'
    path = os.path.join(root, "project.godot")
    text = read(path)
    m = re.search(block, text, flags=re.S)
    blk = m.group(0)
    write(path, text.replace(blk, blk.replace('"physical_keycode":4194306', '"physical_keycode":4194341'), 1))


def extra_action(root):
    sub_once(root, "project.godot", "[layer_names]",
             'debug_toggle={\n"deadzone": 0.2,\n"events": []\n}\n\n[layer_names]')


def i18n_line(root, line):
    """Put one line into [internationalization]. Godot drops default-valued settings when it saves the project, so
    the section (locale/fallback="en" is the default) is not in project.godot since wave 3: it is created in front of
    [layer_names] when it is absent."""
    path = os.path.join(root, "project.godot")
    text = read(path)
    if "[internationalization]\n" in text:
        write(path, text.replace("[internationalization]\n", "[internationalization]\n\n" + line + "\n", 1))
    else:
        sub_once(root, "project.godot", "[layer_names]", "[internationalization]\n\n" + line + "\n\n[layer_names]")


def fallback_da(root):
    path = os.path.join(root, "project.godot")
    if 'locale/fallback="en"' in read(path):
        sub_once(root, "project.godot", 'locale/fallback="en"', 'locale/fallback="da"')
    else:
        i18n_line(root, 'locale/fallback="da"')


def input_page_extra_pad_button(root, name):
    """One more pad event (Y) behind the contract events of a ui_page_* action: the action must be exactly PageUp / PageDown plus LB / RB."""
    block_edit(root, name, "\n]\n}\n", '\n, Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"button_index":3,"pressure":0.0,"pressed":true,"script":null)\n]\n}\n')


def people_pad_button(root):
    block_edit(root, "people", "\n]\n}\n", '\n, Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"button_index":8,"pressure":0.0,"pressed":true,"script":null)\n]\n}\n')


# check ids a qualified binding (Shift+W, left Shift only, device 0 only ...) must trip
QUALIFIED = ["p01.input_map_matches_contract", "p01.input_events_are_plain_unqualified"]
# check ids a broken PLAN 3.2 last row (ui_accept joy A, ui_cancel joy B, D-pad focus walk) must trip
UI_BROKEN = ["p01.input_map_matches_contract", "p01.ui_accept_cancel_take_joy_a_b_dpad_walks_focus"]
# check ids a broken pad paging (ui_page_up = PageUp + LB, ui_page_down = PageDown + RB, RB still on drink / rotate_item) must trip
UI_PAGE_BROKEN = ["p01.input_map_matches_contract", "project.input_map_matches_contract", "project.ui_page_pad_bindings"]
# check ids a broken `people` action (P, nothing else, 36 actions) must trip
PEOPLE_BROKEN = ["p01.input_map_matches_contract", "project.input_map_matches_contract"]

# the mutants that must be ACCEPTED: a fully green run, print_inputmap.gd green too
ACCEPT_MUTANTS = [(ACCEPT_ID, accept_features), (ACCEPT_SOCIAL_ID, accept_social_manager_only)]

# id -> (check ids that must FAIL, mutate(root))
MUTANTS = [
    ("texture_filter_3", ["p01.texture_filter_is_2"], lambda r: sub_once(r, "project.godot", "default_texture_filter=2", "default_texture_filter=3")),
    ("viewport_1080p", ["p01.viewport_1280x720"], lambda r: sub_once(r, "project.godot", "viewport_width=1280", "viewport_width=1920")),
    ("stretch_mode", ["p01.stretch_canvas_items_expand"], lambda r: sub_once(r, "project.godot", 'window/stretch/mode="canvas_items"', 'window/stretch/mode="viewport"')),
    ("window_override", ["p01.no_window_size_override"], lambda r: sub_once(r, "project.godot", "window/size/viewport_height=720", "window/size/viewport_height=720\nwindow/size/window_width_override=1920")),
    ("renderer_forward_plus", ["p01.renderer_gl_compatibility"], lambda r: sub_once(r, "project.godot", 'renderer/rendering_method="gl_compatibility"', 'renderer/rendering_method="forward_plus"')),
    ("renderer_mobile_default", ["p01.renderer_gl_compatibility"], lambda r: sub_once(r, "project.godot", 'renderer/rendering_method.mobile="gl_compatibility"\n', "")),
    ("s3tc_off", ["p01.s3tc_bptc_import_on"], lambda r: sub_once(r, "project.godot", "import_s3tc_bptc=true", "import_s3tc_bptc=false")),
    ("clear_color", ["p01.clear_color_sky_a9d3e0"], lambda r: sub_once(r, "project.godot", "default_clear_color=Color(0.6627451, 0.827451, 0.8784314, 1)", "default_clear_color=Color(0, 0, 0, 1)")),
    ("no_mipmap_default", ["p01.importer_default_texture_mipmaps"], lambda r: sub_once(r, "project.godot", '"mipmaps/generate": true', '"mipmaps/generate": false')),
    ("msaa_3d_back", ["p01.no_msaa_and_no_snap"], lambda r: append(r, "project.godot", "anti_aliasing/quality/msaa_3d=2\n")),
    ("translations_list_back", ["p01.no_locale_translations_list"], lambda r: i18n_line(r, 'locale/translations=PackedStringArray("res://localization/da.da.translation")')),
    ("fallback_da", ["p01.locale_fallback_en"], fallback_da),
    ("layer_renamed", ["p01.layer_names_2d_1_to_11"], lambda r: sub_once(r, "project.godot", '2d_physics/layer_3="npc"', '2d_physics/layer_3="npcs"')),
    ("layer_3d_back", ["p01.no_3d_layer_names"], lambda r: sub_once(r, "project.godot", '2d_physics/layer_1="world"', '2d_physics/layer_1="world"\n3d_physics/layer_1="world"')),
    ("animation_section_back", ["p01.no_animation_3d_key"], lambda r: sub_once(r, "project.godot", "[application]", "[animation]\n\ncompatibility/default_parent_skeleton_in_mesh_instance_3d=true\n\n[application]")),
    ("name_wrong", ["p01.name_is_traetoppen"], lambda r: sub_once(r, "project.godot", 'config/name="Trætoppen"', 'config/name="PongPong"')),
    ("forward_plus_feature", ["p01.features_4_7_gl_compatibility"], lambda r: sub_once(r, "project.godot", '"GL Compatibility"', '"Forward Plus"')),
    ("user_dir_off", ["p01.custom_user_dir"], lambda r: sub_once(r, "project.godot", "config/use_custom_user_dir=true", "config/use_custom_user_dir=false")),
    ("theme_removed", ["p01.gui_theme_custom"], lambda r: sub_once(r, "project.godot", 'theme/custom="res://assets/ui/theme.tres"', 'theme/custom=""')),
    ("input_inventory_f10", ["p01.input_map_matches_contract", "p01.inventory_i_and_tab_not_f10"], inventory_f10),
    ("input_action_removed", ["p01.input_map_matches_contract"], lambda r: regex_once(r, "project.godot", action_block("zoom_in"), "")),
    ("input_hotbar_removed", ["p01.input_map_matches_contract", "p01.input_has_38_actions_incl_hotbar", "project.input_has_38_actions_incl_hotbar"], lambda r: regex_once(r, "project.godot", action_block("hotbar_previous"), "")),
    ("input_addendum_removed", ["p01.input_map_matches_contract", "p01.input_has_38_actions_incl_hotbar", "project.input_has_38_actions_incl_hotbar"], lambda r: regex_once(r, "project.godot", action_block("pickup_item"), "")),
    ("input_wheel_on_rotate", ["p01.input_map_matches_contract", "p01.wheel_only_on_zoom"], wheel_on_rotate),
    ("input_extra_action", ["p01.input_map_matches_contract"], extra_action),
    ("input_unintended_clash", ["p01.input_map_matches_contract"], lambda r: sub_once(r, "project.godot", '"physical_keycode":69,', '"physical_keycode":70,')),
    # fix round RT3 task 2: ONE new action `people` = P (36 actions)
    ("input_people_removed", PEOPLE_BROKEN + ["p01.input_has_38_actions_incl_hotbar", "project.input_has_38_actions_incl_hotbar"], lambda r: regex_once(r, "project.godot", action_block("people"), "")),
    ("input_people_wrong_key", PEOPLE_BROKEN, lambda r: block_edit(r, "people", '"physical_keycode":80', '"physical_keycode":79')),
    ("input_people_on_inventory_key", PEOPLE_BROKEN, lambda r: block_edit(r, "people", '"physical_keycode":80', '"physical_keycode":73')),
    ("input_people_gets_a_pad_button", PEOPLE_BROKEN, people_pad_button),
    ("autoload_swapped", ["p01.autoloads_base_in_order_features_after"], swap_autoloads),
    ("autoload_removed", ["p01.autoloads_base_in_order_features_after"], lambda r: sub_once(r, "project.godot", 'ShopSystem="*res://scripts/economy/shop_system.gd"\n', "")),
    ("feature_autoload_too_early", ["p01.autoloads_base_in_order_features_after"], feature_before_animal),
    # fix round RT3: the SIXTH feature autoload (SocialManager) is accepted at its contract path only, once, behind the base block
    ("social_manager_wrong_path", ["p01.autoloads_base_in_order_features_after"], social_manager_wrong_path),
    ("social_manager_twice", ["p01.autoloads_base_in_order_features_after"], social_manager_twice),
    ("social_manager_too_early", ["p01.autoloads_base_in_order_features_after"], social_manager_before_animal),
    ("seventh_autoload_unknown", ["p01.autoloads_base_in_order_features_after"], seventh_autoload),
    ("gitignore_lock_missing", ["project.gitignore_has_feature_entries"], lambda r: sub_once(r, ".gitignore", "project.godot.lock\n", "")),
    ("gitignore_stage_missing", ["project.gitignore_has_feature_entries"], lambda r: sub_once(r, ".gitignore", "tools/features/reports/\n", "")),
    ("gitignore_import_back", ["p01.gitignore_commits_import_and_uid"], lambda r: append(r, ".gitignore", "*.import\n")),
    ("gitignore_translation_dropped", ["p01.gitignore_commits_import_and_uid", "p01.gitignore_keeps_base_and_tool_entries"], lambda r: sub_once(r, ".gitignore", "*.translation\n", "")),
    ("gitattributes_binary_missing", ["p01.gitattributes_binary_and_lfs_outside_godot"], lambda r: sub_once(r, ".gitattributes", "*.webp binary\n", "")),
    # REPO-01: an LFS pointer under assets/ would reach the importer in a clone without git-lfs
    ("gitattributes_lfs_on_assets", ["p01.gitattributes_binary_and_lfs_outside_godot"], lambda r: append(r, ".gitattributes", "assets/**/*.webp filter=lfs diff=lfs merge=lfs -text\n")),
    ("gitattributes_baselines_in_lfs", ["p01.gitattributes_binary_and_lfs_outside_godot"], lambda r: sub_once(r, ".gitattributes", "docs/qa/ui_baseline/*.png plain-blob\n", "")),
    ("gdignore_removed", ["p01.docs_gdignore_exists"], lambda r: remove_file(r, "docs/.gdignore")),
    ("stale_docs_import", ["p01.docs_has_no_stale_import_files"], lambda r: write(os.path.join(r, "docs", "audio", "stale.mp3.import"), "[remap]\n")),
    ("design_plan_missing", ["p01.design_files_exist"], lambda r: remove_file(r, "docs/design/PLAN_2D_FEATURES.md")),
    ("design_link_missing", ["p01.design_plan_links_addendum_and_supersede_line"], lambda r: sub_once(r, "docs/design/PLAN_2D.md", "](features_workpackages.json)", "](workpackages.json)")),
    ("design_supersede_line_missing", ["p01.design_plan_links_addendum_and_supersede_line"], lambda r: sub_once(r, "docs/design/PLAN_2D.md", "supersedes for the features:", "supersedes:")),
    # the retired town name is assembled at runtime so that no repo file spells it out (team rule)
    ("design_old_town_name", ["p01.design_files_use_current_town_name"], lambda r: append(r, "docs/design/PLAN_2D.md", "\nThe town is called " + "Fes" + "by.\n")),
    # fix round RT3: the scan covers EVERY file of docs/design (other documents, nested folders, file names), not only the plan and the features pair
    ("design_old_town_name_in_ui_navigation", ["p01.design_files_use_current_town_name"], lambda r: append(r, "docs/design/UI_NAVIGATION.md", "\nThe town is called " + "Fes" + "by.\n")),
    ("design_old_town_name_in_towns_json", ["p01.design_files_use_current_town_name"], lambda r: append(r, "docs/design/towns_farm_social_workpackages.json", " " + "Fes" + "by")),
    ("design_old_town_name_in_nested_file", ["p01.design_files_use_current_town_name"], lambda r: write(os.path.join(r, "docs", "design", "clock26", "note.txt"), "in " + "Fes" + "by\n")),
    ("design_old_town_name_in_a_file_name", ["p01.design_files_use_current_town_name"], lambda r: write(os.path.join(r, "docs", "design", "fes" + "by_notes.md"), "notes\n")),
    # fix round RT3: the towns addendum is linked from the plan header with its own NEW supersede line
    ("design_towns_addendum_missing", ["p01.design_plan_links_towns_addendum"], lambda r: remove_file(r, "docs/design/TOWNS_FARM_SOCIAL_ADDENDUM.md")),
    ("design_towns_workpackages_missing", ["p01.design_plan_links_towns_addendum"], lambda r: remove_file(r, "docs/design/towns_farm_social_workpackages.json")),
    ("design_towns_addendum_link_missing", ["p01.design_plan_links_towns_addendum"], lambda r: sub_once(r, "docs/design/PLAN_2D.md", "](TOWNS_FARM_SOCIAL_ADDENDUM.md)", "](TOWNS.md)")),
    ("design_towns_workpackages_link_missing", ["p01.design_plan_links_towns_addendum"], lambda r: sub_once(r, "docs/design/PLAN_2D.md", "](towns_farm_social_workpackages.json)", "](workpackages.json)")),
    ("design_towns_supersede_line_missing", ["p01.design_plan_links_towns_addendum"], lambda r: sub_once(r, "docs/design/PLAN_2D.md", "supersedes for the towns, the farm and the social sim:", "supersedes:")),
    ("design_features_supersede_line_rewritten_by_towns", ["p01.design_plan_links_towns_addendum", "p01.design_plan_links_addendum_and_supersede_line"], lambda r: sub_once(r, "docs/design/PLAN_2D.md", "supersedes for the features:", "supersedes for the features and towns:")),
    ("fixture_missing", ["p01.fixture_present"], lambda r: remove_file(r, "tests/tools/fixtures/project_with_feature_autoloads.txt")),
    ("obsolete_dir_back", ["p01.obsolete_3d_asset_dirs_gone"], lambda r: os.makedirs(os.path.join(r, "assets", "models"), exist_ok=True)),
    ("stale_style_guide_import", ["p01.docs_has_no_stale_import_files"], lambda r: write(os.path.join(r, "docs", "Tr\u00e6toppen Style Guide Review", "refs", "stale.jpg.import"), "[remap]\n")),
    # fix round: events that only match under a qualifier (modifier, key location, device)
    ("input_shift_on_move_forward", QUALIFIED, lambda r: block_edit(r, "move_forward", '"shift_pressed":false', '"shift_pressed":true')),
    ("input_ctrl_on_inventory", QUALIFIED, lambda r: block_edit(r, "inventory", '"ctrl_pressed":false', '"ctrl_pressed":true')),
    ("input_alt_on_journal", QUALIFIED, lambda r: block_edit(r, "journal", '"alt_pressed":false', '"alt_pressed":true')),
    ("input_meta_on_pause", QUALIFIED, lambda r: block_edit(r, "pause", '"meta_pressed":false', '"meta_pressed":true')),
    ("input_command_or_control_on_interact", QUALIFIED, lambda r: block_edit(r, "interact", '"meta_pressed":false', '"meta_pressed":false,"command_or_control_autoremap":true')),
    ("input_shift_on_mouse_button", QUALIFIED, lambda r: block_edit(r, "use_tool", '"shift_pressed":false', '"shift_pressed":true')),
    ("input_left_shift_only_on_run", QUALIFIED, lambda r: block_edit(r, "run", '"location":0', '"location":1')),
    ("input_device_0_on_jump_key", QUALIFIED, lambda r: block_edit(r, "jump", '"device":-1', '"device":0')),
    ("input_device_1_on_interact_pad", QUALIFIED, lambda r: block_edit(r, "interact", '"device":-1,"button_index":0', '"device":1,"button_index":0')),
    # fix round: PLAN 3.2 last row, joy A / B on the focus navigation
    ("ui_accept_override_removed", UI_BROKEN, lambda r: regex_once(r, "project.godot", action_block("ui_accept"), "")),
    ("ui_cancel_override_removed", UI_BROKEN, lambda r: regex_once(r, "project.godot", action_block("ui_cancel"), "")),
    ("ui_accept_pad_button_is_x", UI_BROKEN, lambda r: block_edit(r, "ui_accept", '"button_index":0', '"button_index":2')),
    ("ui_cancel_loses_escape", UI_BROKEN, lambda r: block_edit(r, "ui_cancel", '"keycode":4194305', '"keycode":4194306')),
    ("ui_accept_space_replaced", UI_BROKEN, lambda r: block_edit(r, "ui_accept", '"keycode":32', '"keycode":90')),
    # fix round UI.1: pad paging, ui_page_up = PageUp + LB (joy 9), ui_page_down = PageDown + RB (joy 10)
    ("ui_page_up_override_removed", UI_PAGE_BROKEN, lambda r: regex_once(r, "project.godot", action_block("ui_page_up"), "")),
    ("ui_page_down_override_removed", UI_PAGE_BROKEN, lambda r: regex_once(r, "project.godot", action_block("ui_page_down"), "")),
    ("ui_page_up_pad_button_is_y", UI_PAGE_BROKEN, lambda r: block_edit(r, "ui_page_up", '"button_index":9', '"button_index":3')),
    ("ui_page_down_pad_button_is_lb", UI_PAGE_BROKEN, lambda r: block_edit(r, "ui_page_down", '"button_index":10', '"button_index":9')),
    ("ui_page_up_loses_pageup_key", UI_PAGE_BROKEN, lambda r: block_edit(r, "ui_page_up", '"keycode":4194323', '"keycode":4194322')),
    ("ui_page_down_loses_pagedown_key", UI_PAGE_BROKEN, lambda r: block_edit(r, "ui_page_down", '"keycode":4194324', '"keycode":4194322')),
    ("ui_page_up_extra_pad_button", UI_PAGE_BROKEN, lambda r: input_page_extra_pad_button(r, "ui_page_up")),
    ("ui_page_down_extra_pad_button", UI_PAGE_BROKEN, lambda r: input_page_extra_pad_button(r, "ui_page_down")),
    ("rb_taken_off_drink", UI_PAGE_BROKEN, lambda r: block_edit(r, "drink", '"button_index":10', '"button_index":8')),
    ("rb_taken_off_rotate_item", UI_PAGE_BROKEN, lambda r: block_edit(r, "rotate_item", '"button_index":10', '"button_index":8')),
]

# the mutants that must also be caught by print_inputmap.gd (they touch the input map)
INPUTMAP_MUTANTS = {"input_inventory_f10", "input_action_removed", "input_addendum_removed", "input_wheel_on_rotate",
                    "input_extra_action", "input_unintended_clash", "input_hotbar_removed"} | {m[0] for m in MUTANTS if m[1] is QUALIFIED or m[1] is UI_BROKEN or m[1] is UI_PAGE_BROKEN or m[0].startswith("input_people_")}


def isolated_env(project):
    """A throw-away HOME inside the copy (deleted with it): parallel runs never share user:// (Godot's user data dir hangs off HOME)."""
    home = os.path.join(project, ".mutation_home")
    os.makedirs(home, exist_ok=True)
    env = dict(os.environ)
    env["HOME"] = home
    return env


def run_check(project, isolate=False):
    cmd = [GODOT, "--headless", "--path", project, "-s", "res://tests/tools/check_project.gd"]
    p = subprocess.run(cmd, capture_output=True, text=True, timeout=300, env=isolated_env(project) if isolate else None)
    out = p.stdout + "\n" + p.stderr
    fails = set(re.findall(r"^FAIL (\S+?):", out, flags=re.M))
    passes = set(re.findall(r"^PASS (\S+)", out, flags=re.M))
    return p.returncode, fails, passes, out


def run_inputmap(project, isolate=False):
    cmd = [GODOT, "--headless", "--path", project, "-s", "res://tests/tools/print_inputmap.gd"]
    p = subprocess.run(cmd, capture_output=True, text=True, timeout=300, env=isolated_env(project) if isolate else None)
    out = p.stdout + "\n" + p.stderr
    return p.returncode, ("P01 INPUTMAP OK" in out), out


def clone_project(src, dst):
    r = subprocess.run(["cp", "-Rc", src, dst], capture_output=True)
    if r.returncode != 0:
        shutil.rmtree(dst, ignore_errors=True)
        shutil.copytree(src, dst, symlinks=True)
    shutil.rmtree(os.path.join(dst, ".git"), ignore_errors=True)


def run_mutant(project, work, base_fails, mid, expected, mutate):
    """One mutant in its own copy of the project: returns (ok, report lines). Independent of every other mutant, so --jobs can run several at once."""
    dst = os.path.join(work, mid)
    clone_project(project, dst)
    map_rc, map_ok = None, None
    try:
        mutate(dst)
        rc, fails, passes, out = run_check(dst, isolate=True)
        if mid in INPUTMAP_MUTANTS or mid in ACCEPT_IDS:
            map_rc, map_ok, _ = run_inputmap(dst, isolate=True)
    except RuntimeError as e:
        # the anchor of the edit is gone from the file: the mutant tests nothing, so it counts as wrong (never a silent pass, never a crash that hides the rest)
        return False, ["%-34s FAIL  the mutation could not be applied: %s" % (mid, e)]
    finally:
        shutil.rmtree(dst, ignore_errors=True)
    new_fails = fails - base_fails
    lines = []
    if mid in ACCEPT_IDS:
        ok = rc == (1 if base_fails else 0) and not new_fails and map_rc == 0 and map_ok
        lines.append("%-34s %s  (exit %d, new failures: %s, print_inputmap exit %s)" % (mid, "ok  " if ok else "FAIL", rc, sorted(new_fails) or "none", map_rc))
        return ok, lines
    missing = [e for e in expected if e not in fails]
    ok = rc != 0 and not missing
    map_note = ""
    if map_rc is not None:
        map_caught = map_rc != 0 and not map_ok
        ok = ok and map_caught
        map_note = "; print_inputmap exit %d" % map_rc
    lines.append("%-34s %s  caught by %s%s" % (mid, "ok  " if ok else "FAIL", sorted(new_fails) or "NOTHING", map_note))
    if missing:
        lines.append("    expected to fail but did not: %s" % missing)
    if map_rc is not None and not (map_rc != 0 and not map_ok):
        lines.append("    print_inputmap.gd did not reject this mutant (exit %d, OK line %s)" % (map_rc, "present" if map_ok else "absent"))
    return ok, lines


def main():
    sys.stdout.reconfigure(line_buffering=True)   # one line per mutant while the run is still going (the log is read live)
    ap = argparse.ArgumentParser()
    ap.add_argument("--project", required=True, help="test copy of the repo (never the real repo)")
    ap.add_argument("--only", default="", help="comma list of mutant ids")
    ap.add_argument("--workdir", default="")
    ap.add_argument("--jobs", type=int, default=1, help="mutants run at the same time (each in its own copy; the report keeps the list order)")
    args = ap.parse_args()
    project = os.path.abspath(args.project)
    if not os.path.isfile(os.path.join(project, "project.godot")):
        print("not a Godot project: %s" % project)
        return 2
    work = args.workdir or tempfile.mkdtemp(prefix="p01_mut_")
    os.makedirs(work, exist_ok=True)
    only = [s for s in args.only.split(",") if s]
    problems = []
    try:
        rc, base_fails, base_passes, _ = run_check(project)
        print("control (unmutated copy): exit %d, %d passed, failing: %s" % (rc, len(base_passes), sorted(base_fails) or "none"))
        map_rc, map_ok, _ = run_inputmap(project)
        print("control print_inputmap.gd: exit %d, OK line %s" % (map_rc, "present" if map_ok else "ABSENT"))
        if map_rc != 0 or not map_ok:
            problems.append("control print_inputmap")
        todo = [(i, e, f) for (i, e, f) in MUTANTS if not only or i in only]
        for aid, afn in ACCEPT_MUTANTS:
            if not only or aid in only:
                todo.append((aid, [], afn))
        unknown = [o for o in only if o not in {m[0] for m in MUTANTS} | ACCEPT_IDS]
        if unknown:
            print("unknown mutant id(s) in --only: %s" % unknown)
            problems.extend(unknown)
        with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, args.jobs)) as pool:
            futures = [(mid, pool.submit(run_mutant, project, work, base_fails, mid, expected, mutate)) for mid, expected, mutate in todo]
            for mid, fut in futures:                      # in list order, whichever finishes first
                ok, lines = fut.result()
                for line in lines:
                    print(line)
                if not ok:
                    problems.append(mid)
    finally:
        if not args.workdir:
            shutil.rmtree(work, ignore_errors=True)
    print("mutants: %d checked, %d wrong" % (len(todo), len(problems)))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
