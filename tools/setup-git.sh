#!/bin/sh
# One-time setup for a fresh clone. Safe to re-run.
#
#     sh tools/setup-git.sh
#
# Installs the two things git will not let a repository install for itself,
# because both of them run code and a clone is not trusted:
#
#   1. The merge driver for assets/mesh-source/asset_manifest.csv, so a merge or
#      rebase can never replace a Roblox asset id with a blank one. .gitattributes
#      already points at it; this is the half that has to be local.
#
#   2. .githooks as the hook path, which adds a pre-push check that the manifest
#      has not lost any ids. That is the last chance to catch it before the loss
#      is on the branch.
#
# Neither is required to work on the repo. Without them, CI still fails on a
# damaged manifest — you just find out later and after a push instead of before.
set -e

cd "$(dirname "$0")/.."

git config merge.meshmanifest.name "mesh manifest (asset ids never go backwards)"
git config merge.meshmanifest.driver "python3 tools/manifest-merge.py %O %A %B %P"
echo "ok  merge driver registered for assets/mesh-source/asset_manifest.csv"

git config core.hooksPath .githooks
echo "ok  hooks path set to .githooks (pre-push manifest check)"

echo
echo "Verifying:"
python3 tests/check-manifest.py
