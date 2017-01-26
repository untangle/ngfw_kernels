BUILD_DEPS := gcc-6-arm-linux-gnueabihf u-boot-tools rsync dpkg-dev build-essential

VERSION := 4.4.43
KERNEL_DIR := linux-4.4
DEB_BUILD_ARCH := armhf
CONFIG_ORIG := $(KERNEL_DIR)/.config_turris_omnia
KERNEL_IMAGE := $(KERNEL_DIR)/arch/arm/boot/zImage
DTB_IMAGE := $(KERNEL_DIR)/arch/arm/boot/dts/armada-385-turris-omnia.dtb
UPSTREAM := openwrt

# overridables
DESTDIR ?= tmp/install

# constants
TRX_IMAGE := tmp/vmlinux-$(VERSION).trx
TARBALL := $(UPSTREAM)-linux-$(VERSION).tar.xz
TARBALL_URL := http://download.untangle.com/kernels/$(TARBALL)
MODULES_PATH := tmp/modules-$(VERSION)
CONFIG_UNTANGLE_ORIG := untangle.config
CONFIG_DEST := $(KERNEL_DIR)/.config
CONFIG_DEST_KERNEL := $(KERNEL_DIR)/.config-kernel
CONFIG_DEST_MODULES := $(KERNEL_DIR)/.config-modules
CONCURRENCY_LEVEL := $(shell grep -c '^processor\s:' /proc/cpuinfo)
UNTANGLE_PATCH_SERIES := patches/untangle/series
DDWRT_PATCH_SERIES := patches/dd-wrt/series-kernel
DDWRT_PATCH_MODULES_SERIES := patches/dd-wrt/series-modules
COMPILE_FLAGS := MAKEFLAGS= MFLAGS= ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- CONCURRENCY_LEVEL=$(CONCURRENCY_LEVEL)
TMP_TRX_IMAGE := tmp/zImage-$(VERSION)

all:

$(TARBALL):
	curl -O $(TARBALL_URL)

extract: extract-stamp
extract-stamp: $(TARBALL)
	tar xaf $<
	touch $@

patch-untangle: patch-untangle-stamp
patch-untangle-stamp: extract-stamp patches/untangle/*
	while read patch ; do \
	  echo "Applying $$patch" ; \
	  patch -d $(KERNEL_DIR) -p1 < patches/untangle/$$patch ; \
	done < $(UNTANGLE_PATCH_SERIES)
	touch $@

patch-ddwrt-kernel: patch-ddwrt-kernel-stamp
patch-ddwrt-kernel-stamp: extract-stamp patches/dd-wrt/*
	cp $(CONFIG_ORIG) $(CONFIG_ORIG).bak
	while read patch ; do \
	  echo "Applying $$patch" ; \
	  patch -d $(KERNEL_DIR) -p1 < patches/dd-wrt/$$patch || exit 1 ; \
	done < $(DDWRT_PATCH_SERIES)
	cat $(CONFIG_ORIG) $(CONFIG_UNTANGLE_ORIG) >| $(CONFIG_DEST_KERNEL)
	cp $(CONFIG_ORIG).bak $(CONFIG_ORIG)
	touch $@

patch-ddwrt-modules: patch-ddwrt-kernel patch-ddwrt-modules-stamp
patch-ddwrt-modules-stamp: extract-stamp patches/dd-wrt/*
	cp $(CONFIG_ORIG) $(CONFIG_ORIG).bak
	while read patch ; do \
	  echo "Applying $$patch" ; \
	  patch -d $(KERNEL_DIR) -p1 < patches/dd-wrt/$$patch || exit 1 ; \
	done < $(DDWRT_PATCH_MODULES_SERIES)
	cat $(CONFIG_ORIG) $(CONFIG_UNTANGLE_ORIG) >| $(CONFIG_DEST_MODULES)
	cp $(CONFIG_ORIG).bak $(CONFIG_ORIG)
	touch $@

patch: patch-untangle patch-ddwrt-kernel patch-ddwrt-modules

kernel: $(KERNEL_IMAGE)
$(KERNEL_IMAGE): patch
	cd $(KERNEL_DIR) && $(COMPILE_FLAGS) KCONFIG_CONFIG=$(shell basename $(CONFIG_DEST_KERNEL)) make -j $(CONCURRENCY_LEVEL) zImage

modules: modules-stamp
modules-stamp: patch
	mkdir -p $(MODULES_PATH)
	cd $(KERNEL_DIR) && $(COMPILE_FLAGS) INSTALL_MOD_PATH=../$(MODULES_PATH) KCONFIG_CONFIG=$(shell basename $(CONFIG_DEST_MODULES)) make -j $(CONCURRENCY_LEVEL) modules
	cd $(KERNEL_DIR) && $(COMPILE_FLAGS) INSTALL_MOD_PATH=../$(MODULES_PATH) KCONFIG_CONFIG=$(shell basename $(CONFIG_DEST_MODULES)) make -j $(CONCURRENCY_LEVEL) modules_install
	touch modules-stamp

dtb: dtb-stamp
dtb-stamp: kernel
	cd $(KERNEL_DIR) && $(COMPILE_FLAGS) KCONFIG_CONFIG=$(shell basename $(CONFIG_DEST_KERNEL)) make dtbs
	touch $@

trx: $(TRX_IMAGE)
$(TRX_IMAGE): dtb
	mkdir -p tmp
	cat $(KERNEL_IMAGE) $(DTB_IMAGE) > $(TMP_TRX_IMAGE)
	./trx.sh $(TMP_TRX_IMAGE) $(TRX_IMAGE)

install: install-stamp
install-stamp: trx modules
	# zImage, DTB and uImage for this hardware
	mkdir -p $(DESTDIR)/boot
	cp $(TRX_IMAGE) $(DESTDIR)/boot/
	cp $(DTB_IMAGE) $(DESTDIR)/boot/
	cp $(KERNEL_IMAGE) $(DESTDIR)/boot/zImage-$(VERSION)
	# firmware blobs for kernel modules
	mkdir -p $(DESTDIR)/lib/firmware/
	rsync -aHz binary-assets/firmware/ $(DESTDIR)/lib/firmware/
	# modules we built from source
	rsync -aHz $(MODULES_PATH)/ $(DESTDIR)/
	# binary modules from dd-wrt
	mkdir -p $(DESTDIR)/lib/modules/$(VERSION)/extra
	cp binary-assets/modules/* $(DESTDIR)/lib/modules/$(VERSION)/extra || true
	touch install-stamp

debian:
	dpkg-buildpackage -us -uc -b --host-arch $(DEB_BUILD_ARCH)

clean:
	rm -fr $(KERNEL_DIR) tmp
	rm -f *-stamp *deb

.PHONY: debian

.SUFFIXES:
