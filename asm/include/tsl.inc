;;==============================================================================
;; Definitions for Transient System Load | @file /include/tsl.inc
;;=============================================================================

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