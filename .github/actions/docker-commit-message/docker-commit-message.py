#!/usr/bin/env python3

import os
import re
import shlex
import subprocess
from collections import defaultdict

diff = subprocess.check_output(
    ["git", "diff", "-U0", "--no-color"],
    text=True,
)


def from_ref(line):
    content = re.sub(r"^[+-]\s*FROM\s+", "", line, flags=re.I)
    return next(
        (value for value in shlex.split(content) if not value.startswith("--")),
        None,
    )


def ref_parts(ref):
    base, _, digest = ref.partition("@")
    slash = base.rfind("/")
    colon = base.rfind(":")

    if colon > slash:
        repository = base[:colon]
        tag = base[colon + 1 :]
    else:
        repository = base
        tag = ""

    return repository.rsplit("/", 1)[-1], tag, digest


def version_pair(old, new):
    _, old_tag, old_digest = ref_parts(old)
    _, new_tag, new_digest = ref_parts(new)

    if old_tag != new_tag:
        return old_tag or old, new_tag or new

    if old_digest != new_digest:
        return old_digest or old, new_digest or new

    return old, new


def update_type(old, new):
    _, old_tag, old_digest = ref_parts(old)
    _, new_tag, new_digest = ref_parts(new)

    if old_tag == new_tag and old_digest != new_digest:
        return "digest-update"

    def version(tag):
        match = re.match(
            r"^[vV]?(\d+)(?:\.(\d+))?(?:\.(\d+))?",
            tag,
        )

        if not match:
            return None

        return tuple(
            map(
                int,
                (
                    match.group(1),
                    match.group(2) or 0,
                    match.group(3) or 0,
                ),
            )
        )

    old_version = version(old_tag)
    new_version = version(new_tag)

    if not old_version or not new_version:
        return "version-update"

    if old_version[0] != new_version[0]:
        return "version-update:semver-major"

    if old_version[1] != new_version[1]:
        return "version-update:semver-minor"

    if old_version[2] != new_version[2]:
        return "version-update:semver-patch"

    return "version-update"


changes = []
current_file = None
old_images = []

for line in diff.splitlines():
    if line.startswith("+++ b/"):
        current_file = line[6:]
        old_images = []
        continue

    if line.startswith("@@"):
        old_images = []
        continue

    if not current_file:
        continue

    if not os.path.basename(current_file).lower().startswith("dockerfile"):
        continue

    if re.match(r"^-\s*FROM\s+", line, re.I):
        old_images.append(from_ref(line))
        continue

    if re.match(r"^\+\s*FROM\s+", line, re.I) and old_images:
        old = old_images.pop(0)
        new = from_ref(line)

        if old and new and old != new:
            directory = os.path.dirname(current_file)
            directory = f"/{directory}" if directory else "/"
            changes.append((directory, old, new))


if not changes:
    raise SystemExit("No Dockerfile FROM changes found")


def dependency(old, new):
    name = ref_parts(new)[0]
    before, after = version_pair(old, new)
    return name, before, after


def plural(count, word):
    return word if count == 1 else f"{word}s"


groups = defaultdict(list)

for directory, old, new in changes:
    groups[directory].append((old, new))

unique_updates = {dependency(old, new) for _, old, new in changes}

directory_count = len(groups)
update_count = len(unique_updates)

if directory_count == 1:
    location = f"in the {next(iter(groups))} directory"
else:
    location = f"across {directory_count} directories"

message = [
    (
        f"chore(deps): bump the docker group {location} "
        f"with {update_count} {plural(update_count, 'update')} [no ci]"
    ),
    "",
]

for directory, items in sorted(groups.items()):
    directory_updates = {dependency(old, new) for old, new in items}

    names = ", ".join(sorted({item[0] for item in directory_updates}))

    count = len(directory_updates)

    message.append(
        f"Bumps the docker group with {count} "
        f"{plural(count, 'update')} in the {directory} directory: "
        f"{names}."
    )

message.append("")

for _, old, new in changes:
    name, before, after = dependency(old, new)

    message.extend(
        [
            f"Updates `{name}` from {before} to {after}",
            "",
        ]
    )

message.extend(
    [
        "---",
        "updated-dependencies:",
    ]
)

for _, old, new in changes:
    name, _, after = dependency(old, new)

    message.extend(
        [
            f"- dependency-name: {name}",
            f"  dependency-version: '{after}'",
            "  dependency-type: direct:production",
            f"  update-type: {update_type(old, new)}",
            "  dependency-group: docker",
        ]
    )

message.append("...")

print("\n".join(message))
