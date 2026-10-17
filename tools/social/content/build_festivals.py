#!/usr/bin/env python3
"""Export hand-authored bilingual festival content to the literal Lua registries."""
from pathlib import Path
import argparse
import csv
import io
import json
import re

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
KEEP = '[remap]\n\nimporter="keep"\n'

def lua(value, depth=0):
    if isinstance(value, bool): return 'true' if value else 'false'
    if isinstance(value, str): return json.dumps(value, ensure_ascii=False)
    if isinstance(value, (int, float)): return str(value)
    pairs = [(str(k)+' = ',v) for k,v in value.items()] if isinstance(value,dict) else [('',v) for v in value]
    if not pairs: return '{}'
    indent = '  '*(depth+1)
    return '{\n'+''.join(indent+k+lua(v,depth+1)+',\n' for k,v in pairs)+'  '*depth+'}'

def build():
    reference = json.loads((ROOT/'tests/lib/social/fixtures/design_dump.json').read_text())['festivals']
    authored = json.loads((HERE/'festivals.json').read_text())
    assert len(authored) == 9
    rows = []
    files = {}
    family = ['ghostfam_dyne','ghostfam_gnist','ghostfam_silke','ghostfam_blund']
    for fid,copy in authored.items():
        data = json.loads(json.dumps(reference[fid]))
        meta = data['meta']
        meta['stays_open'] = [s for s in meta.get('stays_open',[]) if s != 'seed_shop']
        meta['first' if meta['area']=='traetoppen' else 'guests'] = family
        meta['leave_early'] = {'ghostfam_gnist':2.75 if fid=='badedagen' else 1.5 if fid=='aarsskiftet' else 1.25}
        prefix = 'FEST_'+fid.upper()+'_'
        rows += [[prefix+'NAME',*copy['name']],[prefix+'DESC',*copy['desc']]]
        for index,activity in enumerate(data['activities']):
            rows.append([activity['name_key'],*copy['activities'][index]])
        if 'prizes' in copy:
            data['rewards']['contest'] = {tier:{'items':prize} for tier,prize in zip(['first','second','third'],copy['prizes'])}
        for suffix in ['open','end']:
            event_id = 'ev_'+fid+'_'+suffix
            steps = [{'act':'camera','focus':meta['host'],'zoom':0.6,'time':0.25}]
            for index,text in enumerate(copy[suffix],1):
                key = prefix+suffix.upper()+'_'+str(index)
                rows.append([key,*text])
                steps.append({'act':'say','who':meta['host'],'text_key':key})
            steps += [{'act':'clip','who':meta['host'],'clip':'celebrate'},{'act':'camera','focus':'player','zoom':0.4,'time':0.25}]
            event = {'meta':{'trigger':'festival','festival':fid,'once_per_year':True,'area':meta['area'],'title_key':meta['name_key']},'steps':steps,'rewards':{'points':0}}
            file = ROOT/'lua/events/festivals'/(event_id+'.lua')
            files[file] = '-- Generated from tools/social/content/festivals.json.\nkind = "registry"\nregistry = "events"\nevents = '+lua({event_id:event})+'\n'
        if any(a['kind']=='potluck' for a in data['activities']):
            data['rewards']['potluck'] = {'items':{'cookie':2}}
        file = ROOT/'lua/festivals/fixed'/(fid+'.lua')
        files[file] = '-- Calendar and activity schema: towns/social addendum; copy: tools/social/content/festivals.json.\nkind = "registry"\nregistry = "festivals"\nfestivals = '+lua({fid:data})+'\n'
    markets = {}
    for name,da,en,stock in [
        ('flower','Frøboden','Seed stall',{'carrot_seeds':25,'sunflower_seeds':15,'strawberry_seeds':10}),
        ('honey','Honningboden','Honey stall',{'honey':12,'cookie':12,'milk':10}),
        ('harvest','Høstmarked','Harvest market',{'pumpkin_seeds':15,'carrot_seeds':25,'fertilizer':20}),
        ('moon','Måneboden','Moon stall',{'amethyst':3,'glow_mushroom':10,'lantern_oil':12}),
        ('bake','Bageboden','Bake stall',{'cookie':20,'honey':10,'milk':10})]:
        key = 'FEST_MARKET_'+name.upper()
        rows += [[key+'_NAME',da,en],[key+'_GREETING','Kig bare. Vi deler det gode ved dagens fest.','Take a look. We are sharing the good things of today.']]
        keeper = {'flower':'mayor_lyra','honey':'beekeeper_birk','harvest':'mayor_lyra','moon':'appraiser_fru_ugle','bake':'baker_maja'}[name]
        markets['fest_'+name+'_market'] = {'name_key':key+'_NAME','keeper':keeper,'greeting_key':key+'_GREETING','festival_stall':True,'buy_multiplier':1.0,'sell_multiplier':1.0,'stock':{k:{'stock':v,'restock':v} for k,v in stock.items()}}
    files[ROOT/'lua/shops/festival_markets.lua'] = '-- Generated festival shelves; prices come from the item definitions.\nkind = "shops"\nshops = '+lua(markets)+'\n'
    output = io.StringIO(newline='')
    writer = csv.writer(output,lineterminator='\n')
    writer.writerow(['keys','da','en']);writer.writerows(rows)
    assert len(rows) == len({r[0] for r in rows})
    files[ROOT/'localization/festivals.csv'] = output.getvalue()
    for file in list(files): files[file.with_suffix(file.suffix+'.import')] = KEEP
    return files

def main():
    parser = argparse.ArgumentParser();parser.add_argument('--check',action='store_true');args=parser.parse_args()
    stale = []
    for path,text in build().items():
        if args.check:
            if not path.exists() or path.read_text()!=text: stale.append(str(path.relative_to(ROOT)))
        else:
            path.parent.mkdir(parents=True,exist_ok=True);path.write_text(text)
    if stale: raise SystemExit('stale: '+', '.join(stale))
    print('Nine festivals, eighteen scenes and five markets '+('verified' if args.check else 'exported'))

if __name__=='__main__': main()
