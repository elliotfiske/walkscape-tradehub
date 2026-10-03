"""Tiny client for the WalkScape Tools API, shared by the import scripts.

Docs: https://tools-api-dev.dev.walkscape.app/docs/
Needs WALKSCAPE_DATA_API_KEY in the environment or in .env (never committed).
"""

import json
import os
import sys
import urllib.request

API = "https://tools-api-dev.dev.walkscape.app"
ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))


def api_key():
    key = os.environ.get("WALKSCAPE_DATA_API_KEY")
    env_file = os.path.join(ROOT, ".env")
    if not key and os.path.exists(env_file):
        for line in open(env_file):
            name, _, value = line.strip().partition("=")
            if name == "WALKSCAPE_DATA_API_KEY":
                key = value.strip().strip("\"'")
    if not key:
        sys.exit("WALKSCAPE_DATA_API_KEY isn't set (environment or .env).")
    return key


def call(path, body=None):
    req = urllib.request.Request(
        API + path,
        data=None if body is None else json.dumps(body).encode(),
        headers={"Authorization": "Bearer " + api_key(), "Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=120) as res:
        return json.load(res)
