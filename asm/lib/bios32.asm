;;==============================================================================
;; 32 bits lib for bios boot | @file /asm/lib/bios32.asm
;;==============================================================================

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;%include "./asm/include/sysvar.inc"

global load_tsl_hi
global vesa2uefi

;; mbr.asm
extern failure
extern print_bios
extern msg_ok
extern diskcpy
extern config_paging

section .text

BITS 32


;;==============================================================================
;; load_tsl_hi | carga porcion del payload en la direccion code_hi_start_reloc
;;==============================================================================
;; Video info pasado de bios. Difiere de uefi, por lo que se formatea para dejar
;; las igual.
;;==============================================================================

load_tsl_hi:
	mov si, msg_read_tsl_hi
	call print_bios

	mov ax, (512 + 1)	;; Cant sectors. Load 512 = 262144 bytes = 256 KiB + 1 (
						;; start16.asm). TO-DO: en realidad solo 240 que es el t
						;; amano completo de la payload. Ya incluye a start16. R
						;; evisar tamanos.
	mov bx, 6117		;; Offset = 8192.
	mov cx, 0x7E00		;; Destination.
	call diskcpy		;; Copia payload completo. En este momento no tengo acce
						;; so a 0x800000 donde luego de activar modo progegido, 
						;; copiare tsl.

	mov si, msg_ok
	call print_bios

	ret



;;==============================================================================
;; vesa2uefi | pasa info de vesa a tabla para compatibilidad con uefi
;;==============================================================================
;; Video info pasado de bios. Difiere de uefi, por lo que se formatea para dejar
;; las igual.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;==============================================================================

vesa2uefi:

	; Save the frame buffer address, size (after its calculated), and the screen x,y
	xor eax, eax
	xor ebx, ebx

	mov ax, [0x5F00 + 16]		; BytesPerScanLine (modo vesa)
	push eax
	
	mov bx, [0x5F00 + 16 + 2 * 2]		; YResolution  (vesa)
	push ebx

	mov ax, [0x5F00 + 16 + 2]		; XResolution (vesa)
	push eax
	
	mul ebx
	mov ecx, eax
	shl ecx, 2			; Quick multiply by 4


;; aqui en bios, deja las cosas en el mismo orden que uefi
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;[0x00005F00]		; Frame buffer base
;;;[0x00005F08]		; Frame buffer size (bytes)
;;;[0x00005F10]	; Screen X
;;;;[0x00005F12]	; Screen Y
;;;;[0x00005F14]	; PixelsPerScanLine 
;;;;; recontramega importante (para bios, no uefi), aqui va a colocar 

	mov edi, 0x5F00
	mov eax, [0x5F00 + 40];;;; ya que para bios, el vbeinfoblock tiene esta estructura (framebuffer en +40)
	stosd				; 64-bit Frame Buffer Base (low)
	;;;;;;;; y pasandolo aqui 0x5f00 esta unificando un vbeInfoblock con estructura nueva tanto
	;;;;;;;; para efi como para bios
	
	xor eax, eax
	stosd				; 64-bit Frame Buffer Base (high) completa qword
	
	mov eax, ecx
	stosd				; 64-bit Frame Buffer Size in bytes (low)
	xor eax, eax
	stosd				; 64-bit Frame Buffer Size in bytes (high)
	
	pop eax
	stosw				; 16-bit Screen X

	pop eax
	stosw				; 16-bit Screen Y

	pop eax
	shr eax, 2			; 4 bytes / px => bpsl/4
	stosw				; PixelsPerScanLine
	mov eax, 32
	stosw				; BitsPerPixel

	; Clear memory for the Page Descriptor Entries (0x10000 - 0x5FFFF)
	mov edi, 0x00210000
	mov ecx, 81920
	rep stosd			; Write 320KiB

	ret







;;==============================================================================
;; config_paging | build paging tables
;;==============================================================================
;;
;;==============================================================================

config_paging:


	; Clear memory for the Page Descriptor Entries (0x10000 - 0x5FFFF)
	mov edi, 0x00210000
	mov ecx, 81920
	rep stosd			; Write 320KiB

; Create the temporary Page Map Level 4 Entries (PML4E)
; PML4 is stored at 0x0000000000202000, create the first entry there
; A single PML4 entry can map 512GiB with 2MiB pages
; A single PML4 entry is 8 bytes in length
	cld
	mov edi, 0x00202000		; Create a PML4 entry for the first 4GiB of RAM
	mov eax, 0x00203007		; Bits 0 (P), 1 (R/W), 2 (U/S), location of low PDP (4KiB aligned)
	stosd
	xor eax, eax
	stosd

; Create the temporary Page-Directory-Pointer-Table Entries (PDPTE)
; PDPTE is stored at 0x0000000000203000, create the first entry there
; A single PDPTE can map 1GiB with 2MiB pages
; A single PDPTE is 8 bytes in length
; 4 entries are created to map the first 4GiB of RAM
	mov ecx, 4			; number of PDPE's to make.. each PDPE maps 1GiB of physical memory
	mov edi, 0x00203000		; location of low PDPE
	mov eax, 0x00210007		; Bits 0 (P), 1 (R/W), 2 (U/S), location of first low PD (4KiB aligned)
pdpte_low_32:
	stosd
	push eax
	xor eax, eax
	stosd
	pop eax
	add eax, 0x00001000		; 4KiB later (512 records x 8 bytes)
	dec ecx
	cmp ecx, 0
	jne pdpte_low_32

; Create the temporary low Page-Directory Entries (PDE).
; A single PDE can map 2MiB of RAM
; A single PDE is 8 bytes in length
	mov edi, 0x00210000		; Location of first PDE
	mov eax, 0x0000008F		; Bits 0 (P), 1 (R/W), 2 (U/S), 3 (PWT), and 7 (PS) set
	xor ecx, ecx
pde_low_32:				; Create a 2 MiB page
	stosd
	push eax
	xor eax, eax
	stosd
	pop eax
	add eax, 0x00200000		; Increment by 2MiB
	inc ecx
	cmp ecx, 2048
	jne pde_low_32			; Create 2048 2 MiB page maps.


	ret

;;;;;;;;;;;;;;;;;;;;;;;;hasta aqui oka 7f7e








;; section .data

msg_read_tsl_hi:	db "Reading tsl hi..", 0
