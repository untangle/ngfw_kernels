# Our version number.  Currently must be manually updated.  You've been warned.
OURVERSION=untangle8

# Upstream version numbers
KVER=2.6.22
KDEBVER=14

KUPVER=${KDEBVER}.46
PACKPFX=linux-source-${KVER}_${KVER}
WORKDIR=linux-source-${KVER}-${KVER}
KDSC=${PACKPFX}-${KUPVER}.dsc
KOURPATCH=${PACKPFX}-${KUPVER}-untangle.diff.gz

UMUPVER=${KDEBVER}.37
UMPFX=linux-ubuntu-modules-${KVER}_${KVER}
UMWORKDIR=linux-ubuntu-modules-${KVER}-${KVER}
UMDSC=${UMPFX}-${UMUPVER}.dsc
UMOURPATCH=${UMPFX}-${UMUPVER}-untangle.diff.gz

RMUPVER=${KDEBVER}.9
RMPFX=linux-restricted-modules-${KVER}_${KVER}.4
RMWORKDIR=linux-restricted-modules-${KVER}-${KVER}.4
RMDSC=${RMPFX}-${RMUPVER}.dsc
RMOURPATCH=${RMPFX}-${RMUPVER}-untangle.diff.gz

METAUPVER=${KDEBVER}.21
METAPFX=linux-meta_${KVER}
METAWORKDIR=linux-meta-${KVER}.${METAUPVER}
METADSC=${METAPFX}.${METAUPVER}.dsc
METAOURPATCH=${METAPFX}.${METAUPVER}-untangle.diff.gz

EXTRAPATCHES ?=
EXTRADCHARGS ?=

DOPTIONS=DEB_BUILD_OPTIONS="parallel=${NPROCEXP}" AUTOBUILD=1 KVERS=${KVER}-${KDEBVER}-untangle
VDOPTIONS=DEB_BUILD_OPTIONS="parallel=${NPROCEXP}" AUTOBUILD=1 KVERS=${KVER}-${KDEBVER}-virtual-untangle


NPROCEXP:=$(shell grep processor /proc/cpuinfo|wc -l)
TEMPDIR:=$(shell mktemp)


all:	clean pkgs legitify

pkgs::	kpkg umpkg

deps:	force
	sudo apt-get install ${BUILDDEPS} || echo "unable to run sudo"

kpkg:	${WORKDIR} force
	cd ${WORKDIR}; ${DOPTIONS} fakeroot debian/rules clean custom-binary-untangle
	cd ${WORKDIR}; ${VDOPTIONS} fakeroot debian/rules custom-binary-virtual-untangle
	cd ${WORKDIR}; ${DOPTIONS} fakeroot debian/rules binary-indep binary-arch-headers

# This combines our generic kernel patches with the specific Ubuntu kernel
# patches into one patch to rule them all.
UPATCHSETLOC=${WORKDIR}/debian/binary-custom.d/untangle/patchset
UVPATCHSETLOC=${WORKDIR}/debian/binary-custom.d/virtual-untangle/patchset
${KOURPATCH}: ${PACKPFX}-${KUPVER}-untangle.basediff patches/0*
	rm -rf ${TEMPDIR}
	mkdir -p ${TEMPDIR}/${UPATCHSETLOC}
	mkdir -p ${TEMPDIR}/old/${UPATCHSETLOC}
	cp patches/0* ${TEMPDIR}/${UPATCHSETLOC}
	if [ -n "${EXTRAPATCHES}" ]; then cp "${EXTRAPATCHES}" ${TEMPDIR}/${UPATCHSETLOC}; fi
	-cd ${TEMPDIR};diff -Ncr old/${UPATCHSETLOC} ${UPATCHSETLOC} > ${TEMPDIR}/all.diff
	mkdir -p ${TEMPDIR}/${UVPATCHSETLOC}
	mkdir -p ${TEMPDIR}/old/${UVPATCHSETLOC}
	cp patches/0* ${TEMPDIR}/${UVPATCHSETLOC}
	if [ -n "${EXTRAPATCHES}" ]; then cp "${EXTRAPATCHES}" ${TEMPDIR}/${UVPATCHSETLOC}; fi
	-cd ${TEMPDIR};diff -Ncr old/${UVPATCHSETLOC} ${UVPATCHSETLOC} >> ${TEMPDIR}/all.diff
	cat ${PACKPFX}-${KUPVER}-untangle.basediff >> ${TEMPDIR}/all.diff
	if [ -f ${PACKPFX}-${KUPVER}-untangle.${REPOSITORY}diff ]; then cat ${PACKPFX}-${KUPVER}-untangle.${REPOSITORY}diff >> ${TEMPDIR}/all.diff; fi
	gzip -c ${TEMPDIR}/all.diff > ${KOURPATCH}

${WORKDIR}:	${KDSC} ${KOURPATCH}
	rm -rf ${WORKDIR}
	dpkg-source -x ${KDSC}
	cd ${WORKDIR};gunzip -c ../${KOURPATCH} | patch -p1
# Clean out control.stub so that it always gets generated.
	rm ${WORKDIR}/debian/control.stub
	cd ${WORKDIR}; DEBEMAIL="jdi@untangle.com" dch ${EXTRADCHARGS} -p -v ${KVER}-${KUPVER}${OURVERSION} -D thunderbird "kernel build"

${UMWORKDIR}:	${UMDSC} ${UMOURPATCH}
	rm -rf ${UMWORKDIR}
	dpkg-source -x ${UMDSC}
	gunzip -c ${UMOURPATCH} | patch -p0
	cd ${UMWORKDIR}; DEBEMAIL="jdi@untangle.com" dch ${EXTRADCHARGS} -p -v ${KVER}-${UMUPVER}${OURVERSION} -D thunderbird "kernel build"

${RMWORKDIR}:	${RMDSC} ${RMOURPATCH}
	rm -rf ${RMWORKDIR}
	dpkg-source -x ${RMDSC}
	gunzip -c ${RMOURPATCH} | patch -p0
	cd ${RMWORKDIR}; DEBEMAIL="jdi@untangle.com" dch ${EXTRADCHARGS} -p -v ${KVER}.4-${RMUPVER}${OURVERSION} -D thunderbird "kernel build"

${METAWORKDIR}:	${METADSC} ${METAOURPATCH}
	rm -rf ${METAWORKDIR}
	dpkg-source -x ${METADSC}
	gunzip -c ${METAOURPATCH} | patch -p0
	cd ${METAWORKDIR}; DEBEMAIL="jdi@untangle.com" dch ${EXTRADCHARGS} -p -v ${KVER}.${METAUPVER}${OURVERSION} -D thunderbird "kernel build"

release: force
	echo "make -f HADESHOME/pkgtools/Makefile release-deb REPOSITORY=${REPOSITORY} DISTRIBUTION=thunderbird"


clean::
	rm -f ${KOURPATCH}
	rm -rf ${WORKDIR}
	rm -rf ${UMWORKDIR}
	rm -rf ${RMWORKDIR}
	rm -rf ${METAWORKDIR}
	rm -rf ${VMWTWORKDIR}
	rm -rf notlegit
	rm -f *.deb modules/*.deb
	rm -f *.udeb modules/*.udeb

force:
