#! /bin/sh

tmpImage="tmp/uImage"

mkimage -A arm -O linux -T kernel -a 0x00008000 -C none -e 0x00008000 -n 'Untangle' -d $1 $tmpImage

dd if=$tmpImage of=$2 bs=3072k conv=sync
