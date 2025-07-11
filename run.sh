#!/bin/bash


if [ "$1" = "-d" ]; then
#qemu-system-x86_64 -bios sys/OVMF.fd -s -S -hda img/x64_arq_os.qcow2 -m 512
qemu-system-x86_64 -bios sys/OVMF.fd -s -S -name "arq64 uefi" -device qxl-vga,xres=1366,yres=768 -hda image/x64_arq_os.qcow2 -m 512
else
#qemu-system-x86_64 -bios sys/OVMF.fd -device VGA,edid=on,xres=1024,yres=768 -hda img/x64_arq_os.qcow2 -m 512
qemu-system-x86_64 -bios sys/OVMF.fd -device qxl-vga,xres=1366,yres=768 -hda image/x64_arq_os.qcow2 -m 512

#qemu-system-x86_64 -device qxl-vga,help
fi
