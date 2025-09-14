#!/bin/bash

# By default use uefi boot.
bios_flag="-bios extern/OVMF.fd"

while getopts "b d c:" opt; do
	case "$opt" in
	b)	bios_flag=""
		;;
	d)
		debug_flags="-s -S"
		;;
	c)
		cant_cores="$OPTARG"
		;;
	*)
		echo "Use: $0 [-b] [-d] [-c cant_cores]"
		echo "-b force use bios (default = uefi)"
		echo "-d qemu to debug with gdb"
		echo "-c <number_of_cores>"
		exit 1
		;;
	esac
done

qemu-system-x86_64 $bios_flag -hda img/x64_arq.qcow2 -m 512 \
	-name "arq64 uefi" $debug_flags  -smp "$cant_cores"

### Dejar esto para probar el booteo con bios, luego, agregar flag para seleccionar uno u otro.
##qemu-system-x86_64 -hda img/gpt_with_pmbr.qcow2 -m 512 \
##	-name "arq64 uefi" $debug_flags  -smp "$cant_cores"


#qemu-system-x86_64 -device qxl-vga,help
#qemu-system-x86_64 -bios extern/OVMF.fd -s -S -name "arq64 uefi" -device qxl-vga,xres=1366,yres=768 -hda img/x64_arq.qcow2 -m 512
#-i386