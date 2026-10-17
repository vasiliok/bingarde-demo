#!/usr/bin/env python3
"""Upload the demo builds to a Bingarde server, like a CI would.

For every <project>/<branch>/<build>/<platform>-<config>-<arch>/ folder:
  1. create the build with status "uploading" (POST /api/v2/builds)
  2. upload all its files (POST /api/v2/builds/<id>/files); roles come from the file names
  3. mark it "complete", or "failed" when meta.json says so (PATCH /api/v2/builds/<id>)

Usage:
  BINGARDE_URL=http://localhost:8080 BINGARDE_TOKEN=bg_... python3 seed.py [--from SOURCE] [--replace]

--from is where the builds come from: a folder (default: out/ next to this
script, made by build-all.sh), a .zip file, or the http(s) URL of a .zip.
A zip may hold the build folders at its top or inside one folder (like out/).

--replace deletes every existing build first; that needs a write token of an
admin (an e-mail listed in ADMIN_EMAILS). Users, tokens and presets are kept.
Standard library only.
"""
import argparse
import hashlib
import json
import mimetypes
import os
import shutil
import sys
import tempfile
import urllib.error
import urllib.request
import uuid
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))

COMMIT_MESSAGES = [
    "Fix entity update order on fast frames",
    "Add world checksum to the debug overlay",
    "Bump SDK and toolchain versions",
    "Speed up spawn path for large worlds",
    "Guard against empty entity lists",
    "Clean up compiler warnings",
    "Tune physics step for 120 Hz displays",
    "Log engine version at startup",
]


class Api:
    def __init__(self, url, token):
        self.url = url.rstrip("/")
        self.token = token

    def call(self, method, path, body=None, files=None):
        """A JSON body, or files as multipart/form-data. Returns the JSON answer."""
        headers = {"Authorization": "Bearer " + self.token, "Accept": "application/json"}
        data = None
        if files:
            boundary = uuid.uuid4().hex
            data = encode_multipart({}, files, boundary)
            headers["Content-Type"] = "multipart/form-data; boundary=" + boundary
        elif body is not None:
            data = json.dumps(body).encode()
            headers["Content-Type"] = "application/json"
        request = urllib.request.Request(self.url + path, data=data, headers=headers, method=method)
        try:
            with urllib.request.urlopen(request, timeout=300) as response:
                raw = response.read()
        except urllib.error.HTTPError as exc:
            error = json.load(exc).get("error", {})
            raise SystemExit("API error on %s %s: %s" % (method, path, error.get("message", exc)))
        return json.loads(raw) if raw else None


def encode_multipart(fields, files, boundary):
    parts = []
    for name, value in fields.items():
        parts.append(("--%s\r\nContent-Disposition: form-data; name=\"%s\"\r\n\r\n%s\r\n"
                      % (boundary, name, value)).encode())
    for name, path in files:
        filename = os.path.basename(path)
        ctype = mimetypes.guess_type(filename)[0] or "application/octet-stream"
        with open(path, "rb") as f:
            content = f.read()
        parts.append(("--%s\r\nContent-Disposition: form-data; name=\"%s\"; filename=\"%s\"\r\n"
                      "Content-Type: %s\r\n\r\n" % (boundary, name, filename, ctype)).encode()
                     + content + b"\r\n")
    parts.append(("--%s--\r\n" % boundary).encode())
    return b"".join(parts)


def history(project, branch, build):
    """A few believable changelog lines, the same for the same build every time."""
    lines = []
    for back in range(4):
        rev = hashlib.sha1(("%s/%s/%d" % (project, branch, build - back)).encode()).hexdigest()
        message = COMMIT_MESSAGES[int(rev[:4], 16) % len(COMMIT_MESSAGES)]
        lines.append("%s %s" % (rev[:10], message))
    return "\n".join(lines)


def variants(out_dir):
    for root, dirs, files in sorted(os.walk(out_dir)):
        dirs.sort()
        if "meta.json" not in files:
            continue
        rel = os.path.relpath(root, out_dir).split(os.sep)
        if len(rel) != 4:
            continue
        project, branch, build, _ = rel
        with open(os.path.join(root, "meta.json")) as f:
            meta = json.load(f)
        uploads = sorted(os.path.join(root, n) for n in files if n != "meta.json")
        yield project, branch, int(build), meta, uploads


def builds_root(folder):
    """The folder that holds <project>/<branch>/<build>/<variant>/meta.json, or None."""
    folder = os.path.abspath(folder)
    for root, dirs, files in sorted(os.walk(folder)):
        dirs.sort()
        if "meta.json" in files:
            base = os.path.normpath(os.path.join(root, *[os.pardir] * 4))
            # Only accept it if it is inside the given folder.
            if os.path.commonpath([base, folder]) == folder:
                return base
    return None


def open_source(source, workdir):
    """Turn --from (folder, zip file or zip URL) into a local builds folder."""
    if source.lower().startswith(("http://", "https://")):
        archive = os.path.join(workdir, "builds.zip")
        print("downloading %s" % source)
        try:
            with urllib.request.urlopen(source, timeout=300) as response, open(archive, "wb") as f:
                shutil.copyfileobj(response, f)
        except (urllib.error.URLError, OSError) as exc:
            sys.exit("could not download %s: %s" % (source, exc))
        source = archive
    if os.path.isfile(source):
        if not zipfile.is_zipfile(source):
            sys.exit("%s is not a folder or a zip file" % source)
        folder = os.path.join(workdir, "unzipped")
        with zipfile.ZipFile(source) as z:
            z.extractall(folder)
    elif os.path.isdir(source):
        folder = source
    else:
        sys.exit("%s does not exist (build it with build-all.sh, or pass --from with "
                 "a folder, a .zip file or a .zip URL)" % source)
    root = builds_root(folder)
    if root is None:
        sys.exit("no builds found in %s: expected <project>/<branch>/<build>/<variant>/meta.json"
                 % source)
    return root


def delete_all(api):
    """Delete every build, a page at a time, until none is left."""
    seen = set()
    while True:
        builds = api.call("GET", "/api/v2/builds?limit=1000")["builds"]
        if not builds:
            return len(seen)
        for build in builds:
            seen.add(build["id"])
            api.call("DELETE", "/api/v2/builds/%d" % build["id"])


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--url", default=os.environ.get("BINGARDE_URL", "http://localhost:8080"))
    parser.add_argument("--token", default=os.environ.get("BINGARDE_TOKEN"))
    parser.add_argument("--from", dest="source", default=os.path.join(HERE, "out"),
                        help="folder, .zip file or .zip URL with the builds (default: out/)")
    parser.add_argument("--replace", action="store_true", help="delete all existing builds first")
    args = parser.parse_args()
    if not args.token:
        sys.exit("set BINGARDE_TOKEN (a write token; an admin's for --replace)")

    with tempfile.TemporaryDirectory(prefix="bingarde-seed-") as workdir:
        builds = open_source(args.source, workdir)
        api = Api(args.url, args.token)
        if args.replace:
            print("deleted %d existing builds" % delete_all(api))
        seed(api, builds)


def seed(api, builds):
    count = files = 0
    for project, branch, build, meta, uploads in variants(builds):
        properties = {k: meta[k] for k in ("compiler", "sdk", "triple") if k in meta}
        record = api.call("POST", "/api/v2/builds", {
            "project": project, "branch": branch, "build": build,
            "platform": meta["platform"], "config": meta["config"], "arch": meta["arch"],
            "revision": hashlib.sha1(("%s/%s/%d" % (project, branch, build)).encode()).hexdigest(),
            "status": "uploading",
            "ci_url": "https://ci.example.com/job/%s-%s/%d" % (project, meta["platform"], build),
            "properties": properties,
            "history": history(project, branch, build),
        })
        if uploads:
            api.call("POST", "/api/v2/builds/%d/files" % record["id"],
                     files=[("f%d" % i, path) for i, path in enumerate(uploads)])
        api.call("PATCH", "/api/v2/builds/%d" % record["id"], {"status": meta.get("status", "complete")})
        count += 1
        files += len(uploads)
        print("%-6s %-12s %4d  %-7s %-8s %-9s %d files" % (
            project, branch, build, meta["platform"], meta["config"], meta["arch"], len(uploads)))
    print("seeded %d builds, %d files" % (count, files))


if __name__ == "__main__":
    main()
