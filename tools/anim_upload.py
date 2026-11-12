#!/usr/bin/env python3
"""Animation-upload spike (PLAN_STEAM_PLUS §4.4 A3): upload a Lune-written KeyframeSequence .rbxm as an
Open Cloud **Animation** asset, with the multipart + operation pattern of tools/kit_upload.py.

  lune run tools/anim_spike.luau build/anim_spike.rbxm
  python3 tools/anim_upload.py build/anim_spike.rbxm          # prints the asset id or the exact error

The result goes to assets/anim_ids.json ({stem: {assetId, sha256, moderation}}). The engine check is
tests/clone_engine.luau ("animation spike"): it loads the id on a server-side R15 rig's Animator.
Key: in a Claude cloud session the network proxy injects it (any placeholder works); locally set
ROBLOX_API_KEY. The asset must belong to the experience owner, or the game cannot play it.
"""

import json
import os
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import kit_upload as K  # noqa: E402  (multipart, call, wait_operation, OWNER_USER_ID)

IDS = K.ROOT / "assets/anim_ids.json"


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    path = pathlib.Path(sys.argv[1]).resolve()
    key = os.environ.get("ROBLOX_API_KEY", "proxy-injected")
    request = {
        "assetType": "Animation",
        "displayName": "EH Spike " + path.stem,
        "description": f"Heist Yourself animation spike: {path.name} (sha256 {K.sha256(path)[:16]})",
        "creationContext": {"creator": K.CREATOR},
    }
    body, form_type = K.multipart([
        ("request", None, "application/json", json.dumps(request).encode()),
        ("fileContent", path.name, "model/x-rbxm", path.read_bytes()),
    ])
    try:
        op = K.call("POST", f"{K.API}/assets", key, body, form_type)
        print("create response:", json.dumps(op)[:800])
        if "path" not in op:
            print("NO OPERATION: the upload was not accepted")
            return 1
        resp = K.wait_operation(key, op["path"])
    except (K.ScopeError, RuntimeError) as e:
        print("UPLOAD REFUSED:", str(e)[:2000])
        return 1
    print("operation response:", json.dumps(resp)[:800])
    asset_id = resp.get("assetId")
    if not asset_id:
        print("operation finished without an assetId")
        return 1
    ids = K.load_json(IDS, {})
    ids[path.stem] = {
        "assetId": int(asset_id),
        "sha256": K.sha256(path),
        "moderation": (resp.get("moderationResult") or {}).get("moderationState"),
    }
    IDS.write_text(json.dumps(ids, indent=2) + "\n")
    print(f"ACCEPTED: Animation asset {asset_id} -> {IDS.relative_to(K.ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
