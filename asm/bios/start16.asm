;;==============================================================================
;; Real mode swich to protected mode | @file /asm/bios/start16.asm
;;==============================================================================
;; Para bios boot primero real mode a protected mode. Uefi saltea esta parte, ya
;; bootea en 64. 
;;
;; https://wiki.osdev.org/Detecting_Memory_(x86)#BIOS_Function:_INT_0x15,_EAX_=_
;; 0xE820
;; https://wiki.osdev.org/Detecting_Memory_(x86)#Getting_an_E820_Memory_Map
;;==============================================================================


%include "./asm/include/sysvar.inc"

;; mbr.asm
;; TO-DO: poner esto como un simbolo definido en donde mbr.ld hara el load de la
;; funcion.
;;extern print_bios
;;extern failure
print_bios:	equ 0x00de + 0x7c00	;; print_bios en 0x7cde
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;vesa:		equ 0x011d + 0x7c00	;; print_bios en 0x011d
diskcpy:		equ 0x0 + 0x7c00	;; print_bios en 0x011d

msg_ok:	equ 0x00

;; /lib/bios.asm
extern vesa
extern vesa2uefi

;; tsl.asm
extern start64

;; tsl_ap.asm
;;extern GDTR32
GDTR32: equ 0x8200

extern tmpGDTR64	;; Only for bios boot. See tsl.asm 1178 TO-DO.
extern SYS64_CODE_SEL


section .text


;;==============================================================================
;;
;;==============================================================================

BITS 16

start16:
	mov ax, print_bios
	mov si, msg_e820
	call ax	;; Calling using pointer works with directly defining functio addr.


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



	mov ax, vesa
	call ax	;; Calling using pointer works with directly defining functio addr.






	mov bl, 'B'			; 'B' as we booted via BIOS

	; At this point we are done with real mode and BIOS interrupts. Jump to 32-bit mode.
	cli				; No more interrupts

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 0x7ea0
	lgdt [cs:GDTR32]		; Load GDT register
	mov eax, cr0
	or al, 0x01			; Set protected mode bit
	mov cr0, eax

;;;;;;;;;;;;;; esto tiene que ser a start32
;;jmp 8:0x8000
jmp 0x08:start32
;;;;;;;;;;;;;;; here ends mbr completion


;;==============================================================================
;; failure | abort boot with error notification
;;==============================================================================
;; Argument:
;; -- si: string.
;;==============================================================================

;; no se usa, puesto que reutiliza el del mbr.

;;failure:
;;	call print_bios
;;halt:
;;.halt:
;;	mov si, msg_halt
;;	call print_bios
;;	hlt
;;	jmp $


;;msg_halt:		db "System halted", 0




BITS 32



;;;Pasaje 32 to 64 bits
start32:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;mov eax, tmpGDTR64





	mov [p_BootDisk], bh		;; Save disk from where system was booted from

	mov eax, 0x10			;; Set the correct segment registers
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov fs, ax
	mov gs, ax

	xor eax, eax			;; Clear all registers
	xor ebx, ebx
	xor ecx, ecx
	xor edx, edx
	xor esi, esi
	xor edi, edi
	xor ebp, ebp
	;;;;;;;;;;;;;;;;;;;;;mov esp, 0x8000			; Set a known free location for the stack
	mov esp, 0x7000			; Set a known free location for the stack





load_tsl_hi:
	mov ax, print_bios
	mov si, msg_read_tsl_hi
	call ax	;; Calling using pointer works with directly defining functio addr.

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





	call vesa2uefi


;;;;;;;;;;;;;;;;; 7f23
;;;;;;;;;;;;;;;;;;;;;;;;; este salto lo hace bien





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




;;;;;;;;;;;;;;;;;;;;;;;;hasta aqui oka 7f7e



mov eax, tmpGDTR64

; Load the GDT
	lgdt [tmpGDTR64]




mov al, [0x8000]
jmp 8:salto
nop
nop
nop
nop
nop
nop
nop
nop
nop
nop
nop
nop
nop
nop
nop
nop
nop
nop
salto:





;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; aqui estamos en 0x7f7e
; Enable extended properties
	mov eax, cr4
	or eax, 0x0000000B0		; PGE (Bit 7), PAE (Bit 5), and PSE (Bit 4)
	mov cr4, eax

;;;;;;;;;;;;;;;;;;;; hasta aqui oka 0x7f90
; Point cr3 at PML4
	mov eax, 0x00202008		; Write-thru enabled (Bit 3)
	mov cr3, eax

;;;;;;;;;;;;;;;;;;;;;;;;; hasta aqui llega 0x7f98
; Enable long mode and SYSCALL/SYSRET
	mov ecx, 0xC0000080		; EFER MSR number
	rdmsr				; Read EFER
	or eax, 0x00000101 		; LME (Bit 8)
	wrmsr				; Write EFER


;;;;;;;;;;;;;;;;;;;; hasta aqui oka 0x7fa6
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;mov al, [0x8000]
;;jmp 8:salto
;;nop
;;nop
;;nop
;;nop
;;nop
;;nop
;;nop
;;nop
;;nop
;;nop
;;nop
;;nop
;;nop
;;nop
;;nop
;;nop
;;nop
;;nop
;;salto:

	mov bl, 'B'
	mov bh, byte [p_BootDisk]


;; hasta aqui llega. 0x7fae
; Enable paging to activate long mode
	mov eax, cr0
	or eax, 0x80000000		; PG (Bit 31)
	mov cr0, eax

;;;;;;;;;; hasta aqui 0x7fb9
mov al, [0x8000]
	jmp SYS64_CODE_SEL:start64	; Jump to 64-bit mode




	;;;;;;;;;;;;;;;;;;;; delete this
	;;print_bios:
	;;nop


;;==============================================================================
;; section .data
;;==============================================================================

;; TO-DO: agregar section data.

msg_e820:			db "Performing e820..", 0
msg_read_tsl_hi:	db "Reading tsl hi..", 0


;; Zero fill.
;;;;times 512 - $ + $$	db 0
