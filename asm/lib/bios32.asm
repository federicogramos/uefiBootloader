;;==============================================================================
;; 32 bits lib for bios boot | @file /asm/lib/bios32.asm
;;==============================================================================

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;%include "./asm/include/sysvar.inc"

global vesa2uefi

extern failure


section .text_low

BITS 32


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

