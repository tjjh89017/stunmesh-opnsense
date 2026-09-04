#!/bin/sh
# build-site.sh <repo-root> <site-dir>
#
# Runs on the Linux CI host, in the "feed" job, after scripts/build-repo.sh
# has already signed every ABI's catalog inside <site-dir>. Assembles the
# rest of the GitHub Pages site around those already-built ABI
# directories: the repo conf, the public key, the install script, and an
# index page. GitHub Pages serves no directory listings, so pkg only ever
# needs the exact files this script and build-repo.sh produce -- that is
# fine, since nothing else fetches from this site.

set -eu

usage() {
	echo "usage: $0 <repo-root> <site-dir>" >&2
	exit 1
}

[ $# -eq 2 ] || usage

REPO_ROOT=$1
SITE_DIR=$2

[ -f "$REPO_ROOT/dist/stunmesh.conf" ] || { echo "error: '$REPO_ROOT/dist/stunmesh.conf' not found" >&2; exit 1; }
[ -f "$REPO_ROOT/dist/install.sh" ] || { echo "error: '$REPO_ROOT/dist/install.sh' not found" >&2; exit 1; }
[ -f "$REPO_ROOT/keys/stunmesh.pub" ] || { echo "error: '$REPO_ROOT/keys/stunmesh.pub' not found" >&2; exit 1; }

mkdir -p "$SITE_DIR"

cp "$REPO_ROOT/dist/stunmesh.conf" "$SITE_DIR/stunmesh.conf"
cp "$REPO_ROOT/dist/install.sh" "$SITE_DIR/install.sh"
cp "$REPO_ROOT/keys/stunmesh.pub" "$SITE_DIR/stunmesh.pub"
: > "$SITE_DIR/.nojekyll"

{
	echo '<!doctype html><title>stunmesh-opnsense feed</title>'
	echo '<h1>stunmesh-opnsense package feed</h1>'
	echo '<p>Signed pkg repository for the <code>os-stunmesh</code> OPNsense plugin.'
	echo 'Install instructions: <a href="https://github.com/tjjh89017/stunmesh-opnsense#readme">README</a>.</p>'
	echo '<h2>Setup files</h2><ul>'
	echo '<li><a href="stunmesh.pub">stunmesh.pub</a> -- repository signing public key</li>'
	echo '<li><a href="stunmesh.conf">stunmesh.conf</a> -- /usr/local/etc/pkg/repos/stunmesh.conf</li>'
	echo '<li><a href="install.sh">install.sh</a> -- one-line installer</li>'
	echo '</ul>'
	echo '<h2>OPNsense versions</h2><ul>'
	( cd "$SITE_DIR" && find . -mindepth 1 -maxdepth 1 -type d | sed 's|^\./||' | sort ) | while read -r abi; do
		# Directory names stay the raw pkg ABI string (colons and
		# all) -- stunmesh.conf's "${ABI}" needs that exact form.
		# The visible label instead names the OPNsense series, since
		# that's what a reader picks a directory by, not the FreeBSD
		# base version underneath it.
		freebsd_rel=$(printf '%s' "$abi" | cut -d: -f2)
		arch=$(printf '%s' "$abi" | cut -d: -f3)
		case "$freebsd_rel" in
			15) opnsense_series="OPNsense 26.x" ;;
			14) opnsense_series="OPNsense 25.x" ;;
			*) opnsense_series="OPNsense (FreeBSD $freebsd_rel)" ;;
		esac
		echo "<li><strong>$opnsense_series ($arch)</strong><ul>"
		( cd "$SITE_DIR/$abi" && find . -mindepth 1 -maxdepth 1 -type f | sed 's|^\./||' | sort ) | while read -r f; do
			# "./" prefix: a colon in the first path segment of a
			# relative URL (ABI names look like "FreeBSD:15:amd64")
			# would otherwise be misread as a URI scheme by browsers.
			echo "<li><a href=\"./$abi/$f\">$f</a></li>"
		done
		echo '</ul></li>'
	done
	echo '</ul>'
} > "$SITE_DIR/index.html"

echo ">>> Site assembled:"
find "$SITE_DIR" -type f | sort
