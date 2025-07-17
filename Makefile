ASM = nasm
LD = ld

ifndef FORCE_STEP_MODE
FORCE_STEP_MODE = 0	# Step mode (prompteo durante boot) por defecto deshabilita\
					# do salvo que sea forzado en la invocacion del makefile.
endif

UEFI_SRC = uefi.asm
UEFI_OBJ = $(UEFI_SRC:.asm=.o)
UEFI_SYS = $(UEFI_SRC:.asm=.sys)

TSL_SYS = tsl.sys

all: uefi.sys tsl.sys


$(UEFI_SYS): build
	$(ASM) -g -F DWARF -f elf64 ./asm/lib/lib.asm -o ./obj/lib.o
	$(ASM) -g -F DWARF -f elf64 ./asm/lib/lib_efi.asm -o ./obj/lib_efi.o
	$(ASM) -D STEP_MODE_INIT_VAL=$(FORCE_STEP_MODE) -g -F DWARF -f elf64 ./asm/uefi.asm -o ./obj/uefi.o
#	$(LD) -T uefi.ld -o ./build/$(UEFI_SYS) ./obj/uefi.o
#	$(LD) --oformat=elf64-x86-64 -T uefi.ld -o ./obj/uefi.elf ./obj/uefi.o
	$(LD) -T uefi.ld -o ./build/$(UEFI_SYS) ./obj/uefi.o ./obj/lib.o ./obj/lib_efi.o
	$(LD) --oformat=elf64-x86-64 -T uefi.ld -o ./obj/uefi.elf ./obj/uefi.o ./obj/lib.o ./obj/lib_efi.o

$(TSL_SYS): $(UEFI_SYS)
	$(ASM) ./asm/tsl.asm -o ./build/$(TSL_SYS)


build:
	mkdir build img out obj
		
clean:
	rm -rf build img out obj

.PHONY: all clean
