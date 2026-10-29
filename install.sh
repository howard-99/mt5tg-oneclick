#!/usr/bin/env bash
# Public bootstrap: application and approved editor remain private release assets.
set -Eeuo pipefail
umask 077
readonly REPO='howard-99/MT5-to-Telegram'
readonly TAG='v21.26.0'
readonly EDITOR_SHA256='66fef88fe6a5d6071163a31ea46b3382ab482e19239b048f5fd578e8a13bd03a'
readonly ZIP_SHA256='3e1ce03608d93e7ecac02b98a242f3e72840b2b415be3f317038eb86821aea61'
readonly LAUNCHER_SHA256='3208b589505d5579a02ce4280e464353f1d7249508210d34325ddcb3d0c3fc9a'
editor=''; with_platform=false; work=''; platform_args=()
die(){ printf 'Installation stopped: %s\n' "$*" >&2; exit 1; }
cleanup(){ [[ -z $work ]] || rm -rf -- "$work"; }
trap cleanup EXIT
usage(){
cat <<'EOF'
MT5TG compiler installer v1.0.2 for platforms v21.26.0, v21.27.0 and v21.28.0-rc.1
Usage: sudo bash install.sh [OPTIONS]
  --compiler-only          Configure the installed platform compiler (default).
  --with-platform          Install the pinned private platform release first.
  --editor-file PATH       Use the approved local MetaEditor64.exe.
  --server-address IP      Forward to the fresh platform installer.
  --certificate-email EMAIL Forward to the fresh platform installer.
  --resume                 Forward interrupted-install recovery.
  -h, --help               Show help.
Ubuntu 24.04/26.04 x86_64 with systemd is required.
Remote downloads require read access to the private platform release.
With a local editor, compiler-only setup needs no GitHub authentication.
EOF
}
supported_compiler_platform(){
 case "$1" in v21.26.0|v21.27.0|v21.28.0-rc.1) return 0 ;; *) return 1 ;; esac
}
while (($#)); do
 case "$1" in
 --editor-file|--server-address|--certificate-email)
  (($#>=2)) || die "$1 requires a value"
  [[ -n $2 && $2 != --* ]] || die "$1 requires a value"
  if [[ $1 == --editor-file ]]; then editor=$2; else platform_args+=("$1" "$2"); fi
  shift 2 ;;
 --compiler-only) with_platform=false; shift ;;
 --with-platform) with_platform=true; shift ;;
 --resume) platform_args+=(--resume); shift ;;
 -h|--help) usage; exit 0 ;;
 *) die "Unknown option: $1" ;;
 esac
done
[[ $EUID == 0 ]] || die 'Run with sudo.'
[[ $(uname -m) == x86_64 ]] || die 'Requires x86_64.'
source /etc/os-release
[[ ${ID:-} == ubuntu && ( ${VERSION_ID:-} == 24.04 || ${VERSION_ID:-} == 26.04 ) ]] || die 'Ubuntu 24.04 or 26.04 is required.'
[[ -d /run/systemd/system ]] || die 'systemd is required.'
[[ $with_platform == true || ${#platform_args[@]} == 0 ]] || die 'Platform flags require --with-platform.'
verify(){ printf '%s  %s\n' "$1" "$2" | sha256sum --check --status; }
if [[ -n $editor ]]; then
 editor=$(realpath -- "$editor")
 [[ -s $editor ]] && verify "$EDITOR_SHA256" "$editor" || die 'Local editor is missing or has an incorrect checksum.'
fi
work=$(mktemp -d -t mt5tg-compiler.XXXXXXXX)
github_ready=false
github(){
 [[ $github_ready == false ]] || return 0
 export DEBIAN_FRONTEND=noninteractive
 apt-get update -qq
 apt-get -o DPkg::Lock::Timeout=180 install -y --no-install-recommends gh curl ca-certificates python3
 if ! gh auth status --hostname github.com >/dev/null 2>&1; then
  [[ -r /dev/tty ]] || die 'Run sudo gh auth login --hostname github.com --web first.'
  gh auth login --hostname github.com --web --git-protocol https </dev/tty >/dev/tty
 fi
 gh auth status --hostname github.com >/dev/null 2>&1 || die 'GitHub authentication failed.'
 github_ready=true
}
if [[ $with_platform == true ]]; then
 if [[ -f /opt/mt5tg/VERSION && -f /etc/mt5tg/platform.env && ! -f /etc/mt5tg/install-incomplete ]]; then
  supported_compiler_platform "$(tr -d '[:space:]' </opt/mt5tg/VERSION)" || die 'Upgrade the existing platform with its release launcher first.'
 else
  [[ ! -f /etc/mt5tg/platform.env || -f /etc/mt5tg/install-incomplete ]] || die 'Existing configuration requires a platform upgrade.'
  github
  gh release download "$TAG" --repo "$REPO" --dir "$work" --pattern "MT5-Telegram-Platform-$TAG.zip" --pattern mt5tg-install.bash
  verify "$ZIP_SHA256" "$work/MT5-Telegram-Platform-$TAG.zip" && verify "$LAUNCHER_SHA256" "$work/mt5tg-install.bash" || die 'Platform archive/launcher checksum mismatch.'
  bash "$work/mt5tg-install.bash" "${platform_args[@]}"
 fi
fi
[[ -f /etc/mt5tg/platform.env && -f /opt/mt5tg/VERSION ]] || die 'Install the platform first, or use --with-platform.'
supported_compiler_platform "$(tr -d '[:space:]' </opt/mt5tg/VERSION)" || die 'This helper supports platform v21.26.0, v21.27.0 and v21.28.0-rc.1.'
[[ ! -f /etc/mt5tg/install-incomplete ]] || die 'Finish the interrupted platform installation first.'
[[ -s /opt/mt5tg/scripts/configure-ea-compiler.bash ]] || die 'Installed compiler helper is missing.'
if [[ -z $editor ]]; then
 for candidate in /root/MetaEditor64.exe /var/lib/mt5tg/compiler/editor/MetaEditor64.exe; do
  if [[ -s $candidate ]] && verify "$EDITOR_SHA256" "$candidate"; then editor=$candidate; break; fi
 done
fi
if [[ -z $editor ]]; then
 github
 gh release download "$TAG" --repo "$REPO" --dir "$work" --pattern MetaEditor64.exe
 editor="$work/MetaEditor64.exe"
fi
verify "$EDITOR_SHA256" "$editor" || die 'Editor checksum mismatch.'
# The platform helper handles detached systemd provisioning and journal output.
bash /opt/mt5tg/scripts/configure-ea-compiler.bash "$editor" "$EDITOR_SHA256"
systemctl is-active --quiet mt5tg-api mt5tg-ea-builder || die 'API or EA builder is inactive.'
ready=false
api_port=$(systemctl show mt5tg-api.service --property=ExecStart --value | sed -nE 's/.*--port ([0-9]+).*/\1/p')
[[ $api_port =~ ^[0-9]{1,5}$ && $api_port -gt 0 && $api_port -le 65535 ]] || die 'Unable to determine the installed API readiness port.'
for attempt in {1..30}; do
 if curl -fsS --max-time 3 "http://127.0.0.1:$api_port/health/ready" >/dev/null; then ready=true; break; fi
 sleep 1
done
[[ $ready == true ]] || die 'API readiness failed; inspect journalctl -u mt5tg-api.'
printf '\nSUCCESS: compiler configured and API ready.\nComplete browser owner setup, then download a dedicated EA from My setup.\n'
