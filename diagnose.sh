#!/usr/bin/env bash
# Read-only checks: do not print private application environment or credentials.
set -Eeuo pipefail
readonly EDITOR_SHA256='66fef88fe6a5d6071163a31ea46b3382ab482e19239b048f5fd578e8a13bd03a'
readonly EDITOR_PATH='/var/lib/mt5tg/compiler/editor/MetaEditor64.exe'
failed=0
check() {
  if "$@" >/dev/null 2>&1; then printf 'PASS: %s\n' "$*"; else printf 'FAIL: %s\n' "$*"; failed=$((failed+1)); fi
}
[[ $EUID == 0 ]] || { echo 'Run with sudo for all checks.' >&2; exit 1; }
printf 'ORVIX MT5TG compiler diagnostic (read-only)\n'
if [[ -f /opt/mt5tg/VERSION ]]; then printf 'Platform: %s\n' "$(cat /opt/mt5tg/VERSION)"; fi
if command -v wine >/dev/null 2>&1; then wine --version; else echo 'Wine unavailable'; failed=$((failed+1)); fi
check systemctl is-active --quiet mt5tg-api
check systemctl is-active --quiet mt5tg-ea-builder
check systemctl is-active --quiet nginx
check curl -fsS --max-time 8 http://127.0.0.1:8765/health/ready
check test -s "$EDITOR_PATH"
if [[ -s "$EDITOR_PATH" ]]; then
  digest=$(sha256sum "$EDITOR_PATH" | awk '{print $1}')
  if [[ $digest == "$EDITOR_SHA256" ]]; then echo 'PASS: exact MetaEditor SHA-256'; else echo "FAIL: editor checksum $digest"; failed=$((failed+1)); fi
fi
if [[ -f /etc/mt5tg/platform.env ]]; then
  if grep -Fq 'MT5_COMPILER_COMMAND=' /etc/mt5tg/platform.env; then
    echo 'PASS: MT5_COMPILER_COMMAND configured'
  else
    echo 'FAIL: compiler command missing'; failed=$((failed+1))
  fi
else
  echo 'FAIL: platform env missing'; failed=$((failed+1))
fi
printf '\nNumber of failed checks: %d\n' "$failed"
(( failed == 0 )) || {
  echo 'For server-side failures: journalctl -u mt5tg-ea-builder -n 100 --no-pager' >&2
  exit 1
}
echo 'OS/service checks passed. Also run the authenticated admin compiler probe and download a dedicated EX5.'
