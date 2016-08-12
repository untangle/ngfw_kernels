BUILD_DEPS := gcc-5-arm-linux-gnueabihf u-boot-tools cgpt

MAJOR_VERSION := 3.18
CONFIG_ORIG := config_mvebu

TARBALL := dd-wrt-linux-$(MAJOR_VERSION).tar.bz2
TARBALL_URL := http://download.untangle.com/kernels/$(TARBALL)
KERNEL_DIR := linux-$(MAJOR_VERSION)
KERNEL_IMAGE := $(KERNEL_DIR)/arch/arm/boot/zImage
DTB_IMAGE := $(KERNEL_DIR)/arch/arm/boot/dts/armada-385-linksys-shelby.dtb
TMP_ITF_IMAGE := /tmp/zImage-$(MAJOR_VERSION)
ITF_IMAGE := $(KERNEL_DIR)/arch/arm/boot/vmlinux.itf
MODULES_PATH=/tmp/mods-$(MAJOR_VERSION)
MODULES_TARBALL := modules-$(MAJOR_VERSION).tar.bz2
VIMAGE := $(KERNEL_DIR)/vimage
CONFIG_UNTANGLE_ORIG := untangle.config
CONFIG_DEST := $(KERNEL_DIR)/.config
CONCURRENCY_LEVEL := $(shell grep -c '^processor\s:' /proc/cpuinfo)
UNTANGLE_PATCH_SERIES := patches/untangle/series
DDWRT_PATCH_SERIES := patches/dd-wrt/series

all: kernel modules

$(TARBALL):
	curl -O $(TARBALL_URL)

extract: extract-stamp
extract-stamp: $(TARBALL)
	tar xjf $<
	touch $@

patch: patch-stamp
patch-stamp: patch-untangle patch-ddwrt
	touch $@

patch-untangle: patch-untangle-stamp
patch-untangle-stamp: extract-stamp patches/untangle/*
	while read patch ; do \
	  echo "Applying $$patch" ; \
	  patch -d $(KERNEL_DIR) -p1 < patches/untangle/$$patch ; \
	done < $(UNTANGLE_PATCH_SERIES)
	touch $@

patch-ddwrt: patch-ddwrt-stamp
patch-ddwrt-stamp: extract-stamp patches/dd-wrt/*
	while read patch ; do \
	  echo "Applying $$patch" ; \
	  patch -d $(KERNEL_DIR) -p1 < patches/dd-wrt/$$patch ; \
	done < $(DDWRT_PATCH_SERIES)
	touch $@

config: $(CONFIG_DEST)
$(CONFIG_DEST): extract-stamp $(CONFIG_ORIG) $(CONFIG_UNTANGLE_ORIG)
	cat $(CONFIG_ORIG) $(CONFIG_UNTANGLE_ORIG) >| $@

kernel: $(KERNEL_IMAGE)
$(KERNEL_IMAGE): patch-stamp config
	cd $(KERNEL_DIR) ; \
	MAKEFLAGS= MFLAGS= ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- CONCURRENCY_LEVEL=$(CONCURRENCY_LEVEL) make -j $(CONCURRENCY_LEVEL) zImage

dtb: dtb-stamp
dtb-stamp: kernel
	cd $(KERNEL_DIR) ; \
	MAKEFLAGS= MFLAGS= ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- CONCURRENCY_LEVEL=$(CONCURRENCY_LEVEL) make dtbs
	touch $@

itf: $(ITF_IMAGE)
$(ITF_IMAGE): dtb
#	mkimage -D '-I dts -O dtb -p 1024' -f onhub.its $(ITF_IMAGE)
	cat $(KERNEL_IMAGE) $(DTB_IMAGE) > $(TMP_ITF_IMAGE)
	mkimage -A arm -O linux -T kernel -a 0x00008000 -C none -e 0x00008000 -n 'Untangle' -d $(TMP_ITF_IMAGE) $(ITF_IMAGE)

modules: $(MODULES_TARBALL)
$(MODULES_TARBALL): kernel
	rm -fr $(MODULES_PATH)
	mkdir -p $(MODULES_PATH)
	cd $(KERNEL_DIR) && MAKEFLAGS= MFLAGS= ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- CONCURRENCY_LEVEL=$(CONCURRENCY_LEVEL) INSTALL_MOD_PATH=$(MODULES_PATH) make -j $(CONCURRENCY_LEVEL) modules
	cd $(KERNEL_DIR) && MAKEFLAGS= MFLAGS= ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- CONCURRENCY_LEVEL=$(CONCURRENCY_LEVEL) INSTALL_MOD_PATH=$(MODULES_PATH) make -j $(CONCURRENCY_LEVEL) modules_install
	tar -C $(MODULES_PATH) -cjf $@ .

clean:
	rm -fr $(KERNEL_DIR) $(MODULES_TARBALL) $(MODULES_PATH) $(TMP_ITF_IMAGE)
	rm -f *-stamp *deb
