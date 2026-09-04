# stunmesh-opnsense

OPNsense plugin packaging [stunmesh-go](https://github.com/tjjh89017/stunmesh-go),
a WireGuard helper that connects peers behind NAT with STUN and no
rendezvous server. Package name: `os-stunmesh`.

Signed pkg feed: **https://tjjh89017.github.io/stunmesh-opnsense/**

## Supported OPNsense versions

The stunmesh-go binary is downloaded prebuilt from upstream's GitHub
releases (FreeBSD amd64/arm64), so this feed just repackages it; only the
`abi`/`arch` tag in the package manifest differs per target:

| OPNsense series | amd64 | aarch64 |
| --- | --- | --- |
| 26.x | `FreeBSD:15:amd64` | `FreeBSD:15:aarch64` |
| 25.x | `FreeBSD:14:amd64` | `FreeBSD:14:aarch64` |

## Install from the signed feed (recommended)

Every push to `main` builds `os-stunmesh` for every ABI above and
publishes a signed pkg repository to GitHub Pages. On the OPNsense
firewall, as root:

```sh
fetch -o - https://tjjh89017.github.io/stunmesh-opnsense/install.sh | sh
```

This installs the signing key to `/usr/local/etc/ssl/stunmesh.pub` and
the repo conf to `/usr/local/etc/pkg/repos/stunmesh.conf`, then refreshes
the pkg catalog. It does the same thing as running by hand:

```sh
fetch -o /usr/local/etc/ssl/stunmesh.pub https://tjjh89017.github.io/stunmesh-opnsense/stunmesh.pub
fetch -o /usr/local/etc/pkg/repos/stunmesh.conf https://tjjh89017.github.io/stunmesh-opnsense/stunmesh.conf
pkg update -f
```

Either way, install the plugin from **System > Firmware > Plugins**
(tick "Show community plugins" if it's hidden) and pick `os-stunmesh`, or
from the shell:

```sh
configctl firmware install os-stunmesh
```

Do not run `pkg install os-stunmesh` directly -- it skips OPNsense's
plugin registration hooks (menu entries, service registration) that the
Firmware GUI and `configctl firmware install` both run.

The key fingerprint can be checked against `keys/stunmesh.pub` in this
repo; see [`keys/README.md`](keys/README.md).

## Configuration

The plugin adds a **VPN > STUNMESH** page with four tabs:

- **General**: enable the service, choose the configuration source
  ("Generate from Interfaces and Peers" or "Custom YAML"), and set the
  refresh interval, log level, STUN servers and default ping
  settings used in generated mode. A "Generated config preview" panel
  shows the config.yaml that would be produced from the currently saved
  settings, rendered live by configd; it does not touch
  `/usr/local/etc/stunmesh/config.yaml` on disk. It refreshes automatically
  on page load, when the General tab is shown, and after any storage
  plugin/interface/peer change, or on demand with "Refresh preview"; "Copy
  to editor" copies its text into the custom YAML box, client side only.
- **Storage plugins**: the stunmesh-go storage backends (builtin
  Cloudflare/OpenDHT, or an external `exec`/`shell` command) that peers
  publish and read their endpoints through.
- **Interfaces**: which WireGuard instances stunmesh-go manages, with
  per-interface protocol and proxy/listen options.
- **Peers**: which WireGuard peers get STUN-tracked endpoints, mapping
  each one to an interface and a storage plugin, with optional ping
  monitoring.

In "Generate from Interfaces and Peers" mode the config file is built
from the three tabs above. In "Custom YAML" mode the text in the
Configuration box on the General tab is written verbatim instead; the
Storage plugins, Interfaces and Peers tabs are ignored in that mode. The
two modes are not merged: Custom YAML fully replaces the generated file,
so switching to it keeps whatever was last written until you paste a
fresh copy in with "Copy to editor".
Either way the config is written to `/usr/local/etc/stunmesh/config.yaml`
only when Apply is pressed. The service shows up under
**Status > Services** once enabled. stunmesh-go logs via `daemon -S` to
syslog, visible under **System > Log Files > General**.

stunmesh-go looks up `wg` on `$PATH` to manage WireGuard peers.
OPNsense ships `wg` at `/usr/bin/wg` as part of its FreeBSD base image
(WireGuard is core, not a plugin), so this package declares no
`PLUGIN_DEPENDS` for it -- there is no separate `wireguard-tools` pkg
in OPNsense's own repository to depend on.

## How the build works

CI does the equivalent of, for each ABI:

```sh
scripts/fetch-binary.sh amd64   # or arm64; verifies sha256 against distinfo
# ... place the right binary at src/bin/stunmesh-go, mode 0755 ...
cd <checkout of opnsense/plugins>/net/stunmesh
make PKG="pkg -o ABI=<abi>" package
```

`Mk/plugins.mk` in opnsense/plugins runs the actual packaging
(`pkg create`); it sets `PKG` without `?=`, and BSD make command-line
variable assignments override that regardless, so overriding `PKG` on
the `make` invocation is what makes one FreeBSD 15.1 amd64 VM able to
build all four ABIs instead of needing a VM per (release, arch). Each
built `.pkg`'s ABI is verified with `pkg query -F <file> '%q'` before it
is accepted.

See [`scripts/build-package.sh`](scripts/build-package.sh) for the full
build, [`scripts/build-repo.sh`](scripts/build-repo.sh) for signing and
verifying the catalog, and
[`.github/workflows/build.yml`](.github/workflows/build.yml) for how CI
wires it together.

After `build`, a `test` job boots a real OPNsense VM with
[`vmactions/opnsense-vm`](https://github.com/vmactions/opnsense-vm) and
runs [`scripts/test-package.sh`](scripts/test-package.sh): it installs
the `.pkg` matching that VM's own ABI (`pkg config ABI`), checks
`/usr/local/bin/stunmesh-go` and `rc.d/stunmesh`, lints every installed
PHP file, and confirms the menu/ACL entries registered. `feed` only
publishes once `test` passes. `opnsense-vm` currently offers a single
OPNsense release (26.7, x86_64), so this only exercises that ABI, not
all four the `build` job produces.

## Updating to a new stunmesh-go release

1. Bump `PLUGIN_VERSION` in `Makefile` and reset `PLUGIN_REVISION` to `1`.
2. Refresh `distinfo`:
   ```sh
   gh release view vX.Y.Z --repo tjjh89017/stunmesh-go --json assets --jq \
     '.assets[] | "\(.name) \(.digest)"'
   ```
   and update the `SHA256 (...)  = ...` lines to match.
3. Push to `main`; CI rebuilds and republishes the feed.

Packaging-only changes (init script, config template) bump only
`PLUGIN_REVISION` instead.

## Signing key

Packages and catalogs are signed by CI with the RSA 4096 key in the
`PKG_PRIVATE_KEY` repository secret; `keys/stunmesh.pub` is its public
half. To rotate:

```sh
openssl genrsa -out pkg-private-key.pem 4096
openssl rsa -in pkg-private-key.pem -pubout -out keys/stunmesh.pub
gh secret set PKG_PRIVATE_KEY < pkg-private-key.pem
```

Commit the updated `keys/stunmesh.pub`, then have every existing install
re-run `install.sh` (or re-fetch `stunmesh.pub` by hand) to pick up the
new key.

## License

The plugin code in this repository is BSD-2-Clause. See [LICENSE](LICENSE).

The packaged `stunmesh-go` binary is a separate upstream project licensed
LGPL-3.0-or-later; its source is at
https://github.com/tjjh89017/stunmesh-go. The package's `pkg` license
field reflects this repository's plugin code, BSD2CLAUSE.
