# Generic Makefile for building an Untangle kernel based on a Debian one
# 
# Nothing should have to change in this file; instead,
# version-specific settings and variables can be defined in
# kernel.conf

include $(shell dirname $(MAKEFILE_LIST))/kernel.conf

UNTANGLE_MIRROR := https://downloads.untangle.com/public/kernels
ORIG_TARBALL := linux_$(UPSTREAM_VERSION).orig.tar.xz
ORIG_TARBALL_URL := $(UNTANGLE_MIRROR)/$(ORIG_TARBALL)
DEBIAN_TARBALL := linux_$(UPSTREAM_VERSION)-$(DEBIAN_VERSION).debian.tar.xz
DEBIAN_TARBALL_URL := $(UNTANGLE_MIRROR)/$(DEBIAN_TARBALL)

KDSC := linux_$(UPSTREAM_VERSION)-$(DEBIAN_VERSION).dsc
UNTANGLE_PATCH_SERIES := patches/untangle/series
DEBIAN_PATCH_SERIES := patches/debian/series

KERNEL_DIR := linux-$(UPSTREAM_VERSION)
UNTANGLE_BUILD_PROFILES_FILE=$(KERNEL_DIR)/debian/untangle-build-profiles

ARCH ?= $(shell dpkg-architecture -qDEB_BUILD_ARCH_CPU)

ifeq ($(ARCH),armhf)
  PARALLEL_JOBS ?= 1
else
  PARALLEL_JOBS ?= $(shell echo "$$((1+`nproc`))")
endif

export CONCURRENCY_LEVEL=$(PARALLEL_JOBS)
export DEBIAN_KERNEL_JOBS=$(PARALLEL_JOBS)
export DEB_BUILD_OPTIONS="parallel=$(PARALLEL_JOBS)"
export AUTOBUILD=1
export DEB_BUILD_PROFILES="$(shell sed -e 's/,/ /g' $(UNTANGLE_BUILD_PROFILES_FILE))"

all:	clean pkgs

download: $(ORIG_TARBALL) $(DEBIAN_TARBALL)
$(ORIG_TARBALL):
	curl -O $(ORIG_TARBALL_URL)
$(DEBIAN_TARBALL):
	curl -O $(DEBIAN_TARBALL_URL)

extract: extract-stamp
extract-stamp: $(ORIG_TARBALL) $(DEBIAN_TARBALL)
	dpkg-source -x $(KDSC)
	touch $@

patch-debian: patch-debian-stamp
patch-debian-stamp: extract-stamp patches/debian/*
	while read patch ; do \
	  echo "Applying $$patch" ; \
	  patch -d $(KERNEL_DIR) -p1 < patches/debian/$$patch || exit 1 ; \
	done < $(DEBIAN_PATCH_SERIES)
	touch $@

patch-untangle: patch-untangle-stamp
patch-untangle-stamp: extract-stamp patches/untangle/*
	mkdir -p $(KERNEL_DIR)/debian/patches-untangle
	cp patches/untangle/* $(KERNEL_DIR)/debian/patches-untangle
	touch $@

version: version-stamp
version-stamp: changelog
	cat  changelog $(KERNEL_DIR)/debian/changelog > /tmp/changelog
	mv /tmp/changelog $(KERNEL_DIR)/debian/changelog
	touch $@

patch: patch-debian patch-untangle version

pkgs:	kpkg-arch kpkg-indep

deps:	force control-real
	cd $(KERNEL_DIR) ; apt build-dep -y --build-profiles $(shell cat debian/untangle-build-profiles) --host-architecture $(ARCH) .

kpkg-arch: control-real force
	fakeroot make -C $(KERNEL_DIR) -j $(PARALLEL_JOBS) -f debian/rules.gen binary-arch_$(ARCH)_untangle
kpkg-indep: control-real force
	fakeroot make -C $(KERNEL_DIR) -j $(PARALLEL_JOBS) -f debian/rules binary-indep

kern:   ${KERNEL_DIR} kpkg-arch

src: 	${KERNEL_DIR} control-real force
	fakeroot make -C $(KERNEL_DIR) -f debian/rules.gen source_untangle setup_$(ARCH)_untangle

control-real: ${KERNEL_DIR}/debian/control-real
${KERNEL_DIR}/debian/control-real: force patch
	which kernel-wedge || apt install -y kernel-wedge
	# do not build -dbg images 
	# FIXME: this should be a proper patch in patches/debian, so
	# we're warned early on when we bump versions and the syntax
	# has changed
	perl -i -pe 's/debug-info:.*/debug-info: false/' $(KERNEL_DIR)/debian/config/*/defines $(KERNEL_DIR)/debian/config/defines
	# do not sign images 
	# FIXME: this should be a proper patch in patches/debian, so
	# we're warned early on when we bump versions and the syntax
	# has changed
	perl -i -pe 's/signed-code:.*/signed-code: false/' $(KERNEL_DIR)/debian/config/*/defines $(KERNEL_DIR)/debian/config/defines
	cd ${KERNEL_DIR};make -f debian/rules debian/control-real || true
	# # limit the arch-dep target to untangle kernels
	# perl -i -pe 's/(binary-arch_.*)/$$1_untangle/' $(KERNEL_DIR)/debian/rules

clean::
	rm -rf ${KERNEL_DIR} *stamp
	rm -f *.deb modules/*.deb
	rm -f *.udeb modules/*.udeb

force:
