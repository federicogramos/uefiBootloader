;;==============================================================================
;; @file /asm/cpu/acpi.asm
;;==============================================================================
;; Toma la informacion de acpi y busca de sus tablas las requeridas para la mini
;; ma inicializacion del sistema.
;;
;; Documentos:
;; -- Advanced Configuration and Power Interface (ACPI) Spec Release 6.5
;;    https://uefi.org/sites/default/files/resources/ACPI_Spec_6_5_Aug29.pdf
;; -- https://uefi.org/sites/default/files/resources/BDAT_Spec_v4_0_9%20(2).pdf
;;==============================================================================


bits 64


;;==============================================================================
;;
;;==============================================================================

init_acpi:
	mov al, [p_BootMode]	;; How the system was booted.
	cmp al, 'U'				;; UEFI.
	je .uefi_rsdp_validate

	;; Find the ACPI RSDP Structure on a BIOS system.
	mov esi, 0x000E0000		;; Look for the Root Sys Desc Pointer Structure.
	mov rbx, "RSD PTR "		;; ACPI Struct Tab Signature (0x2052545020445352).
.search_acpi:
	lodsq					;; Load qword from rsi, store in rax, inc rsi 8.
	cmp rax, rbx			;; Verify Signature.
	je .rsdp_parse

	mov r9, msg_acpi_rsd_ptr	;; Err message in case of acpi_fail_msg taken.
	cmp esi, 0x000FFFFF			;; Keep looking until we get here.
	jae acpi_fail_msg			;; ACPI tables couldn't be found, fail.
	jmp .search_acpi

;; ACPI found from UEFI boot.
.uefi_rsdp_validate:
	mov rsi, [0x400000 + 4 * 1024 + 8 * 6]	;; TODO: simbolizar. 0x400000 = base
											;; addr donde imagen efi se carga. E
											;; l 4 es KiB que ocupa seccion de c
											;; odigo de uefi.
	mov rbx, "RSD PTR "	;; Root Sys Description Pointer Table (RSDT). Signature.
	lodsq				;; Carga signature. Luego de carga, apunta a checksum.

	mov r9, msg_acpi_rsd_ptr	;; Err message in case of acpi_fail_msg taken.
	cmp rax, rbx
	jne acpi_fail_msg

;; Root System Description Pointer (RSDP) Structure (5.2.5.3 in acpi spec).
.rsdp_parse:
	push rsi		;; rsi = RSDP[checksum]
	xor rbx, rbx
	mov rcx, 20		;; First 20 bytes [19..0] matter. These must sum to zero.
	sub rsi, 8		;; rsi = RSDP[0]. Revisar suma cero bytes 0..19.

.rsdp_next_checksum:
	lodsb			;; Checksum byte.
	add bl, al
	dec cl
	jnz .rsdp_next_checksum

	mov r9, msg_acpi_rsdp_checksum
	cmp bl, 0					;; Checksum tiene q dar cero.
	jne acpi_fail_msg			;; TODO: msg checksum not zero.
	
	pop rsi						;; rsi = RSDP[checksum]

.acpi_get_version:
	lodsb						;; Checksum.
	lodsd						;; OEMID (First 4 bytes).
	lodsw						;; OEMID (Last 2 bytes).
	lodsb						;; Revision (0 = v1.0, 1 = v2.0, 2 = v3.0, etc).
	cmp al, 0
	jne .set_acpi_version_flag
	jmp sys_table_load

.set_acpi_version_flag:
	mov byte [acpi_version_flag], 1	;; V2.0 or higher.

sys_table_load:
	cmp byte [acpi_version_flag], 0
	jne .v2
.v1:
	xor rax, rax
	lodsd			;; RsdtAddress - 32 bit physical addr of RSDT (offset 16).
	jmp .sys_table_signature
.v2:
	lodsd			;; RsdtAddress - 32 bit physical addr of RSDT (Offset 16).
	lodsd			;; Length.
	lodsq			;; XsdtAddress - 64 bit physical addr of XSDT (Offset 24).

.sys_table_signature:
	mov rsi, rax	;; rsi now points to the RSDT (V1) / XSDT (V2)
	lodsd			;; Load Signature.
	xor rbx, rbx
	mov bl, [acpi_version_flag]
	cmp eax, [acpi_sdt_signature + 4 * rbx]	;; Son 4 chars.

	mov r9, msg_acpi_sdt_signature	;; Load msg antes por si debe indicar error.
	jne acpi_fail_msg	;; Not the same, out.
	sub rsi, 4
	mov [p_ACPITableAddress], rsi	;; *RSDT Table.

cant_tables:
	add rsi, 4
	xor rax, rax
	lodsd			;; Length [bytes]
	add rsi, 28		;; Skip to the Entry offset
	sub rax, 36		;; eax = sdt size. Subtract the header size to and obtain nu
					;; mber of bytes occupied by pointers to other tables.

	cmp byte [acpi_version_flag], 0
	jne .v2
.v1:
	shr rax, 2		;; Addresses are dw.
	jmp parse_entries
.v2:
	shr rax, 3		;; Addresses are qw.

parse_entries:
	mov rdx, rax	;; rdx = entry count
	xor rax, rax	;; En caso de usar lodsd.
	xor rcx, rcx

.next_entry:
	cmp byte [acpi_version_flag], 0
	jne .v2
.v1:
	lodsd			;; 32-bit entry.
	jmp .continue
.v2:
	lodsq			;; 64-bit entry.

.continue:
	push rax		;; All entries to the stack.
	inc rcx
	cmp rcx, rdx
	jne .next_entry


;;==============================================================================
;; At this point: all table entries addresses pushed into the stack.
;==============================================================================

acpi_tab_find:
	xor rcx, rcx

.acpi_parse_table:
	cmp rcx, rdx			;; Compare current count to entry count.
	je .acpi_finish

	pop rsi					;; Pop an entry address from the stack.
	lodsd					;; Signature.
	inc rcx

	mov ebx, "APIC"			;; Signature for the Multiple APIC Description Tab.
	cmp eax, ebx
	je .apic_found

	mov ebx, "HPET"			;; Signature for the HPET Description Table.
	cmp eax, ebx
	je .hpet_found

	mov ebx, "MCFG"			;; Signature for the PCIe Enhanced Config Mechanism.
	cmp eax, ebx
	je .mcfg_found

	mov ebx, "FACP"			;; Signature for the Fixed ACPI Description Table.
	cmp eax, ebx
	je .facp_found

	jmp .acpi_parse_table

.apic_found:
	call table_apic_parse
	jmp .acpi_parse_table

.hpet_found:
	call table_hpet_parse
	jmp .acpi_parse_table

.mcfg_found:
	call table_mcfg_parse
	jmp .acpi_parse_table

.facp_found:
	call table_facp_parse
	jmp .acpi_parse_table

.acpi_finish:
	ret


;;==============================================================================
;; ACPI error report
;;==============================================================================


acpi_fail_msg:
	mov rsi, r9
	mov r9, msg_acpi_fail
	mov r11, PRINT_COLOR_RED
	call print_color

	mov r9, msg_sys_in_hlt
	call print

acpi_fail:
	jmp $


;;==============================================================================
;; 5.2.12 Multiple APIC Description Table (MADT). Chapter 5.2.12
;;==============================================================================
;; Argumentos:
;; -- rsi = puntero, apuntando a campo length de la tabla.
;;
;; Conserva el valor de rcx y rdx.
;;==============================================================================

table_apic_parse:
	push rcx
	push rdx

	lodsd			;; Length of MADT in bytes.
	mov ecx, eax	;; Store the length in ecx
	lodsb			;; Revision
	lodsb			;; Checksum
	lodsd			;; OEMID (First 4 bytes)
	lodsw			;; OEMID (Last 2 bytes)
	lodsq			;; OEM Table ID
	lodsd			;; OEM Revision
	lodsd			;; Creator ID
	lodsd			;; Creator Revision
	lodsd			;; Local APIC Address. The 32-bit physical address at which 
					;; each processor can access its local interrupt controller.
					;; This should match what was pulled already via the MSR.
	lodsd			;; A one indicates that the system also has a PC-AT-compat.
					;; dual-8259 setup. The 8259 vectors must be disabled (that 
					;; is, masked) when enabling the ACPI APIC operation.

	;; TODO: esto no revise si requiere que backapee registros usados antes de p
	;; rint.
	mov rsi, rax
	mov r9, msg_pc_at_compat
	call print

	mov rbx, 44			;; rbx to keep track of current position in table. Compa
						;; ring with length, we will know then end is reached.
	mov rdi, 0x00005100	;; Array of bytes. Valid CPU IDs.

;; Ahora va a recorrer cada apic irq structure. Son mas tablas anidadas dentro d
;; e la apic description table. rsi starts pointing to the 1st.
apic_irq_struct_read:
	cmp rbx, rcx
	jae .end

	lodsb						;; First byte declares type of structure.

	cmp al, 0x00				;; Processor Local APIC.
	je table_apic_irq_struct_local_apic

	cmp al, 0x01				;; I/O APIC.
	je table_apic_irq_struct_io_apic

	cmp al, 0x02				;; Interrupt Source Override.
	je table_apic_irq_struct_irq_src_override

;;	cmp al, 0x03				;; Non-maskable Interrupt Source (NMI).
;;	je APICnmi

;;	cmp al, 0x04				;; Local APIC NMI.
;;	je APIClocalapicnmi

;;	cmp al, 0x05				;; Local APIC Address Override.
;;	je APICaddressoverride

;;	cmp al, 0x06				;; I/O SAPIC Structure.
;;	je APICiosapic

;;	cmp al, 0x07				;; Local SAPIC Structure.
;;	je APIClocalsapic

;;	cmp al, 0x08				;; Platform Interrupt Source Structure.
;;	je APICplatformint

;;	cmp al, 0x0	9				;; Processor Local x2APIC.
;;	je APICx2apic

;;	cmp al, 0x0A				;; Local x2APIC NMI.
;;	je APICx2nmi

.next:
	xor rax, rax
	lodsb						;; Length. Now 2 bytes after start of table.
	sub rsi, 2					;; Back to the begginning.
	add rsi, rax				;; This entry is none of the above. Point next.
	add rbx, rax				;; Update bytes read.
	jmp apic_irq_struct_read	;; Read the next structure.

.end:
	pop rdx
	pop rcx
	ret


;;==============================================================================
;; Processor Local APIC Structure - 5.2.12.2
;;==============================================================================

table_apic_irq_struct_local_apic:						;; Entry type 0.
	xor rax,rax
	xor rdx, rdx
	lodsb						;; Second byte of the structure declares the len
								;; gth (will be set to 8).
	add rbx, rax
	lodsb						;; ACPI Processor ID
	lodsb						;; APIC ID
	xchg eax, edx				;; Save the APIC ID to EDX
	lodsd						;; Flags (Bit 0 set if enabled/usable)
	bt eax, 0					;; Test to see if usable
	jnc apic_irq_struct_read		;; Read the next structure if CPU not usable
	inc word [p_cpu_detected]
	xchg eax, edx				;; Restore the APIC ID back to EAX
	stosb						;; Store the 8-bit APIC ID
	jmp apic_irq_struct_read	;; Read the next structure


;;==============================================================================
;; I/O APIC Structure - 5.2.12.3
;;==============================================================================

table_apic_irq_struct_io_apic:						;; Entry type 1
	xor eax, eax
	lodsb						;; Length (will be set to 12)
	add ebx, eax
	push rdi
	push rcx
	mov rdi, IM_IOAPICAddress	;; Copy this data directly to the InfoMap
	xor ecx, ecx
	mov cl, [p_IOAPICCount]
	shl cx, 4
	add rdi, rcx
	pop rcx
	xor eax, eax
	lodsb						;; IO APIC ID
	stosd
	lodsb						;; Reserved
	lodsd						;; I/O APIC Address
	stosd
	lodsd						;; Global System Interrupt Base
	stosd
	pop rdi
	inc byte [p_IOAPICCount]
	jmp apic_irq_struct_read	;; Read the next structure


;;==============================================================================
;; Interrupt Source Override Structure - 5.2.12.5
;;==============================================================================

table_apic_irq_struct_irq_src_override:	;; Entry type 2
	xor eax, eax
	lodsb						;; Length (will be set to 10)
	add ebx, eax
	push rdi
	push rcx
	mov rdi, IM_IOAPICIntSource	;; Copy this data directly to the InfoMap
	xor ecx, ecx
	mov cl, [p_IOAPICIntSourceC]
	shl cx, 3
	add rdi, rcx
	lodsb				;; Bus Source
	stosb
	lodsb				;; IRQ Source
	stosb
	lodsd				;; Global System Interrupt
	stosd
	lodsw				;; Flags - bit 1 Low(1)/High(0), Bit 3 Level(1)/Edge(0)
	stosw
	pop rcx
	pop rdi
	inc byte [p_IOAPICIntSourceC]
	jmp apic_irq_struct_read	;; Read the next structure

;; Processor Local x2APIC Structure - 5.2.12.12
;;APICx2apic:			;; Entry type 9
;;	xor eax, eax
;;	xor edx, edx
;;	lodsb				;; Length (will be set to 16)
;;	add ebx, eax
;;	lodsw				;; Reserved; Must be Zero
;;	lodsd
;;	xchg eax, edx		;; Save the x2APIC ID to EDX
;;	lodsd				;; Flags (Bit 0 set if enabled/usable)
;;	bt eax, 0			;; Test to see if usable
;;	jnc APICx2apicEnd	;; Read the next structure if CPU not usable
;;	xchg eax, edx		;; Restore the x2APIC ID back to EAX
;;;;;;;;;;;;;;;;;;;;;;;;;; TODO - Save the ID's somewhere
;;APICx2apicEnd:
;;	lodsd				;; ACPI Processor UID
;;	jmp apic_irq_struct_read	;; Read the next structure



;;==============================================================================
;; High Precision Event Timer (HPET)
;;==============================================================================
;; http://www.intel.com/content/dam/www/public/us/en/documents/technical-specifi
;; cations/software-developers-hpet-spec-1-0a.pdf
;;==============================================================================

table_hpet_parse:
	lodsd						;; Length of HPET in bytes.
	lodsb						;; Revision.
	lodsb						;; Checksum.
	lodsd						;; OEMID (First 4 bytes).
	lodsw						;; OEMID (Last 2 bytes).
	lodsq						;; OEM Table ID.
	lodsd						;; OEM Revision.
	lodsd						;; Creator ID.
	lodsd						;; Creator Revision.

	lodsb						;; Hardware Revision ID.
	lodsb						;; # of Comparators (5:0), COUNT_SIZE_CAP (6), L
								;; egacy IRQ (7).
	lodsw						;; PCI Vendor ID.
	lodsd						;; Generic Address Structure.
	lodsq						;; Base Address Value.
	mov [p_HPET_Address], rax	;; Save the Address of the HPET.
	lodsb						;; HPET Number.
	lodsw						;; Main Counter Minimum.
	mov [p_HPET_CounterMin], ax	;; Save the Counter Minimum.
	lodsb						;; Page Protection And OEM Attribute.
	ret


;;==============================================================================
;; PCI Express Memory-mapped Configuration (MCFG)
;;==============================================================================
;; pcie specification:
;; https://picture.iczhiku.com/resource/eetop/SYkDTqhOLhpUTnMx.pdf
;;==============================================================================

table_mcfg_parse:
	push rdi
	push rcx
	xor eax, eax
	xor ecx, ecx
	mov cx, [p_PCIECount]
	shl ecx, 4
	mov rdi, IM_PCIE
	add rdi, rcx
	lodsd						;; Length of MCFG in bytes.
	sub eax, 44					;; Subtract the size of the table header.
	shr eax, 4
	mov ecx, eax				;; ecx now stores the number of 16-byte records.
	add word [p_PCIECount], cx
	lodsb						;; Revision.
	lodsb						;; Checksum.
	lodsd						;; OEMID (First 4 bytes).
	lodsw						;; OEMID (Last 2 bytes).
	lodsq						;; OEM Table ID.
	lodsd						;; OEM Revision.
	lodsd						;; Creator ID.
	lodsd						;; Creator Revision.
	lodsq						;; Reserved.

;; Loop through each entry.
table_mcfg_parse_next:
	lodsq					;; Base address of enhanced configuration mechanism.
	stosq
	lodsw					;; PCI Segment Group Number.
	stosw
	lodsb					;; Start PCI bus number decoded by this host bridge.
	stosb
	lodsb					;; End PCI bus number decoded by this host bridge.
	stosb
	lodsd					;; Reserved.
	stosd
	sub ecx, 1
	jnz table_mcfg_parse_next
	xor eax, eax
	not rax					;; 0xFFFFFFFFFFFFFFFF
	stosq					;; Mark the end of the table.
	stosq

	pop rcx
	pop rdi
	ret


;;==============================================================================
;; Fixed ACPI Description Table (FADT). Chapter 5.2.9
;;==============================================================================

;; At this point rsi points to offset 4 for the FADT.
table_facp_parse:

	sub rsi, 4			;; Set rsi back to start to make offsets easier below

	;; Gather IAPC_BOOT_ARCH
	mov eax, [rsi + 10]			;; Check start of OEMID.
	cmp eax, 0x48434F42			;; Is it "BOCH"?
	je table_facp_parse_end		;; If so, bail out.
	mov ax, [rsi + 109]			;; IAPC_BOOT_ARCH (IA-PC Boot Architecture Flags
								;; - 5.2.9.3).
	mov [p_IAPC_BOOT_ARCH], ax	;; Save the IAPC_BOOT_ARCH word.

;;	add rsi, 116	;; RESET_REG (Generic Address Structure - 5.2.3.2).
;;	lodsb			;; Address Space ID (0x00 = Memory, 0x01 = I/O, 0x02 = PCI).
;;	lodsb			;; Register Width.
;;	lodsb			;; Register Offset.
;;	lodsb			;; Access Size.
;;	lodsq			;; Address.
;;	lodsb			;; RESET_VALUE.

;;	add rsi, 36
;;	lodsd			;; DSDT
;;	add rsi, 20
;;	lodsd			;; PM1a_CNT_BLK

table_facp_parse_end:
	ret

