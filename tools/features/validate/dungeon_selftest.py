"""Real-data control and independent one-defect probes for the dungeon rules."""
import copy
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import dungeon_rules

ROOT=Path(__file__).resolve().parents[3]

def run(check):
    with tempfile.TemporaryDirectory(prefix='dungeon-rule-probes-') as directory:
        out=Path(directory)/'lua.json'
        subprocess.run([shutil.which('lua5.4') or 'lua',str(ROOT/'tools/features/validate/ser.lua'),str(out),*[str(p.relative_to(ROOT)) for p in sorted((ROOT/'lua').rglob('*.lua'))]],cwd=ROOT,check=True,capture_output=True)
        live={r['file']:r['globals'] for r in json.loads(out.read_text())}
    result=dungeon_rules.validate(live)
    check('dl_control_all_rules_pass',not any(result.values()),str({k:v for k,v in result.items() if v}))
    def probe(name,rule,mutate):
        data=copy.deepcopy(live);mutate(data)
        findings=dungeon_rules.validate(data)
        check('dl_'+name,any(k.split()[0]==rule and v for k,v in findings.items()),str({k:v for k,v in findings.items() if v}))
    def cfg(data,path,key):return data['lua/config/'+path+'.lua']['config'][key]
    probe('weapon_damage_30_percent','W1',lambda x:x['lua/items/weapons.lua']['items']['wpn_dagger_thorn'].update(damage=4))
    probe('recipe_buy_cost','W5',lambda x:x['lua/recipes/dungeon.lua']['recipes']['dng_forge_dagger_thorn']['ingredients'].update(wood=100))
    probe('legendary_shop_pool','R7',lambda x:x['lua/shops/smithy.lua']['shops']['smithy']['rotation'][0]['pool'].append('wpn_sword_moon'))
    probe('unique_appraisal_pool','G3',lambda x:cfg(x,'dungeon_loot','dungeon_loot')['appraisal']['pools']['rare'].append({'item':'gem_rune_heart','w':10}))
    probe('orphan_shard','K1',lambda x:x['lua/data/loot_tables.lua']['config']['loot']['boss']['snurresvamp']['first_kill_items'].clear())
    probe('spot_wrong_floor','DB4',lambda x:x['lua/data/loot_tables.lua']['config']['loot']['spots']['soeskatten_skov'].update(floor=4))
    probe('boss_wrong_floor','DB2',lambda x:cfg(x,'bosses','bosses')['snurresvamp'].update(floor=5))
    probe('material_sell_too_high','M2',lambda x:x['lua/items/dungeon_materials.lua']['items']['dng_resin'].update(sell_price=4))
    probe('unused_node_yield','DB5',lambda x:cfg(x,'dungeon_loot','dungeon_loot')['node_yields'].update(unplaced_probe={'item':'wood','amount':[1,1]}))
    probe('cyclic_node_alias','DB5',lambda x:cfg(x,'dungeon_loot','dungeon_loot')['node_yields']['crystal'].update(alias='amethyst'))
    probe('static_band_node_source','M1',lambda x:x['lua/items/dungeon_materials.lua']['items']['dng_resin']['sources'].append({'kind':'node','node':'steel_vein','zone':'skovkant'}))
