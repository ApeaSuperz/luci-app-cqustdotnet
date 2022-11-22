include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-cqustdotnet
PKG_VERSION:=1.0.0
PKG_RELEASE:=beta
PKG_MAINTAINER:=Hurring <https://github.com/ApeaSuperZ/luci-app-cqustdotnet>

LUCI_TITLE:=A LuCI app to simply connect to network of CQUST
LUCI_PKGARCH:=all
LUCI_DEPENDS:=+lua +libuci-lua

define Package/$(PKG_NAME)/conffiles
/etc/config/cqustdotnet
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
