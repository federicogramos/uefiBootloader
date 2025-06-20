ASM = nasm
#BMFS_MBR = bmfs_mbr.sys
#PXESTART = pxestart.sys
PURE64 = pure64.sys
UEFI = uefi.sys

#all: bmfs_mbr.sys pxestart.sys pure64.sys
all: pure64.sys uefi.sys

#$(BMFS_MBR):
#	$(ASM) src/bootsectors/bmfs_mbr.asm -o $(BMFS_MBR)

#$(PXESTART):
#	$(ASM) src/bootsectors/pxestart.asm -o $(PXESTART)

$(PURE64):
	cd asm;	$(ASM) pure64.asm -o ./../build/$(PURE64)

$(UEFI):
	cd ./asm/boot; nasm uefi.asm -o ./../../build/uefi.sys

clean:
	rm -rf *.sys

.PHONY: all clean
