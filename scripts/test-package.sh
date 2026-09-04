#!/bin/sh
# test-package.sh <packages-dir>
#
# Runs INSIDE the OPNsense VM (vmactions/opnsense-vm), as root, with a
# full OPNsense install: real pkg(8), php, and configd already running.
#
# <packages-dir>  the "packages" build artifact downloaded by build.yml,
#                 one subdirectory per ABI (e.g.
#                 <packages-dir>/FreeBSD:15:amd64/os-stunmesh-*.pkg),
#                 rsync'd into the VM alongside this script.
#
# This is an install smoke test, not a functional test: it installs the
# .pkg matching the VM's own ABI, checks the binary and PHP files it
# dropped, and confirms OPNsense picked up the menu/ACL/service
# registration. It does not exercise STUN/WireGuard/DHT behavior.

set -eu

usage() {
	echo "usage: $0 <packages-dir>" >&2
	exit 1
}

[ $# -eq 1 ] || usage

PACKAGES_DIR=$1
[ -d "$PACKAGES_DIR" ] || { echo "error: packages dir '$PACKAGES_DIR' not found" >&2; exit 1; }

ABI=$(pkg config ABI)
echo ">>> VM ABI: $ABI"

PKG_DIR="$PACKAGES_DIR/$ABI"
[ -d "$PKG_DIR" ] || { echo "error: no built package for ABI '$ABI' under $PACKAGES_DIR" >&2; exit 1; }

PKG_FILE=$(find "$PKG_DIR" -maxdepth 1 -name '*.pkg' | head -n1)
[ -n "$PKG_FILE" ] || { echo "error: no .pkg found under $PKG_DIR" >&2; exit 1; }

echo "::group::Install $PKG_FILE"
# No PLUGIN_DEPENDS (see Makefile): "wg" ships at /usr/bin/wg in
# OPNsense's FreeBSD base, not as a separate pkg -- confirmed below --
# so a plain "pkg add" (no dependency resolution) is enough.
test -x /usr/bin/wg || { echo "error: /usr/bin/wg missing or not executable" >&2; exit 1; }
command -v wg >/dev/null 2>&1 || { echo "error: 'wg' not found on PATH" >&2; exit 1; }
pkg add "$PKG_FILE"
pkg info os-stunmesh
echo "::endgroup::"

echo "::group::Check installed files"
[ -x /usr/local/bin/stunmesh-go ] || { echo "error: /usr/local/bin/stunmesh-go missing or not executable" >&2; exit 1; }
/usr/local/bin/stunmesh-go -version || /usr/local/bin/stunmesh-go --version || /usr/local/bin/stunmesh-go -h

[ -x /usr/local/etc/rc.d/stunmesh ] || { echo "error: /usr/local/etc/rc.d/stunmesh missing or not executable" >&2; exit 1; }
echo "::endgroup::"

echo "::group::Lint installed PHP files"
find /usr/local/opnsense/mvc/app/controllers/OPNsense/Stunmesh \
     /usr/local/opnsense/mvc/app/models/OPNsense/Stunmesh \
     -name '*.php' | while read -r f; do
	echo ">>> php -l $f"
	php -l "$f"
done
echo "::endgroup::"

echo "::group::Check menu/ACL registration"
grep -q 'VisibleName="STUNMESH"' /usr/local/opnsense/mvc/app/models/OPNsense/Stunmesh/Menu/Menu.xml
grep -q 'page-vpn-stunmesh' /usr/local/opnsense/mvc/app/models/OPNsense/Stunmesh/ACL/ACL.xml
echo ">>> menu/ACL entries present"
echo "::endgroup::"

# From here on: checks that depend on configd/rc being fully up inside a
# freshly booted CI VM. Reported, but not fatal to the job -- a flaky
# configd handshake here should not block a signed feed publish when the
# package itself installed and lints cleanly above.
echo "::group::Service checks (best effort)"
service stunmesh onestatus || echo ">>> service stunmesh onestatus: non-zero (service not started, expected by default)"

if command -v configctl >/dev/null 2>&1; then
	configctl stunmesh status && exit_code=0 || exit_code=$?
	echo ">>> configctl stunmesh status exit=$exit_code"
else
	echo ">>> configctl not available, skipping"
fi
echo "::endgroup::"

echo "::group::Run migrations (if available)"
if [ -x /usr/local/opnsense/mvc/script/run_migrations.php ]; then
	php /usr/local/opnsense/mvc/script/run_migrations.php
	echo ">>> run_migrations.php exit 0"
else
	echo ">>> run_migrations.php not present, skipping"
fi
echo "::endgroup::"

echo "::group::Render config.yaml template in generated mode"
# configctl template reload must exit 0 whether or not the plugin is
# enabled in /conf/config.xml: it only renders the Jinja templates, it
# does not require a <stunmesh> config section to already exist.
configctl template reload OPNsense/Stunmesh
echo ">>> configctl template reload OPNsense/Stunmesh exit 0"
echo "::endgroup::"

echo ">>> Install smoke test OK for $ABI"
