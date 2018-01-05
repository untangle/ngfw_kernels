# Generic Makefile for building an Untangle kernel based on a Debian one
# 
# Nothing should have to change in this file; instead,
# version-specific settings and variables can be defined in
# kernel.conf

include kernel.conf

ORIG_TARBALL := linux_$(UPSTREAM_VERSION).orig.tar.xz
ORIG_TARBALL_URL := http://download.untangle.com/kernels/$(ORIG_TARBALL)
DEBIAN_TARBALL := linux_$(UPSTREAM_VERSION)-$(DEBIAN_VERSION).debian.tar.xz
DEBIAN_TARBALL_URL := http://download.untangle.com/kernels/$(DEBIAN_TARBALL)

KERNEL_DIR := linux-$(UPSTREAM_VERSION)
KDSC := linux_$(UPSTREAM_VERSION)-$(DEBIAN_VERSION).dsc

UNTANGLE_PATCH_SERIES := patches/untangle/series
DEBIAN_PATCH_SERIES := patches/debian/series

MACHINE:=$(shell dpkg-architecture -qDEB_BUILD_ARCH)
NPROCEXP:=$(shell echo "$$((1+`grep -c processor /proc/cpuinfo`))")

ifeq ($(MACHINE),armhf)
  NPROCEXP := 1
endif

DOPTIONS = DEBIAN_KERNEL_JOBS=${NPROCEXP} DEB_BUILD_OPTIONS="parallel=${NPROCEXP}" CONCURRENCY_LEVEL=${NPROCEXP} AUTOBUILD=1

all:	clean pkgs

$(ORIG_TARBALL):
	curl -O $(ORIG_TARBALL_URL)
$(DEBIAN_TARBALL):
	curl -O $(DEBIAN_TARBALL_URL)

extract: extract-stamp
extract-stamp: $(ORIG_TARBALL) $(DEBIAN_TARBALL)
	dpkg-source -x ${KDSC}
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
	mkdir -p $(KERNEL_DIR)/debian/patches/features/all/untangle
	cp patches/untangle/*.patch $(KERNEL_DIR)/debian/patches/features/all/untangle
	perl -pe 's|^|features/all/untangle/|' patches/untangle/series > $(KERNEL_DIR)/debian/patches/series-untangle
	touch $@

version: version-stamp
version-stamp: changelog
	cat  changelog $(KERNEL_DIR)/debian/changelog > /tmp/changelog
	mv /tmp/changelog $(KERNEL_DIR)/debian/changelog
	touch $@

patch: patch-debian patch-untangle version
	# FIXME: make this a debian patch ?
	perl -i -pe 's/fuzz=0/fuzz=3 || true/' ${KERNEL_DIR}/debian/rules.{defs,gen,real}*

pkgs:	kpkg-arch kpkg-indep

deps:	force
	sudo apt-get install ${BUILDDEPS} || echo "unable to run sudo"

kpkg-arch: control-real force
	cd ${KERNEL_DIR}; ${DOPTIONS} fakeroot make -j ${NPROCEXP} -f debian/rules.gen binary-arch_${MACHINE}_untangle
kpkg-indep: control-real force
	cd ${KERNEL_DIR}; ${DOPTIONS} fakeroot make -j ${NPROCEXP} -f debian/rules binary-indep

kern:   ${KERNEL_DIR} kpkg-arch

src: 	${KERNEL_DIR} control-real force
	cd ${KERNEL_DIR}; ${DOPTIONS} fakeroot make -f debian/rules.gen source_untangle setup_${MACHINE}_untangle

control-real: ${KERNEL_DIR}/debian/control-real
${KERNEL_DIR}/debian/control-real: force patch
	cd ${KERNEL_DIR};make -f debian/rules debian/control-real || true

clean::
	rm -rf ${KERNEL_DIR} *stamp
	rm -f *.deb modules/*.deb
	rm -f *.udeb modules/*.udeb

force:
