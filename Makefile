ASM = nasm
#BMFS_MBR = bmfs_mbr.sys
#PXESTART = pxestart.sys
BOOTLOADER = bootloader.sys
UEFI = uefi.sys

#all: bmfs_mbr.sys pxestart.sys bootloader.sys
all: bootloader.sys uefi.sys

#$(BMFS_MBR):
#	$(ASM) src/bootsectors/bmfs_mbr.asm -o $(BMFS_MBR)

#$(PXESTART):
#	$(ASM) src/bootsectors/pxestart.asm -o $(PXESTART)

$(BOOTLOADER):
	cd asm;	$(ASM) bootloader.asm -o ./../build/$(BOOTLOADER)

$(UEFI):
	cd ./asm/boot; nasm uefi.asm -o ./../../build/uefi.sys

clean:
	rm -rf *.sys

.PHONY: all clean
