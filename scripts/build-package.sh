#!/bin/sh
# build-package.sh <plugins-dir> <plugin-src-dir> <out-dir> <abi> [abi ...]
#
# Runs INSIDE the FreeBSD build VM (vmactions/freebsd-vm), as root, with
# real pkg(8) bootstrapped and network access.
#
# <plugins-dir>    a checkout of github.com/opnsense/plugins (ref: master)
# <plugin-src-dir> this repo's own checkout: Makefile, pkg-descr, src/,
#                  and dist-bin/stunmesh-go.<goarch> (from fetch-binary.sh)
# <out-dir>        receives one subdirectory per ABI, each holding the
#                  built .pkg, e.g. <out-dir>/FreeBSD:15:amd64/os-stunmesh-*.pkg
# <abi>...         one or more OPNsense/pkg ABI strings, e.g.
#                  FreeBSD:15:amd64 FreeBSD:14:amd64 FreeBSD:15:aarch64
#                  FreeBSD:14:aarch64
#
# The plugin content is identical across every ABI; only the ABI tag
# pkg(8) stamps into the package manifest differs. Rather than one VM
# per (release, arch), this builds every ABI in a single FreeBSD 15.1
# amd64 VM by overriding pkg(8)'s ABI on the make command line: Mk/plugins.mk
# sets "PKG=  ${LOCALBASE}/sbin/pkg" (no "?=") in Mk/defaults.mk, and BSD
# make command-line variable assignments always win over both in-makefile
# assignments and the environment, so
#   make PKG="pkg -o ABI=<abi>" package
# makes every ${PKG} invocation in the "package" target (including the
# final "pkg create") run with that ABI override. "pkg -o ABI=<abi>
# create ... -o <pkgdir>" is unambiguous: the global "-o KEY=VALUE" option
# precedes the "create" subcommand, and "create"'s own "-o <dir>" output
# flag comes after it.
#
# Any PLUGIN_DEPENDS entries are installed once, up front, with the
# host's native (non-overridden) pkg -- not per ABI. Mk/plugins.mk's
# "package" target runs "${PKG} install -yA <dep>" only when
# "${PKG} info <dep>" reports it missing; pre-installing it here means
# that check always finds it already present, so the per-ABI ABI
# override never has to fetch a package from a repo that may not carry
# a matching catalog for that overridden ABI. The plugin currently has
# none: WireGuard (wg(4) plus the "wg" CLI) ships in OPNsense's base
# image, not as a separate pkg -- see the Makefile.

set -eu

usage() {
	echo "usage: $0 <plugins-dir> <plugin-src-dir> <out-dir> <abi> [abi ...]" >&2
	exit 1
}

[ $# -ge 4 ] || usage

PLUGINS_DIR=$1
PLUGIN_SRC_DIR=$2
OUT_DIR=$3
shift 3

[ -d "$PLUGINS_DIR" ] || { echo "error: plugins dir '$PLUGINS_DIR' not found" >&2; exit 1; }
[ -f "$PLUGIN_SRC_DIR/Makefile" ] || { echo "error: '$PLUGIN_SRC_DIR/Makefile' not found" >&2; exit 1; }

PLUGINS_DIR=$(CDPATH= cd -- "$PLUGINS_DIR" && pwd)
PLUGIN_SRC_DIR=$(CDPATH= cd -- "$PLUGIN_SRC_DIR" && pwd)
mkdir -p "$OUT_DIR"
OUT_DIR=$(CDPATH= cd -- "$OUT_DIR" && pwd)

PLUGIN_DIR="$PLUGINS_DIR/net/stunmesh"

echo ">>> Bootstrapping pkg"
if ! command -v pkg >/dev/null 2>&1; then
	env ASSUME_ALWAYS_YES=yes pkg bootstrap -y
fi
pkg -N >/dev/null 2>&1 || env ASSUME_ALWAYS_YES=yes pkg bootstrap -y

echo ">>> Installing plugin dependencies (native ABI, once)"
for dep in $(sed -n 's/^PLUGIN_DEPENDS=[[:space:]]*//p' "$PLUGIN_SRC_DIR/Makefile" | head -n1); do
	if ! pkg info "$dep" >/dev/null 2>&1; then
		pkg install -yA "$dep"
	fi
done

for ABI in "$@"; do
	echo "::group::Build $ABI"

	case "$ABI" in
		*:amd64) GOARCH=amd64 ;;
		*:aarch64) GOARCH=arm64 ;;
		*)
			echo "error: cannot map ABI '$ABI' to a Go architecture" >&2
			exit 1
			;;
	esac

	BINARY="$PLUGIN_SRC_DIR/dist-bin/stunmesh-go.$GOARCH"
	[ -f "$BINARY" ] || { echo "error: '$BINARY' not found (run fetch-binary.sh first)" >&2; exit 1; }

	echo ">>> Resetting plugin working copy"
	rm -rf "$PLUGIN_DIR"
	mkdir -p "$PLUGIN_DIR"
	# Copy everything the plugin tree needs except this repo's own CI
	# plumbing (.github, scripts, dist, dist-bin, distinfo, keys, .git),
	# which has no place inside opnsense/plugins.
	(cd "$PLUGIN_SRC_DIR" && find . -mindepth 1 -maxdepth 1 \
		! -name .git ! -name .github ! -name scripts \
		! -name dist ! -name dist-bin ! -name distinfo ! -name keys \
		! -name README.md ! -name .gitignore) | while read -r entry; do
		cp -a "$PLUGIN_SRC_DIR/${entry#./}" "$PLUGIN_DIR/"
	done

	mkdir -p "$PLUGIN_DIR/src/bin"
	install -m 0755 "$BINARY" "$PLUGIN_DIR/src/bin/stunmesh-go"

	echo ">>> make package (PKG override: pkg -o ABI=$ABI)"
	( cd "$PLUGIN_DIR" && rm -rf work && make PKG="pkg -o ABI=$ABI" package )

	PKG_FILE=$(find "$PLUGIN_DIR/work/pkg" -maxdepth 1 -name '*.pkg' | head -n1)
	[ -n "$PKG_FILE" ] || { echo "error: no .pkg produced under $PLUGIN_DIR/work/pkg" >&2; exit 1; }

	echo ">>> Verifying ABI of $PKG_FILE"
	BUILT_ABI=$(pkg query -F "$PKG_FILE" '%q')
	if [ "$BUILT_ABI" != "$ABI" ]; then
		echo "error: $PKG_FILE has ABI '$BUILT_ABI', expected '$ABI'" >&2
		exit 1
	fi

	mkdir -p "$OUT_DIR/$ABI"
	cp "$PKG_FILE" "$OUT_DIR/$ABI/"
	echo ">>> $ABI OK: $(basename -- "$PKG_FILE")"

	echo "::endgroup::"
done

echo ">>> All ABIs built:"
find "$OUT_DIR" -name '*.pkg' | sort
