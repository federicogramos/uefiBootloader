;;==============================================================================
;; Real mode swich to protected mode | @file /asm/bios/start16.asm
;;==============================================================================


%include "./asm/include/sysvar.inc"


;; TO-DO: poner esto como un simbolo definido en donde mbr.ld hara el load de la
;; funcion.
;;extern print_bios
;;extern failure
print_bios	equ 0x00de + 0x7c00	;; print_bios en 0x7cde
;;failure	equ 0x0067 + 0x7c00
;;vesa	equ 0x0111 + 0x7c00


;; tsl_ap.asm
extern GDTR32
extern tmpGDTR64	;; Only for bios boot. See tsl.asm 1178 TO-DO.
extern SYS64_CODE_SEL

extern start64


;; Primera parte: pasa real mode a protected mode.

BITS 16
start16:
	mov ax, print_bios
	mov si, msg_e820
	call ax

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







	mov bl, 'B'			; 'B' as we booted via BIOS

	; At this point we are done with real mode and BIOS interrupts. Jump to 32-bit mode.
	cli				; No more interrupts
	lgdt [cs:GDTR32]		; Load GDT register
	mov eax, cr0
	or al, 0x01			; Set protected mode bit
	mov cr0, eax
	;;jmp 8:0x8000			; Jump to 32-bit protected mode

;;;;;;;;;;;;;; esto tiene que ser a start32
;;jmp 8:0x8000
jmp 8:start32
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
	mov [p_BootDisk], bh		;; Save disk from where system was booted from

	mov eax, 16			;; Set the correct segment registers
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
	mov esp, 0x8000			; Set a known free location for the stack


;;;;;;;;;;;;;;;; importante, aqui toma lo que le ha pasado desde bios, esto esta dentro de ifdef
;;;; por eso lo que le pasa difiere de uefi
;;;; leer info de video de VBEModeInfoBlock esta bien. Tener en cuenta que aqui es solo la asignacion para bios
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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

; Load the GDT
	lgdt [tmpGDTR64]

; Enable extended properties
	mov eax, cr4
	or eax, 0x0000000B0		; PGE (Bit 7), PAE (Bit 5), and PSE (Bit 4)
	mov cr4, eax

; Point cr3 at PML4
	mov eax, 0x00202008		; Write-thru enabled (Bit 3)
	mov cr3, eax

; Enable long mode and SYSCALL/SYSRET
	mov ecx, 0xC0000080		; EFER MSR number
	rdmsr				; Read EFER
	or eax, 0x00000101 		; LME (Bit 8)
	wrmsr				; Write EFER

	mov bl, 'B'
	mov bh, byte [p_BootDisk]

; Enable paging to activate long mode
	mov eax, cr0
	or eax, 0x80000000		; PG (Bit 31)
	mov cr0, eax

	jmp SYS64_CODE_SEL:start64	; Jump to 64-bit mode




	;;;;;;;;;;;;;;;;;;;; delete this
	;;print_bios:
	;;nop


;;==============================================================================
;; section .data
;;==============================================================================

;; TO-DO: agregar section data.

msg_e820:	db "Performing e820..", 0
