;;==============================================================================
;; master boot record | @file /asm/boot/mbr.asm
;;==============================================================================
;; Referencias:
;; -- BIOS Enhanced Disk Drive Specification 3.0: http://www.o3one.org/hwdocs/bi
;; os_doc/bios_specs_edd30.pdf
;; -- https://github.com/fysnet/FYSOS/blob/master/boot/embr/embr.asm
;; http://www.ctyme.com/intr/rb-0708.htm
;; -- https://stanislavs.org/helppc/int_10.html
;;
;; This mbr is for 32 and 64 bit machines. Will not work fine on 16 bit 8086 or 
;; 80286 because it uses prefix override for some instructions.
;;==============================================================================


%include "./asm/include/mbr.inc"


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

	mov [drvNum], dl	;; Bios passes drive number in dl.

	call extensionTest

	mov si, msg_load
	call print

	mov ax, 512			;; Cant sectors. Load 512 = 262144 bytes = 256 KiB.
	mov bx, 6117		;; Offset = 8192.
	mov cx, 0x8000		;; Copy here.
	call diskcpy		;; Copia payload completo.

	mov si, msg_ok
	call print

;; TO-DO reponer
	;;mov eax, [0x8000 + SIGNATURE_OFFSET]
	;;cmp eax, "BOOT"	;; Simple payload verification (tsl_start.sys binary).
	;;jne magic_fail

	mov eax, 0
	mov ebx, 0
	mov ecx, 0
	mov edx, 0
	mov fs, ax
	mov es, ax

	jmp 0x0000:0x8000


;;==============================================================================
;; failure | abort boot with error notification
;;==============================================================================
;; Argument:
;; -- si: string.
;;==============================================================================

failure:
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
	call cpySec	;; Each loop 512 byte copy.
	dec ax
	cmp ax, 0
	jnz diskcpy
	ret


;;==============================================================================
;; cpySec | Read a sector from a disk using extended read (2TB max disk size)
;;==============================================================================
;; Arguments:
;; -- ebx: low word of 64 bit src sector (only 32 bits implementation).
;; -- {es:cx}: destination address, {seg:offset}
;; Returns:
;; -- ebx: low word of src sector.
;; -- {es:cx}: p2dest + cantBytes2copy
;;
;; No altera registros, excepto los que indica retorna.
;; Size of source sector received in ebx, so limited to 2^32 sectors (= 2TB).
;;==============================================================================

cpySec:
	push ax			;; Reg is overriden by bios in 0x42 service return.
	push dx
	push si
	push di

.cpy:
	mov di, sp		;; Base of disk address packet.

	;; Build disk address packet.
	push dword 0	;; dap10..15 dap.srcLba.hi. No necesario, trunco a 2TB.
	push ebx		;; dap06..09 dap.srcLba.lo
	push es			;; dap04..05 dap.dst.seg
	push cx			;; dap02..03 dap.dst.offset
	push byte 1		;; dap01 dap.bkCant
	push byte 16	;; dap00 dap.pkSiz

	mov si, sp
	mov dl, [drvNum]
	mov ah, 0x42		;; Extended read.
	int 0x13

	mov sp, di			;; Clean stack.

	jnc .success		;; Check for errors.

.failure:
	mov si, msg_err		;; TO-DO: retry before failure. Can also report error co
						;; de in ah.
	jmp failure
	
.success:
	add ebx, 1		;; Next sector.
	add cx, 512		;; Destination addr update.
	jnc .noCarry	;; if overflow...

.carry:
	mov dx, es
	add dh, 0x10	;; Carry to real mode segment register.
	mov es, dx

.noCarry:
	pop di
	pop si
	pop dx
	pop ax

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
	mov bx, 55aah			;; Required signature.
	mov dl, [drvNum]
	int 0x13
	jc .unsupported
	cmp bx, 0xaa55
	jne .unsupported

	mov si, msg_ok
	call print
	jmp .fin

.unsupported:
	mov si, msg_no
	jmp failure

.fin:
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

msg_extSupport:	db "Verifying bios ext support..", 0
msg_no:			db " no", 13, 10, 0
msg_load:		db "Reading disk..", 0
msg_err:		db " [error]", 13, 10, 0
msg_ok:			db " [ok]", 13, 10, 0
msg_halt:		db "System halted", 0

drvNum:			db 0x00

;; Zero fill.
times 446 - $ + $$	db 0

;; False partition table entry required by some BIOS vendors.
					db 0x80, 0x00, 0x01, 0x00, 0xEB, 0xFF, 0xFF, 0xFF
					db 0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF

times 510 - $ + $$	db 0

sign:				dw 0xAA55
