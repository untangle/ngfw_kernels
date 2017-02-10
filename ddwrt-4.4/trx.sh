#! /bin/sh

CURRENT_DIR=$(dirname $0)
BIN_DIR=${CURRENT_DIR}/binary-assets

zImage=$1
trx=$2

tmpImage="tmp/lzmaImage"
tmpTrx="tmp/image.trx"
tmpSquashfs="tmp/root.squashfs"

${BIN_DIR}/lzma_4k e $zImage $tmpImage

# dynamically create a 28M dummy squashfs filled with zeros
dd if=/dev/zero of=$tmpSquashfs bs=1MB count=28

# assemble the TRX file
${BIN_DIR}/trx -m 40000000 -o $tmpTrx $tmpImage -a 131072 $tmpSquashfs

# run through trx_vendor to compute a correct TRX checksum
${BIN_DIR}/trx_vendor -i $tmpTrx -r RT-AC88U,3.0.0.4,380,760,$trx

