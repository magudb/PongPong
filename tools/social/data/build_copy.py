#!/usr/bin/env python3
"""Author the LEAN social CSVs from editable citizen profiles.

Core copy keeps weather/season variants in shared pools so first meetings,
hearts bands and personal topics fit the 346/300/133/25 row budgets. Chat
milestones remain text until the separate listening test approves more voice.
No audio is generated. Edit profiles.json and/or the final CSV prose for review.
"""
from pathlib import Path
import csv, json, re, sys
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'tools/copy'))
import copy_lint

def build(root=ROOT):
    profiles=json.loads((root/'tools/social/data/profiles.json').read_text())
    citizens=copy_lint.entries(root/'lua/social/citizens.lua','citizens')
    buckets={name:[] for name in ['social_talk','social_arch','gifts','birthdays']}
    def row(file,key,da,en):buckets[file].append([key,da,en])
    greets=[('Godt at se dig. Jeg tænkte netop på {d}.','Good to see you. I was just thinking about {d}.'),
            ('Kom nærmere. Der er altid plads ved {p}.','Come closer. There is always room by {p}.'),
            ('Jeg har gemt en lille historie om {d} til dig.','I saved a little story about {d} for you.'),
            ('Du kender vejen til {p} nu. Jeg er glad for dit selskab.','You know the way to {p} now. I am glad of your company.')]
    chats=[('Jeg blev nysgerrig på {d} allerede som lille. Det er rart at dele det med dig.','I have been curious about {d} since I was little. It is lovely to share that with you.'),
           ('Ved {p} finder jeg altid en rolig stund. Du må gerne blive lidt.','I always find a quiet moment by {p}. You are welcome to stay a while.'),
           ('Jeg troede engang, at jeg vidste alt om {d}. Så fandt jeg noget nyt.','I once thought I knew everything about {d}. Then I found something new.'),
           ('Nogle dage går jeg bare forbi {p} og lytter. Det hjælper at tage sig tid.','Some days I just pass by {p} and listen. Taking time helps.'),
           ('Du har hørt mange af mine historier om {d}. Jeg vil også gerne høre dine.','You have heard many of my stories about {d}. I would love to hear yours too.')]
    topics={
        'mayor_lyra':[('Rosenkjolen','The rose gown','dress_gown_rose'),('Sølvdiademet','The silver tiara','circlet_tiara_silver'),('Honningkagen','The honey cake','honey_cake')],
        'baker_maja':[('Melet','The flour','flour'),('Honningen','The honey','honey'),('Jordbærrene','The strawberries','strawberry')],
        'merchant_pip':[('Måneblomsten','The moonflower','moonflower'),('Lysbærrene','The glowberries','glow_berry'),('Solsikken','The sunflower','sunflower')],
        'gardener_hoppe':[('Guleroden','The carrot','carrot'),('Måneblomsten','The moonflower','moonflower'),('Bregnen','The fern','plant_fern')],
        'carpenter_brumme':[('Honningen','The honey','honey'),('Bjælken','The beam','timber_beam'),('Egeplanken','The oak plank','plank_oak')],
        'postman_pip':[('Æblet','The apple','apple'),('De gule gummistøvler','The yellow wellies','shoes_wellies_yellow'),('Den blå kasket','The blue cap','hat_cap_blue')],
        'bathkeeper_sofus':[('Honningkagen','The honey cake','honey_cake'),('De bløde tøfler','The soft slippers','shoes_slippers_cream'),('Det vævede tæppe','The woven rug','rug_natural')],
        'beekeeper_birk':[('Honningen','The honey','honey'),('Honningkagen','The honey cake','honey_cake'),('Solsikken','The sunflower','sunflower')],
        'smith_thorin':[('Jernbarren','The iron ingot','iron_ingot'),('Jernmalmen','The iron ore','iron_ore'),('Kobbermalmen','The copper ore','copper_ore')],
        'farmer_rosa':[('Ægget','The egg','egg'),('Mælken','The milk','milk'),('Ulden','The wool','wool')],
    }
    reveals={}
    for npc,block in citizens.items():
        if npc not in profiles:raise ValueError('Missing profile: '+npc)
        p=profiles[npc];tier=copy_lint.field(block,'tier');key='SOC_'+npc.upper()+'_'
        row('social_talk',key+'FIRST_1_V',p['first_da'],p['first_en'])
        count={'A':4,'B':2,'C':1}[tier]
        for band in range(count):
            da,en=greets[band]
            # One tier-A headline is voiced; the others stay text.
            voiced='_V' if tier=='A' and band==0 else ''
            row('social_talk',key+f'GREET_H{band}_1'+voiced,da.format(d=p['detail_da'],p=p['place_da']),en.format(d=p['detail_en'],p=p['place_en']))
        for i in ([0,1,2,3,4] if tier=='A' else [1,3] if tier=='B' else []):
            da,en=chats[i];row('social_talk',key+f'CHAT_H{[2,4,6,8,10][i]}_1',da.format(d=p['detail_da'],p=p['place_da']),en.format(d=p['detail_en'],p=p['place_en']))
        if tier=='A':
            reveals[npc]=[]
            for n,(da,en,item) in enumerate(topics[npc],1):
                row('social_talk',key+f'TOPIC_{n}',da,en)
                row('social_talk',key+f'TOPIC_ANSWER_{n}',f'{da} minder mig om noget rart. Det er en af mine yndlingsting.',f'{en} reminds me of something lovely. It is one of my favourite things.')
                reveals[npc].append(dict(item=item,hearts=[2,5,8][n-1],choice_key=key+f'TOPIC_{n}',answer_key=key+f'TOPIC_ANSWER_{n}'))
        for i,(da,en) in enumerate([('En stille stund.','A quiet moment.'),('Nogen kommer forbi.','Someone is passing by.'),('Bladene rasler igen.','The leaves rustle again.')][:3 if tier=='A' else 2 if tier=='B' else 0],1):
            row('social_talk',key+f'BARK_{i}',da,en)
        row('social_talk',key+'BIO_1',f"Du møder mig ved {p['place_da']}. Jeg holder af {p['detail_da']} og af de små samtaler, der gør Trætoppen hjemlig.",f"You will find me by {p['place_en']}. I love {p['detail_en']} and the little conversations that make Trætoppen feel like home.")
        if tier in ['A','B']:
            reactions=[('LOVE','Du har fundet noget, jeg holder særligt af. Tak!','You found something I especially love. Thank you!'),('LIKE','Hvor betænksomt. Den her bliver jeg glad for.','How thoughtful. I will enjoy this.'),('NEUTRAL','Tak, fordi du tænkte på mig.','Thank you for thinking of me.'),('DISLIKE','Tak for tanken. En anden kan måske bruge den bedre.','Thank you for the thought. Someone else might enjoy it more.'),('HATE','Det var venligt af dig. Den her passer bare ikke helt til mig.','That was kind of you. This one just is not quite for me.')]
            for taste,da,en in reactions:
                voiced='_V' if tier=='A' else ''
                row('gifts','GIFT_'+npc.upper()+'_'+taste+'_1'+voiced,da,en)
        if tier=='A':
            row('birthdays','BDAY_'+npc.upper()+'_GREET_1_V','Du kom på min fødselsdag! Det gør dagen lidt varmere.','You came on my birthday! That makes the day a little warmer.')
            row('birthdays','BDAY_'+npc.upper()+'_THANKS_1','Tak for fødselsdagshilsenen. Jeg gemmer den i hjertet.','Thank you for the birthday greeting. I will keep it in my heart.')
    arch_details={
        'child':('min lille legehule','my little play den'), 'wanderer':('stien mellem grenene','the path between the branches'),
        'fairy':('lyset mellem bladene','the light among the leaves'), 'shopkeeper':('den lille disk','the little counter'),
        'gardener':('haven i trækronen','the garden in the treetop'), 'watcher':('broen ved skovkanten','the bridge by the forest edge'),
        'elder':('den varme vindueskrog','the warm window nook'), 'craftsman':('mit gamle arbejdsbord','my old workbench')}
    for arch,(detail,detail_en) in arch_details.items():
        k='SOC_ARCH_'+arch.upper()+'_'
        for band in range(4):
            for n,(da,en) in enumerate([
                (f'Kom, der er plads ved {detail}.',f'Come, there is room by {detail_en}.'),
                (f'Jeg blev glad, da jeg så dig ved {detail}.',f'I was happy to see you by {detail_en}.'),
                (f'Skal vi dele en lille stund ved {detail}?',f'Shall we share a little time by {detail_en}?')],1):
                warmth=[('',''),(' Det er rart at kende dig.',' It is lovely to know you.'),(' Jeg har savnet dit selskab.',' I missed your company.'),(' Du er altid velkommen her.',' You are always welcome here.')][band]
                row('social_arch',k+f'GREET_H{band}_{n}',da+warmth[0],en+warmth[1])
        for taste,variants in {
            'LOVE':[('Den her betyder noget særligt for mig.','This means something special to me.'),('Du kender mig godt. Tusind tak!','You know me well. Thank you so much!')],
            'LIKE':[('Hvor er det en fin tanke.','What a lovely thought.'),('Den her vil jeg nyde.','I will enjoy this.')],
            'NEUTRAL':[('Tak, fordi du kom med en gave.','Thank you for bringing a gift.'),('Du tænkte på mig. Det var rart.','You thought of me. That was lovely.')],
            'DISLIKE':[('Tak for tanken, selv om den ikke helt passer til mig.','Thank you for the thought, though it is not quite for me.'),('Måske kan en nabo få glæde af den.','Perhaps a neighbour can enjoy it.')],
            'HATE':[('Det var venligt. Jeg holder bare mere af andre ting.','That was kind. I just prefer other things.'),('Tak. Du må gerne spørge, hvad jeg kan lide en anden gang.','Thank you. You can ask what I like another time.')],
        }.items():
            for n,(da,en) in enumerate(variants,1):row('social_arch',k+'GIFT_'+taste+'_'+str(n),da,en)
        for n,(da,en) in enumerate([('En fødselsdag bliver rarere med besøg.','A birthday is lovelier with visitors.'),('I dag er min fødselsdag. Vil du holde mig med selskab?','Today is my birthday. Will you keep me company?')],1):row('social_arch',k+'BDAY_'+str(n),da,en)
        for n,(da,en) in enumerate([('Der kom et vindpust.','A little breeze arrived.'),('En nabo går forbi.','A neighbour passes by.'),('Lyset falder så fint.','The light falls so softly.'),('Der dufter af træ.','It smells of timber.'),('En lille pause nu.','A little break now.'),('Jeg lytter til bladene.','I listen to the leaves.')],1):row('social_arch',k+'BARK_'+str(n),da,en)
        for n,(da,en) in enumerate([('Kig dig bare omkring.','Feel free to look around.'),('Jeg hjælper gerne ved disken.','I am happy to help at the counter.'),('Der er mange små ting på hylderne.','There are many little things on the shelves.'),('Tag dig tid. Vi finder det sammen.','Take your time. We will find it together.')],1):row('social_arch',k+'SHOP_'+str(n),da,en)
    shared=[('WX_REGN','Regnen trommer blidt på bladene.','The rain taps softly on the leaves.'),('WX_TAAGE','Tågen pakker broerne ind i dag.','The mist wraps up the bridges today.'),('WX_SNE','Der ligger sne på de små grene.','Snow rests on the little branches.'),('WX_TORDEN','Det buldrer. Her er en rar krog at vente i.','Thunder rumbles. Here is a cosy nook to wait in.'),('SEASON_FORAAR','Der kommer nye knopper på træet.','New buds are appearing on the tree.'),('SEASON_SOMMER','Bladene giver en dejlig skygge i dag.','The leaves give lovely shade today.'),('SEASON_EFTERAAR','Jeg fandt et gyldent blad på broen.','I found a golden leaf on the bridge.'),('SEASON_VINTER','Vi holder varmen sammen heroppe.','We keep warm together up here.'),('FEST','Der er fest mellem grenene.','There is a celebration among the branches.'),('FEST','Jeg glæder mig til at møde naboerne.','I look forward to seeing the neighbours.')]
    for i,(slot,da,en) in enumerate(shared,1):row('social_arch','SOC_ANY_'+slot+'_'+str(i),da,en)
    for n,(da,en) in enumerate([('Godt at se dig heroppe.','Good to see you up here.'),('Kom nærmere, hvis du har lyst.','Come closer if you like.'),('Vi har en rar dag mellem grenene.','We are having a lovely day among the branches.')],1):row('social_arch','SOC_ANY_GREET_'+str(n),da,en)
    for file,rows in buckets.items():
        with (root/'localization'/f'{file}.csv').open('w',newline='') as f:csv.writer(f,lineterminator='\n').writerows([['keys','da','en']]+rows)
        (root/'localization'/f'{file}.csv.import').write_text('[remap]\n\nimporter="keep"\n')
        print(file,len(rows))
    # Declarative reveals, used by DialogueBridge after the corresponding topic finishes.
    (root/'tools/social/data/topic_reveals.json').write_text(json.dumps(reveals,ensure_ascii=False,indent=2)+'\n')
    def lua(value,depth=0):
        if isinstance(value,str):return json.dumps(value,ensure_ascii=False)
        if isinstance(value,int):return str(value)
        if not value:return '{}'
        pairs=[(k+' = ' if isinstance(value,dict) else '')+lua(v,depth+1)+',' for k,v in (value.items() if isinstance(value,dict) else enumerate(value))]
        return '{\n'+'\n'.join('  '*(depth+1)+p for p in pairs)+'\n'+'  '*depth+'}'
    (root/'lua/social/topics.lua').write_text('kind = "config"\nconfig = '+lua({'social_topics':reveals})+'\n')
if __name__=='__main__':build()
