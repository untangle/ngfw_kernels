BUILDDEPS=debhelper cpio module-init-tools python xmlto quilt kernel-wedge kmod python python-six lzma patchutils bc gcc-4.8 xz-utils

REPOSITORY=wheezy

# EXTRADCHARGS:= --distributor Untangle

# Upstream version numbers
KVER=3.16.7
KDEBVER=2

ORIG_TARBALL := linux_$(KVER).orig.tar.xz
ORIG_TARBALL_URL := https://downloads.edge.arista.com/public/kernels//$(ORIG_TARBALL)
DEBIAN_TARBALL := linux_$(KVER)-$(KDEBVER).debian.tar.xz
DEBIAN_TARBALL_URL := https://downloads.edge.arista.com/public/kernels//$(DEBIAN_TARBALL)

KUPVER=${KDEBVER}
PACKPFX=linux_${KVER}
WORKDIR=linux-${KVER}
KDSC=${PACKPFX}-${KUPVER}.dsc
KOURDIFF=untangle-debian.diff
KOURPATCH=${KOURDIFF}.gz

MACHINE:=$(shell dpkg-architecture -qDEB_BUILD_ARCH)
NPROCEXP:=$(shell echo "$$((1+`grep -c processor /proc/cpuinfo`))")
TEMPDIR:=$(shell mktemp)
TEMPDIR2:=$(shell mktemp)

ifeq ($(MACHINE),armhf)
  NPROCEXP := 1
endif

DOPTIONS = DEBIAN_KERNEL_JOBS=${NPROCEXP} DEB_BUILD_OPTIONS="parallel=${NPROCEXP}" CONCURRENCY_LEVEL=${NPROCEXP} AUTOBUILD=1

all:	clean pkgs

$(ORIG_TARBALL):
	curl -O $(ORIG_TARBALL_URL)
$(DEBIAN_TARBALL):
	curl -O $(DEBIAN_TARBALL_URL)

pkgs:	kpkg-arch kpkg-indep

deps:	force
	sudo apt-get install ${BUILDDEPS} || echo "unable to run sudo"

kpkg-arch: control-real force
	cd ${WORKDIR}; ${DOPTIONS} fakeroot make -j ${NPROCEXP} -f debian/rules.gen binary-arch_${MACHINE}_untangle
kpkg-indep: control-real force
	cd ${WORKDIR}; ${DOPTIONS} fakeroot make -j ${NPROCEXP} -f debian/rules binary-indep

kern:   ${WORKDIR} kpkg-arch

src: 	${WORKDIR} control-real force
	cd ${WORKDIR}; ${DOPTIONS} fakeroot make -f debian/rules.gen source_untangle setup_${MACHINE}_untangle

# This combines our "generic" kernel patches with the specific Debian kernel
# patches into one patch to rule them all.
UPATCHSETLOC=${WORKDIR}/debian/patches/features/all/untangle
${KOURPATCH}: untangle-debian.basediff patches/*
	rm -rf ${TEMPDIR} ${TEMPDIR2}
	mkdir -p ${TEMPDIR}/${WORKDIR}/debian/templates
	mkdir -p ${TEMPDIR}/${UPATCHSETLOC}
	mkdir -p ${TEMPDIR2}/${UPATCHSETLOC}
	cp patches/* ${TEMPDIR}/${UPATCHSETLOC}
	perl -pe 's|^|features/all/untangle/|' patches/series > ${TEMPDIR}/${WORKDIR}/debian/patches/series-untangle
	cp maintainer-scripts/* ${TEMPDIR}/${WORKDIR}/debian
	if [ -n "${EXTRAPATCHES}" ]; then cp "${EXTRAPATCHES}" ${TEMPDIR}/${UPATCHSETLOC}; fi
	-(cd ${TEMPDIR2}/${WORKDIR} ; diff -Ncr . ${TEMPDIR}/${WORKDIR}) | perl -pe 's|'${TEMPDIR}/${WORKDIR}/?'|./|g' > ${KOURDIFF}
	cat untangle-debian.basediff >> ${KOURDIFF}
	if [ -f untangle-debian.${REPOSITORY}diff ]; then cat untangle-debian.${REPOSITORY}diff >> ${KOURDIFF}; fi
	gzip -c ${KOURDIFF} > ${KOURPATCH}

patch: ${WORKDIR}
${WORKDIR}: $(ORIG_TARBALL) $(DEBIAN_TARBALL) ${KDSC} ${KOURPATCH}
	dpkg-source -x ${KDSC}
	cd ${WORKDIR};gunzip -c ../${KOURPATCH} | patch -p1
	perl -i -pe 's/fuzz=0/fuzz=3/' ${WORKDIR}/debian/rules*

control-real: ${WORKDIR}/debian/control-real
${WORKDIR}/debian/control-real: force patch
	cd ${WORKDIR};make -f debian/rules debian/control-real || true

clean::
	rm -f ${KOURPATCH} ${KOURDIFF}
	rm -rf ${WORKDIR}
	rm -f *.deb modules/*.deb
	rm -f *.udeb modules/*.udeb

force:
