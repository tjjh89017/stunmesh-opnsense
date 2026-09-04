#!/bin/sh
# fetch-binary.sh <goarch> [output-path]
#
# Downloads the stunmesh-go FreeBSD release binary for one Go
# architecture (amd64, arm64), verifies its sha256 against distinfo, and
# installs it to <output-path> (default: dist-bin/stunmesh-go.<goarch>)
# with mode 0755.
#
# The version comes from PLUGIN_VERSION in Makefile, so bumping that one
# line is the only change needed to track a new stunmesh-go release
# (after distinfo is refreshed to match).
#
# Runs on the Linux CI host (build.yml downloads both goarch binaries
# before entering the FreeBSD VM), so it uses curl. It falls back to
# fetch(1) so it also works unmodified on a FreeBSD workstation.

set -eu

usage() {
	echo "usage: $0 <goarch> [output-path]" >&2
	exit 1
}

[ $# -ge 1 ] || usage
GOARCH="$1"
case "$GOARCH" in
	amd64|arm64) ;;
	*)
		echo "error: unsupported goarch '$GOARCH' (expected amd64 or arm64)" >&2
		exit 1
		;;
esac

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

OUTPUT="${2:-$REPO_ROOT/dist-bin/stunmesh-go.$GOARCH}"

MAKEFILE="$REPO_ROOT/Makefile"
[ -f "$MAKEFILE" ] || { echo "error: $MAKEFILE not found" >&2; exit 1; }

VERSION=$(sed -n 's/^PLUGIN_VERSION=[[:space:]]*//p' "$MAKEFILE" | head -n1)
[ -n "$VERSION" ] || { echo "error: PLUGIN_VERSION not found in $MAKEFILE" >&2; exit 1; }

ASSET="stunmesh-freebsd-${GOARCH}-v${VERSION}"
URL="https://github.com/tjjh89017/stunmesh-go/releases/download/v${VERSION}/${ASSET}"

DISTINFO="$REPO_ROOT/distinfo"
[ -f "$DISTINFO" ] || { echo "error: $DISTINFO not found" >&2; exit 1; }

EXPECTED_SHA256=$(sed -n "s/^SHA256 (${ASSET}) = //p" "$DISTINFO" | head -n1)
[ -n "$EXPECTED_SHA256" ] || {
	echo "error: no distinfo entry for '$ASSET'" >&2
	exit 1
}

TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

echo ">>> Downloading $URL"
if command -v curl >/dev/null 2>&1; then
	curl -fsSL -o "$TMPFILE" "$URL"
elif command -v fetch >/dev/null 2>&1; then
	fetch -o "$TMPFILE" "$URL"
else
	echo "error: neither curl nor fetch is available" >&2
	exit 1
fi

echo ">>> Verifying sha256"
if command -v sha256sum >/dev/null 2>&1; then
	ACTUAL_SHA256=$(sha256sum "$TMPFILE" | awk '{print $1}')
elif command -v sha256 >/dev/null 2>&1; then
	ACTUAL_SHA256=$(sha256 -q "$TMPFILE")
else
	echo "error: neither sha256sum nor sha256 is available" >&2
	exit 1
fi

if [ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]; then
	echo "error: sha256 mismatch for $ASSET" >&2
	echo "  expected: $EXPECTED_SHA256" >&2
	echo "  actual:   $ACTUAL_SHA256" >&2
	exit 1
fi

mkdir -p "$(dirname -- "$OUTPUT")"
cp "$TMPFILE" "$OUTPUT"
chmod 0755 "$OUTPUT"

echo ">>> Installed $ASSET to $OUTPUT"
