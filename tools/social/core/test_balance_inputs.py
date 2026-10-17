#!/usr/bin/env python3
"""Regression guards for live schedule coverage, door access and clock budgets."""
import copy
import json
from pathlib import Path
import sys
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parent))
import availability as AV
from balance_mc import Model, PROFILES
ROOT = Path(__file__).resolve().parents[3]
class BalanceInputs(unittest.TestCase):
    def test_home_access_needs_the_owner_not_the_visitor(self):
        table = {'npcs':{'visitor':{'0':{'klart':[['home:owner',8,10]]}}}}
        self.assertFalse(AV.talkable(table,'visitor',0,9,False,{'visitor':10}))
        self.assertTrue(AV.talkable(table,'visitor',0,9,False,{'owner':1}))
        self.assertFalse(AV.talkable(table,'visitor',0,10,False,{'owner':1}))
        self.assertFalse(AV.talkable(table,'visitor',0,9,True,{'owner':1}))
    def test_staff_post_stays_private(self):
        table = {'talkable_kinds':['public','counter'],'npcs':{'worker':{'0':{'klart':[['room',8,10],['public',11,12],['counter',13,14]]}}}}
        self.assertFalse(AV.talkable(table,'worker',0,9,False,{'worker':10}))
        self.assertFalse(AV.talkable(table,'worker',0,10.5,False))
        self.assertTrue(AV.talkable(table,'worker',0,11,False))
        self.assertFalse(AV.talkable(table,'worker',0,12,False))
        self.assertTrue(AV.talkable(table,'worker',0,13.5,False))
    def test_current_citizen_cannot_silently_have_no_schedule(self):
        dump = json.loads((ROOT/'tests/lib/social/fixtures/design_dump.json').read_text())
        table = json.loads((ROOT/'tests/lib/social/fixtures/availability_design.json').read_text())
        missing = copy.deepcopy(table); del missing['npcs']['rasmus']
        with self.assertRaisesRegex(ValueError,'missing current citizens: rasmus'):
            Model(dump,'mixed',missing,'lean')
        empty = copy.deepcopy(table); empty['npcs']['rasmus'] = {}
        with self.assertRaisesRegex(ValueError,'no routine spans for: rasmus'):
            Model(dump,'mixed',empty,'lean')
    def test_clock_changes_preserve_visits_per_real_minute(self):
        dump = json.loads((ROOT/'tests/lib/social/fixtures/design_dump.json').read_text())
        dump['time'].update(day_start_hour=6,day_end_hour=26,minutes_per_real_second=2)
        model = Model(dump,'free',None,'lean')
        self.assertEqual(model.day_seconds,600)
        self.assertEqual(model.week_minutes,70)
        self.assertAlmostEqual(PROFILES['typical']['talks']*model.visit_scale/model.day_seconds,2.6/540)
        # Overnight visits must exist; a model ending all evenings at 21 cannot evaluate nocturnal citizens.
        visits = [model.visit_hour(1000,d,0) for d in range(1,100)]
        mixed = Model(dump,'mixed',json.loads((ROOT/'tests/lib/social/fixtures/availability_design.json').read_text()),'lean')
        visits = [mixed.visit_hour(1000,d,0) for d in range(1,100)]
        self.assertTrue(any(h>=24 for h in visits))
        self.assertTrue(all(9<=h<25.5 for h in visits))
if __name__ == '__main__': unittest.main()
