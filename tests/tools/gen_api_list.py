#!/usr/bin/env python3
"""Generate the list of names ReaImGui exposes for a given API version.

Usage:  python3 gen_api_list.py <path-to-reaimgui-checkout> [version] > ../reaimgui_api_0.9.txt

For every name we find the version it was introduced in (the oldest of its
API_* declarations in api/*.cpp and SHIM_FUNC / SHIM_PROXY / SHIM_ALIAS in
shims/*.cpp). Names that no longer exist in api/ are treated as removed at the
version of the shim file that keeps them alive. A name is available to
`require 'imgui' '<version>'` when introduced <= version < removed.
"""
import re, sys, pathlib

root = pathlib.Path(sys.argv[1])
def ver(s):
    v = tuple(int(x) for x in s.replace(".", "_").split("_"))
    return v + (0,) * (3 - len(v))
req = ver(sys.argv[2] if len(sys.argv) > 2 else "0.9")

intro, in_api, removed = {}, set(), {}
def seen(name, v):
    if name not in intro or v < intro[name]:
        intro[name] = v

api_decl = re.compile(r"API_\w*\(\s*(\d+(?:_\d+)*)\s*,\s*(?:[^,()]+,\s*)?(\w+)\s*[,)]")
for f in sorted((root / "api").glob("*.cpp")):
    for m in api_decl.finditer(f.read_text(encoding="utf8")):
        seen(m.group(2), ver(m.group(1)))
        in_api.add(m.group(2))

shim_decl = re.compile(r"SHIM_(?:FUNC|PROXY|ALIAS)\(\s*(\d+(?:_\d+)*)\s*,\s*(?:[^,()]+,\s*)??(\w+)\s*[,)]")
for f in sorted((root / "shims").glob("*.cpp")):
    text = f.read_text(encoding="utf8")
    file_ver = ver(f.stem)
    for m in re.finditer(r"SHIM_(FUNC|PROXY|ALIAS)\(\s*(\d+(?:_\d+)*)\s*,\s*(.*?)[,)]", text):
        kind, v, rest = m.group(1), ver(m.group(2)), m.group(3)
        # SHIM_FUNC(ver, ret, Name, ...) / SHIM_PROXY(ver, Name, ...) / SHIM_ALIAS(ver, Name, Target)
        if kind == "FUNC":
            nm = re.match(r"\s*([\w:<>* ]+?)\s*,\s*(\w+)", text[m.start(3):])
            name = nm.group(2) if nm else None
        else:
            name = rest.strip()
        if name and re.fullmatch(r"\w+", name):
            seen(name, v)
            if name not in in_api:
                removed[name] = min(removed.get(name, (99, 0, 0)), file_ver)

names = sorted(n for n, v in intro.items() if v <= req < removed.get(n, (99, 0, 0)))
print("\n".join(names))
