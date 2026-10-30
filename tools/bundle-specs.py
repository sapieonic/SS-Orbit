#!/usr/bin/env python3
"""Bundle the module specs into one OpenAPI file per client: contracts/build/mobile.yaml and web.yaml.

The client generators (dart-dio for mobile/, orval for web/) need one input file each. This merges every
contracts/openapi/<module>.yaml, keeps the paths of the client's surfaces and only the components those paths
(and a few doc-only roots, below) reach.

    mobile.yaml  /v1/auth/, /v1/farmer/, /v1/fa/, /v1/web/   (farmer app, FA app)
    web.yaml     /v1/auth/, /v1/admin/, /v1/web/             (HO portal, farmer web pages)

It fails (exit 1, naming both specs) when two specs define the same component name with different bodies,
when two specs define the same path or operationId, or when a $ref in a bundle does not resolve. Fix a clash at
the source by renaming the schema (names are not on the wire). Refs to _shared_components.yaml
('_shared_components.yaml#/components/...') are resolved into the bundle like local ones.

Run from anywhere (needs PyYAML):
    python3 tools/bundle-specs.py           # write contracts/build/*.yaml
    python3 tools/bundle-specs.py --check   # exit 1 if the committed bundles are stale (CI)
"""
import argparse
import copy
import pathlib
import sys

import yaml

ROOT = pathlib.Path(__file__).resolve().parent.parent
SPECS = ROOT / "contracts" / "openapi"
BUILD = ROOT / "contracts" / "build"
SHARED = "_shared_components.yaml"

BUNDLES = {
    "mobile": {
        "title": "Orbit mobile API (farmer app, FA app)",
        "prefixes": ["/v1/auth/", "/v1/farmer/", "/v1/fa/", "/v1/web/"],
        # Doc-only schemas no path references, kept so clients get typed models:
        # the sync command payloads (CommandIn.payload is free-form on the wire).
        "roots": [("schemas", "SyncCommandPayloads")],
    },
    "web": {
        "title": "Orbit web API (HO portal, farmer web pages)",
        "prefixes": ["/v1/auth/", "/v1/admin/", "/v1/web/"],
        "roots": [],
    },
}

SECTIONS = ["schemas", "parameters", "responses", "requestBodies", "headers", "examples", "links",
            "callbacks", "securitySchemes"]
METHODS = {"get", "put", "post", "delete", "options", "head", "patch", "trace"}


class BundleError(Exception):
    pass


class NoAliasDumper(yaml.SafeDumper):
    """Never emit &anchors / *aliases (generators handle them badly)."""

    def ignore_aliases(self, data):
        return True


def local_ref(ref, spec_name):
    """Map a $ref to (section, name), or raise for anything outside components."""
    file, _, frag = ref.partition("#")
    if file not in ("", SHARED):
        raise BundleError(f"{spec_name}: unsupported $ref {ref!r} (only local and {SHARED} refs)")
    parts = frag.strip("/").split("/")
    if len(parts) != 3 or parts[0] != "components" or parts[1] not in SECTIONS:
        raise BundleError(f"{spec_name}: unsupported $ref {ref!r}")
    return parts[1], parts[2]


def normalise(node, spec_name):
    """Deep copy with every $ref rewritten to the local '#/components/<section>/<name>' form."""
    if isinstance(node, dict):
        out = {}
        for k, v in node.items():
            if k == "$ref" and isinstance(v, str):
                section, name = local_ref(v, spec_name)
                out[k] = f"#/components/{section}/{name}"
            else:
                out[k] = normalise(v, spec_name)
        return out
    if isinstance(node, list):
        return [normalise(v, spec_name) for v in node]
    return node


def refs_in(node):
    """Yield every (section, name) referenced under node (already normalised)."""
    if isinstance(node, dict):
        for k, v in node.items():
            if k == "$ref" and isinstance(v, str):
                parts = v.split("/")
                yield parts[2], parts[3]
            else:
                yield from refs_in(v)
    elif isinstance(node, list):
        for v in node:
            yield from refs_in(v)


def load_specs():
    """Return (modules, components). modules: name -> normalised doc. components: (section, name) -> (body, spec)."""
    modules = {}
    components = {}
    errors = []
    files = sorted(SPECS.glob("*.yaml"), key=lambda p: (p.name != SHARED, p.name))  # shared first
    for path in files:
        doc = normalise(yaml.safe_load(path.read_text()), path.name)
        for section, items in (doc.get("components") or {}).items():
            if section not in SECTIONS:
                errors.append(f"{path.name}: unknown components section {section!r}")
                continue
            for name, body in (items or {}).items():
                key = (section, name)
                if key in components and components[key][0] != body:
                    errors.append(f"components/{section}/{name} differs between {components[key][1]} and "
                                  f"{path.name}; rename one (or make the bodies identical)")
                components.setdefault(key, (body, path.name))
        if path.name != SHARED:
            modules[path.stem] = doc
    if errors:
        raise BundleError("\n".join(errors))
    return modules, components


def build(bundle, cfg, modules, components):
    paths, op_ids, tags, errors = {}, {}, {}, []
    used_modules = []
    for mod in sorted(modules):
        doc = modules[mod]
        kept = False
        for path, item in (doc.get("paths") or {}).items():
            if not any(path.startswith(p) for p in cfg["prefixes"]):
                continue
            if path in paths:
                errors.append(f"path {path} is defined in {paths[path][1]}.yaml and {mod}.yaml")
                continue
            for method, op in item.items():
                if method in METHODS and isinstance(op, dict) and op.get("operationId"):
                    oid = op["operationId"]
                    if oid in op_ids:
                        errors.append(f"operationId {oid} is used in {op_ids[oid]}.yaml and {mod}.yaml")
                    op_ids[oid] = mod
            paths[path] = (item, mod)
            kept = True
        if kept:
            used_modules.append(mod)
            for t in doc.get("tags") or []:
                tags.setdefault(t["name"], t)  # first spec (alphabetical) wins the description
    if errors:
        raise BundleError(f"{bundle}: " + "\n".join(errors))

    # Components reachable from the kept paths, the global security and the doc-only roots.
    wanted = set()
    todo = [r for item, _ in paths.values() for r in refs_in(item)]
    todo += [("securitySchemes", "bearerAuth")] + list(cfg["roots"])
    missing = []
    while todo:
        key = todo.pop()
        if key in wanted:
            continue
        if key not in components:
            missing.append(f"#/components/{key[0]}/{key[1]}")
            continue
        wanted.add(key)
        todo.extend(refs_in(components[key][0]))
    if missing:
        raise BundleError(f"{bundle}: unresolved $ref(s): " + ", ".join(sorted(set(missing))))

    comps = {}
    for section in SECTIONS:
        names = sorted(n for s, n in wanted if s == section)
        if names:
            comps[section] = {n: copy.deepcopy(components[(section, n)][0]) for n in names}

    used_tags = {t for item, _ in paths.values() for op in item.values() if isinstance(op, dict)
                 for t in op.get("tags") or []}
    return {
        "openapi": "3.0.3",
        "info": {
            "title": cfg["title"],
            "version": max((modules[m].get("info") or {}).get("version", "0.0.0") for m in used_modules),
            "description": "Generated by tools/bundle-specs.py from contracts/openapi/{"
                           + ",".join(used_modules) + "}.yaml. Do not edit; edit the module specs and re-run it.",
        },
        "tags": [copy.deepcopy(tags[t]) for t in sorted(tags) if t in used_tags],
        "security": [{"bearerAuth": []}],
        "paths": {p: copy.deepcopy(paths[p][0]) for p in sorted(paths)},
        "components": comps,
    }


def render(doc):
    return yaml.dump(doc, Dumper=NoAliasDumper, sort_keys=False, allow_unicode=True, width=120,
                     default_flow_style=False)


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--check", action="store_true", help="exit 1 if contracts/build/ is stale; write nothing")
    args = ap.parse_args()
    try:
        modules, components = load_specs()
        outputs = {BUILD / f"{name}.yaml": render(build(name, cfg, modules, components))
                   for name, cfg in BUNDLES.items()}
    except BundleError as e:
        print(f"bundle-specs: {e}", file=sys.stderr)
        return 1

    if args.check:
        stale = [p for p, text in outputs.items() if not p.exists() or p.read_text() != text]
        for p in stale:
            print(f"bundle-specs: {p.relative_to(ROOT)} is stale; run python3 tools/bundle-specs.py", file=sys.stderr)
        return 1 if stale else 0

    BUILD.mkdir(parents=True, exist_ok=True)
    for p, text in outputs.items():
        p.write_text(text)
        print(f"wrote {p.relative_to(ROOT)} ({text.count(chr(10))} lines)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
