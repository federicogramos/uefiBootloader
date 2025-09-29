;;==============================================================================
;; System Variables | @file /include/sysvar.inc
;;==============================================================================


;; Memory locations
;; Info de video en 2 lugares para consultar: InfoMap y VBEModeInfoBlock.
;; Info de video desde 0x5080
;; 0x5080 = qword, framebuffer
;; 0x5088 = word, screen x
;; 0x508A = word, screen y
;; 0x508C = word, ppsl
;; 0x508E = word, bits per pixel

InfoMap:			equ 0x0000000000005000
IM_DetectedCoreIDs:	equ 0x0000000000005100	;; Byte array. APIC ID of each core.
IM_PCIE:			equ 0x0000000000005400	;; 16 bytes per entry
IM_IOAPICAddress:	equ 0x0000000000005600	;; 16 bytes per entry
IM_IOAPICIntSource:	equ 0x0000000000005700	;; 8 bytes per entry
SystemVariables:	equ 0x0000000000005800
IM_ActivedCoreIDs:	equ 0x0000000000005E00	;; 1by per entry. 1 = 1 core active.


;; Cuando bootea uefi, la info de video durante uefi la mete aqui:
;; [0x00005F00]	;; Frame buffer base
;; [0x00005F08]	;; Frame buffer size (bytes)
;; [0x00005F10]	;; Screen X
;; [0x00005F12]	;; Screen Y
;; [0x00005F14]	;; PixelsPerScanLine
;; Luego, durante el bootloader, la mantiene aqui, pero tambien copia al infoMap
;; 0x5080

VBEModeInfoBlock:



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; transient










; Set the desired screen resolution values below
;;;;;; esto en br1100 no cambia nada
;;;;;; en qemu hace que se vea ok, o que no pueda inicializar pantalla (1366 por ej)
Horizontal_Resolution		equ 1024
Vertical_Resolution		equ 768

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;VBEModeInfoBlock: equ 0x5F00
; VESA
; Mandatory information for all VBE revisions
VBEModeInfoBlock.ModeAttributes		equ VBEModeInfoBlock + 0	; DW - mode attributes
VBEModeInfoBlock.WinAAttributes		equ VBEModeInfoBlock + 2	; DB - window A attributes
VBEModeInfoBlock.WinBAttributes		equ VBEModeInfoBlock + 3	; DB - window B attributes
VBEModeInfoBlock.WinGranularity		equ VBEModeInfoBlock + 4	; DW - window granularity in KB
VBEModeInfoBlock.WinSize		equ VBEModeInfoBlock + 6	; DW - window size in KB
VBEModeInfoBlock.WinASegment		equ VBEModeInfoBlock + 8	; DW - window A start segment
VBEModeInfoBlock.WinBSegment		equ VBEModeInfoBlock + 10	; DW - window B start segment
VBEModeInfoBlock.WinFuncPtr		equ VBEModeInfoBlock + 12	; DD - real mode pointer to window function
VBEModeInfoBlock.BytesPerScanLine	equ VBEModeInfoBlock + 16	; DW - bytes per scan line
; Mandatory information for VBE 1.2 and above
VBEModeInfoBlock.XResolution		equ VBEModeInfoBlock + 18	; DW - horizontal resolution in pixels or characters
VBEModeInfoBlock.YResolution		equ VBEModeInfoBlock + 20	; DW - vertical resolution in pixels or characters
VBEModeInfoBlock.XCharSize		equ VBEModeInfoBlock + 22	; DB - character cell width in pixels
VBEModeInfoBlock.YCharSize		equ VBEModeInfoBlock + 23	; DB - character cell height in pixels
VBEModeInfoBlock.NumberOfPlanes		equ VBEModeInfoBlock + 24	; DB - number of memory planes
VBEModeInfoBlock.BitsPerPixel		equ VBEModeInfoBlock + 25	; DB - bits per pixel
VBEModeInfoBlock.NumberOfBanks		equ VBEModeInfoBlock + 26	; DB - number of banks
VBEModeInfoBlock.MemoryModel		equ VBEModeInfoBlock + 27	; DB - memory model type
VBEModeInfoBlock.BankSize		equ VBEModeInfoBlock + 28	; DB - bank size in KB
VBEModeInfoBlock.NumberOfImagePages	equ VBEModeInfoBlock + 29	; DB - number of image pages
VBEModeInfoBlock.Reserved		equ VBEModeInfoBlock + 30	; DB - reserved (0x00 for VBE 1.0-2.0, 0x01 for VBE 3.0)
; Direct Color fields (required for direct/6 and YUV/7 memory models)
VBEModeInfoBlock.RedMaskSize		equ VBEModeInfoBlock + 31	; DB - size of direct color red mask in bits
VBEModeInfoBlock.RedFieldPosition	equ VBEModeInfoBlock + 32	; DB - bit position of lsb of red mask
VBEModeInfoBlock.GreenMaskSize		equ VBEModeInfoBlock + 33	; DB - size of direct color green mask in bits
VBEModeInfoBlock.GreenFieldPosition	equ VBEModeInfoBlock + 34	; DB - bit position of lsb of green mask
VBEModeInfoBlock.BlueMaskSize		equ VBEModeInfoBlock + 35	; DB - size of direct color blue mask in bits
VBEModeInfoBlock.BlueFieldPosition	equ VBEModeInfoBlock + 36	; DB - bit position of lsb of blue mask
VBEModeInfoBlock.RsvdMaskSize		equ VBEModeInfoBlock + 37	; DB - size of direct color reserved mask in bits
VBEModeInfoBlock.RsvdFieldPosition	equ VBEModeInfoBlock + 38	; DB - bit position of lsb of reserved mask
VBEModeInfoBlock.DirectColorModeInfo	equ VBEModeInfoBlock + 39	; DB - direct color mode attributes
; Mandatory information for VBE 2.0 and above
VBEModeInfoBlock.PhysBasePtr		equ VBEModeInfoBlock + 40	; DD - physical address for flat memory frame buffer
VBEModeInfoBlock.Reserved1		equ VBEModeInfoBlock + 44	; DD - Reserved - always set to 0
VBEModeInfoBlock.Reserved2		equ VBEModeInfoBlock + 48	; DD - Reserved - always set to 0



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



FB:			equ 0x0000000000005F00	;; 8 bytes, 256 bytes.
FB_SIZE		equ 0x0000000000005F08	;; 8 bytes, Frame buffer size (bytes)
HR:			equ 0x0000000000005F10	;; 2 bytes, Screen X
VR:			equ 0x0000000000005F12	;; 2 bytes, Screen Y
PPSL:		equ 0x0000000000005F14	;; 2 bytes, PixelsPerScanLine




;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;






;; DQ - Starting at offset 0, increments by 0x8
p_ACPITableAddress:	equ SystemVariables + 0x00	;; *RSDT Table
p_LocalAPICAddress:	equ SystemVariables + 0x10
p_Counter_Timer:	equ SystemVariables + 0x18
p_Counter_RTC:		equ SystemVariables + 0x20
p_HPET_Address:		equ SystemVariables + 0x28

;; DD - Starting at offset 0x80, increments by 4
p_BSP:				equ SystemVariables + 0x80
p_mem_amount:		equ SystemVariables + 0x84	;; MiB
p_HPET_Frequency:	equ SystemVariables + 0x88

;; DW - Starting at offset 0x100, increments by 2
p_cpu_speed:		equ SystemVariables + 0x100
p_cpu_activated:	equ SystemVariables + 0x102
p_cpu_detected:		equ SystemVariables + 0x104
p_PCIECount:		equ SystemVariables + 0x106
p_HPET_CounterMin:	equ SystemVariables + 0x108
p_IAPC_BOOT_ARCH:	equ SystemVariables + 0x10A

; DB - Starting at offset 0x180, increments by 1
p_IOAPICCount:		equ SystemVariables + 0x180
p_BootMode:			equ SystemVariables + 0x181	;; 'U' for UEFI, otherwise BIOS
p_IOAPICIntSourceC:	equ SystemVariables + 0x182
p_x2APIC:			equ SystemVariables + 0x183
p_HPET_Timers:		equ SystemVariables + 0x184
p_BootDisk:			equ SystemVariables + 0x185	;; 'F' for Floppy drive
p_1gb_pages:		equ SystemVariables + 0x186	;; 1 if 1GB pages are supported

