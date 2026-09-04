#!/bin/sh
# install.sh -- add the stunmesh-opnsense signed pkg repository to this
# OPNsense host.
#
# Usage (as root, on the OPNsense firewall):
#   fetch -o - https://tjjh89017.github.io/stunmesh-opnsense/install.sh | sh
#
# This only registers the repository and refreshes the catalog. It does
# NOT install the plugin: install os-stunmesh from System > Firmware >
# Plugins in the GUI (tick "Show community plugins" if it is hidden), or
# run "configctl firmware install os-stunmesh". Do not "pkg install
# os-stunmesh" directly -- that skips OPNsense's plugin registration
# hooks (menu entries, service registration) that the Firmware GUI and
# configctl both run.
#
# POSIX sh, idempotent: safe to re-run to refresh the key/conf/catalog.

set -eu

if [ "$(id -u)" -ne 0 ]; then
	echo "error: must be run as root" >&2
	exit 1
fi

SITE="https://tjjh89017.github.io/stunmesh-opnsense"

mkdir -p /usr/local/etc/ssl /usr/local/etc/pkg/repos

echo ">>> Installing signing key to /usr/local/etc/ssl/stunmesh.pub"
fetch -o /usr/local/etc/ssl/stunmesh.pub "$SITE/stunmesh.pub"

echo ">>> Installing repo conf to /usr/local/etc/pkg/repos/stunmesh.conf"
fetch -o /usr/local/etc/pkg/repos/stunmesh.conf "$SITE/stunmesh.conf"

echo ">>> Refreshing pkg catalog"
pkg update -f

cat <<'EOF'

Repository registered. Install the plugin with one of:

  - System > Firmware > Plugins (tick "Show community plugins" if needed)
  - configctl firmware install os-stunmesh

Do not run "pkg install os-stunmesh" directly: it skips OPNsense's
plugin registration hooks.
EOF
