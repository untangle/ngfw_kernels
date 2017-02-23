include kernel.conf

# overridables
DESTDIR ?= tmp/install

# variables
DEBIAN_VERSION := $(shell dpkg-parsechangelog -S version)
UNTANGLE_VERSION := $(patsubst $(VERSION)%,%,$(DEBIAN_VERSION))
TRX_IMAGE := tmp/vmlinux-$(DEBIAN_VERSION).trx
TARBALL := $(UPSTREAM)-linux-$(VERSION).tar.xz
TARBALL_URL := http://download.untangle.com/kernels/$(TARBALL)
MODULES_PATH := tmp/modules-$(DEBIAN_VERSION)
CONFIG_UNTANGLE_ORIG := untangle.config
KERNEL_BOOT_DIR := $(KERNEL_DIR)/arch/$(KERNEL_ARCH)/boot
DTB_IMAGE := $(KERNEL_BOOT_DIR)/dts/$(DTB_NAME)
KERNEL_IMAGE := $(KERNEL_BOOT_DIR)/$(KERNEL_IMAGE)
CONFIG_ORIG := $(KERNEL_DIR)/$(CONFIG_NAME)
CONFIG_DEST := $(KERNEL_DIR)/.config
CONFIG_DEST_KERNEL := $(KERNEL_DIR)/.config-kernel
CONFIG_DEST_MODULES := $(KERNEL_DIR)/.config-modules
CONCURRENCY_LEVEL := $(shell grep -c '^processor\s:' /proc/cpuinfo)
UNTANGLE_PATCH_SERIES := patches/untangle/series
DDWRT_PATCH_SERIES := patches/dd-wrt/series-kernel
DDWRT_PATCH_MODULES_SERIES := patches/dd-wrt/series-modules
COMPILE_FLAGS := MAKEFLAGS= MFLAGS= ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- CONCURRENCY_LEVEL=$(CONCURRENCY_LEVEL)
TMP_TRX_IMAGE := tmp/zImage-$(DEBIAN_VERSION)

all: kernel modules

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

set-local-revision: patch set-local-revision-stamp
set-local-revision-stamp:
	perl -i -pe 's/(?<=^CONFIG_LOCALVERSION=")/'$(UNTANGLE_VERSION)/ $(CONFIG_DEST_KERNEL) $(CONFIG_DEST_MODULES)
	touch $@

kernel: $(KERNEL_IMAGE)
$(KERNEL_IMAGE): set-local-revision
	cd $(KERNEL_DIR) && $(COMPILE_FLAGS) KCONFIG_CONFIG=$(shell basename $(CONFIG_DEST_KERNEL)) make -j $(CONCURRENCY_LEVEL) zImage

modules: modules-stamp
modules-stamp: set-local-revision
	mkdir -p $(MODULES_PATH)
	cd $(KERNEL_DIR) && $(COMPILE_FLAGS) INSTALL_MOD_PATH=../$(MODULES_PATH) KCONFIG_CONFIG=$(shell basename $(CONFIG_DEST_MODULES)) make -j $(CONCURRENCY_LEVEL) modules
	cd $(KERNEL_DIR) && $(COMPILE_FLAGS) INSTALL_MOD_PATH=../$(MODULES_PATH) KCONFIG_CONFIG=$(shell basename $(CONFIG_DEST_MODULES)) make -j $(CONCURRENCY_LEVEL) modules_install
	touch modules-stamp

dtb: dtb-stamp
dtb-stamp: kernel
	cd $(KERNEL_DIR) && $(COMPILE_FLAGS) KCONFIG_CONFIG=$(shell basename $(CONFIG_DEST_KERNEL)) make dtbs
	touch $@

trx: $(TRX_IMAGE)
$(TRX_IMAGE): dtb $(DTB_IMAGE)
	mkdir -p tmp
	cat $(KERNEL_IMAGE) $(DTB_IMAGE) > $(TMP_TRX_IMAGE)
	./trx.sh $(TMP_TRX_IMAGE) $(TRX_IMAGE)

install: trx modules
	rm -fr $(DESTDIR)
	# zImage, DTB and uImage for this hardware
	mkdir -p $(DESTDIR)/boot
	# TRX and symlink
	cp $(TRX_IMAGE) $(DESTDIR)/boot/
	ln -sf $(shell basename $(TRX_IMAGE)) $(DESTDIR)/boot/trx
	# DTB and symlink (if necessary)
	[ $(DTB_IMAGE) = /dev/null ] || { cp $(DTB_IMAGE) $(DESTDIR)/boot/ ; ln -sf $(shell basename $(DTB_IMAGE)) $(DESTDIR)/boot/dtb ; }
	# zImage and symlink
	cp $(KERNEL_IMAGE) $(DESTDIR)/boot/zImage-$(DEBIAN_VERSION)
	ln -sf zImage-$(DEBIAN_VERSION) $(DESTDIR)/boot/zImage
	# firmware blobs for kernel modules
	mkdir -p $(DESTDIR)/lib/firmware/
	rsync -aHz binary-assets/firmware/ $(DESTDIR)/lib/firmware/
	# modules we built from source
	rsync -aHz $(MODULES_PATH)/ $(DESTDIR)/
	# binary modules from dd-wrt
	mkdir -p $(DESTDIR)/lib/modules/$(DEBIAN_VERSION)/extra
	cp binary-assets/modules/* $(DESTDIR)/lib/modules/$(DEBIAN_VERSION)/extra || true

debian: debian-stamp
debian-stamp:
	dpkg-buildpackage -us -uc -b --host-arch $(DEB_BUILD_ARCH)
	touch $@

kpkg-arch: debian
kpkg-indep: debian

clean:
	rm -fr $(KERNEL_DIR) tmp
	rm -f *-stamp 
	rm -f ../*.deb ../*.manifest
	find debian -maxdepth 1 -name untangle-linux-image* -type d -exec rm -fr {} \;

.PHONY: debian

.SUFFIXES:
