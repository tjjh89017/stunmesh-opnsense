# CI downloads the stunmesh-go release binary into src/bin/stunmesh-go
# (mode 0755) before `make package` runs.

PLUGIN_NAME=		stunmesh
PLUGIN_VERSION=		1.15.0
PLUGIN_REVISION=	1
PLUGIN_COMMENT=		WireGuard NAT traversal with STUN (stunmesh-go)
PLUGIN_MAINTAINER=	tjjh89017@hotmail.com
PLUGIN_WWW=		https://github.com/tjjh89017/stunmesh-go
PLUGIN_LICENSE=		LGPL3
PLUGIN_DEPENDS=		wireguard-tools
PLUGIN_DEVEL=

.include "../../Mk/plugins.mk"
