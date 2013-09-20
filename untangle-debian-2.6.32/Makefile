BUILDDEPS=debhelper cpio module-init-tools python libelf-dev binutils-dev asciidoc xmlto gcc-4.3 

REPOSITORY=squeeze

# EXTRADCHARGS:= --distributor Untangle

# Upstream version numbers
KVER=2.6.32
KDEBVER=41

KUPVER=${KDEBVER}
PACKPFX=linux-2.6_${KVER}
WORKDIR=linux-2.6-${KVER}
KDSC=${PACKPFX}-${KUPVER}.dsc
KOURDIFF=untangle-debian.diff
KOURPATCH=${KOURDIFF}.gz

DOPTIONS=DEBIAN_KERNEL_JOBS="${NPROCEXP}" DEB_BUILD_OPTIONS="parallel=${NPROCEXP}" AUTOBUILD=1

MACHINE:=$(shell dpkg-architecture -qDEB_BUILD_ARCH)
NPROCEXP:=$(shell echo "$$((1+`grep -c processor /proc/cpuinfo`))")
TEMPDIR:=$(shell mktemp)
TEMPDIR2:=$(shell mktemp)

all:	clean kpkg 

pkgs:	kpkg

deps:	force
	sudo aptitude install ${BUILDDEPS} || echo "unable to run sudo"

kpkg:	control-real force
	cd ${WORKDIR}; ${DOPTIONS} fakeroot make -f debian/rules clean
#	cd ${WORKDIR}; ${DOPTIONS} fakeroot make -f debian/rules.gen source_${MACHINE}_untangle+xen setup_${MACHINE}_untangle+xen source_${MACHINE}_untangle setup_${MACHINE}_untangle
	cd ${WORKDIR}; ${DOPTIONS} fakeroot make -f debian/rules.gen source_${MACHINE}_untangle setup_${MACHINE}_untangle
#	cd ${WORKDIR}; ${DOPTIONS} fakeroot make -f debian/rules.gen binary-arch_${MACHINE}_untangle+xen binary-arch_${MACHINE}_untangle binary-arch_${MACHINE}_real
	cd ${WORKDIR}; ${DOPTIONS} fakeroot make -f debian/rules.gen binary-arch_${MACHINE}_untangle binary-arch_${MACHINE}_real
	cd ${WORKDIR}; ${DOPTIONS} fakeroot make -f debian/rules binary-indep

# for development
src: 	${WORKDIR} control-real force
	cd ${WORKDIR}; ${DOPTIONS} fakeroot make -f debian/rules.gen source_${MACHINE}_untangle setup_${MACHINE}_untangle

# for development
kern:	${WORKDIR} control-real force
	cd ${WORKDIR}; ${DOPTIONS} fakeroot make -f debian/rules.gen binary-arch_${MACHINE}_untangle

# This combines our "generic" kernel patches with the specific Debian kernel
# patches into one patch to rule them all.
UPATCHSETLOC=${WORKDIR}/debian/patches/features/all/untangle
${KOURPATCH}: untangle-debian.basediff patches/*
	rm -rf ${TEMPDIR} ${TEMPDIR2}
	mkdir -p ${TEMPDIR}/${WORKDIR}/debian/templates
	mkdir -p ${TEMPDIR}/${UPATCHSETLOC}
	mkdir -p ${TEMPDIR2}/${UPATCHSETLOC}
	cp patches/* ${TEMPDIR}/${UPATCHSETLOC}
	cp maintainer-scripts/* ${TEMPDIR}/${WORKDIR}/debian
	if [ -n "${EXTRAPATCHES}" ]; then cp "${EXTRAPATCHES}" ${TEMPDIR}/${UPATCHSETLOC}; fi
	-(cd ${TEMPDIR2}/${WORKDIR} ; diff -Ncr . ${TEMPDIR}/${WORKDIR}) | perl -pe 's|'${TEMPDIR}/${WORKDIR}/?'|./|g' > ${KOURDIFF}
	cat untangle-debian.basediff >> ${KOURDIFF}
	if [ -f untangle-debian.${REPOSITORY}diff ]; then cat untangle-debian.${REPOSITORY}diff >> ${KOURDIFF}; fi
	gzip -c ${KOURDIFF} > ${KOURPATCH}

patch: ${WORKDIR}
${WORKDIR}:	${KDSC} ${KOURPATCH}
	rm -rf ${WORKDIR}
	dpkg-source -x ${KDSC}
	cd ${WORKDIR};gunzip -c ../${KOURPATCH} | patch -p1
#	cd ${WORKDIR};make -f debian/rules debian/

control-real:
	cd ${WORKDIR};make -f debian/rules debian/control-real || true

clean::
	rm -f ${KOURPATCH} ${KOURDIFF}
	rm -rf ${WORKDIR}
	rm -f *.deb modules/*.deb
	rm -f *.udeb modules/*.udeb

force:

# Utility rule to fetch the new ones
getsrc:
	-sudo apt-get update
	apt-get --download-only source linux-image-2.6.32-1-amd64
	apt-get --download-only source linux-latest-2.6
