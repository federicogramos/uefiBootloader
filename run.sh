#!/bin/bash

while getopts "d c:" opt; do
	case "$opt" in
	d)
		debug_flags="-s -S"
		;;
	c)
		cant_cores="$OPTARG"
		;;
	*)
		echo "Use: $0 [-d] [-c cant_cores]"
		exit 1
		;;
	esac
done

qemu-system-x86_64 -bios extern/OVMF.fd -hda img/x64_arq.qcow2 -m 512 \
	-name "arq64 uefi" $debug_flags  -smp "$cant_cores"

#qemu-system-x86_64 -device qxl-vga,help
#qemu-system-x86_64 -bios extern/OVMF.fd -s -S -name "arq64 uefi" -device qxl-vga,xres=1366,yres=768 -hda img/x64_arq.qcow2 -m 512
