ASM = nasm
#BMFS_MBR = bmfs_mbr.sys
#PXESTART = pxestart.sys
UEFI = uefi.sys
BOOTLOADER = bootloader.sys

#all: bmfs_mbr.sys pxestart.sys bootloader.sys
all: uefi.sys bootloader.sys

#$(BMFS_MBR):
#	$(ASM) src/bootsectors/bmfs_mbr.asm -o $(BMFS_MBR)

#$(PXESTART):
#	$(ASM) src/bootsectors/pxestart.asm -o $(PXESTART)

$(UEFI): build
	cd ./asm/boot; nasm uefi.asm -o ./../../build/uefi.sys
	cd ./asm/boot; ld -g --oformat elf64-x86-64 --entry 0x400000 ./../../build/uefi.sys -o ./../../build/uefi.elf

$(BOOTLOADER): $(UEFI)
	cd asm;	$(ASM) bootloader.asm -o ./../build/$(BOOTLOADER)

build:
	mkdir build image out
		
clean:
	rm -rf build image out

.PHONY: all clean
