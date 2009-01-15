BUILDDEPS=gcc-4.1 automake sudo fakeroot debhelper module-assistant module-init-tools kernel-wedge xmlto docbook-utils gs transfig bzip2 sharutils cpio rpm sed g++ lftp devscripts apt-utils \
libc6-dev libqt3-mt-dev libgtk2.0-dev libxxf86misc-dev libxtst-dev libxxf86vm-dev libxinerama-dev libstdc++5 liburi-perl libncurses5-dev

REPOSITORY=lenny

# EXTRADCHARGS:= --distributor Untangle

# Upstream version numbers
KVER=2.6.26
KDEBVER=12

KUPVER=${KDEBVER}
PACKPFX=linux-2.6_${KVER}
WORKDIR=linux-2.6-${KVER}
KDSC=${PACKPFX}-${KUPVER}.dsc
KOURPATCH=untangle-debian.diff.gz

DOPTIONS=DEBIAN_KERNEL_JOBS="${NPROCEXP}" DEB_BUILD_OPTIONS="parallel=${NPROCEXP}" AUTOBUILD=1

MACHINE:=$(shell if [ `uname -m` = "x86_64" ]; then echo "amd64"; else echo "i386"; fi)
NPROCEXP:=$(shell echo "$$((1+`grep processor /proc/cpuinfo|wc -l`))")
TEMPDIR:=$(shell mktemp)


all:	clean pkgs legitify

pkgs::	kpkg

deps:	force
	sudo apt-get install ${BUILDDEPS} || echo "unable to run sudo"

kpkg:	${WORKDIR} force
	cd ${WORKDIR}; ${DOPTIONS} fakeroot make -f debian/rules clean
	cd ${WORKDIR}; ${DOPTIONS} fakeroot make -f debian/rules.gen source_${MACHINE}_untangle setup_${MACHINE}_untangle
	cd ${WORKDIR}; ${DOPTIONS} fakeroot make -f debian/rules.gen binary-arch_${MACHINE}_untangle binary-arch_${MACHINE}_real
	cd ${WORKDIR}; ${DOPTIONS} fakeroot make -f debian/rules binary-indep

# This combines our "generic" kernel patches with the specific Debian kernel
# patches into one patch to rule them all.
UPATCHSETLOC=${WORKDIR}/debian/patches/features/all/untangle
${KOURPATCH}: untangle-debian.basediff patches/*
	rm -rf ${TEMPDIR}
	mkdir -p ${TEMPDIR}/${UPATCHSETLOC}
	mkdir -p ${TEMPDIR}/old/${UPATCHSETLOC}
	cp patches/* ${TEMPDIR}/${UPATCHSETLOC}
	if [ -n "${EXTRAPATCHES}" ]; then cp "${EXTRAPATCHES}" ${TEMPDIR}/${UPATCHSETLOC}; fi
	-cd ${TEMPDIR};diff -Ncr old/${UPATCHSETLOC} ${UPATCHSETLOC} > ${TEMPDIR}/all.diff
	cat untangle-debian.basediff >> ${TEMPDIR}/all.diff
	if [ -f untangle-debian.${REPOSITORY}diff ]; then cat untangle-debian.${REPOSITORY}diff >> ${TEMPDIR}/all.diff; fi
	gzip -c ${TEMPDIR}/all.diff > ${KOURPATCH}

${WORKDIR}:	${KDSC} ${KOURPATCH}
	rm -rf ${WORKDIR}
	dpkg-source -x ${KDSC}
	cd ${WORKDIR};gunzip -c ../${KOURPATCH} | patch -p1
	-cd ${WORKDIR};make -f debian/rules debian/control-real
#	cd ${WORKDIR};make -f debian/rules debian/

clean::
	rm -f ${KOURPATCH}
	rm -rf ${WORKDIR}
	rm -rf notlegit
	rm -f *.deb modules/*.deb
	rm -f *.udeb modules/*.udeb

force:

# Get rid of packages we don't need.
# Ugly alert. XXX
legitify:
	mkdir -p notlegit
#	for i in *deb; do dpkg-deb -I $$i | grep untangle | grep -v -q ${OURVERSION} || mv $$i notlegit; done
#	mv notlegit/linux-libc-dev*deb .
#	mv notlegit/linux-headers*_all.deb .
#	mv notlegit/linux-source*_all.deb .
#	mv notlegit/linux-restricted-modules-common*deb .
#	mv notlegit/nvidia-glx-new_*deb .


# Utility rule to fetch the new ones
getsrc:
	-sudo apt-get update
	apt-get --download-only source linux-image-2.6.26-1-amd64
	apt-get --download-only source linux-latest-2.6 
