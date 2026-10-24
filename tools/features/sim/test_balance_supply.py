"""Source-backed supply regressions. Run with the repository art Python, no Godot copy.

Fixtures shrink only home demands/income to isolate stock waits; the lifetime
acceptance uses unmodified costs, gates, prices and all three named profiles.
"""
import copy
import contextlib
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'tools/dungeon_loot'))
sys.path.insert(0, str(Path(__file__).resolve().parent))
from live_data import snapshot
import balance_sim as balance


class SupplyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = snapshot()

    def world(self):
        return balance.World(copy.deepcopy(self.data), copy.deepcopy(self.data), 'repo')

    def isolated(self, material, amount):
        world = self.world()
        # No grants: finite ordinary 500 starting gold, no income, fixtures only.
        for tier in world.home['tiers'][1:]:
            tier['requires'] = {}
            tier['cost'] = dict(gold=0, days=1, materials={})
        world.home['tiers'][1]['cost']['materials'] = {material: amount}
        world.forest_day = lambda day: {}
        world.quests = {key: dict(meta={}, rewards={'gold': 0}) for key in world.quests}
        profile = copy.deepcopy(balance.PROFILES['typical'])
        profile['lifestyle'] = 0
        return world, profile

    def run_isolated(self, world, profile):
        with patch.object(balance, 'best_crop', return_value=(None, 0)), patch.object(balance, 'INVEST', []):
            return balance.simulate(world, 'fixture', profile)

    def test_affordable_out_of_stock_waits_for_dawn(self):
        world, profile = self.isolated('nails', 41)
        result = self.run_isolated(world, profile)
        self.assertEqual(result['start'][2], 2, '41 nails cannot be bought from a 40-unit shelf on day 1')
        self.assertEqual(result['stock_wait'][2], 1)
        purchases = [row for row in result['purchases'] if row['item'] == 'nails']
        self.assertEqual([(row['day'], row['amount']) for row in purchases], [(1, 40), (2, 1)])
        self.assertEqual(sum(row['gold'] for row in purchases), 41 * world.buy('nails'))

    def test_weekly_exhaustion_waits_until_next_epoch(self):
        world, profile = self.isolated('marble_block', 41)
        world.items['marble_block']['buy_price'] = 1  # finite affordability fixture, not lifetime tuning
        result = self.run_isolated(world, profile)
        self.assertEqual(result['start'].get(2), 8, 'weekly shelf must retain exhaustion on days 2..7')
        self.assertEqual(result['stock_wait'][2], 7)
        self.assertEqual([(row['day'], row['amount']) for row in result['purchases']], [(1, 40), (8, 1)])

    def test_source_building_closed_day_blocks_purchase(self):
        world, profile = self.isolated('nails', 1)
        profile['gate_days']['intro_lottery'] = 5
        world.home['tiers'][1]['requires'] = {'quests': ['intro_lottery']}
        result = self.run_isolated(world, profile)
        self.assertEqual(result['start'].get(2), 6, 'builder is closed on weekday 4 (Friday), even with money and stock')
        self.assertEqual(result['purchases'][0]['day'], 6)

    def test_source_festival_closes_noon_visit(self):
        world, profile = self.isolated('nails', 1)
        profile['gate_days']['intro_lottery'] = 7
        world.home['tiers'][1]['requires'] = {'quests': ['intro_lottery']}
        result = self.run_isolated(world, profile)
        self.assertEqual(result['start'].get(2), 8, 'spring day 7 festival closes the builder at noon')

    def test_material_quote_does_not_invent_self_craft_discount(self):
        world = self.world()
        tier = world.home['tiers'][1]
        full = sum(world.buy(item) * amount for item, amount in tier['cost']['materials'].items())
        self.assertEqual(balance.material_gold(world, tier), full)

    def test_dynamic_dungeon_pools_do_not_invent_income(self):
        world = self.world()
        # Current runtime draws gems/weapons via dungeon_loot rules, not these
        # legacy static pools. Omit their EV rather than reweighting cheap finds.
        self.assertEqual(balance.pool_value(world, 'skovkant', 'gem', 'normal'), (0, {}))

    def test_lifetime_profiles_never_receive_unearned_credit(self):
        for name, profile in balance.PROFILES.items():
            with self.subTest(profile=name):
                result = balance.simulate(self.world(), name, profile)
                self.assertGreaterEqual(min(result['wealth']), 0, 'scheduled investments must wait for earned gold, not create debt')
                self.assertEqual(set(result['done']), set(range(1, 11)))

    def test_late_tier_earned_progression_conserves_money_and_availability(self):
        for name, profile in balance.PROFILES.items():
            with self.subTest(profile=name):
                world = self.world()
                result = balance.simulate(world, name, profile)
                total_investments = sum(gold for _, gold in balance.INVEST)
                expected = 500 + result['cum'] * (1 - profile['lifestyle']) - total_investments - result['spent_home']
                self.assertAlmostEqual(result['gold'], expected, places=6)
                self.assertEqual(result['investments_pending'], [])
                self.assertGreaterEqual(result['gold'], 0)
                self.assertEqual(result['spent_home'], sum(tier.get('cost', {}).get('gold', 0) for tier in world.home['tiers']) + sum(row['gold'] for row in result['purchases']))
                shelves = balance.BuilderStock(world)
                for row in result['purchases']:
                    shelves.dawn(row['day'])
                    self.assertTrue(shelves.is_open())
                    self.assertLessEqual(row['amount'], shelves.available(row['item']))
                    self.assertEqual(row['gold'], row['amount'] * shelves.price(row['item']))
                    self.assertGreaterEqual(row['gold_before'], row['gold'])
                    shelves.take(row['item'], row['amount'])
                for tier in world.home['tiers'][1:]:
                    n = tier['tier']
                    self.assertEqual(result['done'][n], result['start'][n] + tier['cost']['days'])
                    self.assertGreaterEqual(result['start'][n], result['gate_ready'][n])
                    self.assertGreaterEqual(result['start'][n], result['done'][n - 1])
                self.assertTrue(any(row['item'] == 'marble_block' and row['tier'] == 10 for row in result['purchases']))
                self.assertTrue(any(tier >= 8 and days > 0 for tier, days in result['stock_wait'].items()))

    def test_cli_exposes_stock_waits_and_transaction_audit(self):
        with tempfile.TemporaryDirectory(prefix='builder-supply-report-') as directory:
            dump, summary = Path(directory) / 'dump.json', Path(directory) / 'summary.json'
            dump.write_text(json.dumps([dict(file=key, globals=value) for key, value in self.data.items()]))
            output = io.StringIO()
            with patch.object(sys, 'argv', ['balance_sim.py', '--lua-dump', str(dump), '--repo-lua-dump', str(dump), '--crops', 'repo', '--json', str(summary)]), contextlib.redirect_stdout(output):
                balance.main()
            self.assertIn('wait stock/closed d', output.getvalue())
            for result in json.loads(summary.read_text())['repo'].values():
                self.assertIn('stock_wait', result)
                self.assertIn('purchases', result)
                self.assertIn('gold', result)

    def test_rotation_absence_is_not_a_purchase_offer(self):
        world, profile = self.isolated('marble_block', 1)
        # A deliberately narrow future catalogue catches the whole class of
        # "listed in item.sources, therefore buyable today" mistakes.
        world.shops['builder_yard']['rotation'] = [dict(id='fixture', period=7, pick=1, qty=1,
                                                       pool=['gold_leaf', 'marble_block'], price_mult=1.0)]
        shelves = balance.BuilderStock(world)
        absent = ({'gold_leaf', 'marble_block'} - set(shelves.offers())).pop()
        world.home['tiers'][1]['cost']['materials'] = {absent: 1}
        world.items[absent]['buy_price'] = 1
        first_offer = None
        for day in range(1, 100):
            shelves.dawn(day)
            if shelves.available(absent):
                first_offer = day
                break
        self.assertIsNotNone(first_offer)
        self.assertGreater(first_offer, 1)
        result = self.run_isolated(world, profile)
        self.assertEqual(result['start'].get(2), first_offer)
        self.assertEqual(result['purchases'][0]['day'], first_offer)

    def test_stock_take_is_atomic_and_dawn_is_capped(self):
        world = self.world()
        world.shops['builder_yard']['stock']['nails'] = dict(stock=40, restock=1)
        shelves = balance.BuilderStock(world)
        for amount in (0, -1, 41):
            with self.assertRaises(ValueError):
                shelves.take('nails', amount)
            self.assertEqual(shelves.available('nails'), 40)
        shelves.take('nails', 40)
        shelves.dawn(2)
        self.assertEqual(shelves.available('nails'), 1)
        shelves.dawn(2)
        self.assertEqual(shelves.available('nails'), 1)
        shelves.dawn(100)
        self.assertEqual(shelves.available('nails'), 40)
        with self.assertRaises(ValueError):
            shelves.take('not_an_offer', 1)

    def test_all_tiers_fit_bounded_supply_without_buyable_gems(self):
        world = self.world()
        shelves = balance.BuilderStock(world)
        for tier in world.home['tiers'][1:]:
            for item, amount in tier['cost']['materials'].items():
                if item in ('amethyst', 'moonstone'):
                    self.assertFalse(shelves.sells(item))
                    continue
                self.assertTrue(shelves.sells(item))
                if item in shelves.fixed:
                    self.assertLessEqual(amount, 3 * shelves.fixed[item]['stock'])
                    self.assertEqual(shelves.fixed[item]['restock'], shelves.fixed[item]['stock'])
                else:
                    slot = next(slot for slot in shelves.shop['rotation'] if item in slot['pool'])
                    self.assertEqual(slot['pick'], len(slot['pool']))
                    self.assertLessEqual(amount, slot['qty'] * (2 if slot['period'] == 1 else 1))


if __name__ == '__main__':
    unittest.main(verbosity=2)
