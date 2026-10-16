#!/usr/bin/env python3
"""Exercise the reviewed fourteen generator mutants in one disposable copy.
A compile/engine error never counts as detecting a logic defect. At least twelve
mutants must be caught by actual assertions. Every survivor is reported for
review. Source files in the working tree are never edited.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import sys
ROOT = Path(__file__).resolve().parents[2]
MUTANTS = [('M1_no_final_island_repair',
  'dungeon_gen.gd',
  '\tfl.stats["repaired_b"] = _repair_islands(fl)',
  '\tfl.stats["repaired_b"] = 0',
  'no_unreachable_floor_islands|first_attempt_rate|mean_attempts'),
 ('M2_can_block_always_true',
  'dungeon_gen.gd',
  '\tvar k: int = n + e + s + wv\n\tif k == 0:\n\t\treturn true',
  '\treturn true\n\tvar k: int = n + e + s + wv\n\tif k == 0:\n\t\treturn true',
  'no_unreachable_floor_islands|every_marker_reachable_from_spawn|first_attempt_rate|mean_attempts'),
 ('M3_solid_ok_always_true',
  'dungeon_gen.gd',
  '\tvar free_n: int = 0\n\tfor o in DIRS:\n\t\tif _free(fl, x + o.x, y + o.y):',
  '\treturn true\n\tvar free_n: int = 0\n\tfor o in DIRS:\n\t\tif _free(fl, x + o.x, y + o.y):',
  'every_marker_reachable_from_spawn|first_attempt_rate|mean_attempts'),
 ('M4_crown_protect_ignored',
  'dungeon_export.gd',
  ' or prot_ov > 0',
  '',
  'no_feature_or_spawn_under_a_crown_disc'),
 ('M5_crown_walk_overlap_unbounded',
  'dungeon_export.gd',
  'const WALK_OVERLAP: Array[int] = [2, 3, 4]',
  'const WALK_OVERLAP: Array[int] = [40, 60, 90]',
  'rim_crown_walk_overlap_at_most_4_cells'),
 ('M6_mirror_after_canopy',
  'dungeon_gen.gd',
  '\t_mirror(fl, rng)           # before the canopy: a crown disc is not mirror-symmetric (it rises above '
  'its anchor)\n',
  '',
  'no_feature_or_spawn_under_a_crown_disc',
  '\tfl.stats["repaired_b"] = _repair_islands(fl)',
  '\tfl.stats["repaired_b"] = _repair_islands(fl)\n\t_mirror(fl, rng)'),
 ('M7_enemy_distance_guard_removed',
  'dungeon_gen.gd',
  'and _d2(sp2.x, sp2.y, ex, ey) >= 14 * 14:',
  'and true:',
  'no_enemy_near_spawn'),
 ('M8_boss_hulen_not_sealed',
  'dungeon_gen.gd',
  '{"to": floor_no + 1, "sealed": boss}',
  '{"to": floor_no + 1, "sealed": false}',
  'hulen_sealed_iff_boss_floor'),
 ('M9_border_1_cell',
  'dungeon_gen.gd',
  'const BORDER: int = 3',
  'const BORDER: int = 1',
  'forest_border_of_3_cells_is_not_walkable'),
 ('M10_day_ignored_by_seed_hash',
  'dungeon_rng.gd',
  'h1 = fmix32(h1 ^ mul32(d_lo, 0x9E3779B1))',
  'h1 = fmix32(h1 ^ mul32(0, 0x9E3779B1))',
  'SEEDS_FAIL'),
 ('M11_lake_chest_off_the_shore',
  'dungeon_gen.gd',
  '\t\t\t\t\tif not by_pond or not can_block(fl, x, y):\n\t\t\t\t\t\tcontinue',
  '\t\t\t\t\tif not can_block(fl, x, y):\n\t\t\t\t\t\tcontinue',
  'lake_chest_stands_on_a_pond_shore'),
 ('M12_moonstone_not_placed',
  'dungeon_gen.gd',
  '\tfor nk in node_kinds:\n\t\tfor k in int((spec["nodes"] as Dictionary)[nk]):',
  '\tfor nk in node_kinds:\n'
  '\t\tif str(nk) == "moonstone":\n'
  '\t\t\tcontinue\n'
  '\t\tfor k in int((spec["nodes"] as Dictionary)[nk]):',
  'generation_failed|required_node_kinds_are_exact'),
 ('M13_ambush_tutorial_distance_removed',
  'dungeon_gen.gd',
  'var lo: int = 150 if (made_amb == 0 and floor_no <= 2) else 14 * 14',
  'var lo: int = 0',
  'tutorial_ambush_6_to_11_cells_from_spawn|no_enemy_near_spawn'),
 ('M14_nook_distance_removed_and_spur_open',
  'dungeon_gen.gd',
  '\t\t\t\t\tif fl.ground[ni] != G_WALL:\n\t\t\t\t\t\tok = false',
  '\t\t\t\t\tpass',
  'nook_features_sit_in_hidden_dead_ends|no_unreachable_floor_islands|every_marker_reachable_from_spawn')]

def main():
    destination = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(tempfile.mkdtemp(prefix="dungeon-mutant-reports-"))
    destination.mkdir(parents=True,exist_ok=True)
    rows=[]
    with tempfile.TemporaryDirectory(prefix="traetoppen-mutants-") as scratch:
        copy=Path(scratch)/"repo"
        if sys.platform == "darwin":
            subprocess.run(["cp","-Rc",str(ROOT)+"/.",str(copy)],check=True)
        else:
            shutil.copytree(ROOT,copy,ignore=shutil.ignore_patterns(".git"))
        for mutant in MUTANTS:
            name,filename,old,new,expected,*extra=mutant
            path=copy/"scripts/dungeon/gen"/filename
            original=path.read_text()
            if old not in original or (extra and extra[0] not in original):
                raise RuntimeError(f"stale mutation pattern: {name}")
            patched=original.replace(old,new)
            if extra: patched=patched.replace(extra[0],extra[1],1)
            path.write_text(patched)
            report=destination/(name+".json")
            try:
                result=subprocess.run(["tests/run_playtest.sh","--no-import","--fast","--strict","--no-boot","--only=dungeon_gen",f"--report={report}"],cwd=copy,capture_output=True,text=True,timeout=180)
                (destination/(name+".log")).write_text(result.stdout+result.stderr)
                data=json.loads(report.read_text())
                engine=data.get("engine",[])
                valid=not engine and not data.get("problems",[])
                failures=data.get("failures",[])
                killed=valid and result.returncode == 1 and bool(failures)
                rows.append({"name":name,"killed":killed,"valid_run":valid,"failures":failures,"survived":valid and not killed})
                print(name,"KILLED" if killed else "SURVIVED" if valid else "INVALID",flush=True)
            finally:
                path.write_text(original)
    killed=sum(r["killed"] for r in rows)
    payload={"total":len(rows),"killed":killed,"rows":rows}
    (destination/"summary.json").write_text(json.dumps(payload,indent=2)+"\n")
    print(f"killed {killed} of {len(rows)}; reports {destination}")
    return 0 if killed >= 12 and all(r["valid_run"] for r in rows) else 1

if __name__ == "__main__":
    raise SystemExit(main())
