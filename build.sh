#!/usr/bin/env bash

# El unico argumento que recibe build.sh es -d o --debug que fuerza a que el boo
# teo sea con el "modo step" el cual promptea para avanzar y permite leer los me
# nsajes de inicializacion. Si se arma sin flag, entonces el modo step aun se pu
# ede usar, y acciona presionando tecla 's' durante el arranque. 

set +e


# See if BMFS_SIZE was defined for custom disk sizes.
if [ "x$BMFS_SIZE" = x ]; then
	BMFS_SIZE=128
fi


# Initialize disk images. Arg 1 is BMFS size in MiB.
function init_imgs { 

	echo -n "Creating disk image files... "

	dd if=/dev/zero of=./img/bmfs.img count=$1 bs=1048576 > /dev/null 2>&1

	mformat -t 128 -h 2 -s 1024 -C -F -i ./img/fat32.img
	mmd -i ./img/fat32.img ::/EFI > /dev/null 2>&1
	mmd -i ./img/fat32.img ::/EFI/BOOT > /dev/null 2>&1
	retVal=$?
	if [ $retVal -ne 0 ]; then
		echo -n "no UEFI support (due to bad mtools), "
	fi
	echo "\EFI\BOOT\BOOTX64.EFI" > startup.nsh
	mcopy -i ./img/fat32.img startup.nsh ::/
	rm startup.nsh

	echo "OK"
}


# Build the source code and create the software files.
function build_all {

	make clean -C .

	if [ "$1" = "-d" -o "$1" = "--debug" ]; then
		make_output=$(make FORCE_STEP_MODE=1 all -C . 2>&1)
	else
		make_output=$(make all -C . 2>&1)
	fi

	echo "$make_output" | grep --color=always -i "error" || echo "$make_output"

	if [ ! -f "./build/uefi.sys" ]; then # Simple check of files generated ok.
		echo -e "\e[1;31m Error: uefi.sys no generado!\e[0m"
		exit 1
	elif [ ! -f "./build/tsl.sys" ]; then
		echo -e "\e[1;31m Error: tsl.sys no generado!\e[0m"
		exit 1
	fi

	init_imgs $BMFS_SIZE

	cat ./build/tsl.sys ./extern/kernel.bin > ./out/payload.sys
	payload_size=$(wc -c <./out/payload.sys)
	if [ $payload_size -gt 32768 ]; then
		echo "Warning - payload binary is larger than 32768 bytes!"
	fi

	# Prepara UEFI loader (uefi += bootloader + kernel + userland). Colocar en 
	# la posicion indicada en uefi.asm 
	cp ./build/uefi.sys ./out/BOOTX64.EFI
	dd if=./out/payload.sys of=./out/BOOTX64.EFI bs=16384 seek=1 conv=notrunc > /dev/null 2>&1

	echo -n "Formatting BMFS disk... "
	./extern/bmfs ./img/bmfs.img format
	echo "OK"

	img_install
	convert_img
}


# Dejar lista imagen de disco.
function img_install {

	# Copy UEFI boot to disk image.
	if [ -x "$(command -v mcopy)" ]; then
		mcopy -oi ./img/fat32.img ./out/BOOTX64.EFI ::/EFI/BOOT/BOOTX64.EFI > /dev/null 2>&1
		retVal=$?
		if [ $retVal -ne 0 ]; then
			echo -n "no UEFI support (due to bad mtools), "
		fi
	fi

	cat ./img/fat32.img ./img/bmfs.img > ./img/x64_arq.img
}


function convert_img {
	echo -n "Creating VMDK and QCOW2 images... "
	qemu-img convert -O vmdk ./img/x64_arq.img ./img/x64_arq.vmdk
	qemu-img convert -f vmdk -O qcow2 ./img/x64_arq.vmdk ./img/x64_arq.qcow2
	echo "OK"
}


build_all $1