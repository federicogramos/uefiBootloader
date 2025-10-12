;;==============================================================================
;; 16 bits lib for bios boot | @file /asm/lib/bios16.asm
;;==============================================================================

%include "./asm/include/sysvar.inc"

;; TO-DO: print_bios reponer el address correcto.
extern print_bios
print_bios: equ 0

global vesa
global failure


section .text_low

BITS 16


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


;;==============================================================================
;; failure | abort boot with error notification
;;==============================================================================
;; Argument:
;; -- si: string.
;;
;; TO-DO: codigo repetido. Ver si esto lo reemplazo por el failure definido en mbr.
;;==============================================================================

failure:
	call print_bios

.halt:
	mov si, msg_halt
	call print_bios
	hlt
	jmp $




msg_halt:		db "System halted", 0
x:				dd msg_halt