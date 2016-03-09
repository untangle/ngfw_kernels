BUILD_DEPS := gcc-5-arm-linux-gnueabihf device-tree-compiler u-boot-tools cgpt vboot-kernel-utils

TARBALL := dd-wrt-linux-4.4.tar.bz2
KERNEL_DIR := linux-4.4
KERNEL_IMAGE := $(KERNEL_DIR)/arch/arm/boot/zImage
MODULES_PATH=/tmp/mods-3.14.0
MODULES_TARBALL := $(KERNEL_DIR)/modules.tar.bz2
VIMAGE := $(KERNEL_DIR)/vimage
CONFIG_ORIG := config_northstart_smp
CONFIG_UNTANGLE_ORIG := untangle.config
CONFIG_DEST := $(KERNEL_DIR)/.config
CONCURRENCY_LEVEL := $(shell grep -c '^processor\s:' /proc/cpuinfo)
UNTANGLE_PATCH_SERIES := patches/untangle/series

all: kernel modules

extract: extract-stamp
extract-stamp: $(TARBALL)
	tar xjf $<
	touch $@

patch: patch-stamp
patch-stamp: patch-untangle
	touch $@

patch-untangle: patch-untangle-stamp
patch-untangle-stamp: extract-stamp patches/untangle/*
	while read patch ; do \
	  echo "Applying $$patch" ; \
	  patch -d $(KERNEL_DIR) -p1 < patches/untangle/$$patch ; \
	done < $(UNTANGLE_PATCH_SERIES)
	touch $@

config: $(CONFIG_DEST)
$(CONFIG_DEST): extract-stamp $(CONFIG_ORIG) $(CONFIG_UNTANGLE_ORIG)
	cat $(CONFIG_ORIG) $(CONFIG_UNTANGLE_ORIG) >| $@

kernel: $(KERNEL_IMAGE)
$(KERNEL_IMAGE): patch-stamp config
	cd $(KERNEL_DIR) ; \
	MAKEFLAGS= MFLAGS= ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- CONCURRENCY_LEVEL=$(CONCURRENCY_LEVEL) make -j $(CONCURRENCY_LEVEL) zImage

kernel-package: patch-stamp config
	cd $(KERNEL_DIR) ; \
	MAKEFLAGS= MFLAGS= DEB_HOST_ARCH=armhf CONCURRENCY_LEVEL=$(CONCURRENCY_LEVEL) fakeroot make-kpkg --arch arm --cross-compile arm-linux-gnueabihf- --revision=1+untangle1 kernel_image kernel_headers

modules: $(MODULES_TARBALL)
$(MODULES_TARBALL): kernel
	rm -fr $(MODULES_PATH)
	mkdir -p $(MODULES_PATH)
	cd $(KERNEL_DIR) && MAKEFLAGS= MFLAGS= ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- CONCURRENCY_LEVEL=$(CONCURRENCY_LEVEL) INSTALL_MOD_PATH=$(MODULES_PATH) make -j $(CONCURRENCY_LEVEL) modules
	cd $(KERNEL_DIR) && MAKEFLAGS= MFLAGS= ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- CONCURRENCY_LEVEL=$(CONCURRENCY_LEVEL) INSTALL_MOD_PATH=$(MODULES_PATH) make -j $(CONCURRENCY_LEVEL) modules_install
	tar -C $(MODULES_PATH) -cjf $@ .

clean:
	rm -fr $(KERNEL_DIR)
	rm -f *-stamp *deb
