;;==============================================================================
;; Master Boot Record
;;
;; Referencias:
;; -- https://github.com/fysnet/FYSOS/blob/master/boot/embr/embr.asm
;; -- BIOS Enhanced Disk Drive Specification 3.0: http://www.o3one.org/hwdocs/bi
;; os_doc/bios_specs_edd30.pdf
;; http://www.ctyme.com/intr/rb-0708.htm
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

	mov bx, sp
	push eax
	sub bx, sp
	pop eax
	add [msg_sizeofPush + 32], bl
	mov si, msg_sizeofPush
	call print_string_16

	mov si, msg_extSupport
	call print_string_16

	mov ah, 41h		;; Check extensions present.
	mov bx, 55AAh	;; Required signature.
	mov dl, [driveNumber]
	int 13h
	jc  print_ext_not_supported
	cmp bx, 0xAA55
	jne print_ext_not_supported

	mov si, msg_ok
	call print_string_16

	mov si, msg_load
	call print_string_16

	mov ax, 512	;; Load 512 sectors = 262144 bytes = 256 KiB.
	mov bx, 6117	;; Offset = 8192.
	mov cx, 0x8000	;; Copy here.

load_nextsector:
	call readsector	;; Each loop 512 bytes.
	dec ax
	cmp ax, 0
	jnz load_nextsector

	mov si, msg_ok
	call print_string_16


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

	mov eax, 0x00
	mov ebx, 0x00
	mov ecx, 0x00
	mov edx, 0x00
	mov fs, ax
	mov es, ax


	jmp 0x0000:0x8000


err:
	mov si, msg_err
	call print_string_16

;; TO-DO: aqui mensaje.
print_ext_not_supported:
	mov si, msg_no
	call print_string_16


halt:
	mov si, msg_halt
	call print_string_16
	hlt
	jmp $

;------------------------------------------------------------------------------
; Read a sector from a disk, using LBA
; IN:	EAX - High word of 64-bit DOS sector number
;	EBX - Low word of 64-bit DOS sector number
;	ES:CX - destination buffer
; OUT:	ES:CX points one byte after the last byte read
;	EAX - High word of next sector
;	EBX - Low word of sector
readsector:
	push eax
	xor eax, eax			; We don't need to load from sectors > 32-bit
	push dx
	push si
	push di

read_it:
	push eax			; Save the sector number
	push ebx
	mov di, sp			; remember parameter block end

	push eax			; [C] sector number high 32bit
	push ebx			; [8] sector number low 32bit
	push es				; [6] buffer segment
	push cx				; [4] buffer offset
	push byte 1			; [2] 1 sector (word)
	push byte 16			; [0] size of parameter block (word)

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
	jmp read_it

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
;------------------------------------------------------------------------------


;------------------------------------------------------------------------------
; 16-bit function to print a string to the screen
; IN:	SI - Address of start of string
print_string_16:			; Output string in SI to screen
	pusha
	mov ah, 0x0E			; int 0x10 teletype function
.repeat:
	lodsb				; Get char from string
	cmp al, 0
	je .done			; If char is zero, end of string
	int 0x10			; Otherwise, print it
	jmp short .repeat
.done:
	popa
	ret


;;==============================================================================


msg_sizeofPush:	db "16b mode 32b push opcode pushes 0 bytes", 13, 10, 0
msg_extSupport:	db "Verifying bios ext support..", 0
msg_no:			db " no", 13, 10, 0
msg_load:		db "Reading disk..", 0
msg_ok:			db " ok", 13, 10, 0
msg_exec:		db "Executing..", 0
msg_err:		db " error", 0
msg_halt:		db "Sys halted", 0

driveNumber:		db 0x00

times 446 - $ + $$	db 0

; False partition table entry required by some BIOS vendors.
db 0x80, 0x00, 0x01, 0x00, 0xEB, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF

;; TO-DO: ld script.
;;times 510 - $ + $$	db 0

sign dw 0xAA55
