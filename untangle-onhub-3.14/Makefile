BUILD_DEPS := gcc-5-arm-linux-gnueabihf device-tree-compiler u-boot-tools cgpt vboot-kernel-utils

TARBALL := chromeos-3.14.tar.bz2
KERNEL_DIR := chromeos-3.14
KERNEL_IMAGE := $(KERNEL_DIR)/arch/arm/boot/zImage
ITF_IMAGE := $(KERNEL_DIR)/arch/arm/boot/vmlinux.itf
MODULES_PATH=/tmp/mods-3.14.0
MODULES_TARBALL := $(KERNEL_DIR)/modules.tar.bz2
VIMAGE := $(KERNEL_DIR)/vimage
#CMDLINE := cmdline.txt
CMDLINE := cmdline-untangle.txt
CONFIG_ORIG := config_chromiumos-ipq806x.config
CONFIG_UNTANGLE_ORIG := untangle.config
CONFIG_DEST := $(KERNEL_DIR)/.config
CONCURRENCY_LEVEL := $(shell grep -c '^processor\s:' /proc/cpuinfo)
UNTANGLE_PATCH_SERIES := patches/untangle/series

all: kernel vimage modules

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
	export WIFIVERSION=-3.18 ; \
	MAKEFLAGS= MFLAGS= ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- CONCURRENCY_LEVEL=$(CONCURRENCY_LEVEL) make -j $(CONCURRENCY_LEVEL) zImage

kernel-package: patch-stamp config
	cd $(KERNEL_DIR) ; \
	export WIFIVERSION=-3.18 ; \
	MAKEFLAGS= MFLAGS= DEB_HOST_ARCH=armhf CONCURRENCY_LEVEL=$(CONCURRENCY_LEVEL) fakeroot make-kpkg --arch arm --cross-compile arm-linux-gnueabihf- --revision=1+untangle1 kernel_image kernel_headers

dtb: dtb-stamp
dtb-stamp: kernel
	cd $(KERNEL_DIR) ; \
	export WIFIVERSION=-3.18 ; \
	MAKEFLAGS= MFLAGS= ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- CONCURRENCY_LEVEL=$(CONCURRENCY_LEVEL) make dtbs
	touch $@

itf: $(ITF_IMAGE)
$(ITF_IMAGE): dtb
	mkimage -D '-I dts -O dtb -p 1024' -f onhub.its $(ITF_IMAGE)

vimage: $(VIMAGE)
$(VIMAGE): itf
	vbutil_kernel --verbose --pack $(VIMAGE) --keyblock /usr/share/vboot/devkeys/recovery_kernel.keyblock --version 1 --signprivate /usr/share/vboot/devkeys/recovery_kernel_data_key.vbprivk --config $(CMDLINE) --vmlinuz $(ITF_IMAGE) --arch arm --bootloader bootloader.bin

verify: vimage
	vbutil_kernel --verbose --debug --verify $(VIMAGE)

modules: $(MODULES_TARBALL)
$(MODULES_TARBALL): kernel
	rm -fr $(MODULES_PATH)
	mkdir -p $(MODULES_PATH)
	export WIFIVERSION=-3.18 && cd $(KERNEL_DIR) && MAKEFLAGS= MFLAGS= ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- CONCURRENCY_LEVEL=$(CONCURRENCY_LEVEL) INSTALL_MOD_PATH=$(MODULES_PATH) make -j $(CONCURRENCY_LEVEL) modules
	export WIFIVERSION=-3.18 && cd $(KERNEL_DIR) && MAKEFLAGS= MFLAGS= ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- CONCURRENCY_LEVEL=$(CONCURRENCY_LEVEL) INSTALL_MOD_PATH=$(MODULES_PATH) make -j $(CONCURRENCY_LEVEL) modules_install
	tar -C $(MODULES_PATH) -cjf $@ .

clean:
	rm -fr $(KERNEL_DIR)
	rm -f *-stamp *deb
