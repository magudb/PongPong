#!/usr/bin/env python3
"""Adapt the authored family draft to the shipped topic/voice contracts."""
import argparse
import csv
import io
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
EN_EDITS = {
    'SOC_GHOSTFAM_DYNE_FIRST_1_V': 'Hello! I knit for chilly neighbours. Come, sit by the fire.',
    'SOC_GHOSTFAM_DYNE_CHAT_2_1_V': 'Two hundred years? I stopped counting. I only count stitches.',
    'SOC_GHOSTFAM_DYNE_CHAT_8_1_V': 'You bring a little light inside. Even without glasses, I can see it.',
    'SOC_GHOSTFAM_GNIST_FIRST_1_V': 'Hello! I make lanterns. Come by before you head into the dark.',
    'SOC_GHOSTFAM_SILKE_FIRST_1_V': "Hello. I keep watch at night. I'll gladly walk you home.",
    'SOC_GHOSTFAM_BLUND_BARK_1': "Don't look! I'm hiding!",
    'GHOSTFAM_KIN_STORY': 'For four springs, Dyne entered your name in the Fairy King’s lottery, with moonlight tied around the ticket. This year he drew it. Now you have a treetop farm and a family by the fire.',
}
TOPICS = {
    'DYNE': [('Hvor kommer garnet fra?', 'Where does the yarn come from?'), ('Fortæl om din familie', 'Tell me about your family'), ('Hvordan har natten det?', 'How is the night doing?')],
    'GNIST': [('Hvad skal jeg have med?', 'What should I bring?')],
    'SILKE': [('Hvor kommer lygten fra?', 'Where is the lantern from?')],
    'BLUND': [('Hvor gemmer du dig?', 'Where do you hide?')],
}

def render():
    source = HERE / 'authoring/ghostfamily-source.csv'
    result = io.StringIO(newline='')
    writer = csv.writer(result, lineterminator='\n')
    for row in csv.reader(source.read_text().splitlines()):
        if len(row) == 3:
            if row[0] in EN_EDITS:
                row[2] = EN_EDITS[row[0]]
            if re.fullmatch(r'SOC_GHOSTFAM_\w+_TOPIC_\d+', row[0]):
                row[0] = row[0].replace('_TOPIC_', '_TOPIC_ANSWER_')
        writer.writerow(row)
    for npc, questions in TOPICS.items():
        for index, question in enumerate(questions, 1):
            writer.writerow([f'SOC_GHOSTFAM_{npc}_TOPIC_{index}', *question])
    return result.getvalue()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    path = ROOT / 'localization/ghostfamily.csv'
    content = render()
    if args.write:
        path.write_text(content)
    if path.read_text() != content:
        raise SystemExit('FAIL family copy differs from the portable authoring source')
    print('PASS family copy regeneration (168 draft rows)')

if __name__ == '__main__':
    main()
