#!/bin/bash
#============================================================
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
# Lisence: MIT
# Author: P3TERX
# Blog: https://p3terx.com
#============================================================

# 修复 helloworld 新版 GN 在 Ubuntu 22.04 上的 host 编译兼容问题
GN_MAKEFILE="feeds/helloworld/gn/Makefile"

if [ -f "$GN_MAKEFILE" ] && ! grep -q 'CC=gcc-12 CXX=g++-12 AR=ar' "$GN_MAKEFILE"; then
    sed -i '/$(PYTHON).*build\/gen.py/ s|$(PYTHON)|CC=gcc-12 CXX=g++-12 AR=ar $(PYTHON)|' "$GN_MAKEFILE"
fi

# 替换默认IP
sed -i 's#192.168.1.1#192.168.1.99#g' package/base-files/files/bin/config_generate

# cpufreq
sed -i 's/LUCI_DEPENDS.*/LUCI_DEPENDS:=\@\(arm\|\|aarch64\)/g' feeds/luci/applications/luci-app-cpufreq/Makefile
sed -i 's/services/system/g' feeds/luci/applications/luci-app-cpufreq/luasrc/controller/cpufreq.lua

# 修改大雕源码里的erofs-utils源码位置
# sed -i \
#   -e 's|^PKG_SOURCE:=.*|PKG_SOURCE:=v$(PKG_VERSION).tar.gz|' \
#   -e 's|^PKG_SOURCE_URL=.*|PKG_SOURCE_URL:=https://github.com/erofs/erofs-utils/archive/refs/tags|' \
#   -e 's|^PKG_HASH:=.*|PKG_HASH:=05eb4edebe11decce6ecb34e98d2f80c8cd283c2f2967d8ba7efd58418570514|' \
#   tools/erofs-utils/Makefile

# 升级大雕的rust源码到官方最新版本1.85.1
sed -i 's/PKG_VERSION:=1.84.0/PKG_VERSION:=1.85.1/' feeds/packages/lang/rust/Makefile
sed -i 's/PKG_HASH:=15cee7395b07ffde022060455b3140366ec3a12cbbea8f1ef2ff371a9cca51bf/PKG_HASH:=0f2995ca083598757a8d9a293939e569b035799e070f419a686b0996fb94238a/' feeds/packages/lang/rust/Makefile

# 移除 lede feeds 自带的番茄核心包
rm -rf feeds/packages/net/xray-core
rm -rf feeds/packages/net/v2ray-geodata
rm -rf feeds/packages/net/sing-box
rm -rf feeds/packages/net/chinadns-ng
rm -rf feeds/packages/net/dns2socks
# rm -rf feeds/packages/net/dns2tcp
rm -rf feeds/packages/net/microsocks
cp -r feeds/passwall_packages/xray-core feeds/packages/net
cp -r feeds/passwall_packages/v2ray-geodata feeds/packages/net
cp -r feeds/passwall_packages/sing-box feeds/packages/net
cp -r feeds/passwall_packages/chinadns-ng feeds/packages/net
cp -r feeds/passwall_packages/dns2socks feeds/packages/net
# cp -r feeds/passwall_packages/dns2tcp feeds/packages/net
cp -r feeds/passwall_packages/microsocks feeds/packages/net

# 修改golang源码以编译xray26.9.9+版本
rm -rf feeds/packages/lang/golang
git clone https://github.com/sbwml/packages_lang_golang -b 27.x feeds/packages/lang/golang
sed -i '/-linkmode external \\/d' feeds/packages/lang/golang/golang-package.mk

# =====================================================================
# 自动更新 FRP 到官方最新稳定版
# =====================================================================
FRP_DIR="feeds/packages/net/frp"
FRP_MAKEFILE="$FRP_DIR/Makefile"

FRP_VERSION="$(
    git ls-remote --tags --refs https://github.com/fatedier/frp.git \
    | sed -n 's#.*refs/tags/v\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\)$#\1#p' \
    | sort -V \
    | tail -1
)"

curl -fL "https://codeload.github.com/fatedier/frp/tar.gz/v${FRP_VERSION}" \
    -o /tmp/frp.tar.gz

FRP_HASH="$(sha256sum /tmp/frp.tar.gz | cut -d' ' -f1)"

sed -i -E "s/^PKG_VERSION:=.*/PKG_VERSION:=${FRP_VERSION}/" "$FRP_MAKEFILE"
sed -i -E "s/^PKG_HASH:=.*/PKG_HASH:=${FRP_HASH}/" "$FRP_MAKEFILE"

# FRP 0.68.0+ 官方支持 noweb
if grep -q '^GO_PKG_TAGS:=' "$FRP_MAKEFILE"; then
    sed -i -E 's/^GO_PKG_TAGS:=.*/GO_PKG_TAGS:=noweb/' "$FRP_MAKEFILE"
else
    sed -i '/^GO_PKG_BUILD_PKG:=/a GO_PKG_TAGS:=noweb' "$FRP_MAKEFILE"
fi

# 当前旧版 OpenWrt recipe 会强制执行 npm/Web 编译，
# noweb 模式下改为只执行 Go 编译
sed -i '/^define Build\/Compile$/,/^endef$/c\
define Build/Compile\
	$(call GoPackage/Build/Compile)\
endef' "$FRP_MAKEFILE"

rm -f /tmp/frp.tar.gz

# =====================================================================
# 自动更新 Tailscale 到官方最新稳定版
# =====================================================================
TAILSCALE_MAKEFILE="feeds/packages/net/tailscale/Makefile"
TAILSCALE_VERSION="$(git ls-remote --tags --refs https://github.com/tailscale/tailscale.git | sed -n 's#.*refs/tags/v\([0-9.]*\)$#\1#p' | sort -V | tail -1)"

curl -fL "https://codeload.github.com/tailscale/tailscale/tar.gz/v${TAILSCALE_VERSION}" -o /tmp/tailscale.tar.gz
TAILSCALE_HASH="$(sha256sum /tmp/tailscale.tar.gz | cut -d' ' -f1)"

sed -i -E "s/^PKG_VERSION:=.*/PKG_VERSION:=${TAILSCALE_VERSION}/" "$TAILSCALE_MAKEFILE"
sed -i -E "s/^PKG_HASH:=.*/PKG_HASH:=${TAILSCALE_HASH}/" "$TAILSCALE_MAKEFILE"

rm -rf feeds/packages/net/tailscale/patches /tmp/tailscale.tar.gz

# 添加luci-app-homeproxy
cp -r openwrt_helloworld/luci-app-homeproxy package
rm -rf openwrt_helloworld

# 移除不用软件包
rm -rf package/lean/luci-app-wrtbwmon
rm -rf package/lean/luci-theme-argon
rm -rf feeds/packages/multimedia/aliyundrive-webdav
rm -rf feeds/luci/applications/luci-app-aliyundrive-webdav

# 添加aliyundrive-webdav
git clone https://github.com/messense/aliyundrive-webdav.git
cp -r aliyundrive-webdav/openwrt/aliyundrive-webdav feeds/packages/multimedia
cp -r aliyundrive-webdav/openwrt/luci-app-aliyundrive-webdav feeds/luci/applications
rm -rf aliyundrive-webdav

# 添加额外软件包
# git clone https://github.com/jerrykuku/luci-app-jd-dailybonus.git package/luci-app-jd-dailybonus
# git clone https://github.com/VictC79/luci-app-vssr.git package/luci-app-vssr
git clone https://github.com/jerrykuku/lua-maxminddb.git package/lua-maxminddb
git clone https://github.com/kongfl888/luci-app-adguardhome.git package/luci-app-adguardhome
git clone https://github.com/Cneupa/luci-app-bypass package/luci-app-bypass
git clone https://github.com/UnblockNeteaseMusic/luci-app-unblockneteasemusic package/luci-app-unblockneteasemusic

# 科学上网插件依赖
wget https://codeload.github.com/vernesong/OpenClash/zip/refs/heads/master -O OpenClash.zip
unzip OpenClash.zip
cp -r OpenClash-master/luci-app-openclash package/
rm -rf OpenClash.zip OpenClash-master
# 编译 po2lmo (如果有po2lmo可跳过)
pushd package/luci-app-openclash/tools/po2lmo
make && sudo make install
popd

git clone https://github.com/kenzok8/openwrt-packages.git
cp -r openwrt-packages/luci-app-eqos package/luci-app-eqos
rm -rf openwrt-packages

# 添加luci-app-amlogic / 晶晨宝盒
git clone https://github.com/ophub/luci-app-amlogic.git
cp -r luci-app-amlogic/luci-app-amlogic package/luci-app-amlogic
rm -rf luci-app-amlogic

# themes
git clone https://github.com/davinyue/luci-theme-edge package/luci-theme-edge
git clone -b 18.06 https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon
git clone https://github.com/jerrykuku/luci-app-argon-config package/luci-app-argon-config
git clone https://github.com/xiaoqingfengATGH/luci-theme-infinityfreedom package/luci-theme-infinityfreedom
git clone https://github.com/Leo-Jo-My/luci-theme-opentomcat.git package/luci-theme-opentomcat
git clone https://github.com/openwrt-develop/luci-theme-atmaterial.git package/luci-theme-atmaterial
git clone https://github.com/sirpdboy/luci-theme-opentopd package/luci-theme-opentopd
git clone https://github.com/zxlhhyccc/luci-theme-opentomato.git
cp -r luci-theme-opentomato/luci/themes/luci-theme-opentomato package/luci-theme-opentomato
rm -rf luci-theme-opentomato
git clone https://github.com/rosywrt/luci-theme-rosy.git
cp -r luci-theme-rosy/luci-theme-rosy package/luci-theme-rosy
rm -rf luci-theme-rosy
git clone https://github.com/rosywrt/luci-theme-purple.git
cp -r luci-theme-purple/luci-theme-purple package/luci-theme-purple
rm -rf luci-theme-purple

#添加smartdns
git clone https://github.com/kiddin9/smartdns-le package/smartdns-le
git clone https://github.com/kenzok8/openwrt-packages.git
cp -r openwrt-packages/luci-app-smartdns package/luci-app-smartdns
rm -rf openwrt-packages

#修改makefile
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/include\ \.\.\/\.\.\/luci\.mk/include \$(TOPDIR)\/feeds\/luci\/luci\.mk/g' {}
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/include\ \.\.\/\.\.\/lang\/golang\/golang\-package\.mk/include \$(TOPDIR)\/feeds\/packages\/lang\/golang\/golang\-package\.mk/g' {}
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/PKG_SOURCE_URL:=\@GHREPO/PKG_SOURCE_URL:=https:\/\/github\.com/g' {}
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/PKG_SOURCE_URL:=\@GHCODELOAD/PKG_SOURCE_URL:=https:\/\/codeload\.github\.com/g' {}

#修改xfsprogs的Makefile
sed -i 's/TARGET_CFLAGS += -DHAVE_MAP_SYNC/TARGET_CFLAGS += -DHAVE_MAP_SYNC -D_LARGEFILE64_SOURCE/' feeds/packages/utils/xfsprogs/Makefile

# =====================================================================
# TVGuard - 家庭电视时间管理（LuCI 原生固件集成）
# =====================================================================
TVGUARD_DIR="package/luci-app-tvguard"

# 防止重复软件包覆盖
if [ -e "$TVGUARD_DIR" ]; then
    echo "ERROR: TVGuard package directory already exists" >&2
    exit 1
fi

# 与现有其他插件相同，直接跟踪主分支最新源码
git clone --depth 1 -b main \
    https://github.com/wekingchen/luci-app-tvguard.git \
    "$TVGUARD_DIR" || exit 1

# 确认原生打包所需文件完整
if [ ! -f "$TVGUARD_DIR/Makefile" ] ||
   [ ! -f "$TVGUARD_DIR/scripts/stage-openwrt-native.sh" ] ||
   [ ! -f "$TVGUARD_DIR/native/root/etc/init.d/tvguard-native-bootstrap" ]; then
    echo "ERROR: TVGuard native packaging files are missing" >&2
    exit 1
fi

echo "TVGuard source integrated successfully"
