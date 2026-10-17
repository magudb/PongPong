"""The 30 daily routines (the content of lua/routines/<id>.lua). A plan is a list of (arrival time, place, act); the NPC is at `place` from `arrival` until it has to
leave for the next block (leave = next arrival - travel time, computed from the baked route table). Day plans cover 06:00-24:00; before the first block the citizen is at
its last place of the day before (= the bed).
Places: `<area>.<post>` (area = traetoppen | hyggebyen | farm | int_<building>), `nowhere` (absent: sleeping bat, away in the forest).
Home places of buildings without a modelled room are the DOOR ANCHOR with act `inside` (the citizen walks to the door and vanishes).
"""
from __future__ import annotations
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from model import hm

T, H, F = "traetoppen.", "hyggebyen.", "farm."
WORKDAYS = (0, 1, 2, 3, 4)


def _t(v):
    """None | hour of the day ('17:30' or 17.5) | a stay duration '+0:10' (leave 10 game minutes after arriving)."""
    if v is None:
        return None
    if isinstance(v, str) and v.startswith("+"):
        return ("+", hm(v[1:]))
    return hm(v) if isinstance(v, str) else float(v)


def P(*blocks):
    """(arrive, place, act[, leave]): arrive = None means 'as soon as the walk from the previous place is done'; leave = None means 'in time for the next arrival'."""
    out = []
    for b in blocks:
        t, place, act = b[0], b[1], b[2]
        until = b[3] if len(b) > 3 else None
        out.append((_t(t), place, act, _t(until)))
    return out


PLANS: dict[str, dict] = {}
RULES: dict[str, list] = {}
SHELTER: dict[str, str] = {}
EXTRAS: dict[str, dict] = {}


def cit(id, shelter, plans, rules):
    PLANS[id] = {k: P(*v) for k, v in plans.items()}
    RULES[id] = rules
    SHELTER[id] = shelter


def rule(plan, **when):
    return {"when": when, "plan": plan} if when else {"plan": plan}


# ===================================================================== TRAETOPPEN
cit("gardener_hoppe", "int_hoppe_hut.table", {
    "work": [("06:30", "int_hoppe_hut.table", "eat"), ("07:15", T + "a_beds1", "tend"), ("10:30", T + "a_beds2", "tend"), ("12:30", T + "a_bench", "sit"),
             ("13:30", T + "a_beds1", "tend", "16:30"), (None, T + "t_fire_n", "sit", "18:06"), (None, "int_hoppe_hut.table", "eat"), ("20:30", "int_hoppe_hut.hearth", "stand"),
             ("22:00", "int_hoppe_hut.bed", "sleep")],
    "rest": [("07:30", "int_hoppe_hut.table", "eat"), ("09:00", T + "a_bench", "sit"), ("11:00", T + "t_fire_s", "sit"), ("13:00", "int_torvekroen.seat_a", "sit"),
             ("15:30", T + "u_terrace", "sit"), ("18:00", "int_hoppe_hut.table", "eat"), ("22:00", "int_hoppe_hut.bed", "sleep")],
    "farm_visit": [("06:30", "int_hoppe_hut.table", "eat"), ("07:15", T + "a_beds1", "tend"), ("11:30", T + "a_bench", "sit", "12:51"), ("15:00", F + "hoppe_fence", "stand", "16:00"),
                   (None, T + "t_fire_n", "sit", "18:06"), (None, "int_hoppe_hut.table", "eat"), ("22:00", "int_hoppe_hut.bed", "sleep")],
    "inn": [("06:30", "int_hoppe_hut.table", "eat"), ("07:15", T + "a_beds1", "tend"), ("10:30", T + "a_beds2", "tend"), ("12:30", T + "a_bench", "sit"),
            ("13:30", T + "a_beds1", "tend", "17:00"), (None, "int_hoppe_hut.table", "eat"), ("19:30", "int_torvekroen.seat_b", "sit"), ("22:45", "int_hoppe_hut.bed", "sleep")],
}, [rule("inn", weekday=[4, 5]), rule("farm_visit", weekday=[2], min_hearts=2), rule("rest", weekday=[6]), rule("work")])

cit("carpenter_brumme", "int_brummes_hus.table", {
    "work": [("06:30", "int_brummes_hus.table", "eat"), ("07:45", "int_brummes_vaerksted.counter", "work", "16:00"), (None, T + "c_bench", "sit", "17:15"), (None, "int_brummes_hus.table", "eat"),
             ("19:00", "int_brummes_hus.hearth", "stand"), ("21:30", "int_brummes_hus.bed", "sleep")],
    "stall": [("06:30", "int_brummes_hus.table", "eat"), ("09:30", T + "t_stall", "work", "16:00"), (None, T + "t_fire_w", "sit", "17:30"), ("18:20", "int_torvekroen.seat_a", "sit"),
              ("21:30", "int_brummes_hus.bed", "sleep")],
    "inn": [("06:30", "int_brummes_hus.table", "eat"), ("07:45", "int_brummes_vaerksted.counter", "work", "16:00"), (None, T + "c_bench", "sit", "17:30"), ("18:21", "int_torvekroen.seat_a", "sit"),
            ("22:00", "int_brummes_hus.bed", "sleep")],
}, [rule("stall", weekday=[5, 6]), rule("inn", weekday=[4]), rule("work")])

cit("rasmus", "int_brummes_hus.table", {
    "work": [("06:45", "int_brummes_hus.table", "eat"), ("07:50", "int_brummes_vaerksted.work", "work", "16:00"), (None, T + "t_bench1", "sit", "17:30"), ("18:20", "int_torvekroen.seat_c", "sit"),
             ("21:30", "int_brummes_hus.bed", "sleep")],
    "stall": [("06:45", "int_brummes_hus.table", "eat"), ("09:30", T + "t_stall", "work", "16:00"), (None, T + "t_fire_e", "sit", "17:30"), ("18:20", "int_torvekroen.seat_c", "sit"),
              ("21:30", "int_brummes_hus.bed", "sleep")],
    "rest": [("08:00", "int_brummes_hus.table", "eat", "09:00"), (None, H + "torv_fountain_e", "sit", "12:30"), (None, H + "pond_dock", "fish", "16:00"), (None, H + "torv_bench2", "sit", "18:30"),
             (None, "int_torvekroen.seat_c", "sit"), ("22:30", "int_brummes_hus.bed", "sleep")],
}, [rule("stall", weekday=[5]), rule("rest", weekday=[6]), rule("work")])

cit("postman_pip", "int_postkontoret.bed", {
    "work": [("06:00", "int_postkontoret.bed", "sleep", "06:05"), ("07:10", F + "pip_mailbox", "stand", "07:30"), (None, "int_postkontoret.counter", "work", "17:00"), (None, T + "t_fire_n", "sit", "18:00"),
             ("19:20", "int_torvekroen.seat_d", "sit"), ("21:30", "int_postkontoret.bed", "sleep")],
    "rest": [("06:00", "int_postkontoret.bed", "sleep", "07:00"), (None, T + "t_fire_n", "sit", "09:30"), (None, T + "b_bench", "sit", "11:00"), ("12:00", "int_torvekroen.seat_d", "sit"), ("15:00", T + "e_bench", "sit"),
             ("18:00", T + "t_fire_n", "sit"), ("21:30", "int_postkontoret.bed", "sleep")],
}, [rule("town_only", day_max=1), rule("rest", weekday=[6]), rule("work")])
# day 1: the farm track's first-morning tutorial has Pip at the farm mailbox at 06:00 (he delivers in person): his own farm walk starts on day 2
EXTRAS["postman_pip"] = {"speed_mult": 1.6}
PLANS["postman_pip"]["town_only"] = P(("06:00", "int_postkontoret.bed", "sleep", "08:15")) + [b for b in PLANS["postman_pip"]["work"][2:]]

cit("bathkeeper_sofus", "int_badehuset.bed", {
    "work": [("08:00", "int_badehuset.bed", "eat"), ("09:45", "int_badehuset.tub", "sit", "21:00"), (None, T + "e_tub", "stand", "22:00"), (None, "int_badehuset.bed", "sleep")],
    "sat": [("08:00", "int_badehuset.bed", "eat"), ("09:45", "int_badehuset.tub", "sit", "21:00"), (None, "int_torvekroen.seat_e", "sit", "22:15"), (None, "int_badehuset.bed", "sleep")],
}, [rule("sat", weekday=[5]), rule("work")])

cit("appraiser_fru_ugle", "int_uglehulen.perch", {
    "work": [("07:00", "int_uglehulen.perch", "perch"), ("11:45", "int_uglehulen.counter", "work", "20:00"), (None, T + "a_ugle_perch", "perch", "22:00"), (None, "int_uglehulen.perch", "sleep")],
    "field": [("07:00", "int_uglehulen.perch", "perch", "09:00"), (None, "away:traetoppen.gate_skovlift", "away", "17:00"), (None, T + "a_ugle_perch", "perch", "22:00"), (None, "int_uglehulen.perch", "sleep")],
}, [rule("field", weekday=[0, 3]), rule("work")])

cit("guard_oak", "int_vagthytten.table", {
    "work": [("06:30", "int_vagthytten.table", "eat"), ("07:30", T + "b_lift", "guard", "12:00"), (None, T + "b_bench", "sit", "12:45"), (None, T + "b_lift", "guard", "15:00"),
             (None, T + "t_fire_e", "patrol", "15:40"), (None, T + "b_lift", "guard", "17:30"), ("18:20", "int_torvekroen.seat_b", "sit"), ("21:00", "int_vagthytten.table", "eat"),
             ("22:00", "int_vagthytten.bed", "sleep")],
    "inn": [("06:30", "int_vagthytten.table", "eat"), ("07:30", T + "b_lift", "guard", "12:00"), (None, T + "b_bench", "sit", "12:45"), (None, T + "b_lift", "guard", "17:00"),
            ("17:57", "int_torvekroen.seat_a", "sit"), ("22:30", "int_vagthytten.bed", "sleep")],
}, [rule("inn", weekday=[5]), rule("work")])

cit("cub_bamse", "int_vagthytten.table", {
    "work": [("07:00", "int_vagthytten.table", "eat"), ("08:30", T + "t_fire_s", "play"), ("11:30", "int_vagthytten.table", "eat"), ("13:00", T + "b_bench", "play"),
             ("17:30", "int_vagthytten.table", "eat"), ("20:00", "int_vagthytten.bed", "sleep")],
    "visit": [("07:00", "int_vagthytten.table", "eat"), ("08:30", T + "t_fire_s", "play"), ("11:30", "int_vagthytten.table", "eat", "12:30"), (None, H + "torv_playground", "play", "16:00"),
              (None, "int_vagthytten.table", "eat"), ("20:00", "int_vagthytten.bed", "sleep")],
}, [rule("visit", weekday=[5]), rule("work")])

cit("lamplighter_kiki", "int_kikis_hytte.table", {
    "work": [("06:30", "int_kikis_hytte.table", "eat"), ("08:00", T + "t_fire_w", "sit"), ("09:15", T + "g_bench", "sit"), ("11:45", T + "t_bench1", "sit"), ("13:30", T + "e_bench", "sit"),
             ("15:30", T + "u_terrace", "sit"), ("17:30", T + "t_lamp", "lamp", "+0:06"), (None, T + "u_lamp", "lamp", "+0:06"), (None, T + "e_lamp", "lamp", "+0:06"), (None, T + "b_lamp", "lamp", "+0:06"),
             (None, "int_torvekroen.seat_e", "sit", "21:30"), (None, "int_kikis_hytte.bed", "sleep")],
    "rest": [("08:30", "int_kikis_hytte.table", "eat"), ("10:00", T + "t_bench2", "sit"), ("13:00", T + "e_bench", "sit"), ("16:30", T + "b_bench", "sit"),
             ("21:30", "int_kikis_hytte.bed", "sleep")],
}, [rule("rest", weekday=[6]), rule("work")])

cit("clerk_fjerpen", "traetoppen.door_fjerpens_hytte", {
    "work": [("07:30", T + "door_fjerpens_hytte", "inside"), ("08:40", "int_raadhuset.counter", "work", "15:00"), (None, T + "t_bench1", "sit", "17:00"), (None, "int_torvekroen.seat_a", "sit", "20:30"),
             (None, T + "door_fjerpens_hytte", "inside")],
    "rest": [("09:30", T + "door_fjerpens_hytte", "inside"), ("11:00", T + "t_fire_n", "sit"), ("14:00", T + "u_terrace", "sit"), ("18:00", "int_torvekroen.seat_a", "sit"),
             ("21:30", T + "door_fjerpens_hytte", "inside")],
}, [rule("rest", weekday=[5, 6]), rule("work")])

cit("mapseller_natteblik", "traetoppen.e_bat_window", {
    "work": [("06:00", "nowhere", "away", "19:30"), (None, T + "e_bat_window", "perch", "23:30"), (None, "nowhere", "away")],
}, [rule("work")])

cit("innkeeper_kvak", "int_torvekroen.seat_a", {
    "work": [("07:00", "int_torvekroen.bed", "eat", "09:00"), (None, "int_torvekroen.counter", "work", "23:00"), (None, "int_torvekroen.bed", "sleep")],
    "mon": [("06:00", "int_torvekroen.bed", "eat", "07:30"), (None, H + "pond_dock", "fish", "12:00"), (None, H + "torv_fountain_s", "sit", "13:30"), (None, H + "pond_dock", "fish", "15:45"),
            (None, "int_torvekroen.counter", "work", "23:00"), (None, "int_torvekroen.bed", "sleep")],
}, [rule("mon", weekday=[0]), rule("work")])

cit("fiddler_strimmel", "int_musikstuen.table", {
    "work": [("08:00", "int_musikstuen.table", "eat"), ("10:00", T + "f_bench", "play"), ("13:00", "int_musikstuen.hearth", "play"), ("16:00", T + "t_fire_w", "play"),
             ("18:30", "int_torvekroen.seat_c", "sit"), ("21:30", "int_musikstuen.bed", "sleep")],
    "gig": [("08:00", "int_musikstuen.table", "eat"), ("10:00", T + "f_bench", "play"), ("14:00", "int_musikstuen.hearth", "play"), ("18:30", "int_torvekroen.stage", "play"),
            ("22:30", "int_musikstuen.bed", "sleep")],
    "busk": [("08:00", "int_musikstuen.table", "eat", "09:30"), (None, H + "torv_fountain_w", "play", "13:00"), (None, T + "t_fire_w", "play", "17:30"), ("18:30", "int_torvekroen.stage", "play"),
             ("22:30", "int_musikstuen.bed", "sleep")],
}, [rule("busk", weekday=[5]), rule("gig", weekday=[4]), rule("work")])

cit("bertil", "traetoppen.door_koekkenhave_skuret", {
    "work": [("06:30", T + "door_koekkenhave_skuret", "inside"), ("07:00", T + "g_planter1", "tend"), ("10:00", T + "g_planter3", "tend"), ("12:30", T + "g_bench", "sit"), ("14:00", T + "g_planter2", "tend"),
             ("17:30", T + "t_fire_s", "sit"), ("19:00", "int_torvekroen.seat_e", "sit"), ("21:30", T + "door_koekkenhave_skuret", "inside")],
    "visit": [("07:00", T + "door_koekkenhave_skuret", "inside", "08:00"), (None, H + "bakery_terrace", "sit", "11:30"), (None, H + "torv_fountain_e", "sit", "14:30"), (None, H + "blossom_bench1", "sit", "17:30"),
              ("19:30", "int_torvekroen.seat_e", "sit"), ("22:00", T + "door_koekkenhave_skuret", "inside")],
}, [rule("visit", weekday=[6]), rule("work")])

# ===================================================================== HYGGEBYEN
cit("mayor_lyra", "int_hyldeblomsts_hus.table", {
    "work": [("07:00", "int_hyldeblomsts_hus.table", "eat"), ("09:30", "int_raadhuset.mayor_desk", "work", "15:00"), (None, H + "torv_fountain_n", "sit", "18:30"), (None, "int_hyldeblomsts_hus.table", "eat"),
             ("21:30", "int_hyldeblomsts_hus.bed", "sleep")],
    "rest": [("08:00", "int_hyldeblomsts_hus.table", "eat"), ("10:30", H + "blossom_bench1", "sit"), ("13:00", H + "torv_fountain_n", "sit"), ("16:00", H + "well", "stand"),
             ("18:30", "int_hyldeblomsts_hus.table", "eat"), ("21:30", "int_hyldeblomsts_hus.bed", "sleep")],
}, [rule("work", weekday=[1, 2, 3]), rule("rest")])

cit("baker_maja", "hyggebyen.door_bageriet", {
    "work": [("06:00", H + "door_bageriet", "inside", "06:30"), (None, "int_bageriet.counter", "work", "17:00"), (None, H + "bakery_terrace", "sit", "18:00"), (None, H + "torv_fountain_e", "sit", "20:00"),
             (None, H + "door_bageriet", "inside")],
    "mon": [("07:00", H + "door_bageriet", "inside"), ("09:00", H + "blossom_bench2", "sit"), ("11:00", H + "torv_fountain_e", "sit"), ("14:00", H + "well", "stand"),
            ("17:00", H + "bakery_terrace", "sit"), ("20:30", H + "door_bageriet", "inside")],
}, [rule("mon", weekday=[0]), rule("work")])

cit("merchant_pip", "hyggebyen.door_froebutikken", {
    "work": [("06:00", H + "door_froebutikken", "inside", "07:30"), (None, "int_froebutikken.counter", "work", "18:00"), (None, H + "blossom_bench1", "sit", "19:00"), (None, H + "torv_fountain_n", "sit", "20:30"),
             (None, H + "door_froebutikken", "inside")],
    "sun": [("08:00", H + "door_froebutikken", "inside"), ("09:30", H + "blossom_bench1", "sit"), ("12:00", H + "well", "stand"), ("15:00", H + "torv_fountain_n", "sit"),
            ("20:30", H + "door_froebutikken", "inside")],
}, [rule("sun", weekday=[6]), rule("work")])

cit("smith_thorin", "hyggebyen.door_smedjen", {
    "work": [("06:30", H + "door_smedjen", "inside", "07:35"), (None, "int_bageriet.cust1", "stand", "+0:10"), (None, "int_smedjen.counter", "work", "17:00"), (None, H + "forge_front", "work", "18:30"), (None, H + "torv_fountain_e", "sit", "21:00"),
             (None, H + "door_smedjen", "inside")],
    "sun": [("08:30", H + "door_smedjen", "inside"), ("10:00", H + "forge_front", "work"), ("13:00", H + "torv_bench2", "sit"), ("17:00", H + "torv_fountain_e", "sit"), ("21:30", H + "door_smedjen", "inside")],
    "inn": [("06:30", H + "door_smedjen", "inside", "07:35"), (None, "int_bageriet.cust1", "stand", "+0:10"), (None, "int_smedjen.counter", "work", "17:00"), (None, H + "forge_front", "work", "18:00"), ("19:30", "int_torvekroen.seat_f", "sit"),
            ("23:00", H + "door_smedjen", "inside")],
    "work_mon": [("06:30", H + "door_smedjen", "inside", "08:30"), (None, "int_smedjen.counter", "work", "17:00"), (None, H + "forge_front", "work", "18:30"), (None, H + "torv_fountain_e", "sit", "21:00"),
                 (None, H + "door_smedjen", "inside")],
}, [rule("sun", weekday=[6]), rule("work_mon", weekday=[0]), rule("inn", weekday=[4]), rule("work")])

cit("farmer_rosa", "hyggebyen.door_dyrehuset", {
    "work": [("06:30", H + "door_dyrehuset", "inside", "06:50"), (None, H + "rosa_pen", "tend", "08:30"), (None, "int_dyrehuset.counter", "work", "17:00"), (None, "int_froebutikken.cust2", "stand", "+0:12"), (None, H + "rosa_pen", "tend", "18:36"),
             (None, H + "torv_bench2", "sit", "20:30"), (None, H + "door_dyrehuset", "inside")],
    "rest": [("08:00", H + "door_dyrehuset", "inside"), ("08:30", H + "rosa_pen", "tend"), ("11:00", H + "market_row3", "stand"), ("14:00", H + "torv_fountain_s", "sit"), ("17:00", H + "rosa_pen", "tend"),
             ("21:00", H + "door_dyrehuset", "inside")],
}, [rule("rest", weekday=[3]), rule("work_sun", weekday=[6]), rule("work")])
PLANS["farmer_rosa"]["work_sun"] = [b for b in PLANS["farmer_rosa"]["work"] if "froebutikken" not in b[1]]      # the seed shop is closed on Sundays: no errand there

cit("fairy_wizard", "hyggebyen.door_troldmandstaarnet", {
    "work": [("08:00", H + "door_troldmandstaarnet", "inside", "10:30"), (None, "int_troldmandstaarnet.counter", "work", "19:00"), (None, H + "round_w", "patrol", "20:30"), (None, H + "door_troldmandstaarnet", "inside")],
    "lesson": [("08:00", H + "door_troldmandstaarnet", "inside"), ("10:00", H + "torv_playground", "stand"), ("12:00", H + "blossom_bench2", "sit"), ("15:00", H + "round_w", "patrol"),
               ("21:00", H + "door_troldmandstaarnet", "inside")],
}, [rule("lesson", weekday=[1]), rule("work")])

cit("fairy_builder", "hyggebyen.door_toemmerhandlen", {
    "work": [("06:30", H + "door_toemmerhandlen", "inside", "07:30"), (None, "int_toemmerhandlen.counter", "work", "16:00"), (None, H + "market_row2", "stand", "17:30"), (None, H + "torv_bench1", "sit", "20:30"),
             (None, H + "door_toemmerhandlen", "inside")],
    "rest": [("08:30", H + "door_toemmerhandlen", "inside"), ("10:00", H + "market_row2", "stand"), ("13:00", H + "torv_bench1", "sit"), ("15:30", H + "blossom_bench2", "sit"),
             ("16:30", H + "door_toemmerhandlen", "inside")],
}, [rule("rest", weekday=[4]), rule("work")])

cit("fairy_furnisher", "hyggebyen.door_moebelbutikken", {
    "work": [("06:30", H + "door_moebelbutikken", "inside", "08:30"), (None, "int_moebelbutikken.counter", "work", "17:00"), (None, H + "market_row1", "stand", "18:00"), (None, H + "torv_fountain_w", "sit", "20:30"),
             (None, H + "door_moebelbutikken", "inside")],
    "rest": [("09:00", H + "door_moebelbutikken", "inside"), ("11:00", H + "market_row1", "stand"), ("14:00", H + "blossom_bench1", "sit"), ("17:00", H + "torv_fountain_w", "sit"),
             ("21:00", H + "door_moebelbutikken", "inside")],
}, [rule("rest", weekday=[2]), rule("work")])

cit("fairy_tailor", "hyggebyen.door_skraedderiet", {
    "work": [("06:30", H + "door_skraedderiet", "inside", "08:30"), (None, "int_skraedderiet.counter", "work", "17:00"), (None, H + "market_row2", "stand", "18:00"), (None, H + "torv_fountain_s", "sit", "20:30"),
             (None, H + "door_skraedderiet", "inside")],
    "rest": [("09:00", H + "door_skraedderiet", "inside"), ("11:00", H + "market_row2", "stand"), ("14:00", H + "blossom_bench2", "sit"), ("16:30", H + "door_skraedderiet", "inside")],
}, [rule("rest", weekday=[0]), rule("work")])

cit("pippin_boegeknop", "int_pippins_hus.table", {
    "work": [("07:30", "int_pippins_hus.table", "eat"), ("09:30", H + "pond_dock", "fish"), ("12:30", "int_pippins_hus.table", "eat"), ("14:00", H + "torv_bench1", "sit"),
             ("17:30", "int_pippins_hus.table", "eat"), ("21:30", "int_pippins_hus.bed", "sleep")],
    "weekend": [("08:00", "int_pippins_hus.table", "eat", "09:00"), (None, "int_loppeloftet.counter", "work", "16:00"), (None, "int_pippins_hus.table", "eat"),
                ("21:30", "int_pippins_hus.bed", "sleep")],
}, [rule("weekend", weekday=[5, 6]), rule("work")])

cit("cat_morfar_mis", "int_pippins_hus.hearth", {
    "work": [("08:00", "int_pippins_hus.hearth", "sit"), ("10:00", H + "torv_bench2", "sit"), ("13:00", "int_pippins_hus.hearth", "sit"), ("15:30", H + "blossom_bench2", "sit"),
             ("18:00", "int_pippins_hus.hearth", "sit"), ("20:00", "int_pippins_hus.bed", "sleep")],
}, [rule("work")])

cit("fairy_king", "int_fekongens_hus.throne", {
    "work": [("06:00", "int_fekongens_hus.throne", "sit", "17:00"), (None, H + "king_balcony", "sit", "19:00"), (None, "int_fekongens_hus.throne", "sit")],
}, [rule("work")])

cit("fairy_lily", "int_hyldeblomsts_hus.table", {
    "work": [("07:30", "int_hyldeblomsts_hus.table", "eat"), ("09:00", H + "torv_playground", "play"), ("12:00", "int_hyldeblomsts_hus.table", "eat"), ("14:00", H + "torv_playground", "play"),
             ("17:30", "int_hyldeblomsts_hus.table", "eat"), ("20:00", "int_hyldeblomsts_hus.bed", "sleep")],
    "visit": [("07:30", "int_hyldeblomsts_hus.table", "eat"), ("09:00", H + "torv_playground", "play"), ("12:00", "int_hyldeblomsts_hus.table", "eat", "12:45"), (None, T + "t_fire_s", "play", "16:30"),
              (None, "int_hyldeblomsts_hus.table", "eat"), ("20:30", "int_hyldeblomsts_hus.bed", "sleep")],
}, [rule("visit", weekday=[5]), rule("work")])

cit("penguin_postman", "hyggebyen.door_pingvinens_hus", {
    "work": [("07:00", H + "door_pingvinens_hus", "inside", "07:30"), (None, T + "door_postkontoret", "stand", "+0:10"), (None, H + "round_e", "patrol", "+0:05"), (None, H + "door_froebutikken", "stand", "+0:08"),
             (None, H + "door_bageriet", "stand", "+0:08"), (None, H + "round_s", "patrol", "+0:05"), (None, H + "door_dyrehuset", "stand", "+0:08"), (None, H + "round_w", "patrol", "+0:05"),
             (None, H + "door_pippins_hus", "stand", "+0:08"), (None, H + "door_pingvinens_hus", "inside")],
    "rest": [("09:00", H + "door_pingvinens_hus", "inside"), ("10:30", H + "torv_bench1", "sit"), ("13:30", H + "pond_dock", "fish"), ("15:15", H + "door_pingvinens_hus", "inside")],
}, [rule("rest", weekday=[6]), rule("work")])

cit("beekeeper_birk", "int_birks_bistade.table", {
    "honey": [("06:30", "int_birks_bistade.table", "eat", "07:10"), (None, "int_bageriet.cust2", "stand", "+0:10"), (None, H + "bees1", "tend", "11:30"), (None, H + "bees2", "tend", "13:00"), (None, H + "blossom_bench2", "sit", "14:00"),
              (None, H + "bees1", "tend", "17:30"), (None, H + "torv_fountain_s", "sit", "19:00"), (None, "int_birks_bistade.table", "eat"), ("21:30", "int_birks_bistade.bed", "sleep")],
    "sun": [("08:00", "int_birks_bistade.table", "eat"), ("09:30", H + "bees1", "tend"), ("12:00", H + "blossom_bench2", "sit"), ("14:00", "int_birks_bistade.table", "eat"),
            ("21:30", "int_birks_bistade.bed", "sleep")],
    "work": [("06:30", "int_birks_bistade.table", "eat"), ("07:30", H + "bees1", "tend"), ("11:30", H + "bees2", "tend"), ("13:00", H + "blossom_bench2", "sit"), ("14:00", H + "bees1", "tend"),
             ("17:30", H + "torv_fountain_s", "sit"), ("19:00", "int_birks_bistade.table", "eat"), ("21:30", "int_birks_bistade.bed", "sleep")],
    "inn": [("06:30", "int_birks_bistade.table", "eat"), ("07:30", H + "bees1", "tend"), ("11:30", H + "bees2", "tend"), ("14:00", H + "bees1", "tend", "16:30"), (None, "int_birks_bistade.table", "eat", "18:00"),
            (None, "int_torvekroen.seat_f", "sit"), ("23:00", "int_birks_bistade.bed", "sleep")],
}, [rule("inn", weekday=[4]), rule("sun", weekday=[6]), rule("honey", weekday=[1, 2, 3, 5]), rule("work")])

cit("bodil", "hyggebyen.door_bageriet", {
    "work": [("06:00", H + "door_bageriet", "inside", "06:30"), (None, "int_bageriet.work", "work", "14:00"), (None, H + "torv_fountain_w", "sit", "16:00"), (None, H + "pond_dock", "fish", "18:00"),
             (None, H + "blossom_bench1", "sit", "19:30"), (None, H + "door_bageriet", "inside")],
    "mon": [("08:00", H + "door_bageriet", "inside"), ("10:00", H + "blossom_bench1", "sit"), ("13:00", H + "torv_fountain_w", "sit"), ("17:00", H + "bakery_terrace", "sit"),
            ("20:00", H + "door_bageriet", "inside")],
}, [rule("mon", weekday=[0]), rule("work")])

assert len(PLANS) == 30, len(PLANS)
