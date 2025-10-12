;;==============================================================================
;; 16 bits lib for bios boot | @file /asm/lib/bios16.asm
;;==============================================================================

%include "./asm/include/sysvar.inc"

;; mbr.asm
extern failure

global a20_line
global e820
global vesa

section .text

BITS 16



;;==============================================================================
;; a20_line | config a20 line
;;==============================================================================

a20_line:
	call a20_check
	jnz .end

.a20_set:
	in al, 0x64		;; Status.
	test al, 0x02
	jnz .a20_set
	mov al, 0xd1	;; 8042 Write command.
	out 0x64, al

.check:
	in al, 0x64
	test al, 0x02
	jnz .check
	mov al, 0xdf
	out 0x60, al

.end:
	ret


;;==============================================================================
;; a20_check | check the status of a20 line
;;==============================================================================
;; Returns:
;; -- FLAGS[zero] = 1 (a20 disabled) | FLAGS[zero] = 0 (a20 enabled)
;;
;; Preserves all registers including segment registers.
;;==============================================================================

a20_check:
	pusha
	push ds
	push es

	xor ax, ax
	mov es, ax
	not ax					;; 0xFFFF
	mov ds, ax

	mov di, 0x0500
	mov si, 0x0510

	mov al, [es:di]
	push ax
	mov al, [ds:si]
	push ax

	mov byte [es:di], 0x00
	mov byte [ds:si], 0xFF	;; Will overwrite the prev move if a20 not set.
	cmp byte [es:di], 0xFF

	pop ax
	mov [ds:si], al
	pop ax
	mov [es:di], al

	pop es
	pop ds
	popa

	ret


;;==============================================================================
;;e820 | build memmap
;;==============================================================================
;; Arguments:
;; -- {es:di} = destination buffer for 24 byte entries.
;; Returns:
;; -- bp = entry count
;;
;; https://uefi.org/htmlspecs/ACPI_Spec_6_4_html/15_System_Address_Map_Interface
;; s/int-15h-e820h---query-system-address-map.html
;;
;; trashes all registers except esi
;; Creates memory map at 0x6000.
;; and the records are:
;; 64 bit Base
;; 64 bit Length
;; 32 bit Type (1 = normal, 2 reserved, ACPI reclaimable)
;; 32 bit ACPI
;; 64 bit Padding
;;==============================================================================

e820:
	xor bp, bp					;; Entry count.

	mov eax, 0xe820
	xor ebx, ebx				;; Continuation value to get the next range of p
								;; hysical memory.
	mov edi, 0x00006000			;; ;; Buffer Pointer. Destination memmap addr.
	mov ecx, 24					;; Buffer Size [bytes].
	mov edx, 0x0534D4150		;; Signature = "SMAP".
	mov dword [es:di + 20], 1	;; Compatibility with ACPI 3.X entry.
	int 0x15

	jc .nomemmap			;; Error condition if CF = 1. TO-DO: aqui no solo te
							;; rminar, sino que avisar que ha ocurrido error.
	mov edx, 0x0534D4150	;; Need to reset. According wiki.osdev.org: some BIO
							;; Ses apparently trash this register.
	cmp eax, edx			;; eax != "SMAP" notifies incorrect bios revision. T
							;; O-DO> notify this error.
	jne .nomemmap
	test ebx, ebx			;; Continuation value to get the next address range 
							;; descriptor. A value of ebx = 0 means that this is
							;; the last descriptor. Note: the BIOS can also indi
							;; cate that the last descriptor has already been re
							;; turned during previous iterations by returning th
							;; e carry flag set. TO-DO: aunque sea cero debe ser
							;; procesado.
	je .nomemmap
	jmp .jmpin

.loop:
	mov eax, 0xe820
	mov [es:di + 20], dword 1	;; In order to make a valid ACPI 3.X entry.
	mov ecx, 24			; ask for 24 bytes again
	int 0x15
	jc .memmapend			; carry set means "end of list already reached"
	mov edx, 0x0534D4150		; repair potentially trashed register

.jmpin:
	jcxz .skipent			; skip any 0 length entries
	cmp cl, 20			;; Buffer Size. The minimum structure size returned by the BIOS is 20 bytes. It should really be 24 byte ACPI 3.X response.
	jbe .notext
	test byte [es:di + 20], 1	; if so: is the "ignore this data" bit clear?
	je .skipent

.notext:
	mov ecx, [es:di + 8]		; get lower dword of memory region length
	test ecx, ecx			; is the qword == 0?
	jne .goodent
	mov ecx, [es:di + 12]		; get upper dword of memory region length
	jecxz .skipent			; if length qword is 0, skip entry

.goodent:
	inc bp				;; count++
	add di, 32			;; Each record aligns to 32 bytes.

.skipent:
	test ebx, ebx			; if ebx resets to 0, list is complete
	jne .loop

.nomemmap:
.memmapend:
	xor eax, eax		;; Blank record marks end of memmap.
	mov ecx, 8
	rep stosd

	ret


;;==============================================================================
;; vesa | 
;;==============================================================================
;; No me gusta esta fun definida aqui y llamada en start. Luego veo que hacer.
;; Esto es transitorio por cuestiones de espacio.
;;==============================================================================

vesa:
	mov cx, 0x4000 - 1		; Start looking from here

.vbe_search:
	inc cx
	mov bx, cx			; Mode is saved to BX for the set command later
	cmp cx, 0x5000

	;;TO-DO: falta load mensaje error.
	je failure

	mov edi, VBEModeInfoBlock	; VBE data will be stored at this address
	mov ax, 0x4F01			; VESA SuperVGA BIOS - GET SuperVGA MODE INFORMATION - http://www.ctyme.com/intr/rb-0274.htm
	int 0x10
	cmp ax, 0x004F			; Return value in AX should equal 0x004F if command supported and successful
	jne .vbe_search			; Try next mode
	cmp byte [VBEModeInfoBlock.BitsPerPixel], 32 ; Desired bit depth
	jne .vbe_search			; If not equal, try next mode
	cmp word [VBEModeInfoBlock.XResolution], Horizontal_Resolution ; Desired XRes here
	jne .vbe_search
	cmp word [VBEModeInfoBlock.YResolution], Vertical_Resolution ; Desired YRes here
	jne .vbe_search
	or bx, 0x4000			; Use linear/flat frame buffer model (set bit 14)
	mov ax, 0x4F02			; VESA SuperVGA BIOS - SET SuperVGA VIDEO MODE - http://www.ctyme.com/intr/rb-0275.htm
	int 0x10
	cmp ax, 0x004F			; Return value in AX should equal 0x004F if supported and successful

	;;TO-DO: falta load mensaje error.
	jne failure

	ret


;; section .data

