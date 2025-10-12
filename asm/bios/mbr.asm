;;==============================================================================
;; master boot record | @file /asm/boot/mbr.asm
;;==============================================================================
;; Referencias:
;; -- BIOS Enhanced Disk Drive Specification 3.0: http://www.o3one.org/hwdocs/bi
;; os_doc/bios_specs_edd30.pdf
;; -- https://github.com/fysnet/FYSOS/blob/master/boot/embr/embr.asm
;; http://www.ctyme.com/intr/rb-0708.htm
;; -- https://stanislavs.org/helppc/int_10.html
;; -- https://wiki.osdev.org/A20_Line
;;
;; This mbr is for 32 and 64 bit machines. Will not work fine on 16 bit 8086 or 
;; 80286 because it uses prefix override for some instructions.
;;==============================================================================

;; Payload recibido es todo lo enumerado a continuacion, pero en esta etapa de B
;; bootload solo se pasa a memoria las porciones senaladas.
;;  +----------+---------+----------------+--/ /---+--------------+
;;  | start    | tsl_sta |      tsl_      | 00..00 |   tsl.asm    |
;;  | 16.asm   | rt.asm  |      ap.asm    | 00..00 |              |
;;  | .text_   | .text_  | .text_ | .data | 00..00 | .text |.data |
;;  |  start16 |  low    |  low   | _low  | 00..00 |       |      |
;;  +----------+---------+--------+-------+--/ /---+-------+------+
;;  |^         |^                 |^      |^       |^      |^     |^
;; 0x7E00    0x8000            0x8200  0x8800  0x800000  802000  803000
;;  |<- 512 -->|<--------- 4KiB --------->|        |<--- 12KiB --->|
;;  |<--copy-->|<--cpy-->|<-----copy----->|


%include "./asm/include/mbr.inc"
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;%include "./asm/include/sysvar.inc"

global print_bios	;; Export symbol so to use this print function in start16.asm.
global diskcpy
global msg_ok
global failure

section .text


;;=============================================================================
;;
;;=============================================================================

BITS 16

entryPoint:
	cli
	cld
	xor ax, ax
	mov ss, ax
	mov es, ax
	mov ds, ax
	mov sp, 0x7c00
	sti

	mov [drvNum], dl	;; Bios passes drive number in dl.

	mov si, msg_extSupport
	call print_bios

	call extensionTest

;; TO-DO reponer
	;;mov eax, [0x8000 + SIGNATURE_OFFSET]
	;;cmp eax, "BOOT"	;; Simple payload verification (tsl_start.sys binary).
	;;jne magic_fail

	call load_start16_tsl_lo
	call a20_line

	mov eax, 0
	mov ebx, 0
	mov ecx, 0
	mov edx, 0
	mov fs, ax
	mov es, ax

start16_jump:
	jmp 0x0000:0x7E00


;;==============================================================================
;; failure | abort boot with error notification
;;==============================================================================
;; Argument:
;; -- si: string.
;;==============================================================================

failure:
	call print_bios

.halt:
	mov si, msg_halt
	call print_bios
	hlt
	jmp $


;;==============================================================================
;; load_start16_tsl_lo | copy the required part of the payload
;;==============================================================================

load_start16_tsl_lo:
	mov si, msg_reading
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
;; diskcpy | Copy n sectors from disk
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
;; cpySec | read a sector from a disk using extended read (2TB max disk size)
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
;; extensionTest | verifica soporte de extension bios
;;==============================================================================
;; Registers CS, DS, ES, SS, BX, CX, DX are preserved unless
;; explicitly changed
;;==============================================================================

extensionTest:
	mov ah, 0x41			;; Check extensions present.
	mov bx, 55aah			;; Required signature.
	mov dl, [drvNum]
	int 0x13
	jc .unsupported
	cmp bx, 0xaa55
	jne .unsupported

	;;mov si, msg_extSupport
	;;call print_bios

	mov si, msg_ok
	call print_bios
	jmp .fin

.unsupported:
	mov si, msg_no
	jmp failure

.fin:
	ret


;;==============================================================================
;; print_bios | imprime a pantalla usando bootservice
;;==============================================================================
;; Argumentos:
;; -- si: string addr 16 bits.
;;==============================================================================

print_bios:
	pusha
	mov ah, 0x0e	;; int 0x10: write text in teletype mode.

.next:
	lodsb
	cmp al, 0
	je .fin
	int 0x10		;; Write boot service.
	jmp .next

.fin:
	popa
	ret


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
;; section .data
;;==============================================================================

msg_extSupport:	db "Bios ext support..", 0
msg_no:			db " no", 13, 10, 0
msg_reading:	db "Reading disk..", 0
msg_err:		db " [error]", 13, 10, 0
msg_ok:			db " [ok]", 13, 10, 0
msg_halt:		db "System halted", 0

drvNum:			db 0x00

;; Zero fill.
;;times 446 - $ + $$	db 0

;; False partition table entry required by some BIOS vendors.
					db 0x80, 0x00, 0x01, 0x00, 0xEB, 0xFF, 0xFF, 0xFF
					db 0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF

;;times 510 - $ + $$	db 0

sign:				dw 0xAA55
