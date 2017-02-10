TARBALL := linux-3.10.49+ddwrt24710.tar.bz2
TARBALL_URL := http://download.untangle.com/kernels/$(TARBALL)
KERNEL_DIR := linux-3.10.49
UIMAGE := $(KERNEL_DIR)/linux-3.10.49/arch/arm/boot/uImage
CONFIG_ORIG := config_northstar_smp.config
CONFIG_UNTANGLE_ORIG := untangle.config
CONFIG_DEST := $(KERNEL_DIR)/.config
CONCURRENCY_LEVEL := $(shell grep -c '^processor\s:' /proc/cpuinfo)
UNTANGLE_PATCH_SERIES := patches/untangle/series
DDWRT_PATCH_SERIES := patches/dd-wrt/series

all: kernel

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

kernel: patch-stamp config
	cd $(KERNEL_DIR) ; \
	MAKEFLAGS= MFLAGS= ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- CONCURRENCY_LEVEL=$(CONCURRENCY_LEVEL) make

kernel-package: patch-stamp config
	cd $(KERNEL_DIR) ; \
	MAKEFLAGS= MFLAGS= DEB_HOST_ARCH=armhf CONCURRENCY_LEVEL=$(CONCURRENCY_LEVEL) fakeroot make-kpkg --arch arm --cross-compile arm-linux-gnueabihf- --revision=1+untangle1 kernel_image kernel_headers

clean:
	rm -fr $(KERNEL_DIR)
	rm -f *-stamp *deb
