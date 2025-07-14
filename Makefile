ASM = nasm
LD = ld
#BMFS_MBR = bmfs_mbr.sys
#PXESTART = pxestart.sys


UEFI_SRC = uefi.asm
UEFI_OBJ = $(UEFI_SRC:.asm=.o)
UEFI_SYS = $(UEFI_SRC:.asm=.sys)

BOOTLOADER = bootloader.sys

#all: bmfs_mbr.sys pxestart.sys bootloader.sys
all: uefi.sys bootloader.sys

#$(BMFS_MBR):
#	$(ASM) src/bootsectors/bmfs_mbr.asm -o $(BMFS_MBR)

#$(PXESTART):
#	$(ASM) src/bootsectors/pxestart.asm -o $(PXESTART)

$(UEFI_SYS): build
#	$(ASM) ./asm/boot/uefi.asm -o ./build/uefi.sys
	$(ASM) -f elf64 ./asm/boot/uefi.asm -o ./obj/uefi.o
#$(ASM) ./asm/boot/uefi.asm -o ./obj/uefi.o
	$(LD) -T uefi.ld -o ./build/$(UEFI_SYS) ./obj/uefi.o
	$(LD) --oformat=elf64-x86-64 -T uefi.ld -o ./obj/uefi.elf ./obj/uefi.o

#$(LD) $(LDFLAGS) -T kernel.ld -o $(KERNEL) $(LOADEROBJECT) $(OBJECTS) $(OBJECTS_ASM) $(OBJECTS_C) $(OBJECTS_DRIVERS) $(OBJECTS_INTERRUPTIONS) $(STATICLIBS)


#cd ./asm/boot; ld -g --oformat elf64-x86-64 --entry 0x400000 ./../../build/uefi.sys -o ./../../build/uefi.elf

$(BOOTLOADER): $(UEFI)
	$(ASM) ./asm/bootloader.asm -o ./build/$(BOOTLOADER)

#$(UEFI_OBJ):
#	$(ASM) $(UEFI_SRC) -o $(UEFI_OBJ)

build:
	mkdir build img out obj
		
clean:
	rm -rf build img out obj

.PHONY: all clean
