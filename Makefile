ASM = nasm
LD = ld

ifndef FORCE_STEP_MODE
FORCE_STEP_MODE = 0 # Step mode (prompteo durante boot) por defecto deshabilita\
                    # do salvo que sea forzado en la invocacion del makefile.
endif

BUILD_DIR = ./build
IMG_DIR = ./img
OUT_DIR = ./out
OBJ_DIR = ./obj
ASM_DIR = ./asm
LIB_DIR = ./asm/lib
ELF_DIR = ./elf

UEFI_SRC = uefi.asm
UEFI_OBJ = $(OBJ_DIR)/$(UEFI_SRC:.asm=.o)
UEFI_ELF = $(ELF_DIR)/$(UEFI_SRC:.asm=.elf)
UEFI_SYS = $(BUILD_DIR)/$(UEFI_SRC:.asm=.sys)

TSL_SRCS_LO = tsl_start.asm tsl_ap.asm
TSL_SRCS_HI = tsl.asm
TSL_OBJS_LO = $(patsubst %.asm,$(OBJ_DIR)/%.o,$(TSL_SRCS_LO))
TSL_OBJS_HI = $(patsubst %.asm,$(OBJ_DIR)/%.o,$(TSL_SRCS_HI))
TSL_ELF_LO = $(ELF_DIR)/tsl_lo.elf
TSL_ELF_HI = $(ELF_DIR)/tsl_hi.elf
TSL_SYS = $(BUILD_DIR)/tsl.sys


all: $(UEFI_SYS) $(TSL_SYS)

$(OBJ_DIR)/%.o: $(ASM_DIR)/%.asm
	$(ASM) -g -F DWARF -f elf64 $< -o $@

$(OBJ_DIR)/%.o: $(LIB_DIR)/%.asm
	$(ASM) -g -F DWARF -f elf64 $< -o $@

$(UEFI_SYS): build ./obj/lib.o ./obj/efi.o
	$(ASM) -D STEP_MODE_INIT_VAL=$(FORCE_STEP_MODE) -g -F DWARF -f elf64 -o $(UEFI_OBJ) $(ASM_DIR)/uefi.asm
	$(LD) -T uefi.ld -o $@ $(UEFI_OBJ) $(OBJ_DIR)/lib.o $(OBJ_DIR)/efi.o
	$(LD) --oformat=elf64-x86-64 -T uefi.ld -o $(UEFI_ELF) $(UEFI_OBJ) $(OBJ_DIR)/lib.o $(OBJ_DIR)/efi.o

$(TSL_SYS): build $(TSL_OBJS_LO) $(TSL_OBJS_HI)
	$(LD) -T tsl.ld -o $@ $(TSL_OBJS_LO) $(TSL_OBJS_HI) $(OBJ_DIR)/lib.o
	$(LD) --oformat=elf64-x86-64 -T tsl.ld -o $(TSL_ELF_LO) $(TSL_OBJS_LO) $(TSL_OBJS_HI) $(OBJ_DIR)/lib.o
	$(LD) --oformat=elf64-x86-64 -T tsl_hi.ld -o $(TSL_ELF_HI) $(TSL_OBJS_HI) $(OBJ_DIR)/lib.o

build:
	mkdir -p $(BUILD_DIR) $(IMG_DIR) $(OUT_DIR) $(OBJ_DIR) $(ELF_DIR) 

clean:
	rm -rf $(BUILD_DIR) $(IMG_DIR) $(OUT_DIR) $(OBJ_DIR) $(ELF_DIR)

.PHONY: all clean build
