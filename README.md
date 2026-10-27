# MT5TG compiler installer

Install the personalized MT5 EA compiler after installing MT5 to Telegram
**v21.26.0 or v21.27.0** on Ubuntu **24.04 or 26.04 x86_64**.

Installer v1.0.1 detects the installed API port, including legacy port 8000.
The command pins the tested script to an immutable source revision. Its optional
platform download remains pinned to published v21.26.0 until a newer platform
release is qualified and published.

```bash
curl -fsSL https://raw.githubusercontent.com/howard-99/mt5tg-oneclick/aff7c744a3c9fcd12e13b5b33b51c6eac3955fdc/install.sh -o /tmp/mt5tg-compiler-install.sh
sudo bash /tmp/mt5tg-compiler-install.sh
```

The default configures an existing v21.26.0 or v21.27.0 installation. GitHub CLI asks you to
authorize read access to `howard-99/MT5-to-Telegram` to download the approved editor
from its private release. The editor checksum is pinned. The platform helper
provisions Wine 10+, Xvfb and the four CPU targets in a detached systemd unit,
then activates the API and EA build worker. Journals show provisioning progress.

With a local approved editor, compiler-only setup needs no GitHub sign-in:

```bash
sudo bash /tmp/mt5tg-compiler-install.sh --editor-file /secure/path/MetaEditor64.exe
```

For a complete fresh installation:

```bash
sudo bash /tmp/mt5tg-compiler-install.sh --with-platform \
  --server-address YOUR_PUBLIC_IP --certificate-email YOUR_EMAIL
```

The application ZIP and launcher have independent pinned SHA-256 checksums.
HTTPS requires reachable ports 80/443. Complete owner setup using the private
link printed by the platform installer. `--resume` forwards its explicit
interrupted-install recovery option. Existing older platforms must use the
normal release upgrade before compiler setup. Re-running setup reuses a matching
installed editor.

## Verify

```bash
sudo systemctl is-active mt5tg-api mt5tg-ea-builder
api_port=$(systemctl show mt5tg-api.service --property=ExecStart --value | sed -nE 's/.*--port ([0-9]+).*/\1/p')
curl -fsS "http://127.0.0.1:$api_port/health/ready"
```

Clone this repository and run `sudo bash diagnose.sh` for read-only diagnostics.
Download a dedicated EA from **My setup**, install it in MT5 and test a timeframe
change. EA 21.17 restores its session correctly after chart changes. Already
installed EAs need replacement to receive the correction.

## Editor asset

The approved MetaEditor64.exe SHA-256 is:

```text
66fef88fe6a5d6071163a31ea46b3382ab482e19239b048f5fd578e8a13bd03a
```

The executable is a separate asset in the private v21.26.0 application release.
No proprietary executable, customer EX5, application ZIP or credentials are
published here. `upload-editor.sh` is an owner maintenance tool for that private
asset. The MIT license applies to these helper scripts.

## Validation

Run `bash tests/test-static.sh` on Linux. Checks cover syntax, help/invalid
arguments, release pins and exclusion of binaries and secrets. The platform
release also compiles the EA with the approved MetaEditor.

Executed on an isolated Ubuntu 26.04 x86_64 VM with Wine 11.0: compiler-only
provisioning, four CPU smoke targets, authenticated personalized EA builds for
x64/AVX/AVX2/AVX512, download checksum validation, and application/compiler
preflight. Namespace tests also exercised both supported platform versions,
API ports 8000/8765, invalid editor/version rejection, corrupted platform archive
rejection and detached setup success/failure status. Ubuntu 24.04 VM acceptance
and sustained compiler capacity qualification remain separate checks.
