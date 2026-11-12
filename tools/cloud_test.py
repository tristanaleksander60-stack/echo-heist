#!/usr/bin/env python3
"""Publish the Rojo-built place and run tests/engine_smoke.luau in a real Roblox server.

Uses Roblox Open Cloud:
  1. Place publishing:   POST /universes/v1/{universe}/places/{place}/versions
  2. Luau Execution:     POST /cloud/v2/universes/{u}/places/{p}/versions/{v}/luau-execution-session-tasks
                         then poll GET /cloud/v2/{task path}

Usage:
  python3 tools/cloud_test.py --universe 123 --place 456 [--place-file build/EchoHeist.rbxlx]
                              [--script tests/engine_smoke.luau] [--publish-type Saved|Published]

API key: an Open Cloud key with the scopes universe-places:write and
luau-execution-sessions:write for this experience. In a Claude cloud session
the key is injected by the network proxy (x-api-key header); locally, set
ROBLOX_API_KEY.
"""
import argparse, json, os, subprocess, sys, time, urllib.request, urllib.error

BASE = "https://apis.roblox.com"


def call(method, url, key, body=None, ctype="application/json"):
    data = body if isinstance(body, (bytes, type(None))) else json.dumps(body).encode()
    req = urllib.request.Request(url, data=data, method=method,
                                 headers={"x-api-key": key, "Content-Type": ctype, "User-Agent": "echo-heist-cloud-test"})
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            return json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        sys.exit(f"HTTP {e.code} on {method} {url}\n{e.read().decode(errors='replace')[:2000]}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--universe", required=True)
    ap.add_argument("--place", required=True)
    ap.add_argument("--place-file", default="build/EchoHeist.rbxlx")
    ap.add_argument("--script", default="tests/engine_smoke.luau")
    ap.add_argument("--publish-type", default="Saved", choices=["Saved", "Published"])
    ap.add_argument("--version", type=int, help="skip publishing and test this existing version")
    ap.add_argument("--no-build", action="store_true",
                    help="publish --place-file as it is (default: rebuild it with Rojo first, so a stale file never goes up)")
    a = ap.parse_args()
    key = os.environ.get("ROBLOX_API_KEY", "injected-by-proxy")

    version = a.version
    if version is None:
        if not a.no_build and a.place_file == "build/EchoHeist.rbxlx":
            os.makedirs("build", exist_ok=True)
            subprocess.run(["rojo", "build", "-o", a.place_file], check=True, stdout=subprocess.DEVNULL)
            print(f"Rebuilt {a.place_file} with Rojo")
        body = open(a.place_file, "rb").read()
        ctype = "application/xml" if a.place_file.endswith(".rbxlx") else "application/octet-stream"
        r = call("POST", f"{BASE}/universes/v1/{a.universe}/places/{a.place}/versions?versionType={a.publish_type}", key, body, ctype)
        version = r.get("versionNumber")
        print(f"Published place version {version} ({a.publish_type})")

    script = open(a.script, encoding="utf-8").read()
    task = call("POST", f"{BASE}/cloud/v2/universes/{a.universe}/places/{a.place}/versions/{version}/luau-execution-session-tasks",
                key, {"script": script, "timeout": "120s"})
    path = task.get("path")
    print("Task:", path)
    for _ in range(90):
        time.sleep(3)
        t = call("GET", f"{BASE}/cloud/v2/{path}", key)
        state = t.get("state")
        if state in ("COMPLETE", "FAILED", "CANCELLED"):
            if state == "COMPLETE":
                for res in (t.get("output") or {}).get("results", []):
                    print(res)
                logs = call("GET", f"{BASE}/cloud/v2/{path}/logs", key)
                for chunk in logs.get("luauExecutionSessionTaskLogs", []):
                    for line in chunk.get("messages", []):
                        print("[log]", line)
                out = "\n".join(str(x) for x in (t.get("output") or {}).get("results", []))
                sys.exit(1 if "FAIL" in out else 0)
            print("Task", state, json.dumps(t.get("error"), indent=2))
            logs = call("GET", f"{BASE}/cloud/v2/{path}/logs", key)
            for chunk in logs.get("luauExecutionSessionTaskLogs", []):
                for line in chunk.get("messages", []):
                    print("[log]", line)
            sys.exit(1)
    sys.exit("Timed out waiting for the Luau task")


if __name__ == "__main__":
    main()
