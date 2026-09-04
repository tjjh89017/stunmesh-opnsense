# CI downloads the stunmesh-go release binary into src/bin/stunmesh-go
# (mode 0755) before `make package` runs.

PLUGIN_NAME=		stunmesh
PLUGIN_VERSION=		1.15.0
PLUGIN_REVISION=	2
PLUGIN_COMMENT=		WireGuard NAT traversal with STUN (stunmesh-go)
PLUGIN_MAINTAINER=	tjjh89017@hotmail.com
PLUGIN_WWW=		https://github.com/tjjh89017/stunmesh-go
PLUGIN_LICENSE=		LGPL3
PLUGIN_DEVEL=
# No PLUGIN_DEPENDS: stunmesh-go shells out to "wg", which ships in
# OPNsense's base image (wg(4) plus the CLI) rather than as a separate
# pkg -- "wireguard-tools" does not exist in OPNsense's own repo, so
# declaring it here would make every install unresolvable.

.include "../../Mk/plugins.mk"
