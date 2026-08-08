#!/usr/bin/env python3
"""Run a Luau script inside a real place via Open Cloud, and print its output.

The blind spot this closes: nothing in CI can SEE the game. Every check here
runs upstream of the screen, which is how a completely broken asset pipeline
stayed green for hours — and after that was fixed, how "loads fine" and "looks
right" kept getting conflated. The Luau Execution API runs a script in a fresh
server of the actual published place, with the actual DataModel, the actual
uploaded assets and the experience's real permissions, and hands the logs back.
It cannot judge aesthetics, but it answers every geometric and structural
question without spending one of the owner's playtests.

    python3 tools/luau-exec.py --universe U --place P --script tools/foo.luau

Needs ROBLOX_API_KEY with the "Luau Execution" API system enabled for the
experience. If the key lacks it, the POST comes back 401/403 — that is a
one-toggle fix in Creator Hub, and this prints exactly that instead of a stack
trace. Runs from CI; this container cannot reach Roblox.
"""
import argparse
import json
import os
import sys
import time

API = "https://apis.roblox.com/cloud/v2"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--universe", required=True)
    parser.add_argument("--place", required=True)
    parser.add_argument("--script", required=True)
    parser.add_argument("--timeout", type=int, default=300, help="seconds to wait for the task")
    args = parser.parse_args()

    key = os.environ.get("ROBLOX_API_KEY", "").strip()
    if not key:
        raise SystemExit("ROBLOX_API_KEY is not set")
    import requests

    with open(args.script, encoding="utf-8") as handle:
        source = handle.read()

    session = requests.Session()
    session.headers["x-api-key"] = key

    def call(method, url, **kwargs):
        """One transient failure must not abort a 5-minute task run.

        Retries 429/5xx and network-level exceptions with backoff; anything
        else (or the last failure) comes back for the caller to judge.
        """
        last = None
        for attempt in range(4):
            try:
                result = session.request(method, url, timeout=60, **kwargs)
            except requests.RequestException as error:
                last = error
            else:
                if result.status_code not in (429,) and result.status_code < 500:
                    return result
                last = RuntimeError(f"HTTP {result.status_code}: {result.text[:200]}")
            time.sleep(2 ** attempt)
        raise SystemExit(f"{method} {url.rsplit('/cloud/', 1)[-1]} kept failing: {last}")

    response = call("POST",

        f"{API}/universes/{args.universe}/places/{args.place}/luau-execution-session-tasks",
        json={"script": source},
    )
    if response.status_code in (401, 403):
        print(
            f"HTTP {response.status_code}: the API key cannot run Luau in universe {args.universe}.\n"
            f"Fix: Creator Hub -> Open Cloud -> API Keys -> edit the key -> add the\n"
            f"'Luau Execution' API system with this experience, permission read+write.\n"
            f"Body: {response.text[:300]}"
        )
        return 2
    if response.status_code >= 300:
        print(f"create failed: HTTP {response.status_code}: {response.text[:500]}")
        return 1

    task = response.json()
    path = task["path"]
    print(f"task {path.rsplit('/', 1)[-1]} created; polling...", file=sys.stderr)

    deadline = time.time() + args.timeout
    state = task.get("state", "QUEUED")
    while state in ("QUEUED", "PROCESSING") and time.time() < deadline:
        time.sleep(3)
        poll = call("GET", f"{API}/{path}")
        if poll.status_code >= 300:
            print(f"poll failed: HTTP {poll.status_code}: {poll.text[:300]}")
            break  # still fetch whatever logs exist before giving up
        task = poll.json()
        state = task.get("state", "?")

    token = ""
    while True:
        logs = call("GET", f"{API}/{path}/logs", params={"pageToken": token} if token else None)
        if logs.status_code >= 300:
            print(f"logs fetch failed: HTTP {logs.status_code}: {logs.text[:200]}")
            break
        body = logs.json()
        for chunk in body.get("luauExecutionSessionTaskLogs", []):
            for message in chunk.get("messages", []):
                print(message)
        token = body.get("nextPageToken", "")
        if not token:
            break

    if state != "COMPLETE":
        error = task.get("error") or {}
        detail = f"{error.get('code') or ''} {(error.get('message') or '')[:800]}".strip()
        if state in ("QUEUED", "PROCESSING"):
            detail = f"still {state} when the local --timeout of {args.timeout}s elapsed; the task keeps running server-side"
        print(f"\ntask did not complete: {detail}")
        return 1
    output = (task.get("output") or {}).get("results")
    if output:
        print("\nreturn value:")
        print(json.dumps(output, indent=2)[:4000])
    return 0


if __name__ == "__main__":
    sys.exit(main())
