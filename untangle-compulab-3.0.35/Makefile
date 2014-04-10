TARBALL := linux-3.0.35+cmfx6-5.1.tar.bz2
KERNEL_DIR := linux-3.0.35
UIMAGE := $(KERNEL_DIR)/linux-3.0.35/arch/arm/boot/uImage
CONFIG_COMPULAB_ORIG := linux-3.0.35-cm-fx6-5.1.config
CONFIG_UNTANGLE_ORIG := untangle.config
CONFIG_DEST := $(KERNEL_DIR)/.config
CONCURRENCY_LEVEL := $(( 1 + $(grep -c '^processor\s:' /proc/cpuinfo) ))
UNTANGLE_PATCH_SERIES := patches/untangle/series

all: kernel-package uImage

extract: extract-stamp
extract-stamp: $(TARBALL)
	tar xjf $<
	touch $@

patch: patch-stamp
patch-stamp: patch-untangle-stamp
	touch $@

patch-untangle: patch-untangle-stamp 
patch-untangle-stamp: extract-stamp patches/untangle/*
	while read patch ; do \
	  echo "Applying $$patch" ; \
	  patch -d $(KERNEL_DIR) -p1 < patches/untangle/$$patch ; \
	done < $(UNTANGLE_PATCH_SERIES)
	touch $@

config: $(CONFIG_DEST)
$(CONFIG_DEST): extract-stamp $(CONFIG_COMPULAB_ORIG) $(CONFIG_UNTANGLE_ORIG)
	cat $(CONFIG_COMPULAB_ORIG) $(CONFIG_UNTANGLE_ORIG) >| $@

kernel-package: patch-stamp config
	cd $(KERNEL_DIR) ; \
	MAKEFLAGS= MFLAGS= DEB_HOST_ARCH=armel CONCURRENCY_LEVEL=$(CONCURRENCY_LEVEL) fakeroot make-kpkg --arch arm --cross-compile arm-linux-gnueabi- --initrd kernel_image kernel_headers

uImage: $(UIMAGE)
$(UIMAGE): kernel-package
	cd $(KERNEL_DIR) ; \
	ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- CONCURRENCY_LEVEL=$(CONCURRENCY_LEVEL) make uImage

clean:
	rm -fr $(KERNEL_DIR)
	rm -f *-stamp *deb
