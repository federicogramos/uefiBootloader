;;==============================================================================
;; Lib for bios boot | @file /asm/lib/bios.asm
;;==============================================================================




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




	