#!/bin/sh
# build-repo.sh <site-dir> <private-key-file> <public-key-file>
#
# Runs INSIDE the FreeBSD build VM, in the "feed" job, as root, with real
# pkg(8) available.
#
# <site-dir>          holds one subdirectory per ABI (e.g.
#                      <site-dir>/FreeBSD:15:amd64/), each already
#                      containing that ABI's built .pkg file(s) -- see
#                      scripts/build-package.sh.
# <private-key-file>  RSA private key (PEM) used to sign each repo
#                      catalog, mode 600.
# <public-key-file>   the public half committed at keys/stunmesh.pub --
#                      used only to verify the signature this script just
#                      made, never to sign anything.
#
# For every ABI directory: "pkg repo <dir> rsa:<key>" builds and signs
# that directory's catalog (not the "signing_command:" form -- that form
# hangs waiting on stdin in CI). Then this script proves the signature is
# real by pointing a throwaway pkg repo config at the same directory over
# file://, with signature_type "pubkey" and the committed public key, and
# reading the package back out of it with "pkg rquery". Any failure here
# (a bad "pkg repo" invocation, a signature that does not actually
# verify) fails this script -- and so the whole "feed" job -- before
# anything reaches GitHub Pages.

set -eu

usage() {
	echo "usage: $0 <site-dir> <private-key-file> <public-key-file>" >&2
	exit 1
}

[ $# -eq 3 ] || usage

SITE_DIR=$1
KEY_FILE=$2
PUBKEY_FILE=$3

[ -d "$SITE_DIR" ] || { echo "error: site dir '$SITE_DIR' not found" >&2; exit 1; }
[ -s "$KEY_FILE" ] || { echo "error: private key '$KEY_FILE' is missing or empty" >&2; exit 1; }
[ -s "$PUBKEY_FILE" ] || { echo "error: public key '$PUBKEY_FILE' is missing or empty" >&2; exit 1; }

SITE_DIR=$(CDPATH= cd -- "$SITE_DIR" && pwd)
KEY_FILE=$(CDPATH= cd -- "$(dirname -- "$KEY_FILE")" && pwd)/$(basename -- "$KEY_FILE")
PUBKEY_FILE=$(CDPATH= cd -- "$(dirname -- "$PUBKEY_FILE")" && pwd)/$(basename -- "$PUBKEY_FILE")

echo ">>> Bootstrapping pkg"
if ! command -v pkg >/dev/null 2>&1; then
	env ASSUME_ALWAYS_YES=yes pkg bootstrap -y
fi
pkg -N >/dev/null 2>&1 || env ASSUME_ALWAYS_YES=yes pkg bootstrap -y

FOUND_ANY=0

for abi_dir in "$SITE_DIR"/*/; do
	[ -d "$abi_dir" ] || continue
	abi=$(basename -- "$abi_dir")

	if ! ls "$abi_dir"*.pkg >/dev/null 2>&1; then
		echo "no .pkg files under $abi_dir, skipping"
		continue
	fi
	FOUND_ANY=1

	echo "::group::Sign $abi"
	pkg repo "$abi_dir" "rsa:$KEY_FILE"

	echo ">>> Verifying signed repo for $abi"
	CONF_DIR=$(mktemp -d)
	trap 'rm -rf "$CONF_DIR"' EXIT

	cat > "$CONF_DIR/stunmesh.conf" <<-EOF
	stunmesh: {
	  url: "file://${abi_dir%/}",
	  mirror_type: "none",
	  signature_type: "pubkey",
	  pubkey: "$PUBKEY_FILE",
	  enabled: yes
	}
	EOF

	if ! pkg -R "$CONF_DIR" -o ABI="$abi" update -f; then
		echo "error: pkg update against signed repo for $abi failed" >&2
		exit 1
	fi

	RESULT=$(pkg -R "$CONF_DIR" -o ABI="$abi" rquery -r stunmesh '%n-%v' 2>/dev/null || true)
	case "$RESULT" in
		os-stunmesh-*)
			echo ">>> $abi OK: $RESULT"
			;;
		*)
			echo "error: os-stunmesh not found in signed repo for $abi (got: '$RESULT')" >&2
			exit 1
			;;
	esac

	rm -rf "$CONF_DIR"
	trap - EXIT
	echo "::endgroup::"
done

[ "$FOUND_ANY" -eq 1 ] || { echo "error: no ABI directory under $SITE_DIR had any .pkg file" >&2; exit 1; }

echo ">>> All ABI repos signed and verified"
