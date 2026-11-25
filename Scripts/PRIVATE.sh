#!/bin/bash
# 私有修改：修复 luci-app-lxc 新版 overview.js 对 #tabmenu 的依赖
#
# 背景：
#   luci-app-lxc 在 render() 里手动把节点 append 到 #tabmenu，而这个元素只有
#   部分旧主题（Bootstrap / Argon 等）才有。Vantage 等新主题只提供 #maincontent
#   和 #view，于是 document.getElementById('tabmenu') 为 null，报：
#     TypeError: can't access property "append", document.getElementById(...) is null
#
# 做法：
#   在 feeds 安装完成之后、编译之前，把 overview.js 改成 LuCI 的标准写法：
#   由 render() 返回节点，交给 LuCI 放进 #view。
#
# 生效时机：
#   Scripts/Packages.sh 末尾会 source 本文件（此时工作目录是 ./wrt）。

patch_lxc_overview() {
	local LXC_JS CHANGED=0

	LXC_JS=$(find ./feeds -path '*/view/lxc/overview.js' -print -quit 2>/dev/null || true)

	if [ -z "$LXC_JS" ] || [ ! -f "$LXC_JS" ]; then
		echo "warning: luci-app-lxc overview.js not found"
		return 0
	fi

	if grep -Fq "document.getElementById('tabmenu').append" "$LXC_JS"; then
		# 删掉手动 append 到 #tabmenu 的 5 行；
		# 把 this.imagepanel(); 改成“延后执行 + return 节点数组”
		sed -i \
			-e "/document\.getElementById('tabmenu')\.append(/d" \
			-e "s/^\([[:space:]]*\)this\.imagepanel();/\1setTimeout(() => this.imagepanel(), 0);\n\n\1return [ node, lxc_list, lxc_output, create_new, create_output ];/" \
			"$LXC_JS"
		CHANGED=1
	fi

	if grep -Fq "return [ node, lxc_list, lxc_output, create_new, create_output ];" "$LXC_JS"; then
		if [ "$CHANGED" = "1" ]; then
			echo "luci-app-lxc overview.js patched"
		else
			echo "luci-app-lxc overview.js already patched"
		fi
	else
		echo "warning: luci-app-lxc overview.js not patched (upstream structure changed?)"
	fi
}

# 私有修改：修复 luci-app-homeproxy 把 cache/dashboard/resources 目录写入
# keep.d，导致配置备份包含网页资源和缓存的问题。
#
# 背景：
#   luci-app-homeproxy 的 Makefile 在 conffiles 中列出了目录。
#   OpenWrt 的 include/package-pack.mk 会把不是普通文件的 conffiles 条目
#   写入 /lib/upgrade/keep.d/luci-app-homeproxy，sysupgrade 再对目录做
#   递归 find，于是整个 dashboard/resources 都进备份。
#
# 做法：
#   删除 conffiles 中的 cache/、dashboard/、resources/ 三项。
#
# 生效时机：
#   Scripts/Packages.sh 末尾会 source 本文件（此时工作目录是 ./wrt）。
#
patch_homeproxy_backup() {
	local HP_MK CHANGED=0

	HP_MK=$(find ./package ./feeds -path '*/luci-app-homeproxy/Makefile' -print -quit 2>/dev/null || true)

	if [ -z "$HP_MK" ] || [ ! -f "$HP_MK" ]; then
		echo "warning: luci-app-homeproxy Makefile not found"
		return 0
	fi

	if grep -qE '^[[:space:]]*/etc/homeproxy/(cache|dashboard|resources)/[[:space:]]*$' "$HP_MK"; then
		sed -i \
			-e '\#^[[:space:]]*/etc/homeproxy/cache/[[:space:]]*$#d' \
			-e '\#^[[:space:]]*/etc/homeproxy/dashboard/[[:space:]]*$#d' \
			-e '\#^[[:space:]]*/etc/homeproxy/resources/[[:space:]]*$#d' \
			"$HP_MK"
		CHANGED=1
	fi

	if grep -qE '^[[:space:]]*/etc/homeproxy/(cache|dashboard|resources)/[[:space:]]*$' "$HP_MK"; then
		echo "warning: luci-app-homeproxy conffiles not patched (upstream structure changed?)"
	elif [ "$CHANGED" = "1" ]; then
		echo "luci-app-homeproxy conffiles patched"
	else
		echo "luci-app-homeproxy conffiles already patched"
	fi
}

patch_lxc_overview
patch_homeproxy_backup