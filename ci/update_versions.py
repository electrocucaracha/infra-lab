#!/usr/bin/env -S uv --quiet run --script
# Copyright (c) 2026
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Update pinned infrastructure component releases."""

# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "packaging==25.0",
#     "ruamel.yaml==0.18.16",
# ]
# ///

import io
import json
import os
import re
import urllib.request
from collections.abc import Iterable
from pathlib import Path
from urllib.parse import urlsplit, urlunsplit

from packaging.version import InvalidVersion, Version
from ruamel.yaml import YAML
from ruamel.yaml.comments import CommentedMap

yaml = YAML()
yaml.preserve_quotes = True
yaml.indent(mapping=2, sequence=4, offset=2)


def fetch(url: str, token: str | None = None) -> str:
    headers = {"User-Agent": "infra-lab-version-updater"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(request, timeout=60) as response:
        return response.read().decode()


def latest(versions: Iterable[str]) -> str:
    stable = []
    for version in versions:
        try:
            parsed = Version(version)
        except InvalidVersion:
            continue
        if not parsed.is_prerelease and not parsed.is_devrelease:
            stable.append((parsed, version))
    if not stable:
        raise ValueError("No stable versions found")
    return max(stable)[1]


def release(repository: str) -> str:
    url = f"https://api.github.com/repos/{repository}/releases/latest"
    token = os.getenv("GH_TOKEN") or os.getenv("GITHUB_TOKEN")
    data = json.loads(fetch(url, token))
    version = data["tag_name"]
    if not re.fullmatch(r"v?\d+(?:\.\d+){1,2}", version):
        releases = json.loads(fetch(url.replace("/latest", "?per_page=100"), token))
        version = latest(
            entry["tag_name"]
            for entry in releases
            if not entry["draft"]
            and not entry["prerelease"]
            and re.fullmatch(r"v?\d+(?:\.\d+){1,2}", entry["tag_name"])
        )
    return version


def save(path: Path, document: CommentedMap) -> None:
    output = io.StringIO()
    yaml.dump(document, output)
    path.write_text(output.getvalue(), encoding="utf-8")
    print(f"Updated {path}")


def main() -> None:
    for path in sorted(Path("scripts/resources/in-cluster").glob("*.yaml")):
        document = yaml.load(path)
        source = document["spec"]["source"]
        if "chart" not in source:
            continue
        chart = source["chart"]
        repository = source["repoURL"].rstrip("/")
        if repository.startswith("https://"):
            index = yaml.load(fetch(f"{repository}/index.yaml"))
            version = latest(
                entry["version"]
                for entry in index["entries"][chart]
                if not entry.get("deprecated", False)
            )
        elif repository == "ghcr.io/actions/actions-runner-controller-charts":
            scope = f"repository:actions/actions-runner-controller-charts/{chart}:pull"
            token_url = f"https://ghcr.io/token?service=ghcr.io&scope={scope}"
            token = json.loads(fetch(token_url))["token"]
            tags_url = (
                "https://ghcr.io/v2/actions/actions-runner-controller-charts/"
                f"{chart}/tags/list"
            )
            tags = json.loads(fetch(tags_url, token))["tags"]
            version = latest(tags)
        else:
            raise ValueError(f"Unsupported chart repository: {repository}")
        if Version(version) > Version(str(source["targetRevision"])):
            source["targetRevision"] = version
            save(path, document)

    releases: dict[str, str] = {}
    for path in sorted(Path("scripts/resources").rglob("kustomization.yaml")):
        document = yaml.load(path)
        changed = False
        for position, resource in enumerate(document.get("resources", [])):
            url = urlsplit(resource)
            segments = url.path.strip("/").split("/")
            if (
                url.scheme == "https"
                and url.netloc == "github.com"
                and segments[2:4] == ["releases", "download"]
            ):
                version_index = 4
            elif url.scheme == "https" and url.netloc == "raw.githubusercontent.com":
                version_index = 2
            else:
                continue
            if len(segments) <= version_index or not re.fullmatch(
                r"v?\d+(?:\.\d+){1,2}", segments[version_index]
            ):
                raise ValueError(f"Expected a pinned release URL in {path}: {resource}")
            repository = "/".join(segments[:2])
            if repository not in releases:
                releases[repository] = release(repository)
            version = releases[repository]
            if Version(version) > Version(segments[version_index]):
                segments[version_index] = version
                document["resources"][position] = urlunsplit(
                    url._replace(path="/" + "/".join(segments))
                )
                changed = True
        if changed:
            save(path, document)

    path = Path("scripts/resources/management/kind.yaml")
    document = yaml.load(path)
    tags_url = "https://hub.docker.com/v2/repositories/kindest/node/tags?page_size=100"
    tags = json.loads(fetch(tags_url))["results"]
    version = latest(
        tag["name"] for tag in tags if re.fullmatch(r"v\d+\.\d+\.\d+", tag["name"])
    )
    changed = False
    for node in document["nodes"]:
        image = node["image"]
        if not re.fullmatch(r"kindest/node:v\d+\.\d+\.\d+", image):
            raise ValueError(f"Expected a pinned kind node image: {image}")
        if Version(version) > Version(image.split(":", 1)[1]):
            node["image"] = f"kindest/node:{version}"
            changed = True
    if changed:
        save(path, document)


if __name__ == "__main__":
    main()
