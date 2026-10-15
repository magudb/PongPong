extends RefCounted
## Forward-reference scanner (package T-towns-core, task 20): the package-level "no forward dependencies" proof does not see class_name references, and a direct reference to the class of a LATER
## wave is a parse error until that package landed and `--import` ran (measured on the unedited drafts: `Parse Error: Identifier "Routines" not declared in the current scope`).
## scan(paths, forbidden) lists every use of a forbidden identifier OUTSIDE strings and comments: "res://path.gd:LINE identifier". Mentions inside a string literal (the path of Svc.static_call) or
## after a `#` are fine: that is exactly how a later class is allowed to appear. Reused by T-routes and T-director with their own lists.

## The identifiers of classes and autoloads that belong to LATER packages (or to the S track, built in the same wave): never named directly by the scripts of this package.
const WAVE4_FORBIDDEN: Array[String] = [
	"Routines", "RouteTable", "NavGrid", "FestSet", "NpcDirector", "TownsValidate", "TownMarks", "LevelNav",     # T-routes (wave 5)
	"TownDirector", "TownMarker", "CitizenStub", "CityTown",                                                   # T-director (wave 5b)
	"GiftRules", "GiftFlow", "SocialTalk", "SocialManager", "LootService", "HomeManager",                       # S-* and the feature autoloads: reached through Svc.node
]


## "path:line identifier" for every hit; `paths` are res:// paths of GDScript files.
static func scan(paths: Array, forbidden: Array = WAVE4_FORBIDDEN) -> Array[String]:
	var hits: Array[String] = []
	for p in paths:
		if not FileAccess.file_exists(str(p)):
			hits.append("%s: file does not exist" % p)
			continue
		hits.append_array(scan_text(FileAccess.get_file_as_string(str(p)), forbidden, str(p)))
	return hits


static func scan_text(text: String, forbidden: Array, label: String = "text") -> Array[String]:
	var hits: Array[String] = []
	var rx: Dictionary = {}
	for id in forbidden:
		var r := RegEx.new()
		r.compile("(?<![A-Za-z0-9_])%s(?![A-Za-z0-9_])" % str(id))
		rx[str(id)] = r
	var lines: PackedStringArray = _code_only(text)
	for i in lines.size():
		for id in rx:
			if (rx[id] as RegEx).search(lines[i]) != null:
				hits.append("%s:%d %s" % [label, i + 1, id])
	return hits


## The text with comments and string literals blanked out, line by line (strings: "..." '...' and triple-quoted ones; `#` comments; escapes respected).
static func _code_only(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	var triple: String = ""                           # the quote of an open triple-quoted string spanning lines
	for raw in text.split("\n"):
		var line: String = raw
		var res: String = ""
		var i: int = 0
		var quote: String = triple
		while i < line.length():
			var ch: String = line[i]
			if quote != "":
				if quote.length() == 3 and line.substr(i, 3) == quote:
					quote = ""
					triple = ""
					i += 3
					continue
				if quote.length() == 1 and ch == "\\":
					i += 2
					continue
				if quote.length() == 1 and ch == quote:
					quote = ""
				i += 1
				continue
			if ch == "#":
				break
			if (ch == "\"" or ch == "'"):
				if line.substr(i, 3) == ch.repeat(3):
					quote = ch.repeat(3)
					triple = quote
					i += 3
					continue
				quote = ch
				i += 1
				continue
			res += ch
			i += 1
		if quote.length() == 1:
			quote = ""                                 # a single-quoted string never spans lines
		out.append(res)
	return out
