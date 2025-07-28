;;==============================================================================
;; Definitions for Transient System Load | @file /include/tsl.inc
;;=============================================================================

;; TODO: esto sacarlo o definirlo en tsl.ld
TSL_SIZE equ 0x3000	;; 12KiB


;; EFI_MEMORY_TYPE
EfiReservedMemoryType		equ 0
EfiLoaderCode				equ 1
EfiLoaderData				equ 2
EfiBootServicesCode			equ 3
EfiBootServicesData			equ 4
EfiRuntimeServicesCode		equ 5
EfiRuntimeServicesData		equ 6
EfiConventionalMemory		equ 7
EfiUnusableMemory			equ 8
EfiACPIReclaimMemory		equ 9
EfiACPIMemoryNVS			equ 10
EfiMemoryMappedIO			equ 11
EfiMemoryMappedIOPortSpace	equ 12
EfiPalCode					equ 13
EfiMaxMemoryType			equ 14


BASE_IDT	equ 0x00000000
BASE_GDT	equ 0x00001000
BASE_PML4	equ 0x00002000
BASE_PDPT_L	equ 0x00003000
BASE_PDPT_H	equ 0x00004000
BASE_PD_FB	equ 0x0000F000
BASE_PD_L	equ 0x00010000	;; Solo si pag 2MiB.
BASE_PD_H	equ 0x00030000	;; Solo si pag 2MiB.

PHYSICAL_ADDR_MAX_INITIALIZED equ 0x7FFFFFFFF	;; Por defecto se inicializan 32
												;; GiB cuando page size = 2MiB.
