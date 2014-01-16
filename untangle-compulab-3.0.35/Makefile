TARBALL := linux-3.0.35.tar.bz2
KERNEL_DIR := linux-3.0.35
CONFIG_ORIG := linux-3.0.35-cm-fx6-3.config
CONFIG_DEST := $(KERNEL_DIR)/.config
CONCURRENCY_LEVEL := $(( 1 + $(grep -c '^processor\s:' /proc/cpuinfo) ))
UNTANGLE_PATCH_SERIES := patches/untangle/series

all: kernel-package

extract: $(KERNEL_DIR)

$(KERNEL_DIR): $(TARBALL)
	tar xjf $(TARBALL)

patch: patch-compulab patch-untangle

patch-compulab: extract patches/compulab/*
	for patch in patches/compulab/* ; do \
	  echo "Applying $$patch" ; \
	  patch -d $(KERNEL_DIR) -f -p1 < $$patch ; \
	done

patch-untangle: patch-compulab patches/untangle/*
	while read patch ; do \
	  echo "Applying $$patch" ; \
	  patch -d $(KERNEL_DIR) -p1 < patches/untangle/$$patch ; \
	done < $(UNTANGLE_PATCH_SERIES)

config: extract $(CONFIG_DEST)

$(CONFIG_DEST): $(CONFIG_ORIG)
	cp $(CONFIG_ORIG) $(CONFIG_DEST)

kernel-package: patch config
	cd $(KERNEL_DIR) ; \
	MAKEFLAGS= DEB_HOST_ARCH=armel CONCURRENCY_LEVEL=$(CONCURRENCY_LEVEL) fakeroot make-kpkg --arch arm --cross-compile arm-linux-gnueabi- --initrd --revision=+untangle1 kernel_image kernel_headers # --append-to-version=-test1

clean:
	rm -fr $(KERNEL_DIR)
