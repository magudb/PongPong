extends RefCounted
## Production releases use strict, canonical vX.Y.Z tags.
static func numbers(version: String) -> Array[int]:
	var regex := RegEx.new()
	regex.compile("^(0|[1-9][0-9]{0,8})\\.(0|[1-9][0-9]{0,8})\\.(0|[1-9][0-9]{0,8})$")
	if regex.search(version) == null: return []
	var out: Array[int] = []
	for part in version.split("."): out.append(int(part))
	return out

static func newer(candidate: String, current: String) -> bool:
	var a := numbers(candidate)
	var b := numbers(current)
	if a.is_empty() or b.is_empty(): return false
	for index in 3:
		if a[index] != b[index]: return a[index] > b[index]
	return false

static func select_asset(release: Dictionary, current: String, repository: String, platform_name: String) -> Dictionary:
	var tag: Variant = release.get("tag_name", "")
	if not tag is String or not tag.begins_with("v") or release.get("draft", true) != false or release.get("prerelease", true) != false: return {}
	var version: String = tag.substr(1)
	if not newer(version, current) or platform_name not in ["windows", "macos"]: return {}
	var name := "Traetoppen-%s-%s.zip" % [tag, platform_name]
	var expected_url := "https://github.com/%s/releases/download/%s/%s" % [repository, tag, name]
	var assets: Variant = release.get("assets", [])
	if not assets is Array: return {}
	for asset in assets:
		if not asset is Dictionary or asset.get("name") != name or asset.get("browser_download_url") != expected_url: continue
		var digest: Variant = asset.get("digest", "")
		var length: Variant = asset.get("size", 0)
		if not digest is String or not length is float and not length is int: continue
		var regex := RegEx.new()
		regex.compile("^sha256:[0-9a-f]{64}$")
		if regex.search(digest) == null or length <= 0 or length > 1073741824: continue
		return {"version": version, "url": expected_url, "name": name, "sha256": digest.substr(7), "size": int(length)}
	return {}

## GitHub's latest release may have been published before its files exist.
## Inspect a bounded catalogue and keep the newest verified update for this OS.
## A newer but unusable release is not proof that this installation is current.
static func select_catalogue(releases: Array, current: String, repository: String, platform_name: String) -> Dictionary:
	var best: Dictionary = {}
	var incomplete := false
	var malformed := releases.size() > 100
	if malformed or platform_name not in ["windows", "macos"] or numbers(current).is_empty():
		return {"state": "unavailable", "asset": {}}
	for entry in releases:
		if not entry is Dictionary:
			malformed = true
			continue
		if typeof(entry.get("draft")) != TYPE_BOOL or typeof(entry.get("prerelease")) != TYPE_BOOL:
			malformed = true
			continue
		var tag: Variant = entry.get("tag_name")
		if not tag is String:
			malformed = true
			continue
		if entry.draft or entry.prerelease:
			continue
		if not tag.begins_with("v") or not newer(tag.substr(1), current):
			continue
		incomplete = true
		var asset := select_asset(entry, current, repository, platform_name)
		if not asset.is_empty() and (best.is_empty() or newer(asset.version, best.version)):
			best = asset
	return {"state": "available" if not best.is_empty() else "unavailable" if incomplete or malformed else "current", "asset": best}
