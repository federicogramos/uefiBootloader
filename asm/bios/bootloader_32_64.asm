mov [p_BootDisk], bh	; Save disk from where system was booted from

	mov eax, 16			; Set the correct segment registers
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov fs, ax
	mov gs, ax

	xor eax, eax			; Clear all registers
	xor ebx, ebx
	xor ecx, ecx
	xor edx, edx
	xor esi, esi
	xor edi, edi
	xor ebp, ebp
	mov esp, 0x8000			; Set a known free location for the stack

;; importante, aqui toma lo que le ha pasado desde bios, esto esta dentro de ifdef
;; por eso lo que le pasa difiere de uefi
;; leer info de video de VBEModeInfoBlock esta bien. Tener en cuenta que aqui es solo la asignacion para bios

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
	lgdt [tGDTR64]

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

	
