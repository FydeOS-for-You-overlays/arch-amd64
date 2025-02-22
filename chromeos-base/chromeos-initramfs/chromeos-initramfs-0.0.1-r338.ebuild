# Copyright (c) 2012 The Chromium OS Authors. All rights reserved.
# Distributed under the terms of the GNU General Public License v2

EAPI="6"
CROS_WORKON_COMMIT="60d2752c4fabe25bcc7526526c0ff9bac82a307c"
CROS_WORKON_TREE="a0eb23891295669df1647a6ab9b6a94ab8542059"
CROS_WORKON_PROJECT="chromiumos/platform/initramfs"
CROS_WORKON_LOCALNAME="initramfs"
CROS_WORKON_OUTOFTREE_BUILD="1"

inherit cros-workon cros-board cros-constants

DESCRIPTION="Create Chrome OS initramfs"
HOMEPAGE="http://www.chromium.org/"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="*"
IUSE="+cros_ec_utils detachable device_tree +interactive_recovery"
IUSE="${IUSE} menu_ui -mtd +power_management"
IUSE="${IUSE} physical_presence_power physical_presence_recovery"
IUSE="${IUSE} unibuild"

# Build Targets
TARGETS_IUSE="
	factory_netboot_ramfs
	factory_shim_ramfs
	hypervisor_ramfs
	recovery_ramfs
  dual_boot_ramfs
  core_util_ramfs
"
IUSE+=" ${TARGETS_IUSE}"
REQUIRED_USE="|| ( ${TARGETS_IUSE} )"

# Packages required for building recovery initramfs.
RECOVERY_DEPENDS="
	chromeos-base/chromeos-installer
	chromeos-base/common-assets
	chromeos-base/vboot_reference
	chromeos-base/vpd
	sys-apps/flashrom
	sys-apps/pv
	virtual/assets
	virtual/chromeos-regions
	"

# Packages required for building factory installer shim initramfs.
FACTORY_SHIM_DEPENDS="
	chromeos-base/factory_installer
	chromeos-base/vboot_reference
	"

# Packages required for building factory netboot installer initramfs.
FACTORY_NETBOOT_DEPENDS="
	app-arch/lbzip2
	app-arch/pigz
	app-arch/sharutils
	app-misc/jq
	app-shells/bash
	chromeos-base/chromeos-base
	chromeos-base/chromeos-installer
	chromeos-base/chromeos-installshim
	chromeos-base/chromeos-storage-info
	chromeos-base/ec-utils
	chromeos-base/factory_installer
	chromeos-base/vboot_reference
	chromeos-base/vpd
	dev-libs/openssl:0=
	dev-util/shflags
	dev-util/xxd
	net-misc/curl
	net-misc/htpdate
	net-misc/wget
	sys-apps/coreutils
	sys-apps/flashrom
	sys-apps/iproute2
	sys-apps/mosys
	sys-apps/util-linux
	sys-block/parted
	sys-fs/dosfstools
	sys-fs/e2fsprogs
	sys-libs/ncurses
	virtual/udev
	"

# Packages required for building hypervisor initramfs.
HYPERVISOR_DEPENDS="
	app-emulation/qemu
	virtual/linux-sources
	"

FYDEOS_DEPENDS="
    app-arch/lbzip2
    app-arch/pigz
    app-arch/sharutils
    app-misc/jq
    app-shells/bash
    chromeos-base/chromeos-base
    chromeos-base/chromeos-installer
    chromeos-base/chromeos-storage-info
    chromeos-base/ec-utils
    chromeos-base/factory_installer
    chromeos-base/vboot_reference
    chromeos-base/vpd
    dev-libs/openssl
    dev-util/shflags
    dev-util/xxd
    net-misc/curl
    net-misc/htpdate
    net-misc/wget
    sys-apps/coreutils
    sys-apps/flashrom
    sys-apps/iproute2
    sys-apps/mosys
    sys-apps/util-linux
    sys-block/parted
    sys-fs/dosfstools
    sys-fs/e2fsprogs
    sys-libs/ncurses
"

DEPEND="
	factory_netboot_ramfs? ( ${FACTORY_NETBOOT_DEPENDS} )
	factory_shim_ramfs? ( ${FACTORY_SHIM_DEPENDS} )
	recovery_ramfs? ( ${RECOVERY_DEPENDS} )
	hypervisor_ramfs? ( ${HYPERVISOR_DEPENDS} )
  dual_boot_ramfs? ( ${FYDEOS_DEPENDS} )
  core_util_ramfs? ( ${FYDEOS_DEPENDS} sys-apps/frecon-lite virtual/udev )
	sys-apps/busybox[-make-symlinks]
	sys-fs/lvm2
	virtual/chromeos-bsp-initramfs
	chromeos-base/chromeos-init
	sys-apps/frecon-lite
	power_management? ( chromeos-base/power_manager )
	unibuild? ( chromeos-base/chromeos-config )
	chromeos-base/chromeos-config-tools"

RDEPEND=""

src_prepare() {
	export BUILD_LIBRARY_DIR="${CHROOT_SOURCE_ROOT}/src/scripts/build_library"
	export INTERACTIVE_COMPLETE="$(usex interactive_recovery true false)"

	# Need the lddtree from the chromite dir.
	export PATH="${CHROMITE_BIN_DIR}:${PATH}"

  cp -r ${FILESDIR}/* ${S}
  epatch ${FILESDIR}/factory_shim.patch

	eapply_user
}

src_compile() {
	local deps=()
	use mtd && deps+=(/usr/bin/cgpt)
	if use factory_netboot_ramfs; then
		use power_management && deps+=(/usr/bin/backlight_tool)
	fi

	local targets=()
	for target in ${TARGETS_IUSE}; do
		use "${target}" && targets+=("${target%_ramfs}")
	done
	einfo "Building targets: ${targets[*]}"

	local physical_presence
	if use physical_presence_power ; then
		physical_presence="power"
	elif use physical_presence_recovery ; then
		physical_presence="recovery"
	else
		physical_presence="keyboard"
	fi

	emake SYSROOT="${SYSROOT}" BOARD="$(get_current_board_with_variant)" \
		INCLUDE_FIT_PICKER="$(usex device_tree 1 0)" \
		INCLUDE_ECTOOL="$(usex cros_ec_utils 1 0)" \
		DETACHABLE="$(usex detachable 1 0)" \
		MENU_UI="$(usex menu_ui 1 0)" \
		UNIBUILD="$(usex unibuild 1 0)" \
		PHYSICAL_PRESENCE="${physical_presence}" \
		OUTPUT_DIR="${WORKDIR}" EXTRA_BIN_DEPS="${deps[*]}" \
		LOCALE_LIST="${RECOVERY_LOCALES}" "${targets[@]}"
}

src_install() {
	insinto /var/lib/initramfs
	for target in ${TARGETS_IUSE}; do
		use "${target}" &&
			doins "${WORKDIR}/${target}.cpio.xz"
	done
}
