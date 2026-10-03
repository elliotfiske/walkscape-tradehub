#!/usr/bin/env python3
"""Download item icons from the WalkScape Tools API into public/icons/.

    python3 scripts/pull-icons.py           # only if the API's assets changed
    python3 scripts/pull-icons.py --force   # re-download everything

Icons are saved as public/icons/<item id>.png, one per item in
src/ItemData.elm, so the frontend can use "/icons/<item id>.png" directly.
The assets version is kept in public/icons/VERSION so unchanged icons aren't
re-fetched, and icons for items no longer in the catalog are removed.
"""

import base64
import os
import re
import sys

from walkscape_api import ROOT, call

OUT = os.path.join(ROOT, "public", "icons")
ITEM_DATA = os.path.join(ROOT, "src", "ItemData.elm")
BATCH = 100


def catalog():
    """Every item id in the generated catalog."""
    return re.findall(r'\( "([^"]+)", "[^"]+", \(', open(ITEM_DATA).read())


def main():
    force = "--force" in sys.argv
    version = call("/version/")["details"]["assets"]
    version_file = os.path.join(OUT, "VERSION")
    ids = catalog()
    have_all = all(os.path.exists(os.path.join(OUT, id_ + ".png")) for id_ in ids)
    if not force and have_all and os.path.exists(version_file) and open(version_file).read().strip() == version:
        print(f"Icons are up to date (assets {version}).")
        return

    icon_paths = {a["id"]: a["icon"] for a in call("/items/") if a.get("icon")}
    wanted = {id_: icon_paths[id_] for id_ in ids if id_ in icon_paths}
    missing = [id_ for id_ in ids if id_ not in icon_paths]

    os.makedirs(OUT, exist_ok=True)
    order = list(wanted)
    written = 0
    saved = 0
    for i in range(0, len(order), BATCH):
        chunk = order[i : i + BATCH]
        icons = call("/icons/batch", {"iconPaths": [wanted[id_] for id_ in chunk]})
        for id_ in chunk:
            uri = icons.get(wanted[id_])
            if not uri:
                missing.append(id_)
                continue
            data = base64.b64decode(uri.split(",", 1)[1])
            saved += 1
            path = os.path.join(OUT, id_ + ".png")
            if not os.path.exists(path) or open(path, "rb").read() != data:
                open(path, "wb").write(data)
                written += 1
        print(f"  {min(i + BATCH, len(order))}/{len(order)}", end="\r", flush=True)
    print()

    stale = [f for f in os.listdir(OUT) if f.endswith(".png") and f[:-4] not in wanted]
    for f in stale:
        os.remove(os.path.join(OUT, f))
    open(version_file, "w").write(version + "\n")

    print(f"Icons for {saved}/{len(ids)} items (assets {version}): "
          f"{written} new or changed, {len(stale)} removed.")
    if missing:
        print("No icon for: " + ", ".join(missing), file=sys.stderr)


if __name__ == "__main__":
    main()
