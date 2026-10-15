#!/usr/bin/env python3
"""Refresh CSV counts and the review queue; never promote a review state."""
from pathlib import Path
import argparse, json
import copy_lint
ROOT=copy_lint.ROOT
PRIORITY=['social_talk.csv','social_arch.csv','gifts.csv','birthdays.csv','dialogue_cast.csv','dialogue_builder.csv','towns.csv','farm_tutorial.csv','dungeon_services.csv']
def refresh(root=ROOT):
    _,rows=copy_lint.read_rows(root);path=root/'docs/copy/review_status.json'
    status=json.loads(path.read_text()) if path.exists() else {}
    queue=[]
    for file in copy_lint.loc.list_csv_files(root/'localization'):
        key='localization/'+file;group=[r for r in rows if r['file']==key]
        record=status.setdefault(key,dict(status='draft',reviewed_by='',date='',voice_frozen=False))
        record['rows']=len(group)
        words=sum(len(r.get('da','').split()) for r in group)
        queue.append((PRIORITY.index(file) if file in PRIORITY else len(PRIORITY),file,words,record))
    path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(status,ensure_ascii=False,indent=2)+'\n')
    lines=['# Danish copy review queue','','Review daily town and shop dialogue first. Estimates assume 400 Danish words per hour; they exclude English proofreading and listening tests. Only the user can mark copy as native reviewed.','','| File | State | Rows | Danish words | Estimated hours |','| --- | --- | ---: | ---: | ---: |']
    for _,file,words,record in sorted(queue):lines.append(f"| {file} | {record['status']} | {record['rows']} | {words} | {words/400:.1f} |")
    (root/'docs/copy/REVIEW_QUEUE.md').write_text('\n'.join(lines)+'\n')
if __name__=='__main__':
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--root',type=Path,default=ROOT);args=ap.parse_args();refresh(args.root)
