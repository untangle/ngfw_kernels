BUILD_DEPS := gcc-5-arm-linux-gnueabihf u-boot-tools cgpt

VERSION := 3.18.42
KERNEL_DIR := linux-3.18
CONFIG_ORIG := $(KERNEL_DIR)/.config_mvebu
KERNEL_IMAGE := $(KERNEL_DIR)/arch/arm/boot/zImage
DTB_IMAGE := $(KERNEL_DIR)/arch/arm/boot/dts/armada-385-linksys-shelby.dtb

# overridables
DESTDIR ?= /tmp/test

# constants
ITF_IMAGE := $(KERNEL_DIR)/arch/arm/boot/vmlinux.itf
TARBALL := dd-wrt-linux-$(VERSION).tar.xz
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
TMP_ITF_IMAGE := tmp/zImage-$(VERSION)

all: itf modules

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
	  patch -d $(KERNEL_DIR) -p1 < patches/dd-wrt/$$patch ; \
	done < $(DDWRT_PATCH_SERIES)
	cat $(CONFIG_ORIG) $(CONFIG_UNTANGLE_ORIG) >| $(CONFIG_DEST_KERNEL)
	cp $(CONFIG_ORIG).bak $(CONFIG_ORIG)
	touch $@

patch-ddwrt-modules: patch-ddwrt-kernel patch-ddwrt-modules-stamp
patch-ddwrt-modules-stamp: extract-stamp patches/dd-wrt/*
	cp $(CONFIG_ORIG) $(CONFIG_ORIG).bak
	while read patch ; do \
	  echo "Applying $$patch" ; \
	  patch -d $(KERNEL_DIR) -p1 < patches/dd-wrt/$$patch ; \
	done < $(DDWRT_PATCH_MODULES_SERIES)
	cat $(CONFIG_ORIG) $(CONFIG_UNTANGLE_ORIG) >| $(CONFIG_DEST_MODULES)
	cp $(CONFIG_ORIG).bak $(CONFIG_ORIG)
	touch $@

patch: patch-untangle patch-ddwrt-kernel patch-ddwrt-modules

kernel: $(KERNEL_IMAGE)
$(KERNEL_IMAGE): patch
	cd $(KERNEL_DIR) && $(COMPILE_FLAGS) KCONFIG_CONFIG=$(shell basename $(CONFIG_DEST_KERNEL)) make -j $(CONCURRENCY_LEVEL) zImage

modules: $(MODULES_PATH)
$(MODULES_PATH): patch
	mkdir -p $(MODULES_PATH)
	cd $(KERNEL_DIR) && $(COMPILE_FLAGS) INSTALL_MOD_PATH=../$(MODULES_PATH) KCONFIG_CONFIG=$(shell basename $(CONFIG_DEST_MODULES)) make -j $(CONCURRENCY_LEVEL) modules modules_install

dtb: dtb-stamp
dtb-stamp: kernel
	cd $(KERNEL_DIR) && $(COMPILE_FLAGS) KCONFIG_CONFIG=$(shell basename $(CONFIG_DEST_KERNEL)) make dtbs
	touch $@

itf: $(ITF_IMAGE)
$(ITF_IMAGE): dtb
#	mkimage -D '-I dts -O dtb -p 1024' -f onhub.its $(ITF_IMAGE)
	mkdir -p tmp
	cat $(KERNEL_IMAGE) $(DTB_IMAGE) > $(TMP_ITF_IMAGE)
	mkimage -A arm -O linux -T kernel -a 0x00008000 -C none -e 0x00008000 -n 'Untangle' -d $(TMP_ITF_IMAGE) $(ITF_IMAGE)
	cp $(ITF_IMAGE) .

install: itf modules
	# wrapped zImage for this hardware
	mkdir -p $(DESTDIR)/boot
	cp $(ITF_IMAGE) $(DESTDIR)/boot/vmlinux-$(VERSION).trx
	# firmware blobs for kernel modules
	mkdir -p $(DESTDIR)/lib/firmware/
	rsync -aHz binary/firmware/ $(DESTDIR)/lib/firmware/
	# modules we built from source
	rsync -aHz $(MODULES_PATH)/ $(DESTDIR)/
	# binary modules from dd-wrt
	mkdir -p $(DESTDIR)/lib/modules/$(VERSION)/extra
	cp binary/modules/* $(DESTDIR)/lib/modules/$(VERSION)/extra

clean:
	rm -fr $(KERNEL_DIR) tmp
	rm -f *-stamp *deb
