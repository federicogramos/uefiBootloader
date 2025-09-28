;;==============================================================================
;; master boot record | @file /asm/boot/mbr.asm
;;==============================================================================
;; Referencias:
;; -- BIOS Enhanced Disk Drive Specification 3.0: http://www.o3one.org/hwdocs/bi
;; os_doc/bios_specs_edd30.pdf
;; -- https://github.com/fysnet/FYSOS/blob/master/boot/embr/embr.asm
;; http://www.ctyme.com/intr/rb-0708.htm
;; -- https://stanislavs.org/helppc/int_10.html

;; En 16 bits cuando el procesador no es de 16 si no de 32 o 64 pero ejecuta en 
;; un modo de 16 bits, prestar atencion a algunas instrucciones: jumps por ejemp
;; lo. El mismo opcode lo interpreta en 32 de una manera y en 16 de otra, saltan
;; do en cada uno de esos casos a direcciones cercanas pero distintas porque en 
;; 32 toma operando de 32 y en 16 de 16 (8?) lo cual genera un offset en la dire
;; ccion de destino. Pero un push de 32 es reconocido en 16 bits y ejecutado cor
;; rectamente a pesar de estar en modo de 16.
;;==============================================================================


BITS 16

entry:
	cli
	cld
	xor ax, ax
	mov ss, ax
	mov es, ax
	mov ds, ax
	mov sp, 0x7c00
	sti

	mov [driveNumber], dl	;; Bios passes drive number in dl.

	call pushTest
	call extensionTest

	mov si, msg_load
	call print

	mov ax, 512		;; Cant sectors. Load 512 = 262144 bytes = 256 KiB.
	mov bx, 6117	;; Offset = 8192.
	mov cx, 0x8000	;; Copy here.
	call diskcpy	;; Copia payload completo.

	mov si, msg_ok
	call print

;; TO-DO reponer
	;;mov eax, [0x8000 + 6]
	;;cmp eax, "BOOT"		; Match against the tsl_start.sys binary
	;;jne magic_fail

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; esta copia a 60000 no la quiero.

	;;mov ax, 0x0800		; Segment where the bootloader and payload are loaded
	;;mov cx, 0x6000		; Segment where the bootloader and payload will be copied

;;copy_payload_to_free_mem:	; Move bootloader and payload to 0x60000
;;	mov fs, ax				; From segment
;;	mov es, cx				; To segment
;;	mov bx, 0x0				; Offset

;;copy_single_segment:
;;	mov dl, [fs:bx]
;;	mov [es:bx], dl
;;	inc bx
;;	jnz copy_single_segment

;;	add ax, 0x1000
;;	add cx, 0x1000
;;	cmp cx, 0xA000		; Last address (bootloader + payload = 256KiB total)
;;	jnz copy_payload_to_free_mem

	mov eax, 0
	mov ebx, 0
	mov ecx, 0
	mov edx, 0
	mov fs, ax
	mov es, ax

	jmp 0x0000:0x8000


;;==============================================================================
;; errors
;;==============================================================================

notify_ext_not_supported:
	mov si, msg_no
	call print

.halt:
	mov si, msg_halt
	call print
	hlt
	jmp $


;;==============================================================================
;; diskcpy | Copy n sectors from disk.
;;==============================================================================
;; Arguments:
;; -- ax: cant of 512 mem sectors to copy.
;; -- bx: source offset in disk (addr/512).
;; -- cx: destination addr.
;;==============================================================================

diskcpy:
	call readSec	;; Each loop 512 bytes.
	dec ax
	cmp ax, 0
	jnz diskcpy
	ret


;;==============================================================================
;; readSec | Read a sector from a disk using extended read.
;;==============================================================================
;; Arguments:
;; -- eax: high word of 64 bit sector.
;; -- ebx: low word of 64 bit sector.
;; -- {es:cx}: destination address, {seg:offset}
;; Returns:
;; -- eax: high word of next sector.
;; -- ebx: low word of sector.
;; -- {es:cx}: p2source + cantBytes2copy
;;==============================================================================

readSec:
	push eax
	push dx
	push si
	push di

	xor eax, eax	;; We don't need to load from sectors > 32-bit

.read:
	push eax		;; Backup sectorNumber.hi
	push ebx		;; Backup sectorNumber.lo
	mov di, sp		;; Base of disk address packet.

	;; Build disk address packet.
	push eax		;; dap10..15 dap.srcLba.hi
	push ebx		;; dap06..09 dap.srcLba.lo
	push es			;; dap04..05 dap.dst.seg
	push cx			;; dap02..03 dap.dst.offset
	push byte 1		;; dap01 dap.bkCant
	push byte 16	;; dap00 dap.pkSiz

	mov si, sp
	mov dl, [driveNumber]
	mov ah, 42h			; EXTENDED READ
	int 0x13			; http://hdebruijn.soo.dto.tudelft.nl/newpage/interupt/out-0700.htm#0651

	mov sp, di			; remove parameter block from stack
	pop ebx
	pop eax				; Restore the sector number

	jnc read_ok			; jump if no error

	push ax
	xor ah, ah			; else, reset and retry
	int 0x13
	pop ax
	jmp .read

read_ok:
	add ebx, 1			; increment next sector with carry
	adc eax, 0
	add cx, 512			; Add bytes per sector
	jnc no_incr_es			; if overflow...

incr_es:
	mov dx, es
	add dh, 0x10			; ...add 1000h to ES
	mov es, dx

no_incr_es:
	pop di
	pop si
	pop dx
	pop eax

	ret


;;==============================================================================
;; pushTest | Verifica compatibilidad de opcode push eax en modo 16 bits
;;==============================================================================
;; Registers CS, DS, ES, SS, BX, CX, DX are preserved unless
;; explicitly changed
;;==============================================================================

pushTest:
	mov bx, sp
	push eax
	sub bx, sp
	pop eax
	add [msg_sizeofPush + POSITION_COUNT], bl

	mov si, msg_sizeofPush
	call print

	ret


;;==============================================================================
;; extensionTest | Verifica soporte de extension bios.
;;==============================================================================
;; Registers CS, DS, ES, SS, BX, CX, DX are preserved unless
;; explicitly changed
;;==============================================================================

extensionTest:
	mov si, msg_extSupport
	call print

	mov ah, 0x41			;; Check extensions present.
	mov bx, 55AAh			;; Required signature.
	mov dl, [driveNumber]
	int 0x13
	jc  notify_ext_not_supported
	cmp bx, 0xAA55
	jne notify_ext_not_supported

	mov si, msg_ok
	call print

	ret


;;==============================================================================
;; print | Imprime a pantalla usando bootservice.
;;==============================================================================
;; Argumentos:
;; -- si: string addr 16 bits.
;;==============================================================================

print:
	pusha
	mov ah, 0x0e		;; int 0x10: write text in teletype mode.

.next:
	lodsb
	cmp al, 0
	je .fin
	int 0x10			;; Write boot service.
	jmp .next

.fin:
	popa
	ret


;;==============================================================================
;; section .data
;;==============================================================================

msg_sizeofPush:	db "16b mode 32b push opcode pushes "
POSITION_COUNT	equ $ - msg_sizeofPush
				db "0 bytes", 13, 10, 0
msg_extSupport:	db "Verifying bios ext support..", 0
msg_no:			db " no", 13, 10, 0
msg_load:		db "Reading disk..", 0
msg_ok:			db " ok", 13, 10, 0
msg_halt:		db "Sys halted", 0

driveNumber:	db 0x00

;; Zero fill.
times 446 - $ + $$	db 0

;; False partition table entry required by some BIOS vendors.
					db 0x80, 0x00, 0x01, 0x00, 0xEB, 0xFF, 0xFF, 0xFF
					db 0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF

times 510 - $ + $$	db 0

sign:				dw 0xAA55
