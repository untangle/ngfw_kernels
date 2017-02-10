BUILDDEPS=gcc-4.1 automake sudo fakeroot debhelper module-assistant module-init-tools kernel-wedge xmlto docbook-utils gs transfig bzip2 sharutils cpio rpm sed g++ lftp devscripts apt-utils \
libc6-dev libqt3-mt-dev libgtk2.0-dev libxxf86misc-dev libxtst-dev libxxf86vm-dev libxinerama-dev libstdc++5 liburi-perl libncurses5-dev

REPOSITORY=lenny

# EXTRADCHARGS:= --distributor Untangle

# Upstream version numbers
KVER=2.6.26
KDEBVER=22

KUPVER=${KDEBVER}
PACKPFX=linux-2.6_${KVER}
WORKDIR=linux-2.6-${KVER}
KDSC=${PACKPFX}-${KUPVER}.dsc
KOURDIFF=untangle-debian.diff
KOURPATCH=${KOURDIFF}.gz

DOPTIONS=DEBIAN_KERNEL_JOBS="${NPROCEXP}" DEB_BUILD_OPTIONS="parallel=${NPROCEXP}" AUTOBUILD=1

MACHINE:=$(shell if [ `uname -m` = "x86_64" ]; then echo "amd64"; else echo "i386"; fi)
NPROCEXP:=$(shell echo "$$((1+`grep processor /proc/cpuinfo|wc -l`))")
TEMPDIR:=$(shell mktemp)
TEMPDIR2:=$(shell mktemp)

all:	clean kpkg 

pkgs:	kpkg

deps:	force
	sudo aptitude install ${BUILDDEPS} || echo "unable to run sudo"

kpkg:	${WORKDIR} control-real force
	cd ${WORKDIR}; ${DOPTIONS} fakeroot make -f debian/rules clean
	cd ${WORKDIR}; ${DOPTIONS} fakeroot make -f debian/rules.gen source_${MACHINE}_untangle+xen setup_${MACHINE}_untangle+xen source_${MACHINE}_untangle setup_${MACHINE}_untangle
	cd ${WORKDIR}; ${DOPTIONS} fakeroot make -f debian/rules.gen binary-arch_${MACHINE}_untangle+xen binary-arch_${MACHINE}_untangle binary-arch_${MACHINE}_real
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
	-(cd ${TEMPDIR2}/${WORKDIR} ; diff -Ncr . ${TEMPDIR}/${WORKDIR}) > ${KOURDIFF}
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
	apt-get --download-only source linux-image-2.6.26-1-amd64
	apt-get --download-only source linux-latest-2.6

