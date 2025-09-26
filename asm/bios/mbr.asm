;;==============================================================================
;; Master Boot Record
;;
;; Referencias:
;; -- https://github.com/fysnet/FYSOS/blob/master/boot/embr/embr.asm
;; -- BIOS Enhanced Disk Drive Specification 3.0: http://www.o3one.org/hwdocs/bi
;; os_doc/bios_specs_edd30.pdf
;; http://www.ctyme.com/intr/rb-0708.htm
;;==============================================================================


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; Default location of the second stage boot loader. This loads
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 32 KiB from sector 16 into memory at 0x8000
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;%define DAP_SECTORS 512
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;%define DAP_STARTSECTOR 6117
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;%define DAP_ADDRESS 0x8000
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;%define DAP_SEGMENT 0x0000

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; Set the desired screen resolution values below
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; esto en br1100 no cambia nada
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; en qemu hace que se vea ok, o que no pueda inicializar pantalla (1366 por ej)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Horizontal_Resolution		equ 1024
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Vertical_Resolution		equ 768




BITS 16

entry:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;; falta el bootcode y el bios param block

	cli
	cld
	xor ax, ax
	mov ss, ax
	mov es, ax
	mov ds, ax
	mov sp, 0x7C00
	sti

	mov [DriveNumber], dl	;; Bios passes drive number in dl.


;;==============================================================================
;; agrego chequeo.

	;;mov si, msg_ext_support
	;;call print_string_16


	mov ah, 41h		;; Check extensions present.
	mov bx, 55AAh	;; Required signature.
	mov dl, [DriveNumber]
	int 13h
	jc  print_ext_not_supported
	cmp bx, 0xAA55
	jne print_ext_not_supported

;;==============================================================================

	mov si, msg_Load
	call print_string_16


ext_supported:

	mov ax, 512		; Number of sectors to load. 512 sectors = 262144 bytes = 256 KiB
	mov bx, 6117			; Start immediately after directory (offset 8192)
	mov cx, 0x8000		; Pure64 expects to be loaded at 0x8000




	;; Levanta tsl de disco y carga en 0x8000.
	mov ah, 0x42			;; Extended Read
	mov dl, [DriveNumber]
	mov si, DAP	;; ds:si = disk address packet.
	int 0x13
	jnc do_e820


load_nextsector:
	call readsector			; Load 512 bytes
	dec eax
	cmp eax, 0
	jnz load_nextsector

	;;mov eax, [0x8000 + 6]
	;;cmp eax, "BOOT"		; Match against the tsl_start.sys binary
	;;jne magic_fail

	mov ax, 0x0800		; Segment where the bootloader and payload are loaded
	mov cx, 0x6000		; Segment where the bootloader and payload will be copied

copy_payload_to_free_mem:	; Move bootloader and payload to 0x60000
	mov fs, ax				; From segment
	mov es, cx				; To segment
	mov bx, 0x0				; Offset

copy_single_segment:
	mov dl, [fs:bx]
	mov [es:bx], dl
	inc bx
	jnz copy_single_segment

	add ax, 0x1000
	add cx, 0x1000
	cmp cx, 0xA000		; Last address (bootloader + payload = 256KiB total)
	jnz copy_payload_to_free_mem

	mov eax, 0x0		; Reset
	mov ebx, 0x0
	mov ecx, 0x0
	mov edx, 0x0
	mov fs, ax
	mov es, ax

	mov si, msg_LoadDone
	call print_string_16

;;==============================================================================


















; Get the BIOS E820 Memory Map
; https://wiki.osdev.org/Detecting_Memory_(x86)#BIOS_Function:_INT_0x15,_EAX_=_0xE820
; The code below is from https://wiki.osdev.org/Detecting_Memory_(x86)#Getting_an_E820_Memory_Map
; inputs: es:di -> destination buffer for 24 byte entries
; outputs: bp = entry count, trashes all registers except esi
; The function below creates a memory map at address 0x6000 and the records are:
; 64-bit Base
; 64-bit Length
; 32-bit Type (1 = normal, 2 reserved, ACPI reclaimable)
; 32-bit ACPI
; 64-bit Padding
do_e820:
	mov edi, 0x00006000		; location that memory map will be stored to
	xor ebx, ebx			; ebx must be 0 to start
	xor bp, bp			; keep an entry count in bp
	mov edx, 0x0534D4150		; Place "SMAP" into edx
	mov eax, 0xe820
	mov [es:di + 20], dword 1	; force a valid ACPI 3.X entry
	mov ecx, 24			; ask for 24 bytes
	int 0x15
	jc nomemmap			; carry set on first call means "unsupported function"
	mov edx, 0x0534D4150		; Some BIOSes apparently trash this register?
	cmp eax, edx			; on success, eax must have been reset to "SMAP"
	jne nomemmap
	test ebx, ebx			; ebx = 0 implies list is only 1 entry long (worthless)
	je nomemmap
	jmp jmpin
e820lp:
	mov eax, 0xe820			; eax, ecx get trashed on every int 0x15 call
	mov [es:di + 20], dword 1	; force a valid ACPI 3.X entry
	mov ecx, 24			; ask for 24 bytes again
	int 0x15
	jc memmapend			; carry set means "end of list already reached"
	mov edx, 0x0534D4150		; repair potentially trashed register
jmpin:
	jcxz skipent			; skip any 0 length entries
	cmp cl, 20			; got a 24 byte ACPI 3.X response?
	jbe notext
	test byte [es:di + 20], 1	; if so: is the "ignore this data" bit clear?
	je skipent
notext:
	mov ecx, [es:di + 8]		; get lower dword of memory region length
	test ecx, ecx			; is the qword == 0?
	jne goodent
	mov ecx, [es:di + 12]		; get upper dword of memory region length
	jecxz skipent			; if length qword is 0, skip entry
goodent:
	inc bp				; got a good entry: ++count, move to next storage spot
	add di, 32			; Pad to 32 bytes for each record
skipent:
	test ebx, ebx			; if ebx resets to 0, list is complete
	jne e820lp
nomemmap:
memmapend:
	xor eax, eax			; Create a blank record for termination (32 bytes)
	mov ecx, 8
	rep stosd

;; Enable A20 line.
set_A20:
	in al, 0x64
	test al, 0x02
	jnz set_A20
	mov al, 0xD1
	out 0x64, al
check_A20:
	in al, 0x64
	test al, 0x02
	jnz check_A20
	mov al, 0xDF
	out 0x60, al






equ	DAP_SECTORS	
equ	DAP_DST_ADDR
equ	DAP_DST_SEG
equ	DAP_SRC_LBA


align 4

;; Disk address packet. Page 6 BIOS Enhanced Disk Drive Specification 3.0.
dap:	
dap.pkSiz:		db 0x10				;; Packet size (0x10 | 0x18).
				db 0x00				;; Reserved = 0x00.
dap.bkCant:		db DAP_SECTORS		;; Cant block to transfer. Max = 0x7Fh.
				db 0x00				;; Reserved = 0x00.
dap.dst.offset:	dw DAP_DST_ADDR		;; Low word of 32-bit address of the form se
									;; g:offset
dap.dst.seg:	dw DAP_DST_SEG		;; Hi word of 32-bit address of the form seg
									;; :offset
dap.srcLba:		qw DAP_SRC_LBA		;; Starting logical block address, on the ta
									;; rget device, of the data source.

















	jmp 0x0000:0x8000

magic_fail:
	mov si, msg_MagicFail
	call print_string_16

;; TO-DO: aqui mensaje.
print_ext_not_supported:

halt:
	hlt
	jmp halt

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
	mov dl, [DriveNumber]
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
	mov ah, 0x0e			; int 0x10 teletype function
.repeat:
	lodsb				; Get char from string
	cmp al, 0
	je .done			; If char is zero, end of string
	int 0x10			; Otherwise, print it
	jmp short .repeat
.done:
	popa
	ret
;------------------------------------------------------------------------------


msg_Load db "MBR - Reading sectors... ", 0
msg_LoadDone db "ok.", 13, 10, "Executing...", 0
msg_MagicFail db "Not found!", 0
DriveNumber db 0x00

times 446 - $ + $$	db 0

; False partition table entry required by some BIOS vendors.
db 0x80, 0x00, 0x01, 0x00, 0xEB, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF

times 510 - $ + $$	db 0

sign dw 0xAA55
