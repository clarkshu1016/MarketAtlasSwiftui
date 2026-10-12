#!/usr/bin/env python3
"""Usage: build_lang.py <code>  (reads <code>_app.txt, <code>_tags.txt, <code>_misc.py; writes the .xcstrings catalogs)"""
import json, re, sys, importlib.util, pathlib
code = sys.argv[1]
H = pathlib.Path(__file__).parent
ROOT = pathlib.Path("/Users/shuclark/Documents/Github/MarketAtlas/MarketAtlasSwiftui")
spec = importlib.util.spec_from_file_location("misc", H / f"{code}_misc.py"); misc = importlib.util.module_from_spec(spec); spec.loader.exec_module(misc)

def spec_of(s):
    s = re.sub(r"%\d+\$", "%", s)
    return sorted(re.findall(r"%%|%lld|%@|%d|%f", s)) + ["\\n"] * s.count("\n")

def su(v): return {"stringUnit": {"state": "translated", "value": v}}
problems = []

def apply(path, mapping_by_key, plural_by_key=None):
    d = json.load(open(path))
    strings = d["strings"]
    n = 0
    for k, v in mapping_by_key.items():
        if k not in strings: problems.append(f"{path.name}: unknown key {k!r}"); continue
        if spec_of(k) != spec_of(v) and not k.startswith("NS"): problems.append(f"{path.name}: placeholder mismatch {k!r} -> {v!r}")
        strings[k].setdefault("localizations", {})[code] = su(v); n += 1
    for k, forms in (plural_by_key or {}).items():
        strings[k].setdefault("localizations", {})[code] = {"variations": {"plural": {c: su(t) for c, t in forms.items()}}}
        for t in forms.values():
            if spec_of(k) != spec_of(t): problems.append(f"{path.name}: plural placeholder mismatch {k!r} -> {t!r}")
        n += 1
    d["strings"] = dict(sorted(strings.items()))
    path.write_text(json.dumps(d, ensure_ascii=False, indent=2) + "\n")
    print(f"{path.name}: {n} {code} entries")

# --- app catalog
p = ROOT / "MarketAtlas" / "Localizable.xcstrings"
keys = list(json.load(open(p))["strings"].keys())
mapping = {}
for line in (H / f"{code}_app.txt").read_text().splitlines():
    if not line.strip(): continue
    i, text = line.split("|", 1); i = int(i)
    if i in misc.PLURAL: problems.append(f"index {i} is plural but has a plain line"); continue
    mapping[keys[i]] = text.replace("\\n", "\n")
plural = {keys[i]: forms for i, forms in misc.PLURAL.items()}
noloc = {k for k, v in json.load(open(p))["strings"].items() if "localizations" not in v}
missing = [k for k in keys if k not in mapping and k not in plural and k in noloc.symmetric_difference(set()) and False]
# every key that has other-language translations must be translated here too
d0 = json.load(open(p))["strings"]
need = [k for k, v in d0.items() if "ja" in v.get("localizations", {})]
miss = [k for k in need if k not in mapping and k not in plural]
if miss: problems.append(f"missing app translations: {miss[:12]} (+{len(miss)-12 if len(miss)>12 else 0})")
apply(p, mapping, plural)

# --- tags
p = ROOT / "MarketAtlas" / "Tags.xcstrings"
tags = {}
for line in (H / f"{code}_tags.txt").read_text().splitlines():
    if "|" in line:
        en, tr = line.split("|", 1); tags[en] = tr
tagkeys = json.load(open(p))["strings"].keys()
miss = [k for k in tagkeys if k not in tags]
if miss: problems.append(f"missing tags: {miss[:12]} ({len(miss)})")
apply(p, {k: v for k, v in tags.items() if k in tagkeys})

# --- server notes
p = ROOT / "MarketAtlas" / "ServerNotes.xcstrings"
sk = list(json.load(open(p))["strings"].keys())
if len(misc.SERVER) != len(sk): problems.append("server notes count mismatch")
apply(p, dict(zip(sk, misc.SERVER)))
# --- Info.plist + widget
apply(ROOT / "MarketAtlas" / "InfoPlist.xcstrings", misc.INFOPLIST)
apply(ROOT / "MarketAtlasWidget" / "Localizable.xcstrings", misc.WIDGET)
print("PROBLEMS:" if problems else "OK")
for x in problems: print(" -", x)
