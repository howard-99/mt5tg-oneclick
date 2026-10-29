#!/usr/bin/env bash
set -Eeuo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
for script in install.sh upload-editor.sh diagnose.sh tests/test-static.sh; do
  bash -n "$script"
done
bash install.sh --help | grep -Fq -- '--compiler-only'
source <(sed -n '/^supported_compiler_platform(){/,/^}/p' install.sh)
for version in v21.26.0 v21.27.0 v21.28.0-rc.1 v21.29.0-rc.1 v21.30.0-rc.1; do
  supported_compiler_platform "$version"
done
for version in v21.25.0 v21.28.0 v21.28.0-rc.2 v21.29.0 v21.29.0-rc.2 v21.30.0 v21.30.0-rc.2 v22.0.0 unknown ''; do
  if supported_compiler_platform "$version"; then exit 1; fi
done
if bash install.sh --unknown-option >/dev/null 2>&1; then exit 1; fi
if bash install.sh --editor-file >/dev/null 2>&1; then exit 1; fi
if bash install.sh --editor-file --with-platform >/dev/null 2>&1; then exit 1; fi
grep -Fq '*.exe' .gitignore
grep -Fq '*.env' .gitignore
grep -Fq "readonly TAG='v21.26.0'" install.sh
grep -Fq '66fef88fe6a5d6071163a31ea46b3382ab482e19239b048f5fd578e8a13bd03a' install.sh
[[ $(grep -Ec "readonly (ZIP|LAUNCHER)_SHA256='[a-f0-9]{64}'" install.sh) == 2 ]]
if find . -path './.git' -prune -o -type f \( -iname '*.exe' -o -iname '*.ex5' -o -iname '*.env' -o -iname '*.pem' -o -iname '*.token' \) -print | grep -q .; then
  echo 'Public repository contains a binary or secret-like file.' >&2; exit 1
fi
echo 'PASS: shell syntax, help, rejected arguments, release pins and public package safety.'
