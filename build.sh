#!/usr/bin/env bash

set +e
export EXEC_DIR="$PWD"
export OUTPUT_DIR="$EXEC_DIR/image"

# see if BMFS_SIZE was defined for custom disk sizes
if [ "x$BMFS_SIZE" = x ]; then
	BMFS_SIZE=128
fi


# Initialize disk images. Arg 1 is BMFS size in MiB.
function init_imgs { 

	echo -n "Creating disk image files... "

	dd if=/dev/zero of=./image/bmfs.img count=$1 bs=1048576 > /dev/null 2>&1

	mformat -t 128 -h 2 -s 1024 -C -F -i ./image/fat32.img
	mmd -i ./image/fat32.img ::/EFI > /dev/null 2>&1
	mmd -i ./image/fat32.img ::/EFI/BOOT > /dev/null 2>&1
	retVal=$?
	if [ $retVal -ne 0 ]; then
		echo -n "no UEFI support (due to bad mtools), "
	fi
	echo "\EFI\BOOT\BOOTX64.EFI" > startup.nsh
	mcopy -i ./image/fat32.img startup.nsh ::/
	rm startup.nsh

	echo "OK"
}


# Build the source code and create the software files
function build_all {

	make clean -C .
	make all -C .

	init_imgs $BMFS_SIZE


	cat ./build/bootloader.sys ./sys/kernel.bin > ./out/payload.sys
	payload_size=$(wc -c <./out/payload.sys)
	if [ $payload_size -gt 32768 ]; then
		echo "Warning - payload binary is larger than 32768 bytes!"
	fi

	## Prepara UEFI loader (uefi += bootloader + kernel + userland). Fijate q se colo
	## ca en la posicion indicada en uefi.asm 
	cp ./build/uefi.sys ./out/BOOTX64.EFI
	dd if=./out/payload.sys of=./out/BOOTX64.EFI bs=16384 seek=1 conv=notrunc > /dev/null 2>&1

	echo -n "Formatting BMFS disk... "
	./sys/bmfs ./image/bmfs.img format
	echo "OK"

	img_install
	convert_img_vmdk
}


# Dejar lista imagen de disco.
function img_install {

	# Copy UEFI boot to disk image
	if [ -x "$(command -v mcopy)" ]; then
		mcopy -oi ./image/fat32.img ./out/BOOTX64.EFI ::/EFI/BOOT/BOOTX64.EFI > /dev/null 2>&1
		retVal=$?
		if [ $retVal -ne 0 ]; then
			echo -n "no UEFI support (due to bad mtools), "
		fi
	fi

	cat ./image/fat32.img ./image/bmfs.img > ./image/x64_arq_os.img
}


function convert_img_vmdk {
	echo "Creating VMDK image..."
	qemu-img convert -O vmdk "$OUTPUT_DIR/x64_arq_os.img" "$OUTPUT_DIR/x64_arq_os.vmdk"
}



build_all