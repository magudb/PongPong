#!/usr/bin/env python3
"""Source-pinned, isolated real Godot processes; fixed deadlines, no retries."""
import argparse
import contextlib
import fcntl
import hashlib
import json
import os
import re
from pathlib import Path
import socket
import subprocess
import time

ENGINE = "/Applications/Godot.app/Contents/MacOS/Godot"
ROOT = Path(__file__).resolve().parents[1]


def source_pin():
    paths = []
    for domain in ("scripts", "scenes", "lua", "tests"):
        paths.extend(p for p in (ROOT / domain).rglob("*") if p.is_file() and not p.is_symlink() and "__pycache__" not in p.parts)
    paths.extend(ROOT / relative for relative in ("project.godot", "assets/ui/theme.tres", "data/maps/farm.map", "data/maps/greenhouse.map"))
    rows = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(paths)}
    return {"sha256": hashlib.sha256(json.dumps(rows, sort_keys=True).encode()).hexdigest(), "files": rows}


def required_assertions(phase, role, case="normal"):
    host = role == "host"
    if case == "fifth_client":
        common = {"isolated_user_data", "transport_started", "all_counterparts_done", "close_pending_empty"}
        if role == "guest4": return common | {"full_before_fifth", "fifth_refused", "offline_state_exact", "guest_world_files_unchanged"}
        return common | {"four_admitted", "fifth_cannot_disturb_roster"} | (set() if host else {"guest_world_files_unchanged"})
    if phase == "attack":
        common = {"isolated_user_data", "transport_started", "all_counterparts_done", "close_pending_empty"}
        if host:
            common |= {"actual_transport_sender_seen", "no_body_allocation", "no_profile_allocation", "host_still_authoritative"}
            if case in ("pending_disconnect", "prepared_disconnect", "commit_not_received", "guest_free_spawn"):
                common.add("departure_cleaned")
                if case == "prepared_disconnect": common.add("prepared_reservation_observed")
                if case == "commit_not_received": common.add("host_commit_observed")
            else:
                common.add("reentrant_free_cleaned" if case == "free_spawn" else "reentrant_close_once" if case in ("close_spawn", "close_join") else "named_rule_rejected")
        else:
            common |= {"rejected_guest_ended", "guest_admission_then_freed" if case == "guest_free_spawn" else "guest_admission_then_revoked" if case in ("quota", "quota_replace") else "guest_never_admitted", "offline_state_exact", "disposed_guest_never_saved" if case == "guest_free_spawn" else "rejected_guest_cannot_save", "attack_packets_sent"}
        if host and case == "quota_replace":
            common |= {"quota_replacement_bound", "quota_same_sender_connected", "quota_replacement_survives_old_continuation"}
        return common
    required = {"isolated_user_data", "production_session_available", "transport_started", "transport_connected", "production_packet_received", "all_counterparts_done"}
    if phase != "transport":
        required |= {"inert_guest_boot_available", "matching_roster", "application_admitted", "one_local_camera", "p0_alias", "all_profile_visuals_owned", "one_local_input", "remote_frames_passive", "server_rpc_authority_on_all_bodies", "host_configured_profiles_initialized"}
        if not host:
            required.add("guest_parked_not_ready")
    if phase in ("save", "authority", "lifetime"):
        required |= {"host_save_positive", "host_saved_all_live_rows"} if host else {"guest_save_refused", "guest_autosave_refused", "guest_gather_refused", "guest_world_files_unchanged"}
    if phase in ("authority", "lifetime"):
        required |= {"eligible_farm_fixture", "eligible_empty_till", "eligible_seed_inventory"}
        required |= {"host_clock_positive", "host_weather_positive", "host_till_positive", "host_plant_positive", "host_water_positive"} if host else {"guest_clock_refused", "guest_weather_refused", "guest_till_refused", "guest_plant_refused", "guest_water_refused", "guest_farm_load_refused", "guest_autonomous_farm_unchanged", "guest_all_clock_paths_refused", "guest_pause_time_refused", "guest_resume_time_refused"}
    if phase == "navigation":
        if case == "host_loss":
            required |= {"host_loss_closed"} if host else {"guest_host_loss_returns_title", "guest_leave_no_disk_change"}
        else:
            required |= {"navigation_peer_removed"} if host else {"guest_return_title_no_prompt", "guest_leave_disposed_world", "guest_leave_no_disk_change"}
    if phase == "lifetime":
        required |= {"network_is_not_single_player", "network_new_game_refused", "close_idempotent"}
        required |= {"host_spawn_owed_targeted", "host_deferred_reward_keeps_signal_owner", "host_deferred_reward_does_not_borrow_host", "spawn_never_borrows_host_inventory", "host_deferred_reward_positive", "old_offline_queue_cannot_save_new_session", "disconnect_cleans_bodies", "disconnect_retains_profiles", "host_save_after_disconnect", "host_rebind_same_port", "host_disk_load_roundtrip_all_rows"} if host else {"offline_save_positive", "guest_spawn_owed_suppressed", "guest_deferred_reward_suppressed", "queued_offline_autosave_cancelled", "guest_autosave_producer_refused", "guest_load_refused", "guest_load_and_enter_refused", "guest_continue_refused", "guest_timer_refused", "guest_apply_refused", "guest_delete_refused", "guest_playtime_stopped", "guest_modal_nonpausing", "guest_save_before_quit_no_prompt", "guest_teardown_tables_consistent", "guest_close_cleans_bodies", "guest_close_restores_offline_rows", "guest_ended_save_refused", "guest_detached_save_refused", "guest_rehost_refused"}
    if case == "area_lifetime" and host:
        required |= {"area_initial_admission", "area_cached_rebuilt_transition_positive", "area_body_membership_preserved", "area_passive_profile_descriptor_preserved", "area_departure_consistent", "area_retained_profiles_save"}
    return required


def valid_source_pin(value):
    return type(value) is str and re.fullmatch(r"[0-9a-f]{64}", value) is not None


def reconcile(report, expected, expected_source_pin):
    problems = []
    if type(report) is not dict or report.get("role") != expected:
        return ["missing/wrong participant"]
    if not valid_source_pin(report.get("source_pin")):
        problems.append("missing/malformed source pin")
    if not valid_source_pin(expected_source_pin) or report.get("source_pin") != expected_source_pin:
        problems.append("source contract mismatch")
    count = report.get("count")
    phase = report.get("phase")
    if type(count) is not int or count not in ((5,) if report.get("phase") == "admission" and report.get("case") == "fifth_client" else (2, 3, 4)):
        problems.append("malformed participant count")
    if type(phase) is not str or phase not in ("transport", "admission", "save", "authority", "lifetime", "attack", "navigation"):
        return problems + ["unknown phase"]
    rows = report.get("checks")
    if type(rows) is not list or not rows:
        return problems + ["zero/missing assertions"]
    ids = set()
    for ordinal, row in enumerate(rows, 1):
        if type(row) is not dict or type(row.get("id")) is not str or not row["id"] or type(row.get("ok")) is not bool:
            problems.append("malformed assertion")
            continue
        if type(row.get("ordinal")) is not int or row["ordinal"] != ordinal:
            problems.append("malformed assertion ordinal")
        if row["id"] in ids:
            problems.append("duplicate assertion: " + row["id"])
        ids.add(row["id"])
        if not row["ok"]:
            problems.append("failed: " + row["id"])
    required = required_assertions(phase, expected, report.get("case"))
    if ids != required:
        problems.append(f"assertion identities differ: missing={sorted(required - ids)} extra={sorted(ids - required)}")
    if phase not in ("transport", "attack") and report.get("case") != "fifth_client":
        details = report.get("details")
        if type(details) is not dict:
            problems.append("missing body evidence")
        else:
            self_peer = details.get("self_peer")
            if expected == "host" and self_peer != 1:
                problems.append("host must own peer1/p0")
            if expected != "host" and (type(self_peer) is not int or self_peer <= 1):
                problems.append("guest must own a non-host transport peer")
            for key in ("self_peer", "generation", "packets_received"):
                if type(details.get(key)) is not int or details[key] < 1:
                    problems.append("malformed " + key)
            view = details.get("view")
            if type(view) is not list or len(view) != count:
                problems.append("wrong roster count")
            else:
                body_ids, peer_ids, locals_ = set(), set(), []
                for body in view:
                    if type(body) is not dict or type(body.get("id")) is not str or type(body.get("peer")) is not int or body["peer"] < 1 or type(body.get("local")) is not bool or type(body.get("camera")) is not bool or body.get("registered") is not True:
                        problems.append("malformed/unregistered body")
                        continue
                    if body["id"] in body_ids or body["peer"] in peer_ids:
                        problems.append("duplicate body identity")
                    body_ids.add(body["id"])
                    peer_ids.add(body["peer"])
                    if body["camera"] != body["local"]:
                        problems.append("camera/input mismatch")
                    if body["local"]:
                        locals_.append(body["peer"])
                    if (body["id"] == "p0") != (body["peer"] == 1):
                        problems.append("host identity mismatch")
                if type(count) is int and body_ids != {f"p{i}" for i in range(count)}:
                    problems.append("wrong body slots")
                if locals_ != [details.get("self_peer")]:
                    problems.append("wrong process-local owner")
    if report.get("ok") is not True:
        problems.append("peer rejected")
    return problems


def reconcile_participants(reports, roles, expected_source_pin):
    """Shared runtime/bundle boundary; retain exact per-participant contracts."""
    if type(reports) is not list or len(reports) != len(roles):
        return ["missing/extra participants"]
    by_role = {}
    problems = []
    for report in reports:
        if type(report) is not dict or report.get("role") not in roles or report.get("role") in by_role:
            return ["missing/duplicate/unexpected participant"]
        role = report["role"]
        by_role[role] = report
        problems.extend(f"{role}: {p}" for p in reconcile(report, role, expected_source_pin))
    if set(by_role) != set(roles):
        return problems + ["missing participants"]
    host = by_role["host"]
    for report in reports:
        if any(report.get(k) != host.get(k) for k in ("count", "phase", "case", "source_pin")):
            problems.append("participant context/source disagreement")
    if problems or host.get("phase") in ("transport", "attack") or host.get("case") == "fifth_client":
        return problems
    # Each process must report the same full transport-peer/slot roster; local
    # and camera flags intentionally differ and were validated per participant.
    host_map = {body["id"]: body["peer"] for body in host["details"]["view"]}
    self_peers = []
    for role, report in by_role.items():
        view = report["details"]["view"]
        peer_map = {body["id"]: body["peer"] for body in view}
        if peer_map != host_map:
            problems.append(f"{role}: peer/slot map disagrees with host")
        self_peers.append(report["details"]["self_peer"])
    if len(set(self_peers)) != len(roles) or set(self_peers) != set(host_map.values()):
        problems.append("participant transport owners do not cover host roster exactly")
    return problems


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--scratch", type=Path)
    ap.add_argument("--label")
    ap.add_argument("--verify-report", type=Path)
    ap.add_argument("--verify-participants", type=Path)
    ap.add_argument("--expected-source-pin", help="Explicit known runtime source SHA256 for archived verification")
    ap.add_argument("--role", default="host")
    ap.add_argument("--count", type=int, choices=(2, 3, 4, 5), default=2)
    ap.add_argument("--phase", choices=("admission", "save", "authority", "lifetime", "attack", "navigation"), default="lifetime")
    ap.add_argument("--case", default="normal")
    args = ap.parse_args()
    if args.verify_participants is not None:
        try:
            reports = json.loads(args.verify_participants.read_text())
            roles = ["host"] + [f"guest{i}" for i in range(1, args.count)]
            problems = reconcile_participants(reports, roles, args.expected_source_pin)
            if type(reports) is list:
                for report in reports:
                    if type(report) is not dict or report.get("phase") != args.phase or report.get("case") != args.case or type(report.get("count")) is not int or report["count"] != args.count:
                        problems.append("run context mismatch")
        except (OSError, ValueError, TypeError) as exc:
            problems = ["invalid reports: " + str(exc)]
        print(json.dumps({"ok": not problems, "problems": problems}, indent=2))
        return int(bool(problems))
    if args.verify_report is not None:
        try:
            report = json.loads(args.verify_report.read_text())
            problems = reconcile(report, args.role, args.expected_source_pin)
            if report.get("phase") != args.phase or report.get("case") != args.case or type(report.get("count")) is not int or report["count"] != args.count:
                problems.append("run context mismatch")
        except (OSError, ValueError, TypeError) as exc:
            problems = ["invalid report: " + str(exc)]
        print(json.dumps({"ok": not problems, "problems": problems}, indent=2))
        return int(bool(problems))
    if args.scratch is None or not args.label:
        ap.error("--scratch and --label are required for runtime execution")
    if (args.count == 5) != (args.phase == "admission" and args.case == "fifth_client"):
        ap.error("five processes are reserved for the fifth-client capacity case")
    if args.phase == "attack" and args.count != 2:
        ap.error("attack scenarios require exactly host and one adversarial client")
    scratch = args.scratch.resolve()
    run = scratch / args.label
    run.mkdir(parents=True, exist_ok=False)
    roles = ["host"] + [f"guest{i}" for i in range(1, args.count)]
    pin = source_pin()
    result = {"label": args.label, "phase": args.phase, "case": args.case, "expected": roles, "source_before": pin, "commands": [], "peers": {}, "problems": []}
    (run / "contract.json").write_text(json.dumps({"roles": roles, "phase": args.phase, "case": args.case, "bounds": {"hello": 5, "admission": 15, "behavior": 10, "teardown": 5, "scenario": 90}, "source": pin["sha256"], "required_assertions": {role: sorted(required_assertions(args.phase, role, args.case)) for role in roles}}, indent=2))
    children = []
    started = None
    try:
        with contextlib.ExitStack() as stack:
            projects = {}
            for role in roles:
                base = scratch / "peers" / role
                base.mkdir(parents=True, exist_ok=True)
                lease = stack.enter_context((base / "runtime.lock").open("a+"))
                fcntl.flock(lease, fcntl.LOCK_EX | fcntl.LOCK_NB)
                home = run / "homes" / role
                project = base / "project"
                home.mkdir(parents=True, exist_ok=True)
                project.mkdir(exist_ok=True)
                env = os.environ | {"HOME": str(home), "TMPDIR": str(scratch.parent), "NET_SOURCE_PIN": pin["sha256"]}
                sync = ["rsync", "-a", "--delete", "--exclude=.git", "--exclude=.godot", "--exclude=docs", "--exclude=tools/art/.venv", "--exclude=tools/art/_stage", str(ROOT) + "/", str(project) + "/"]
                subprocess.run(sync, check=True, capture_output=True)
                cmd = [ENGINE, "--headless", "--path", str(project), "--editor", "--import"]
                with (run / f"{role}-import.log").open("w") as log:
                    p = subprocess.run(cmd, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=600)
                result["commands"].append({"role": role, "mode": "import", "argv": cmd, "exit": p.returncode})
                if p.returncode:
                    raise RuntimeError(f"{role} import failed")
                projects[role] = (project, env)
            # Reserve one loopback UDP port exactly once. No scanning/retry path.
            port_lock = stack.enter_context((scratch / "port.lock").open("a+"))
            fcntl.flock(port_lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
                sock.bind(("127.0.0.1", 0))
                port = sock.getsockname()[1]
            result["port"] = port
            started = time.monotonic()
            host_ready = None
            for role in roles:
                project, env = projects[role]
                cmd = [ENGINE, "--headless", "--verbose", "--path", str(project), "--script", "res://tests/acceptance/net_attack_peer.gd" if args.phase == "attack" else "res://tests/acceptance/net_peer.gd", "--", f"--role={role}", f"--port={port}", f"--count={args.count}", f"--phase={args.phase}", f"--case={args.case}", f"--directory={run}", f"--report={run / (role + '.json')}"]
                log = stack.enter_context((run / f"{role}.log").open("w"))
                proc = subprocess.Popen(cmd, env=env, stdout=log, stderr=subprocess.STDOUT)
                children.append((role, proc))
                result["commands"].append({"role": role, "mode": "peer", "argv": cmd, "pid": proc.pid})
                if role == "host":
                    # Boot is scenario setup, not the connected-peer hello budget.
                    deadline = started + 90
                    while not (run / "hosting").exists():
                        if proc.poll() is not None or time.monotonic() >= deadline:
                            raise RuntimeError("host did not reach hosting barrier")
                        time.sleep(0.02)
                    host_ready = time.monotonic()
            assert host_ready is not None
            admission_deadline = host_ready + 15
            if args.phase not in ("transport", "attack") and args.case != "area_lifetime":
                while not all((run / f"{role}-admitted").exists() for role in roles):
                    if time.monotonic() >= admission_deadline:
                        raise TimeoutError("15s application admission deadline after host-ready")
                    if any(p.poll() is not None for _, p in children):
                        raise RuntimeError("peer exited before complete admission barrier")
                    time.sleep(0.02)
            deadline = started + 90
            while any(p.poll() is None for _, p in children):
                if time.monotonic() >= deadline:
                    raise TimeoutError("scenario 90s deadline")
                time.sleep(0.02)
    except Exception as exc:
        result["problems"].append(f"{type(exc).__name__}: {exc}")
    finally:
        for role, proc in children:
            if proc.poll() is None:
                proc.terminate()
                try:
                    proc.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    proc.kill()
                    proc.wait(timeout=5)
            entry = {"exit": proc.returncode}
            try:
                report = json.loads((run / f"{role}.json").read_text())
                entry["report"] = report
                if report.get("phase") != args.phase or report.get("case") != args.case or type(report.get("count")) is not int or report["count"] != args.count or report.get("source_pin") != pin["sha256"]:
                    result["problems"].append(f"{role}: run context/source mismatch")
                result["problems"].extend(f"{role}: {s}" for s in reconcile(report, role, pin["sha256"]))
            except (OSError, ValueError) as exc:
                result["problems"].append(f"{role}: missing/invalid report {exc}")
            if proc.returncode != 0:
                result["problems"].append(f"{role}: exit {proc.returncode}")
            text = (run / f"{role}.log").read_text()
            errors = [line for line in text.splitlines() if any(mark in line for mark in ("SCRIPT ERROR:", "ERROR:", "WARNING:", "handle_crash:", "Program crashed"))]
            entry["engine_records"] = errors
            expected_negative = args.case == "forged_roster" and role == "host"
            expected_records = [line for line in errors if "_roster_update" in line and "not allowed" in line and line.startswith("ERROR:")]
            entry["expected_negative_engine_records"] = expected_records if expected_negative else []
            if (expected_negative and (len(errors) != 1 or len(expected_records) != 1)) or (not expected_negative and errors):
                result["problems"].append(f"{role}: unexpected engine diagnostics/missing expected authority rejection")
            result["peers"][role] = entry
        if set(result["peers"]) != set(roles):
            result["problems"].append("missing participants")
        result["problems"].extend(reconcile_participants(
            [entry["report"] for entry in result["peers"].values() if "report" in entry], roles, pin["sha256"]))
        result["source_after"] = source_pin()
        if result["source_after"] != pin:
            result["problems"].append("source changed during execution")
        result["seconds_excluding_import"] = time.monotonic() - started if started else None
        result["ok"] = not result["problems"]
        (run / "supervisor.json").write_text(json.dumps(result, indent=2))
        print(json.dumps({"run": str(run), "ok": result["ok"], "problems": result["problems"]}, indent=2))
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
