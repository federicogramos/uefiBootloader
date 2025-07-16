;;==============================================================================
;; UEFI bootloader | @file /asm/boot/uefi.asm
;;==============================================================================
;; Varios de los comentarios realizados estan basados en la informacion de: 
;; -- Extensible Firmware Interface Specification Version 1.10 December 1, 2002.
;; -- EFI Specification Version 2.8
;; -- Headers: https://learn.microsoft.com/en-us/windows/win32/debug/pe-format
;; Otra info:
;; Calling convention: https://learn.microsoft.com/en-us/cpp/build/x64-calling-c
;; onvention?view=msvc-170
;;
;; La salida de NASM se guarda en /EFI/BOOT/BOOTX64.EFI y se le inyecta el paylo
;; ad (UEFI bootloader + packedKernel.bin) que se requiera. Archivo BOOTX64.EFI,
;; luego de agregado el payload queda:
;;  +--------------------------+-------------------------+------------+
;;  |    binario BOOTX64.EFI   |         payload         | padeo de   |
;;  |         |        |       | bootloader | packed     | 0x00 hasta |
;;  | Encabez | Codigo | Datos |            | Kernel.bin | el fin     |
;;  +---------+--------+-------+------------+------------+------------+
;;  |^        |^       |^      |^           |^           |^          ^|
;; 0x0      0x200   0x1000   0x4000      0x5800      0x40000      0xFFFFF
;; 0        512B    4KiB     16KiB        22KiB       256KiB       1MiB-1
;;==============================================================================


%include "./asm/include/efi.inc"
%define utf16(x) __utf16__(x)


global FB
global FB_SIZE
global PPSL
global STEP_MODE_FLAG

;; efi vars.
global CONOUT_INTERFACE
global CONIN_INTERFACE
global EFI_INPUT_KEY

;; uefi.ld.
extern headerSize
extern codeSize
extern dataSize
extern fileSize
extern codeOffset
extern dataOffset

;; lib.asm
extern print_cursor
extern num2hexStr
extern num2str
extern print
extern memsetFramebuffer
extern keyboard_command
extern keyboard_get_key
extern emptyKbBuffer

;; lib_efi.asm
extern efi_print
extern ventana_modo_step
extern efi_prompt_step_mode


;;==============================================================================
;; Header archivo PE/COFF.
;;==============================================================================

section .header


HEADER:

;; Header DOS, 128 bytes.
DOS_SIGNATURE:			db "MZ", 0x00, 0x00
DOS_HDRS:				times 60 - ($ - HEADER) db 0
PE_SIGNATURE_OFFSET:	dd PE_SIGNATURE - HEADER	;; File offset.
DOS_STUB:				times 64 db 0				;; No program, zero fill.

;; Encabezado PE.
PE_SIGNATURE:			db "PE", 0x00, 0x00

;; COFF File Header, 20 bytes.
MACHINE_TYPE:		dw 0x8664		;; x86-64 machine.
N_SECTIONS:			dw 2			;; Number of entries in section table. Secti
									;; on table immediately follows the headers.
TIMESTAMP:			dd 1745097600	;; File creation, seconds since 1970.
SYM_TAB_P2:			dd 0			;; File offset of the COFF symbol table, zer
									;; o if none. Should be zero for an image be
									;; cause COFF debug info is deprecated.
SYM_TAB_N_SYMBOLS:	dd 0
OPT_HDR_SIZE:		dw OPT_HDR_END - OPT_HDR	;; Optional header. Section tabl
												;; e is determined by calculatin
												;; g the location of the first b
												;; yte after headers. Make sure 
												;; use size of optional header a
												;; s specified in file header.
CHARACTERISTICS:	dw 0x222E		;; Attributes of the file.
;; Flags:
;; IMG_DLL					0x2000
;; IMG_DEBUG_STRIPPED		0x0200	Debugging info removed from the image file.
;; IMG_LARGE_ADDR_AWARE		0x0020	Application can handle > 2-GB addresses.
;; IMG_LOC_SYMS_STRIPPED	0x0008	COFF symbol table entries for local symbols 
;;									removed. Deprecated and should be zero.
;; IMG_LINE_NUMS_STRIPPED	0x0004	COFF line numbers removed. Dep, should be 0.
;; IMG_EXECUTABLE_IMAGE		0x0002	Image only. Image file is valid, can be run.

;; Optional Header Standard Fields
OPT_HDR:
MAGIC_NUMBER:				dw 0x020B ;; PE32+ (64-bit address space) PE format.
MAJOR_LINKER_VERSION:		db 0
MINOR_LINKER_VERSION:		db 0

CODE_SIZE:					dd codeSize	;; Text.
INITIALIZED_DATA_SIZE:		dd dataSize	;; Data.
UNINITIALIZED_DATA_SIZE:	dd 0x00		;; Bss.

ENTRY_POINT_ADDR:		dd codeOffset	;; Entry point relative to img base load
										;; ed in memory.
BASE_OF_CODE_ADDR:		dd codeOffset	;; Relative addr of base of code sect.

IMAGE_BASE:				dq 0x400000		;; Where in memory we would prefer image
										;; to be loaded at. Multiple of 64K.
SECTION_ALIGNMENT:		dd 0x1000		;; Alignment [bytes] of sections when lo
										;; aded in mem (to page boundary, 4K).
FILE_ALIGNMENT:			dd 0x1000		;; Alignment of sections in file, 4K.
MAJOR_OS_VERSION:		dw 0
MINOR_OS_VERSION:		dw 0
MAJOR_IMAGE_VERSION:	dw 0
MINOR_IMAGE_VERSION:	dw 0
MAJOR_SUBSYS_VERSION:	dw 0
MINOR_SUBSYS_VERSION:	dw 0
WIN32_VERSION_VALUE:	dd 0			;; Reserved, must be 0.
IMAGE_SIZE:				dd fileSize		;; The size [bytes] of img loaded in mem
										;; including all headers. Must be multip
										;; le of SectionAlignment (?). Aparentem
										;; ente no es mandatorio. 

HEADERS_SIZE:			dd headerSize	;; Size of all the headers.
CHECKSUM:				dd 0
SUBSYSTEM:				dw 10		;; IMAGE_SUBSYSTEM_EFI_APPLICATION = 10, Ext
									;; ensible Firmware Interface (EFI) app.

DLL_CHARACTERISTICS:	dw 0
STACK_RESERVE_SIZE:		dq 0x200000	;; 2MB. The size of the stack to reserve. On
									;; ly SizeOfStackCommit is committed, rest i
									;; s made available one page at a time until
									;; the reserve size is reached.

STACK_COMMIT_SIZE:	dq 0x1000		;; Commit 4KB of the stack.
HEAP_RESERVE_SIZE:	dq 0x200000		;; Reserve 2MB for the heap.
HEAP_COMMIT_SIZE:	dq 0x1000		;; Commit 4KB of heap.
LOADER_FLAGS:		dd 0x00			;; Reserved, must be zero.
N_OF_RVA_AND_SIZES:	dd 0x00			;; Number of entries in the data directory.
OPT_HDR_END:

;; Section Table (Section Headers)
SECTION_HDRS:
.text_name						db ".text", 0x00, 0x00, 0x00
.text_virtual_size				dd codeSize
.text_virtual_address			dd codeOffset
.text_size_of_raw_data			dd codeSize
.text_pointer_to_raw_data		dd codeOffset
.text_pointer_to_relocations	dd 0
.text_pointer_to_line_numbers	dd 0
.text_number_of_relocations		dw 0
.text_number_of_line_numbers	dw 0
.text_characteristics			dd 0x70000020
;; Section flags:
;; IMAGE_SCN_MEM_SHARED			0x10000000 Can be shared in memory.
;; IMAGE_SCN_MEM_EXECUTE		0x20000000 Can be executed as code.
;; IMAGE_SCN_MEM_READ			0x40000000 Can be read.
;; IMAGE_SCN_CNT_CODE			0x00000020 Contains executable code.

.data_name						db ".data", 0x00, 0x00, 0x00
.data_virtual_size				dd dataSize
.data_virtual_address			dd dataOffset
.data_size_of_raw_data			dd dataSize
.data_pointer_to_raw_data		dd dataOffset
.data_pointer_to_relocations	dd 0
.data_pointer_to_line_numbers	dd 0
.data_number_of_relocations		dw 0
.data_number_of_line_numbers	dw 0
.data_characteristics			dd 0xD0000040
;; Section flags:
;; IMAGE_SCN_MEM_SHARED				0x10000000 Can be shared in memory.
;; IMAGE_SCN_MEM_READ				0x40000000 Can be read.
;; IMAGE_SCN_CNT_INITIALIZED_DATA	0x00000040 Contains initialized data.
;; IMAGE_SCN_MEM_WRITE				0x80000000 Can be written to.

;; El header ocupo exactamente 0x160 bytes. Lo alineo a 0x200 para que termine o
;; cupando 512 bytes.


section .text

;; Entry point prototype:
;; EFI_STATUS main(EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE *SystemTable)
;; Argumentos:
;; -- ImageHandle Handle that identifies the loaded image. Type EFI_HANDLE is de
;;    fined in the InstallProtocolInterface() function description.
;; -- SystemTable System Table for this image.
;;
;; Where UEFI ABI specifies:
;; Calling convention is usual 64-bit fastcall, pero no usa IA64 System V AMD64 
;; ABI, sino (Microsoft) x64 ABI calling conventions.
;; First 4 arguments in RCX, RDX, R8, R9 with space reserved on stack por la fun
;; llamadora, para que la funcion llamada almacene esos argumentos (shadow store
;; ). A single argument is never spread across multiple registers.
;; Rest of arguments passed by stack after the shadow store before the call (se
;; refiere a las direcciones de memoria, no al orden de pusheo). El stack queda:
;; > ret_addr <
;; >32b_shadow< 
;; >args_pila <
;; Right-to-left order push. All arguments passed on the stack are 8-byte aligne
;; d. The x64 ABI considers the registers RAX, RCX, RDX, R8, R9, R10, R11, and X
;; MM0-XMM5 volatile (not preserved by called function).
;; Note: EFI, for every supported architecture defines exact ABI.


entryPoint:
	;; Ubicado en 0x400200 cuando imagen va en 0x400000
	;; UEFI entry point args and rerturn address.
	mov [EFI_IMAGE_HANDLE], rcx
	mov [EFI_SYSTEM_TABLE], rdx
	mov [EFI_IMG_RET_ADDR], rsp

	;; Stack is misaligned by 8 when control is transferred to the EFI entry poi
	;; nt. Lo estaba antes de la llamada al entry_point, pero la call entry_poin
	;; t ha pusheado la direccion de retorno y desalineado. ABI requiere alineam
	;; iento a 16.
	and rsp, -16
	
	;; La especificacion x86 ABI especifica shadow space de 32 bytes. He visto q
	;; ue a veces recomiendan 64. Eso es incorrecto. Es innecesario cuando las f
	;; unciones reciben menos de 4 args, e incorrecto cuando reciben mas de 4.
	sub rsp, 8 * 4

	;; EFI Boot Services Table contains pointers to all boot services.
	mov rax, [EFI_SYSTEM_TABLE]
	mov rax, [rax + EFI_SYSTEM_TABLE_BOOTSERVICES]
	mov [EFI_BOOT_SERVICES], rax
	
	mov rax, [EFI_SYSTEM_TABLE]
	mov rax, [rax + EFI_SYSTEM_TABLE_RUNTIMESERVICES]
	mov [RTS], rax

	mov rax, [EFI_SYSTEM_TABLE]
	mov rax, [rax + EFI_SYSTEM_TABLE_CONFIGURATION_TABLE]
	mov [CONFIG_TABLE], rax

	mov rax, [EFI_SYSTEM_TABLE]
	mov rax, [rax + EFI_SYSTEM_TABLE_CONIN_HANDLE]
	mov [CONIN_INTERFACE_HANDLE], rax
	
    mov rax, [EFI_SYSTEM_TABLE]
	mov rax, [rax + EFI_SYSTEM_TABLE_CONIN]
	mov [CONIN_INTERFACE], rax

	;; -- Modo texto de uefi, imprime en un recuadro centrado en la pantalla ind
	;; ependientemente de la resolucion real. Por defecto 80x25 (mode = 0) tambi
	;; en segun especificacion debe soportar 80x50 = modo 1.
	;; -- Aqui, hlt unicamente no va a haltear. Debe hacer cli, luego hlt.
	mov rax, [EFI_SYSTEM_TABLE]
	mov rax, [rax + EFI_SYSTEM_TABLE_CONOUT]
	mov [CONOUT_INTERFACE], rax

	;; SIMPLE_TEXT_OUTPUT.SetAttribute(). Sets the background and foreground col
	;; ors for the OutputString() and ClearScreen() functions.
	mov rcx, [CONOUT_INTERFACE] 
	mov rdx, 0x07	;; IN UINTN Attribute = Black background, grey foreground.
	call [rcx + EFI_OUT_SET_ATTRIBUTE]

	;; SIMPLE_TEXT_OUTPUT.ClearScreen(). Clears output device(s) display to the 
	;; currently selected background color. Cursor position is set to (0, 0).
	mov rcx, [CONOUT_INTERFACE]	
	call [rcx + EFI_OUT_CLEAR_SCREEN]

	mov rax, [EFI_SYSTEM_TABLE]
	mov rsi, [rax + EFI_SYSTEM_TABLE_FW_VENDOR]
	mov rdx, fmt_fw_vendor
	call efi_print	;; Firmware vendor.

	mov rcx, [CONOUT_INTERFACE]
	mov rbx, [rcx + EFI_OUT_MODE]
	mov rsi, [rbx]	;; Es uint32, voy a blanquearle parte alta.
	push rsi
	mov dword [rsp + 4], 0
	pop rsi
	mov rdx, fmt_max_txt_mode
	call efi_print	;; Cantidad maxima de modos soportados.

	mov rcx, [CONOUT_INTERFACE]
	mov rbx, [rcx + EFI_OUT_MODE]
	mov rsi, [rbx + 4]	;; Debo transformar a uint32.
	push rsi
	mov dword [rsp + 4], 0
	pop rsi
	mov rdx, fmt_curr_txt_mode
	call efi_print	;; Current video settings del modo texto con el q inicia.

;; Ventana en la que se puede activar modo step presionando 's'.
call ventana_modo_step

;; Buscar info ACPI.
acpi_get:
	mov rax, [EFI_SYSTEM_TABLE]
	mov rcx, [rax + EFI_SYSTEM_TABLE_NUMBEROFENTRIES]
	mov rdi, 0
	mov rsi, [CONFIG_TABLE]
	mov rdx, [ACPI_TABLE_GUID]		;; ACPI GUID bajo.
	mov rax, [ACPI_TABLE_GUID + 8]	;; ACPI GUID alto.

.acpi_search:
	cmp rdi, rcx
	je .err
	mov rbx, [rsi]
	cmp rdx, rbx		;; ACPI GUID bajo.
	jne .next
	mov rbx, [rsi + 8]
	cmp rax, rbx		;; ACPI GUID alto.
	jne .next
	mov rax, [rsi + 16]
	mov [ACPI], rax
	jmp locate_edid_active_protocol

.next:
	add rsi, 24
	inc rdi
	jmp .acpi_search

.err:
	mov rsi, msg_acpi_err
	je error_fatal	;; Sin ACPI no se continua.

;; Configurar pantalla. Algunas definiciones:
;; https://www.intel.com/content/dam/doc/guide/uefi-driver-graphics-controller-g
;; uide.pdf
;; https://uefi.org/specs/UEFI/2.10/12_Protocols_Console_Support.html
;; Primero intenta encontrar un EDID, si no encuentra, prueba una resolucion por
;; defecto directo con el GOP.
;; Todos los protocolos disponibles en EDK2:
;; https://github.com/tianocore/edk2/tree/master/MdePkg/Include/Protocol

;; Intento 1: pedir el protocolo activo usando LocateProtocol().
locate_edid_active_protocol:
	mov rcx, EFI_EDID_ACTIVE_PROTOCOL_GUID	;; IN EFI_GUID *Protocol
	mov rdx, 0								;; IN VOID *Registration OPTIONAL
	mov r8, EDID							;; OUT VOID **Interface
	mov rax, [EFI_BOOT_SERVICES]
	mov rax, [rax + EFI_BOOT_SERVICES_LOCATEPROTOCOL]
	call rax
	mov rsi, str_edid_active_protocol		;; Para mostrar info en pantalla.
	cmp rax, EFI_SUCCESS
	je get_EDID

;; Intento 2: pedir el protocolo existente usando LocateProtocol().
locate_edid_discovered_protocol:
	mov rcx, EFI_EDID_DISCOVERED_PROTOCOL_GUID	;; IN EFI_GUID *Protocol
	mov rdx, 0									;; IN VOID *Registr OPTIONAL
	mov r8, EDID								;; OUT VOID **Interface
	mov rax, [EFI_BOOT_SERVICES]
	mov rax, [rax + EFI_BOOT_SERVICES_LOCATEPROTOCOL]
	call rax
	mov rsi, str_edid_discovered_protocol		;; Para mostrar en pantalla.
	cmp rax, EFI_SUCCESS
	je get_EDID

	jmp locate_edid_fail_use_default_resolution	;; Fail message, then use GOP.

;; Si encuentra el protocolo, en cualquiera de ambos casos es:
;; typedef struct {
;; UINT32	SizeOfEdid;
;; UINT8	*Edid;
;; } EFI_EDID_ACTIVE_PROTOCOL;

get_EDID:
	mov rdx, fmt_edid_protocol_located
	call efi_print

	mov rax, [EDID]
	mov ebx, [rax]
	cmp ebx, 128				;; Minimum size of 128 bytes.
	mov rsi, str_edid_size_err	;; Para mostrar en pantalla si toma el jb.
	jb edid_validation_fail		;; Err msg, then continue to GOP.
	;; TODO: en realidad, aqui, si hubo fail en active protocol, aun tengo oport
	;; unidad de un success con discovered protocol, en lugar de ir directo a GO
	;; P, probar el discovered (aunque por lo general van a ser el mismo, salvo 
	;; override).

	mov rbx, [rax + 8]			;; Pointer to EDID. Why not +4? Yes, why? Pendie
								;; nte: revisar que este codigo corra en algun m
								;; omento y lo haga bien.

	mov rax, [rbx]				;; Load rax with EDID header.
	mov rcx, 0x00FFFFFFFFFFFF00	;; Required EDID header
	cmp rax, rcx				;; Fixed header pattern 0x00FFFFFFFFFFFF00.
	mov rsi, str_edid_hdr_err	;; Para mostrar en pantalla si toma el jb.
	jb edid_validation_fail		;; Err msg, then continue to GOP.

	;; TODO: extraer Digital input, Bit depth, Video interface, Manufacturer ID.
	;; https://en.wikipedia.org/wiki/Extended_Display_Identification_Data

	;; Preferred Timing mode descriptor starts at byte 0x36. From the EDID Timin
	;; g Descriptor we get:
	;; 0x38 - Lower 8 bits of Horizontal pixels in bits 7:0
	;; 0x3A - Upper 4 bits of Horizontal pixels in bits 7:4
	;; 0x3B - Lower 8 bits of Vertical pixels in bits 7:0
	;; 0x3D - Upper 4 bits of Vertical pixels in bits 7:4
	xor eax, eax
	xor ecx, ecx
	mov al, [rbx + 0x38]
	mov cl, [rbx + 0x3A]
	and cl, 0xF0
	shl ecx, 4
	or eax, ecx
	mov [Horizontal_Resolution], eax
	xor eax, eax
	xor ecx, ecx
	mov al, [rbx + 0x3B]
	mov cl, [rbx + 0x3D]
	and cl, 0xF0
	shl ecx, 4
	or eax, ecx
	mov [Vertical_Resolution], eax

	mov rsi, [Horizontal_Resolution]
	mov rdx, efi_fmt_resolution_horizontal
	call efi_print						;; Informar resolucion.
	mov rsi, [Vertical_Resolution]
	mov rdx, efi_fmt_resolution_vertical
	call efi_print
	jmp locate_gop_protocol

locate_edid_fail_use_default_resolution:
	mov rdx, msg_locate_edid_fail_use_default_resol
	call efi_print
	jmp locate_gop_protocol

edid_validation_fail:
	mov rdx, fmt_edid_validation_fail
	call efi_print	;; Encuentra EDID pero detecta errores de tamano o header.
	jmp locate_gop_protocol

;; Pedir GOP usando LocateProtocol().
locate_gop_protocol:
	mov rcx, EFI_GRAPHICS_OUTPUT_PROTOCOL_GUID	;; IN EFI_GUID *Protocol
	mov rdx, 0									;; IN VOID *Registr OPTIONAL
	mov r8, VIDEO_INTERFACE						;; OUT VOID **Interface
	mov rax, [EFI_BOOT_SERVICES]
	mov rax, [rax + EFI_BOOT_SERVICES_LOCATEPROTOCOL]
	call rax
	mov rsi, str_gop_protocol_fatal_err			;; Para mostrar en pantalla.
	cmp rax, EFI_SUCCESS
	jne error_fatal

	;; Parse the current graphics information
	;; EFI_GRAPHICS_OUTPUT_PROTOCOL_MODE Structure
	;; 0  UINT32 - MaxMode
	;; 4  UINT32 - Mode
	;; 8  EFI_GRAPHICS_OUTPUT_MODE_INFORMATION - *Info;
	;; 16 UINTN - SizeOfInfo
	;; 24 EFI_PHYSICAL_ADDR - FrameBufferBase
	;; 32 UINTN - FrameBufferSize
    mov rax, [VIDEO_INTERFACE]
	add rcx, EFI_GRAPHICS_OUTPUT_PROTOCOL_MODE
	mov rcx, [rcx]				;; rcx = address of mode structure.
	mov eax, [rcx]				;; eax = uint32_t MaxMode
	mov [vid_max], rax			;; Max video modes.
	jmp .video_mode_busca

.next:
	mov rax, [vid_index]
	add rax, 1					;; Increment the mode number to check.
	mov [vid_index], rax
	mov rdx, [vid_max]
	cmp rax, rdx
	je skip_set_video

.video_mode_busca:
	mov rcx, [VIDEO_INTERFACE]	;; IN EFI_GRAPHICS_OUTPUT_PROTOCOL *This
	mov rdx, [vid_index]		;; IN UINT32 ModeNumber
	lea r8, [vid_size]			;; OUT UINTN *SizeOfInfo
	lea r9, [vid_info]			;; OUT EFI_GRAPHICS_OUTPUT_MODE_INFORMATI **Info
	call [rcx + EFI_GRAPHICS_OUTPUT_PROTOCOL_QUERY_MODE]

	;; TODO: podria promptear para seleccionar por consola una resolucion, sirve
	;; para probar respuesta de SO.
	;; Revisar seteos. Busco el que me ha entregado EFI con el EDID o si no, Por
	;; defecto 1024 x 768.
	mov rsi, [vid_info]
	lodsd					;; UINT32 - Version
	lodsd					;; UINT32 - HorizontalResolution
	cmp eax, [Horizontal_Resolution]
	jne .next
	lodsd					;; UINT32 - VerticalResolution
	cmp eax, [Vertical_Resolution]
	jne .next
	lodsd					;; EFI_GRAPHICS_PIXEL_FORMAT - PixelFormat (UINT32)
	bt eax, 0				;; Bit 0 is set for 32-bit colour mode
	jnc .next

	;; Si llego hasta aqui, he encontrado el modo con resolucion pedida.
	mov rdx, msg_graphics_mode_info_match
	call efi_print

	call efi_prompt_step_mode	;; Ultima parada antes de que se borre pantalla 
								;; y se pase a usar framebuffer directo.

.video_mode_set:
	mov rcx, [VIDEO_INTERFACE]	;; IN EFI_GRAPHICS_OUTPUT_PROTOCOL *This
	mov rdx, [vid_index]		;; IN UINT32 ModeNumber
	call [rcx + EFI_GRAPHICS_OUTPUT_PROTOCOL_SET_MODE]
	cmp rax, EFI_SUCCESS
	jne .next

;; Se acaba de resetear el buffer de video, se blanquea la pantalla. Antes se ve
;; ia baja resolucion, ahora se setea la nueva seleccionada resolucion. Voy a vo
;; lver a mostrar en pantalla los datos de resolucion configurados.
;; Buscar info pantalla actual (modo 0), de modo de ya tener config video falle 
;; o no el intento de cambio.

.video_mode_success:

	mov rax, 0x00000000
	call memsetFramebuffer

	mov qword [print_pending_msg], msg_graphics_success	;; Prepara mensaje para 
														;; mostrar luego.
	mov rsi, [vid_index]
	mov [print_pending_msg + 8], rsi
	jmp get_video

;; Ha probado todos los modos y no encuentra match ni con un EDID encontrado, ni
;; con la resolucion por defecto. Lo que hace es no cambiar el actual modo.
skip_set_video:

	mov qword [print_pending_msg], msg_gop_no_mode_matches	;; Mensaje para mos
															;; trar luego.

;; Haya encontrado match en un video mode y logrado setearlo, o no, continua. us
;; a la resolucion que actualmente tiene seteada, por lo que si al arranque teni
;; a video, se tiene que poder continuar viendo salida. 
get_video:

	;; Get video mode details. https://github.com/tianocore/edk2/blob/master/Mde
	;; Pkg/Include/Protocol/GraphicsOutput.h
	mov rcx, [VIDEO_INTERFACE]
	add rcx, EFI_GRAPHICS_OUTPUT_PROTOCOL_MODE
	mov rcx, [rcx]
	mov rax, [rcx + 24]	;; EFI_PHYSICAL_ADDRESS FrameBufferBase
	mov [FB], rax
	mov rax, [rcx + 32]	;; UINTN FrameBufferSize
	mov [FB_SIZE], rax	;; FB size. No necesariamente es igual a w x h x bpp por
						;; que podria ser mas. Ejemplo: 800 x 600 = 1920000 pero
						;; el fbzise podria ser 1921024 (no multiplo de 2).
	mov rcx, [rcx + 8]	;; EFI_GRAPHICS_OUTPUT_MODE_INFORMATION *Info

	;; EFI_GRAPHICS_OUTPUT_MODE_INFORMATION Structure
	;; 0  UINT32 - Version
	;; 4  UINT32 - HorizontalResolution
	;; 8  UINT32 - VerticalResolution
	;; 12 EFI_GRAPHICS_PIXEL_FORMAT - PixelFormat (UINT32)
	;; 16 EFI_PIXEL_BITMASK - PixelInformation (4 UINT32 - RedMask, GreenMask, B
	;; lueMask, ReservedMask)
	;; 32 UINT32 - PixelsPerScanLine - Defines the number of pixel elements per 
	;; video memory line. Scan lines may be padded for memory alignment.

	mov eax, [rcx + 4]	;; Horizontal Resolution
	mov [HR], rax
	mov eax, [rcx + 8]	;; Vertical Resolution
	mov [VR], rax
	mov eax, [rcx + 32]	;; PixelsPerScanLine
	mov [PPSL], rax

	mov rax, [FB]
	mov [print_cursor], rax	;; Inicializacion del cursor.
	cmp qword [print_pending_msg], 0
	je print_video_information
	mov r9, [print_pending_msg]
	mov rsi, [print_pending_msg + 8]
	mov qword [print_pending_msg], 0
	mov qword [print_pending_msg + 8], 0
	call print

;; Info en pantalla del modo seleccionado y valores que quedaron. Estos son los 
;; seteos que le va a pasar al siguiente bootloader y SO.
print_video_information:
	mov rsi, [HR]
	mov r9, fmt_resolution_horizontal
	call print
	mov rsi, [VR]
	mov r9, fmt_resolution_vertical
	call print
	mov rsi, [PPSL]
	mov r9, fmt_ppsl
	call print
	mov rsi, [FB_SIZE]
	mov r9, fmt_fb_size
	call print
	mov rsi, [FB]
	mov r9, fmt_fb_address
	call print

verifica_payload:
	mov rsi, PAYLOAD + 6
	mov rax, [rsi]
	mov rbx, "UEFIBOOT"	;; Chequeo simple de payload en lugar.
	cmp rax, rbx		;; No se puede hacer cmp con operando inmediato de 64!
	jne payloadSignatureFail

get_memmap:
	mov rdx, [memmap]			;; OUT EFI_MEMORY_DESCRIPTOR *MemoryMap
	lea rcx, [memmapsize]		;; IN OUT UINTN *MemoryMapSize (size of buffer)
	lea r8, [memmapkey]			;; OUT UINTN *MapKey
	lea r9, [memmapdescsize]	;; OUT UINTN *DescriptorSize
	lea r10, [memmapdescver]	;; OUT UINT32 *DescriptorVersion
	mov [rsp + 32], r10
	mov rax, [EFI_BOOT_SERVICES]
	call [rax + EFI_BOOT_SERVICES_GETMEMORYMAP]
	cmp al, EFI_BUFFER_TOO_SMALL
	je .notify_change			;; UEFI ha cambiado memmapsize. Volver a llamar.

	mov rsi, txt_err_memmap		;; Detalle del error, si resulta no se success.
	cmp rax, EFI_SUCCESS
	jne error_fatal8
	jmp .print_info_memmap

.notify_change:
	mov r9, msg_notify_memmap_change
	call print
	jmp get_memmap

;; Each 48-byte EFI_MEMORY_DESCRIPTOR record has the following format:
;; 0  UINT32 - Type
;; 4  UNIT32 - Padding
;; 8  EFI_PHYSICAL_ADDR (UINT64) - PhysicalStart
;; 16 EFI_VIRTUAL_ADDR (UINT64) - VirtualStart
;; 24 UINT64 - NumberOfPages - Number of 4K pages (must be a non-zero value)
;; 32 UINT64 - Attribute
;; 40 UINT64 - Blank
;;
;; Memory Type Usage after ExitBootServices():
;; 0x0 = EfiReservedMemoryType - Not usable
;; 0x1 = EfiLoaderCode - Usable after ExitBootSerivces
;; 0x2 = EfiLoaderData - Usable after ExitBootSerivces
;; 0x3 = EfiBootServicesCode - Usable after ExitBootSerivces
;; 0x4 = EfiBootServicesData - Usable after ExitBootSerivces
;; 0x5 = EfiRuntimeServicesCode
;; 0x6 = EfiRuntimeServicesData
;; 0x7 = EfiConventionalMemory - Usable after ExitBootSerivces
;; 0x8 = EfiUnusableMemory - Not usable - errors detected
;; 0x9 = EfiACPIReclaimMemory - Usable after ACPI is enabled
;; 0xA = EfiACPIMemoryNVS
;; 0xB = EfiMemoryMappedIO
;; 0xC = EfiMemoryMappedIOPortSpace
;; 0xD = EfiPalCode
;; 0xE = EfiPersistentMemory
;; 0xF = EfiMaxMemoryTyp

.print_info_memmap:
	mov rdx, 0
	mov rax, [memmapsize]
	mov rcx, [memmapdescsize]
	div rcx
	mov rsi, rax
	mov r9, fmt_memmap_cant_descriptors
	call print

	mov rsi, [memmapdescsize]
	mov r9, fmt_memmap_descriptor_size	;; Al 2025 reporta 48. El typedef tiene
										;; 40 bytes. La implementacion EFI fuerz
										;; a este numero a proposito. 
	call print

;; Toma informacion de los dispositivos de entrada disponibles. El objetivo por 
;; ahora es solo mostrar cuantos handles hay.
.in_handle_locate:
	mov rcx, 2 ;; SearchType = byProtocol
	mov rdx, EFI_SIMPLE_TEXT_INPUT_PROTOCOL_GUID
	mov r8, 0
	mov r9, aux_buf_size
	mov r10, aux_buffer
	push r10		;; 5to por stack.
	sub rsp, 8*4	;; Shadow.
	mov rax, [EFI_BOOT_SERVICES]
	mov rax, [rax + EFI_LOCATE_HANDLE_BUFFER]
	call rax
	add rsp, 8
	cmp rax, EFI_SUCCESS
	je .in_handle_notify_handlebuffer_ok

.in_handle_notify_handlebuffer_err:
	mov r9, msg_handlebuffer_err
	jmp .in_handle_print

.in_handle_notify_handlebuffer_ok:
	mov r9, msg_handlebuffer_ok
	mov rsi, [aux_buf_size]

.in_handle_print:
	call print

.in_handle_print_conin:
	mov r9, msg_conin_handle_value
	mov rsi, [CONIN_INTERFACE_HANDLE]
	call print

	mov rcx, 0
	mov rax, [aux_buffer]

.in_handle_print_received:
	cmp rcx, [aux_buf_size]
	je .newline

	mov rsi, rcx
	mov r9, msg_located_index
	push rax
	push rcx
	call print
	pop rcx
	pop rax

	mov rsi, [rax + 8 * rcx]
	mov r9, msg_located_value
	push rax
	push rcx
	call print
	pop rcx
	pop rax

	inc rcx
	jmp .in_handle_print_received

.newline:
	mov r9, newline8
	call print

exit_uefi_services:

	;; Notificar a punto de salir, pero aqui no la puedo hacer con efi_print ya 
	;; que luego de obtener mapa de mem, inmediatamente debo hacer el exit.
	mov r9, msg_boot_services_exit
	call print

	mov rcx, [EFI_IMAGE_HANDLE]	;; IN EFI_HANDLE ImageHandle
	mov rdx, [memmapkey]		;; IN UINTN MapKey
	mov rax, [EFI_BOOT_SERVICES]
	call [rax + EFI_BOOT_SERVICES_EXITBOOTSERVICES]
	cmp rax, EFI_SUCCESS
	jne get_memmap				;; Get mem map, then try to exit again.
	cli							;; Ya afuera.

	;; Payload al destino. Maximo tamano 240KiB y por eso cuando armamos imagen 
	;; se deberia revisar que no sea mayor. Un posible payload es:
	;;  +--------------------+----------------------------------+
	;;  | uefiBootloader.sys | kernel.bin + modulosUserland.bin |
	;;  +--------------------+----------------------------------+
	;;  |<------ 6KiB ------>|<------------ 234KiB ------------>|
	;;  |^                   |^                                 |^
	;; 0x8000              0x9800                             0x44000          
	mov rsi, PAYLOAD
	mov rdi, 0x8000
	mov rcx, (240 * 1024)	;; 240KiB a partir de 0x8000
	rep movsb				;; Ultimo byte escrito = 0x8000 + (240 * 1024) - 1 =
							;; 0x43FFF

	;; Datos de video pasamos a siguiente etapa de bootloader. Movemos y queda:
	;; qword [0x00005F00] = Frame buffer base
	;; qword [0x00005F08] = Frame buffer size (bytes)
	;; dword [0x00005F10] = Screen X
	;; dword [0x00005F12] = Screen Y
	;; dword [0x00005F14] = PixelsPerScanLine

	mov rdi, 0x00005F00
	mov rax, [FB]
	stosq				;; 5F00 + 8 * 0 = 64-bit Frame Buffer.
	mov rax, [FB_SIZE]
	stosq				;; 5F00 + 8 * 1 = 64-bit Frame Buffer Size in bytes.
	mov rax, [HR]
	stosw				;; 5F00 + 8 * 2 + 2 * 0 = 16-bit Screen X.
	mov rax, [VR]
	stosw				;; 5F00 + 8 * 2 + 2 * 1 = 16-bit Screen Y.
	mov rax, [PPSL]
	stosw				;; 5F00 + 8 * 2 + 2 * 2 = 16-bit PixelsPerScanLine.
	mov rax, 32			;; BPP hardcodeado, supuestamente uefi siempre 32? Grub 
						;; muestra que hay modos con 24 seleccionables.
	stosw				;; 16-bit BitsPerPixel

	mov rax, [memmap]			;; Mem map base address.
	stosq
	mov rax, [memmapsize]		;; Mem Map size [bytes]
	stosq
	mov rax, [memmapkey]		;; Key to exit Boot Services.
	stosq
	mov rax, [memmapdescsize]	;; EFI_MEMORY_DESCRIPTOR size [bytes]
	stosq
	mov rax, [memmapdescver]	;; EFI_MEMORY_DESCRIPTOR version.
	stosq
	mov rax, [ACPI]				;; ACPI Table Address.
	stosq
	mov rax, [EDID]				;; EDID Data [SizeOfEdi,d *Edid].
	stosq

	;; Append 2 blank entries to end of UEFI memory map (uncomment if necessary)
	 mov rdi, [memmap]
	 add rdi, [memmapsize]
	 mov rcx, [memmapdescsize]
	 shl rcx, 1
	 xor rax, rax
	 rep stosb

	;;mov rax, 0x00000000000101F0
	;;call keyboard_command

	mov r9, msg_boot_services_exit_ok
	call print

;;locate_device_path_protocol:
;;mov rcx, EFI_DEVICE_PATH_PROTOCOL_GUID	;; IN EFI_GUID *Protocol
;;	mov rdx, 0								;; IN VOID *Registration OPTIONAL
;;	mov r8, PROTOCOL_DEVICE_PATH			;; OUT VOID **Interface
;;	mov rax, [EFI_BOOT_SERVICES]
;;	mov rax, [rax + EFI_BOOT_SERVICES_LOCATEPROTOCOL]
;;	call rax
;;	mov rsi, str_edid_active_protocol		;; Para mostrar info en pantalla.
;;	cmp rax, EFI_SUCCESS
;;	je get_EDID

	call emptyKbBuffer
	call keyboard_get_key	;; Poleo para poder promptear ahora que hemos salido
							;; de bootservices.
step
	xor rax, rax
	xor rcx, rcx
	xor rdx, rdx
	xor rbx, rbx
	mov rsp, 0x8000
	xor rbp, rbp
	xor rsi, rsi
	xor rdi, rdi
	xor r8, r8
	xor r9, r9
	xor r10, r10
	xor r11, r11
	xor r12, r12
	xor r13, r13
	xor r14, r14
	xor r15, r15

	mov bl, 'U'

	mov rax, 0x8000
	jmp rax	;; Vamos a siguiente loader. Aprox 0x400702


;;==============================================================================
;; error_fatal | Notifica err fatal (utf16) y cuelga.
;; Argumentos:
;; -- rsi = string descripcion del error.
;;
;; En la pantalla imprime: "Error fatal: %s" donde %s es el string en rsi. Luego
;; se queda en hlt.
;;==============================================================================

;; Podria setearse el fondo de color, o el texto.
error_fatal:
	mov rdx, fmt_err_fatal
	call efi_print
	jmp halt


;;==============================================================================
;; error_fatal8 | Notifica err fatal (utf8) y cuelga.
;; Argumentos:
;; -- rsi = string descripcion del error.
;;
;; En la pantalla imprime: "Error fatal: %s" donde %s es el string en rsi. Luego
;; se queda en hlt.
;;==============================================================================

error_fatal8:
	mov r9, fmt_err_fatal8
	call print
	jmp halt

payloadSignatureFail:
	mov r9, msg_badPayloadSignature
	call print


;;==============================================================================
;; halt
;;==============================================================================

halt:
	cli
	hlt
	jmp halt


;;==============================================================================
;; Cuidado con la posicion de estas tablas, no se pudede cambiar porque por el m
;; omento estan hardcodeadas las posiciones relativas de la misma donde bootload
;; er.asm busca, por ejemplo, ACPI.
;;==============================================================================

section .data

EFI_IMAGE_HANDLE:	    dq 0	;; rcx at entry point.
EFI_SYSTEM_TABLE:	    dq 0	;; rdx at entry point.
EFI_IMG_RET_ADDR:	    dq 0
EFI_BOOT_SERVICES:	    dq 0    ;; *BootServices
RTS:				    dq 0	;; *RuntimeServices;
CONFIG_TABLE:		    dq 0	;; *ConfigurationTable
ACPI:				    dq 0	;; ACPI table address
CONOUT_INTERFACE:	    dq 0	;; Output services
CONIN_INTERFACE_HANDLE:	dq 0	;; ConsoleInHandle
CONIN_INTERFACE:	    dq 0	;; Input services
VIDEO_INTERFACE:	    dq 0	;; Video services
EDID:				    dq 0    ;; [SizeOfEdid, *Edid]
FB:					    dq 0	;; Frame buffer base address
FB_SIZE:			    dq 0	;;
HR:					    dq 0	;; Horizontal Resolution
VR:					    dq 0	;; Vertical Resolution
PPSL:				    dq 0	;; PixelsPerScanLine
BPP:					dq 0	;; BitsPerPixel
memmap:				dq 0x220000	;; Address donde quedara el mapa de memoria.
memmapsize:			dq 32768	;; Tamano max del  buffer para memmap [bytes].
memmapkey:			dq 0
memmapdescsize:		dq 0
memmapdescver:		dq 0
vid_orig:			dq 0
vid_index:			dq 0
vid_max:			dq 0
vid_size:			dq 0
vid_info:			dq 0

;; Para localizar el device path del text input.
EFI_DEVICE_PATH_PROTOCOL_GUID:
	dd	0x09576e91
	dw	0x6d3f, 0x11d2
	db	0x8e, 0x39, 0x00, 0xA0, 0xC9, 0x69, 0x72, 0x3B

EFI_DEVICE_PATH_PROTOCOL:   dq 0    ;; Voy a pedir el de conin.

EFI_SIMPLE_TEXT_INPUT_PROTOCOL_GUID:
	dd	0x387477c1
	dw	0x69c7, 0x11d2
	db 0x8e, 0x39, 0x0, 0xa0, 0xc9, 0x69, 0x72, 0x3b

EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL_GUID:
	dd	0x387477c2
	dw	0x69c7, 0x11d2
	db 0x8e, 0x39, 0x0, 0xa0, 0xc9, 0x69, 0x72, 0x3b

;; typedef struct {
;; UINT16	ScanCode;
;; CHAR16	UnicodeChar;
;; } EFI_INPUT_KEY;
EFI_INPUT_KEY		dw 0, 0

STEP_MODE_FLAG		db 0	;; Lo activa presionar 's' al booteo.

;; Lo que pide al GOP por defecto si no encuentra EDID. Para qemu, cambiar esto 
;; va a cambiar la resolucion de la pantalla.
Horizontal_Resolution:	dd 1024
Vertical_Resolution:	dd 768

ACPI_TABLE_GUID:
	dd 0xeb9d2d30
	dw 0x2d88, 0x11d3
	db 0x9a, 0x16, 0x00, 0x90, 0x27, 0x3f, 0xc1, 0x4d

;; github.com/tianocore/edk2/blob/master/MdePkg/Include/Protocol/EdidActive.h
EFI_EDID_ACTIVE_PROTOCOL_GUID:
	dd 0xbd8c1056
	dw 0x9f36, 0x44ec
	db 0x92, 0xa8, 0xa6, 0x33, 0x7f, 0x81, 0x79, 0x86

EFI_EDID_DISCOVERED_PROTOCOL_GUID:
	dd 0x1c0c34f6
	dw 0xd380, 0x41fa
	db 0xa0, 0x49, 0x8a, 0xd0, 0x6c, 0x1a, 0x66, 0xaa

;; https://github.com/tianocore/edk2/blob/master/MdePkg/Include/Protocol/Graphic
;; sOutput.h
EFI_GRAPHICS_OUTPUT_PROTOCOL_GUID:
	dd 0x9042a9de
	dw 0x23dc, 0x4a38
	db 0x96, 0xfb, 0x7a, 0xde, 0xd0, 0x80, 0x51, 0x6a


msg_placeholder dw 0,0,0,0,0,0,0,0	;; Reserve 8 words for the buffer.
msg_placeholder_len equ ($ - msg_placeholder)

print_pending_msg:	dq 0, 0	;; Espacio para los 2 argumentos de funcion print. U
							;; til para establecer un mensaje distinto segun con
							;; diciones e imprimir en 1 solo lugar el mensaje q
							;; haya ocurrido.
aux_buffer dq 0
aux_buf_size dq 128


;; UTF16 strings para bootservices.
msg_error:								dw utf16("Error"), 0
msg_locate_edid_fail_use_default_resol:	dw	utf16("Locate EDID fail: ")
										dw	utf16("se usara resolucion ")
										dw	utf16("por defecto"), 13, 0xA, 0

fmt_edid_validation_fail:	dw utf16("EDID validation failure = %s"), 13, 0xA, 0
str_edid_size_err:			dw utf16("error de tamano"), 0
str_edid_hdr_err:			dw utf16("error en el encabezado"), 0

efi_fmt_resolution_horizontal:	dw utf16("Video resolution = %d"), 0
efi_fmt_resolution_vertical:	dw utf16(" x %d"), 13, 0xA, 0
efi_fmt_ppsl:					dw utf16("PPSL = %d"), 0
efi_fmt_fb_size:				dw utf16(" | Framebuffer = %d bytes"), 0
efi_fmt_fb_address:				dw utf16(" | Address = 0x%h"), 13, 0xA, 0

msg_graphics_mode_info_match:	dw utf16("Graphics mode info match."), 13, 0xA
								dw utf16("SetMode()..."), 13, 0xA
								dw utf16("[tecla 'n' para continuar]"), 13, 0xA, 0

msg_acpi_err:					dw utf16("ACPI no encontrado."), 0
fmt_err_fatal:					dw utf16("Error fatal: %s"), 0
fmt_max_txt_mode:				dw utf16("Max txt mode = %d"), 0
fmt_curr_txt_mode:				dw utf16(" | Curr mode = %d"), 13, 0xA, 0
fmt_fw_vendor:					dw utf16("FW vendor = %s"), 13, 0xA, 0

str_edid_active_protocol:		dw utf16("active protocol"), 0
str_edid_discovered_protocol:	dw utf16("discovered protocol"), 0
fmt_edid_protocol_located:		dw utf16("EDID protocol found = %s"), 13, 0xA, 0

str_gop_protocol_fatal_err:		dw utf16("GOP protocol no localizado"), 0

msg_por: 						dw utf16(" x "), 0
msg_efi_success:				dw utf16("EFI success"), 13, 0xA, 0
msg_efi_not_ready:				dw utf16("EFI not ready"), 13, 0xA, 0
txt_err_memmap:					dw utf16("get memmap feilure"), 0


;; UTF8 strings para bootloader.
msg_badPayloadSignature:		db "Payload signature check failed.", 0

fmt_resolution_horizontal:		db "Video resolution = %d", 0
fmt_resolution_vertical:		db " x %d", 13, 0xA, 0
fmt_ppsl:						db "PPSL = %d", 0
fmt_fb_size:					db " | Framebuffer = %d bytes", 0
fmt_fb_address:					db " | Address = 0x%h", 13, 0xA, 0

msg_gop_no_mode_matches:	db "Graphics mode: no mode matches.", 13, 0xA, 0
msg_graphics_success:		db "Cambio de modo de video ok "
							db "| Nuevo modo = %d", 13, 0xA, 0

msg_notify_memmap_change:		db "Memory map buffer size change: "
								db "will request again.", 13, 0xA, 0


fmt_memmap_cant_descriptors:	db	"Uefi returned a memory map "
								db	"| Cant descriptors = %d", 13, 0xA, 0
fmt_memmap_descriptor_size:		db	"Memory map descriptor size = %d [bytes]"
								db	" (reported)", 13, 0xA, 0

fmt_err_fatal8:					db "Error fatal: %s", 0

msg_boot_services_exit:			db "ExitBootSerivces()...", 0x0A, 0
msg_boot_services_exit_ok:		db "Exit from UEFI services OK "
								db "(ret val = EFI_SUCCESS).", 0x0A, 0

msg_handlebuffer_err:			db "HandleBuffer() error.", 0x0A, 0
msg_handlebuffer_ok:			db "HandleBuffer() returned EFI_SUCCESS"
								db " | Number of handlers = %d", 0x0A, 0
msg_conin_handle_value			db "Conin handle val = %h | Located: ", 0
msg_located_index				db " [%d] = ", 0
msg_located_value				db "%h", 0
newline8						db 0x0A, 0

msg_handleprotocol_err:		db "HandleProtocol() error.", 0x0A, 0
msg_handleprotocol_ok:		db "HandleProtocol() returned EFI_SUCCESS.", 0x0A, 0

msg_reference				db "conin interface = %d", 0x0A, 0
msg_located					db "located interface = %d", 0


;;==============================================================================
;; Here goes the payload
;; =============================================================================

section .payload

PAYLOAD:
times 240 * 1024 db 0x00

;; Padeo con ceros. Suficientes 0x00 para obtener un tamano de archivo de 1MiB. 
;; Le resto tambien los 16Kib que son el comienzo de la seccion, ocupada por hea
;; der y code.
times 1048576 - ($ - $$) - 16 * 1024	db 0

