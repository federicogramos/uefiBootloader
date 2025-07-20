;;==============================================================================
;; Definitions for Transient System Load | @file /include/tsl.inc
;;=============================================================================


;; Memory Attribute Definitions. These can be 'ORed' together as needed.
EFI_MEM_UC		equ 0x0000000000000001
EFI_MEM_WC		equ 0x0000000000000002
EFI_MEM_WT		equ 0x0000000000000004
EFI_MEM_WB		equ 0x0000000000000008
EFI_MEM_UCE		equ 0x0000000000000010
EFI_MEM_WP		equ 0x0000000000001000
EFI_MEM_RP		equ 0x0000000000002000
EFI_MEM_XP		equ 0x0000000000004000
EFI_MEM_RUNTIME	equ 0x8000000000000000