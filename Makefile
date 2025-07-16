ASM = nasm
LD = ld

UEFI_SRC = uefi.asm
UEFI_OBJ = $(UEFI_SRC:.asm=.o)
UEFI_SYS = $(UEFI_SRC:.asm=.sys)

BOOTLOADER = bootloader.sys

all: uefi.sys bootloader.sys


$(UEFI_SYS): build
	$(ASM) -g -F DWARF -f elf64 ./asm/lib/lib.asm -o ./obj/lib.o
	$(ASM) -g -F DWARF -f elf64 ./asm/lib/lib_efi.asm -o ./obj/lib_efi.o
	$(ASM) -g -F DWARF -f elf64 ./asm/boot/uefi.asm -o ./obj/uefi.o
#	$(LD) -T uefi.ld -o ./build/$(UEFI_SYS) ./obj/uefi.o
#	$(LD) --oformat=elf64-x86-64 -T uefi.ld -o ./obj/uefi.elf ./obj/uefi.o
	$(LD) -T uefi.ld -o ./build/$(UEFI_SYS) ./obj/uefi.o ./obj/lib.o ./obj/lib_efi.o
	$(LD) --oformat=elf64-x86-64 -T uefi.ld -o ./obj/uefi.elf ./obj/uefi.o ./obj/lib.o ./obj/lib_efi.o

$(BOOTLOADER): $(UEFI)
	$(ASM) ./asm/bootloader.asm -o ./build/$(BOOTLOADER)

build:
	mkdir build img out obj
		
clean:
	rm -rf build img out obj

.PHONY: all clean
