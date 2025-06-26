;;==============================================================================
;; UEFI bootloader
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
;; 0x0      0x200     0xC00   0x2000      0x2800      0x40000      0xFFFFF
;; 0        512B      3KiB    8KiB        10KiB       256KiB       1MiB-1

;;==============================================================================


BITS 64
ORG 0x00400000

%define utf16(x) __utf16__(x)

START:
PE:
HEADER:

;; Header DOS, 128 bytes.
DOS_SIGNATURE:			db "MZ", 0x00, 0x00
DOS_HDRS:			times 60-($-HEADER) db 0
PE_SIGNATURE_OFFSET:	dd PE_SIGNATURE - START	;; File offset.
DOS_STUB:				times 64 db 0			;; No program, zero fill.

;; Encabezado PE.
PE_SIGNATURE:			db "PE", 0x00, 0x00

;; COFF File Header, 20 bytes.
MACHINE_TYPE:			dw 0x8664	;; x86-64 machine.
N_SECTIONS:				dw 2		;; Number of entries in section table. Secti
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
MAGIC_NUMBER:			dw 0x020B ;; PE32+ (64-bit address space) PE format.
MAJOR_LINKER_VERSION:	db 0
MINOR_LINKER_VERSION:	db 0
CODE_SIZE:					dd CODE_END - CODE	;; Text.
INITIALIZED_DATA_SIZE:		dd DATA_END - DATA	;; Data.
UNINITIALIZED_DATA_SIZE:	dd 0x00				;; Bss.
ENTRY_POINT_ADDR:		dd EntryPoint - START	;; Entry point relative to img b
												;; ase loaded in memory.
BASE_OF_CODE_ADDR:		dd CODE - START	;; Relative addr of base of code sect.
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
IMAGE_SIZE:				dd END - START	;; The size [bytes] of img loaded in mem
										;; including all headers. Must be multip
										;; le of SectionAlignment (?). Aparentem
										;; ente no es mandatorio. 

HEADERS_SIZE:			dd HEADER_END - HEADER	;; Size of all the headers.
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
SECTION_CODE:
.name					db ".text", 0x00, 0x00, 0x00
.virtual_size			dd CODE_END - CODE
.virtual_address		dd CODE - START
.size_of_raw_data		dd CODE_END - CODE
.pointer_to_raw_data		dd CODE - START
.pointer_to_relocations		dd 0
.pointer_to_line_numbers	dd 0
.number_of_relocations		dw 0
.number_of_line_numbers		dw 0
.characteristics			dd 0x70000020
;; Section flags:
;; IMAGE_SCN_MEM_SHARED		0x10000000 Can be shared in memory.
;; IMAGE_SCN_MEM_EXECUTE	0x20000000 Can be executed as code.
;; IMAGE_SCN_MEM_READ		0x40000000 Can be read.
;; IMAGE_SCN_CNT_CODE		0x00000020 Contains executable code.

SECTION_DATA:
.name						db ".data", 0x00, 0x00, 0x00
.virtual_size				dd DATA_END - DATA
.virtual_address			dd DATA - START
.size_of_raw_data			dd DATA_END - DATA
.pointer_to_raw_data		dd DATA - START
.pointer_to_relocations		dd 0
.pointer_to_line_numbers	dd 0
.number_of_relocations		dw 0
.number_of_line_numbers		dw 0
.characteristics			dd 0xD0000040
;; Section flags:
;; IMAGE_SCN_MEM_SHARED				0x10000000 Can be shared in memory.
;; IMAGE_SCN_MEM_READ				0x40000000 Can be read.
;; IMAGE_SCN_CNT_INITIALIZED_DATA	0x00000040 Contains initialized data.
;; IMAGE_SCN_MEM_WRITE				0x80000000 Can be written to.

;; El header ocupo exactamente 0x160 bytes. Lo alineo a 0x200 para que termine o
;; cupando 512 bytes.
HEADER_END:
align 0x200


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
;; Rest of arguments passed by stack after the shadow store before the call. Rig
;; ht-to-left order push. All arguments passed on the stack are 8-byte aligned.
;; The x64 ABI considers the registers RAX, RCX, RDX, R8, R9, R10, R11, and XMM0
;; -XMM5 volatile (not preserved by called function).
;; Note: EFI, for every supported architecture defines exact ABI.

CODE:
EntryPoint: ;; Ubicado en 0x400200 cuando imagen va en 0x400000

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
	;; ue a veces recomiendan 64. No he encontrado ningun documento que avale es
	; o, por lo que me voy a atener a las especificaciones documentadas que indi
	;; can 32 bytes para los 4 registros.
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
	mov [CONFIG], rax

	mov rax, [EFI_SYSTEM_TABLE]
	mov rax, [rax + EFI_SYSTEM_TABLE_CONIN]
	mov [TXT_IN_INTERFACE], rax

	mov rax, [EFI_SYSTEM_TABLE]
	mov rax, [rax + EFI_SYSTEM_TABLE_CONOUT]
	mov [TXT_OUT_INTERFACE], rax

	;; SIMPLE_TEXT_OUTPUT.SetAttribute(). Sets the background and foreground col
	;; ors for the OutputString() and ClearScreen() functions.
	mov rcx, [TXT_OUT_INTERFACE] 
	mov rdx, 0x07	;; IN UINTN Attribute = Black background, grey foreground.
	call [rcx + EFI_OUT_SET_ATTRIBUTE]

	;; SIMPLE_TEXT_OUTPUT.ClearScreen(). Clears output device(s) display to the 
	;; currently selected background color. Cursor position is set to (0, 0).
	mov rcx, [TXT_OUT_INTERFACE]	
	call [rcx + EFI_OUT_CLEAR_SCREEN]

	;; -- Modo texto de uefi, imprime en un recuadro centrado en la pantalla ind
	;; ependientemente de la resolucion real. Por defecto 80x25 (mode = 0) pero 
	;; si hay otro modo soportado lo usa.
	;; -- Aqui, hlt unicamente no va a haltear. Debe hacer cli, luego hlt.

	mov rcx, [TXT_OUT_INTERFACE]
	mov rbx, [rcx + EFI_OUT_MODE]
	mov rax, [rbx]
	mov rbx, 0
	mov ebx, eax
	mov rdx, msg_max_txt_mode
	call print	;; Current video settings del modo texto con el q inicia.

	mov rcx, [TXT_OUT_INTERFACE]
	mov rbx, [rcx + EFI_OUT_MODE]
	mov rax, [rbx + 4]
	mov rbx, 0
	mov ebx, eax
	mov rdx, msg_curr_txt_mode
	call print	;; Current video settings del modo texto con el q inicia.






	mov rcx, [TXT_IN_INTERFACE]
	mov rdx, EFI_INPUT_KEY	
	call [rcx + EFI_INPUT_READ_KEY]	;; SIMPLE_INPUT.ReadKeyStroke()
	cmp eax, EFI_NOT_READY			;; No hubo ingreso, sigo normalmente. Descar
									;; ta bit 63, de otro modo compararia mal
	je .continue_no_step_mode

	cmp rax, EFI_SUCCESS
	je .get_key

	mov rcx, [TXT_OUT_INTERFACE]	
	mov rdx, msg_efi_input_device_err	;; Notificar, rax = EFI_DEVICE_ERROR
	call [rcx + EFI_OUT_OUTPUTSTRING]
	jmp .continue_no_step_mode			;; Sigo, a pesar del error.
	
.get_key:
	mov dx, [EFI_INPUT_KEY + 2]
	cmp dx, utf16('s')
	jne .continue_no_step_mode
	mov byte [STEP_MODE_FLAG], 1

	mov rcx, [TXT_OUT_INTERFACE]	
	mov rdx, msg_step_mode
	call [rcx + EFI_OUT_OUTPUTSTRING]

.continue_no_step_mode:
	mov rcx, [TXT_OUT_INTERFACE]	
	lea rdx, [msg_uefi_boot]			
	call [rcx + EFI_OUT_OUTPUTSTRING]

;; Primer parada en el modo step.
	call parada_step_mode

;;step_0:
;;	mov rcx, [TXT_IN_INTERFACE]
;;	mov rdx, EFI_INPUT_KEY	
;;	call [rcx + EFI_INPUT_READ_KEY]	;; SIMPLE_INPUT.ReadKeyStroke()
;;	cmp eax, EFI_NOT_READY			;; No hubo ingreso, me quedo poleando.
;;	je step_0
;;
;;	cmp rax, EFI_SUCCESS
;;	je .get_key
;;
;;	mov rcx, [TXT_OUT_INTERFACE]	
;;	mov rdx, msg_efi_input_device_err	;; Notificar, rax = EFI_DEVICE_ERROR
;;	call [rcx + EFI_OUT_OUTPUTSTRING]
;;	jmp step_0
;;	
;;.get_key:
;;	mov dx, [EFI_INPUT_KEY + 2]
;;	cmp dx, utf16('n')
;;	jne step_0						;; Posible salida a siguiente paso.



	;; Find the address of the ACPI data from the UEFI configuration table.
	mov rax, [EFI_SYSTEM_TABLE]
	mov rcx, [rax + EFI_SYSTEM_TABLE_NUMBEROFENTRIES]
	shl rcx, 3						; rcx * 2^3
	mov rsi, [CONFIG]
	
nextentry:
	dec rcx
	cmp rcx, 0
	je error						; Bail out as no ACPI data was detected
	mov rdx, [ACPI_TABLE_GUID]		; First 64 bits of the ACPI GUID
	lodsq
	cmp rax, rdx					; Compare table data to expected GUID data
	jne nextentry
	mov rdx, [ACPI_TABLE_GUID+8]	; Second 64 bits of the ACPI GUID
	lodsq
	cmp rax, rdx					; Compare table data to expected GUID data
	jne nextentry
	lodsq							; Load the address of the ACPI table
	mov [ACPI], rax					; Save the address

	;; Configurar pantalla. Algunas definiciones:
	;; https://www.intel.com/content/dam/doc/guide/uefi-driver-graphics-controll
	;; er-guide.pdf
	;; https://uefi.org/specs/UEFI/2.10/12_Protocols_Console_Support.html
	;; Primero intenta encontrar un EDID, si no encuentra, prueba una resolucion
	;; por defecto directo con el GOP.

	;; Intento 1: interface to EFI_EDID_ACTIVE_PROTOCOL_GUID via its GUID
	mov rcx, EFI_EDID_ACTIVE_PROTOCOL_GUID	; IN EFI_GUID *Protocol
	mov rdx, 0						; IN VOID *Registration OPTIONAL
	mov r8, EDID					; OUT VOID **Interface
	mov rax, [EFI_BOOT_SERVICES]
	mov rax, [rax + EFI_BOOT_SERVICES_LOCATEPROTOCOL]
	call rax
	cmp rax, EFI_SUCCESS
	je get_EDID						; If it exists, process EDID

	;; Intento 2: interface to EFI_EDID_DISCOVERED_PROTOCOL_GUID via its GUID
	mov rcx, EFI_EDID_DISCOVERED_PROTOCOL_GUID		; IN EFI_GUID *Protocol
	mov rdx, 0						; IN VOID *Registration OPTIONAL
	mov r8, EDID					; OUT VOID **Interface
	mov rax, [EFI_BOOT_SERVICES]
	mov rax, [rax + EFI_BOOT_SERVICES_LOCATEPROTOCOL]
	call rax
	cmp rax, EFI_SUCCESS
	je get_EDID						; If it exists, process EDID
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	jmp use_GOP						; If not found, or other error, use GOP con una resolucion por defecto hardcodeada.
jmp edid_fail_use_GOP;; fail message, then use gop.

	; Gather preferred screen resolution
get_EDID:

push rcx;;; diria que no es necesario, por ahora lo dejo
push rdx
mov rcx, [TXT_OUT_INTERFACE]					
lea rdx, [msg_edid_found]					
call [rcx + EFI_OUT_OUTPUTSTRING]
pop rdx
pop rcx

	;; Parse EDID information returned.
	;; https://bsdio.com/edk2/docs/master/_edid_active_8h_source.html
	;; typedef struct {
	;; UINT32    SizeOfEdid;
 	;; UINT8    *Edid;
	;; } EFI_EDID_ACTIVE_PROTOCOL;

	mov rax, [EDID]
	mov ebx, [rax]
	cmp ebx, 128	;; Minimum size of 128 bytes.
;;;;;;;;;;;;;;;;;;;;;;;	jb use_GOP						; Fail out to GOP with default resolution
jb edid_fail_default;; err msg, then continue
;;;;;; En realidad, aqui, si hubo fail en active protocol, aun tengo oportunidad de un success con discovered protocol, en lugar de ir directo a gop, puedo probar el discovered (aunque por lo general van a ser el mismo, salvo override).


	mov rbx, [rax + 8]			;; Pointer to EDID. Why not +4? Yes, why? Pendie
								;; nte: revisar que este codigo corra en algun m
								;; omento y lo haga bien.

	mov rax, [rbx]				;; Load RAX with EDID header.
	mov rcx, 0x00FFFFFFFFFFFF00	;; Required EDID header
	cmp rax, rcx				;; Verify 8-byte header at 0x00 is 0x00FFFFFFFFFFFF00
;;;;;;;;;;;;;	jne use_GOP						; Fail out to GOP with default resolution
jb edid_fail_default;; err msg, then continue
	
	; Preferred Timing Mode starts at 0x36
	; 0x38 - Lower 8 bits of Horizontal pixels in bits 7:0
	; 0x3A - Upper 4 bits of Horizontal pixels in bits 7:4
	; 0x3B - Lower 8 bits of Vertical pixels in bits 7:0
	; 0x3D - Upper 4 bits of Vertical pixels in bits 7:4
	xor eax, eax
	xor ecx, ecx
	mov al, [rbx+0x38]
	mov cl, [rbx+0x3A]
	and cl, 0xF0						; Keep bits 7:4
	shl ecx, 4
	or eax, ecx
	mov [Horizontal_Resolution], eax
	xor eax, eax
	xor ecx, ecx
	mov al, [rbx+0x3B]
	mov cl, [rbx+0x3D]
	and cl, 0xF0						; Keep bits 7:4
	shl ecx, 4
	or eax, ecx
	mov [Vertical_Resolution], eax

;;;;;;;;;;;;;;;;;;;;; informar resolucion
;;;; tengo que hacerlo mas sintetico, no puede pasar 2k el codigo. Por ahora comento.

;;mov rcx, [TXT_OUT_INTERFACE]					
;;lea rdx, [msg_resolution]					
;;call [rcx + EFI_OUT_OUTPUTSTRING]

;push msg_placeholder
;push qword[Horizontal_Resolution]
;call num2strWord
;add rsp, 8*2

;mov rcx, [TXT_OUT_INTERFACE]					
;lea rdx, [msg_placeholder]					
;call [rcx + EFI_OUT_OUTPUTSTRING]

;mov rcx, [TXT_OUT_INTERFACE]					
;lea rdx, [msg_por]					
;call [rcx + EFI_OUT_OUTPUTSTRING]

;push msg_placeholder
;push qword[Vertical_Resolution]
;call num2strWord
;add rsp, 8*2

;mov rcx, [TXT_OUT_INTERFACE]					
;lea rdx, [msg_placeholder]					
;call [rcx + EFI_OUT_OUTPUTSTRING]

jmp use_GOP

;;;;;;;;;;;; Ni siquiera encontro el edid
edid_fail_use_GOP:
push rcx;;; diria que no es necesario, por ahora lo dejo
push rdx
mov rcx, [TXT_OUT_INTERFACE]					
lea rdx, [msg_edid_not_found]					
call [rcx + EFI_OUT_OUTPUTSTRING]
pop rdx
pop rcx
jmp use_GOP


;;;;;;;;;; Encuentra edid pero No encuentra la resolucion por defecto
edid_fail_default:
push rcx;;; diria que no es necesario, por ahora lo dejo
push rdx
mov rcx, [TXT_OUT_INTERFACE]					
lea rdx, [msg_edid_fail_default]					
call [rcx + EFI_OUT_OUTPUTSTRING]
pop rdx
pop rcx
jmp use_GOP






	; Set video to desired resolution. By default it is 1024x768 unless EDID was found
use_GOP:	;; @0x400366



	; Find the interface to GRAPHICS_OUTPUT_PROTOCOL via its GUID
	mov rcx, EFI_GRAPHICS_OUTPUT_PROTOCOL_GUID		; IN EFI_GUID *Protocol
	mov rdx, 0						; IN VOID *Registration OPTIONAL
	mov r8, VIDEO						; OUT VOID **Interface
	mov rax, [EFI_BOOT_SERVICES]
	mov rax, [rax + EFI_BOOT_SERVICES_LOCATEPROTOCOL]
	call rax
	cmp rax, EFI_SUCCESS
	jne error

	; Parse the current graphics information
	; EFI_GRAPHICS_OUTPUT_PROTOCOL_MODE Structure
	; 0  UINT32 - MaxMode
	; 4  UINT32 - Mode
	; 8  EFI_GRAPHICS_OUTPUT_MODE_INFORMATION - *Info;
	; 16 UINTN - SizeOfInfo
	; 24 EFI_PHYSICAL_ADDR - FrameBufferBase
	; 32 UINTN - FrameBufferSize
    mov rax, [VIDEO]
	add rcx, EFI_GRAPHICS_OUTPUT_PROTOCOL_MODE
	mov rcx, [rcx]						; RCX holds the address of the Mode structure
	mov eax, [rcx]						; EAX holds UINT32 MaxMode
	mov [vid_max], rax					; The maximum video modes we can check
	jmp vid_query

next_video_mode:
	mov rax, [vid_index]
	add rax, 1						; Increment the mode # to check
	mov [vid_index], rax
	mov rdx, [vid_max]
	cmp rax, rdx
	je skip_set_video					; If we have reached the max then bail out

;; Recorre arreglo buscando modo de video
vid_query:
	; Query a video mode
	mov rcx, [VIDEO]					; IN EFI_GRAPHICS_OUTPUT_PROTOCOL *This
	mov rdx, [vid_index]					; IN UINT32 ModeNumber
	lea r8, [vid_size]					; OUT UINTN *SizeOfInfo
	lea r9, [vid_info]					; OUT EFI_GRAPHICS_OUTPUT_MODE_INFORMATION **Info
	call [rcx + EFI_GRAPHICS_OUTPUT_PROTOCOL_QUERY_MODE]

	; Check mode settings
	mov rsi, [vid_info]
	lodsd							; UINT32 - Version
	lodsd							; UINT32 - HorizontalResolution
	cmp eax, [Horizontal_Resolution]
	jne next_video_mode
	lodsd							; UINT32 - VerticalResolution
	cmp eax, [Vertical_Resolution]
	jne next_video_mode
	lodsd							; EFI_GRAPHICS_PIXEL_FORMAT - PixelFormat (UINT32)
	bt eax, 0						; Bit 0 is set for 32-bit colour mode
	jnc next_video_mode


;; Si llego hasta aqui, he encontrado el modo con resolucion apropiada segun edid
;;mov rcx, [TXT_OUT_INTERFACE]					
;;lea rdx, [msg_graphics_mode_info_found]					
;;call [rcx + EFI_OUT_OUTPUTSTRING]




	; Set the video mode
	mov rcx, [VIDEO]					; IN EFI_GRAPHICS_OUTPUT_PROTOCOL *This
	mov rdx, [vid_index]					; IN UINT32 ModeNumber
	call [rcx + EFI_GRAPHICS_OUTPUT_PROTOCOL_SET_MODE]
	cmp rax, EFI_SUCCESS
	jne next_video_mode
;; se acaba de resetear el buffer de video, se blanquea la pantalla.
;; antes se veia baja resolucion, ahora se setea la nueva seleccionada resolucion
;; voy a volver a mostrar en pantalla los datos de resolucion configurados
;; Aclaracion: aun sigo sin poder usar hlt
	
	
video_mode_success:

;; Logra setear
push rcx;;; diria que no es necesario, por ahora lo dejo
push rdx
mov rcx, [TXT_OUT_INTERFACE]					
lea rdx, [msg_graphics_success]					
call [rcx + EFI_OUT_OUTPUTSTRING]
pop rdx
pop rcx

jmp get_video

	
skip_set_video:



push rcx;;; diria que no es necesario, por ahora lo dejo
push rdx
mov rcx, [TXT_OUT_INTERFACE]					
lea rdx, [msg_graphics_mode_info_not_found]					
call [rcx + EFI_OUT_OUTPUTSTRING]
pop rdx
pop rcx



;; haya econtrado match en un video mode y logrado setearlo, o no, continua (si no pudo, con la resolucion
;; por defecto y posiblemente no este bien configurado el video, podria fallar, pero va a buscar info igual)
get_video:	;; @0x40046d




	; Gather video mode details
	mov rcx, [VIDEO]
	add rcx, EFI_GRAPHICS_OUTPUT_PROTOCOL_MODE
	mov rcx, [rcx]						; RCX holds the address of the Mode structure
	mov rax, [rcx+24]					; RAX holds the FB base
	mov [FB], rax						; Save the FB base
	mov rax, [rcx+32]					; RAX holds the FB size
	mov [FB_SIZE], rax						; Save the FB size. No necesariamente es 
	;;;;;;;;; igual a w x h x bpp porque podria ser mas. Ejemplo: 800 x 600 = 1920000 pero
	;;;;;;;;; el fbzise podria ser 1921024
	mov rcx, [rcx+8]					; RCX holds the address of the EFI_GRAPHICS_OUTPUT_MODE_INFORMATION Structure
	; EFI_GRAPHICS_OUTPUT_MODE_INFORMATION Structure
	; 0  UINT32 - Version
	; 4  UINT32 - HorizontalResolution
	; 8  UINT32 - VerticalResolution
	; 12 EFI_GRAPHICS_PIXEL_FORMAT - PixelFormat (UINT32)
	; 16 EFI_PIXEL_BITMASK - PixelInformation (4 UINT32 - RedMask, GreenMask, BlueMask, ReservedMask)
	; 32 UINT32 - PixelsPerScanLine - Defines the number of pixel elements per video memory line. Scan lines may be padded for memory alignment.
	mov eax, [rcx+4]					; RAX holds the Horizontal Resolution
	mov [HR], rax						; Save the Horizontal Resolution
	mov eax, [rcx+8]					; RAX holds the Vertical Resolution
	mov [VR], rax						; Save the Vertical Resolution
	mov eax, [rcx+32]					; RAX holds the PixelsPerScanLine
	mov [PPSL], rax						; Save the PixelsPerScanLine










;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;	mov rcx, [TXT_OUT_INTERFACE]					
;;	lea rdx, [msg_error]					
;;	call [rcx + EFI_OUT_OUTPUTSTRING]













;;;;;;;;;;;;;;;;; imprime info screen en pantalla de el modo seleccionado / valores que quedaron
;; imprime esto: 
;; horizResol x vertResol x ppsl x fbSize
;;mov rcx, [TXT_OUT_INTERFACE]					
;;lea rdx, [msg_resolution]					
;;call [rcx + EFI_OUT_OUTPUTSTRING]

push msg_placeholder
push qword[HR]
call num2strWord
add rsp, 8*2

mov rcx, [TXT_OUT_INTERFACE]					
lea rdx, [msg_placeholder]					
call [rcx + EFI_OUT_OUTPUTSTRING]

mov rcx, [TXT_OUT_INTERFACE]					
lea rdx, [msg_por]					
call [rcx + EFI_OUT_OUTPUTSTRING]

push msg_placeholder
push qword[VR]
call num2strWord
add rsp, 8*2

mov rcx, [TXT_OUT_INTERFACE]					
lea rdx, [msg_placeholder]					
call [rcx + EFI_OUT_OUTPUTSTRING]

;;;;;;;;;;;;;; ppsl
;;mov rcx, [TXT_OUT_INTERFACE]					
;;lea rdx, [msg_por]					
;;call [rcx + EFI_OUT_OUTPUTSTRING]

;;push msg_placeholder
;;push qword[PPSL]
;;call num2strWord
;;add rsp, 8*2

;;mov rcx, [TXT_OUT_INTERFACE]					
;;lea rdx, [msg_placeholder]					
;;call [rcx + EFI_OUT_OUTPUTSTRING]



;;;;;;;;;;;;;; framebuffer size
mov qword[msg_placeholder],0
mov qword[msg_placeholder+8],0

mov rcx, [TXT_OUT_INTERFACE]					
lea rdx, [msg_por]					
call [rcx + EFI_OUT_OUTPUTSTRING]

push msg_placeholder
push qword[FB_SIZE]
call num2strWord
add rsp, 8*2

mov rcx, [TXT_OUT_INTERFACE]					
lea rdx, [msg_placeholder]					
call [rcx + EFI_OUT_OUTPUTSTRING]



;;; parate aqui si quisieras ver los seteos que le va a pasar al siguiente bootloader.

	mov rsi, PAYLOAD + 6
	mov rax, [rsi]
	mov rbx, "UEFIBOOT"	;; Chequeo simple de payload en lugar.
	cmp rax, rbx		;; No se puede hacer cmp con operando inmediato de 64!
	jne payloadSignatureFail

; Debug
;	mov rbx, [FB]						; Display the framebuffer address
;	call printhex

get_memmap:
	; Output 'OK' as we are about to leave UEFI
;;;;;;;;;;;;;;;;;;;;;;;;;	mov rcx, [TXT_OUT_INTERFACE]					
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	lea rdx, [msg_OK]					
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	call [rcx + EFI_OUT_OUTPUTSTRING]

	; Get Memory Map from UEFI and save it [memmap]
	lea rcx, [memmapsize]					; IN OUT UINTN *MemoryMapSize
	mov rdx, [memmap]					; OUT EFI_MEMORY_DESCRIPTOR *MemoryMap
	lea r8, [memmapkey]					; OUT UINTN *MapKey
	lea r9, [memmapdescsize]				; OUT UINTN *DescriptorSize
	lea r10, [memmapdescver]				; OUT UINT32 *DescriptorVersion
	mov [rsp+32], r10
	mov rax, [EFI_BOOT_SERVICES]
	call [rax + EFI_BOOT_SERVICES_GETMEMORYMAP]
	cmp al, EFI_BUFFER_TOO_SMALL
	je get_memmap						; Attempt again as the memmapsize was updated by EFI
	cmp rax, EFI_SUCCESS
	jne exitfailure
	; Each 48-byte record has the following format:
	; 0  UINT32 - Type
	; 4  UNIT32 - Padding
	; 8  EFI_PHYSICAL_ADDR (UINT64) - PhysicalStart
	; 16 EFI_VIRTUAL_ADDR (UINT64) - VirtualStart
	; 24 UINT64 - NumberOfPages - This is a number of 4K pages (must be a non-zero value)
	; 32 UINT64 - Attribute
	; 40 UINT64 - Blank
	;
	; UEFI Type:
	; 0x0 = EfiReservedMemoryType - Not usable
	; 0x1 = EfiLoaderCode - Usable after ExitBootSerivces
	; 0x2 = EfiLoaderData - Usable after ExitBootSerivces
	; 0x3 = EfiBootServicesCode - Usable after ExitBootSerivces
	; 0x4 = EfiBootServicesData - Usable after ExitBootSerivces
	; 0x5 = EfiRuntimeServicesCode
	; 0x6 = EfiRuntimeServicesData
	; 0x7 = EfiConventionalMemory - Usable after ExitBootSerivces
	; 0x8 = EfiUnusableMemory - Not usable - errors detected
	; 0x9 = EfiACPIReclaimMemory - Usable after ACPI is enabled
	; 0xA = EfiACPIMemoryNVS
	; 0xB = EfiMemoryMappedIO
	; 0xC = EfiMemoryMappedIOPortSpace
	; 0xD = EfiPalCode
	; 0xE = EfiPersistentMemory
	; 0xF = EfiMaxMemoryTyp

	;; Importante, ya no uso mas uefi
	mov rcx, [EFI_IMAGE_HANDLE]	; IN EFI_HANDLE ImageHandle
	mov rdx, [memmapkey]		; IN UINTN MapKey
	mov rax, [EFI_BOOT_SERVICES]
	call [rax + EFI_BOOT_SERVICES_EXITBOOTSERVICES]
	cmp rax, EFI_SUCCESS
	jne get_memmap				; Get mem map, then try to exit again.
	cli	;; Ya afuera.

	;; Payload al destino. Aqui se establece el maximo tamano y por eso cuando a
	;; rmamos imagen se deberia revisar que no sea mayor. Un posible payload es 
	;; uefiBootloader.sys + kernel.bin + modulosUserland.bin
	mov rsi, PAYLOAD
	mov rdi, 0x8000
;;;;;;;;;;;;;;;;;;;;;;;;	mov rcx, (60 * 1024)	;; 60KiB a partir de 0x8000
	mov rcx, (256 * 1024)	;; 256KiB a partir de 0x8000
	rep movsb				;; Ultimo byte escrito = 0x8000 + (60 * 1024) - 1

	;; Esta info de video la pasamos a la siguiente etapa de bootloader.
	mov rdi, 0x00005F00
	mov rax, [FB]
	stosq				;; 5F00 + 8 * 0 = 64-bit Frame Buffer Base
	mov rax, [FB_SIZE]
	stosq				;; 5F00 + 8 * 1 = 64-bit Frame Buffer Size in bytes
	mov rax, [HR]
	stosw				;; 5F00 + 8 * 2 + 2 * 0 = 16-bit Screen X
	mov rax, [VR]
	stosw				;; 5F00 + 8 * 2 + 2 * 1 = 16-bit Screen Y
	mov rax, [PPSL]
	stosw				;; 5F00 + 8 * 2 + 2 * 2 = 16-bit PixelsPerScanLine
	mov rax, 32			;; Hardcodeado, supuestamente uefi siempre 32? Grub mues
						;; tra que hay modos con 24 seleccionables.
	stosw				;; 16-bit BitsPerPixel

	mov rax, [memmap]
	mov rdx, rax				; Save Memory Map Base address to RDX
	stosq						; Memory Map Base
	mov rax, [memmapsize]
	add rdx, rax				; Add Memory Map Size to RDX
	stosq						; Size of Memory Map in bytes
	mov rax, [memmapkey]
	stosq						; The key used to exit Boot Services
	mov rax, [memmapdescsize]
	stosq						; EFI_MEMORY_DESCRIPTOR size in bytes
	mov rax, [memmapdescver]
	stosq						; EFI_MEMORY_DESCRIPTOR version
	mov rax, [ACPI]
	stosq						; ACPI Table Address
	mov rax, [EDID]
	stosq						; EDID Data (Size and Address)

	; Add blank entries to the end of the UEFI memory map
	mov rdi, rdx				; RDX holds address to end of memory map
	xor eax, eax
	mov ecx, 8
	rep stosq


	;; Hacer un clear del screen.
	mov rdi, [FB]
	mov eax, 0x00000000					; 0x00RRGGBB
	mov rcx, [FB_SIZE];;;;;;;;;; frame buffer size
	shr rcx, 2						; Quick divide by 4 (32-bit colour)
	rep stosd
;;;;;;; verificado que el tamano de pantalla correcto

	; Clear registers
	xor eax, eax
	xor ecx, ecx
	xor edx, edx
	xor ebx, ebx
	mov rsp, 0x8000
	xor ebp, ebp
	xor esi, esi
	xor edi, edi
	xor r8, r8
	xor r9, r9
	xor r10, r10
	xor r11, r11
	xor r12, r12
	xor r13, r13
	xor r14, r14
	xor r15, r15

	mov bl, 'U'

	jmp 0x8000	;; Vamos a siguiente loader. Aprox 0x400702



exitfailure:
	; Set screen to red on exit failure
	mov rdi, [FB]
	mov eax, 0x00FF0000					; 0x00RRGGBB
	mov rcx, [FB_SIZE]
	shr rcx, 2						; Quick divide by 4 (32-bit colour)
	rep stosd
error:
	mov rcx, [TXT_OUT_INTERFACE]					
	lea rdx, [msg_error]					
	call [rcx + EFI_OUT_OUTPUTSTRING]
	jmp halt
payloadSignatureFail:
	mov rcx, [TXT_OUT_INTERFACE]					
	lea rdx, [msg_badPayloadSignature]					
	call [rcx + EFI_OUT_OUTPUTSTRING]
halt:
	hlt
	jmp halt

; -----------------------------------------------------------------------------
; printhex - Display a 64-bit value in hex
; IN: RBX = Value
printhex:			 
	mov rbp, 16						; Counter
	push rax
	push rcx
	push rdx						; 3 pushes also align stack on 16 byte boundary
								; (8+3*8)=32, 32 evenly divisible by 16
	sub rsp, 32						; Allocate 32 bytes of shadow space
printhex_loop:
	rol rbx, 4
	mov rax, rbx
	and rax, 0Fh
	lea rcx, [Hex]
	mov rax, [rax + rcx]
	mov byte [Num], al
	lea rdx, [Num]
	mov rcx, [TXT_OUT_INTERFACE]					
	call [rcx + EFI_OUT_OUTPUTSTRING]
	dec rbp
	jnz printhex_loop
	lea rdx, [newline]
	mov rcx, [TXT_OUT_INTERFACE]					
	call [rcx + EFI_OUT_OUTPUTSTRING]

	add rsp, 32
	pop rdx
	pop rcx
	pop rax
	ret
;; -----------------------------------------------------------------------------


;;==============================================================================
;; print - impresion con cadena de formato (unicamente 1 solo %: %d, %h, %c)
;;==============================================================================
;; Argumentos:
;; -- rdx = cadena fmt
;; -- rbx = 2do argumento en caso de haber %.
;; El comportamiento si la cadena de fmt tiene % y no d, h, o c a continuacion e
;; s que ignora el % y continua imprimiendo. Si tiene muchos % siempre va a usar
;; el mismo argumento para la conversion (el unico que recibe en rbx).
;;==============================================================================

print:

push rbp
mov rbp, rsp

	mov rcx, 0	;; Ix fmt.
	mov rdi, 0	;; Ix placeholder.

parse:
	cmp word [rdx + 2 * rcx], 0x0000
	je .end_placeholder
	cmp word [rdx + 2 * rcx], utf16('%')
	jne .copyChar
	inc rcx

	cmp word [rdx + 2 * rcx], utf16('d')
	je .integer
	cmp word [rdx + 2 * rcx], utf16('h')
	je .hexadecimal
	cmp word [rdx + 2 * rcx], utf16('c')
	je .character
	jmp parse

.integer:

	lea rax, [print_placeholder + 2 * rdi]
	push rax
	push rbx
	call num2strWord2
	add rsp, 8 * 2
	add rdi, rax
	inc rcx
	jmp parse
.hexadecimal:

	inc rcx
	jmp parse
	
.character:

	inc rcx
	jmp parse

.copyChar:
	;;push word [rdx + 2 * rcx]
	;;pop word [print_placeholder + 2 * rdi]
	mov ax, [rdx + 2 * rcx]
	mov [print_placeholder + 2 * rdi], ax
	inc rcx
	inc rdi
	jmp parse

.end_placeholder:
	mov word [print_placeholder + 2 * rdi], 0x0000
	mov rdx, print_placeholder
	mov rcx, [TXT_OUT_INTERFACE]	
	call [rcx + EFI_OUT_OUTPUTSTRING]

	mov rsp, rbp
	pop rbp
	ret




;;==============================================================================
;; Parada en el modo step.
;;==============================================================================

parada_step_mode:
	cmp byte [STEP_MODE_FLAG], 0
	je .fin
	
.pedir_tecla:
	mov rcx, [TXT_IN_INTERFACE]
	mov rdx, EFI_INPUT_KEY	
	call [rcx + EFI_INPUT_READ_KEY]	;; SIMPLE_INPUT.ReadKeyStroke()
	cmp eax, EFI_NOT_READY			;; No hubo ingreso, me quedo poleando.
	je .pedir_tecla

	cmp rax, EFI_SUCCESS
	je .get_key

	mov rcx, [TXT_OUT_INTERFACE]	
	mov rdx, msg_efi_input_device_err	;; Notificar, rax = EFI_DEVICE_ERROR
	call [rcx + EFI_OUT_OUTPUTSTRING]
	jmp .pedir_tecla
	
.get_key:
	mov dx, [EFI_INPUT_KEY + 2]
	cmp dx, utf16('n')
	jne .pedir_tecla			;; Posible salida a siguiente paso.

.fin:
	ret



;;==============================================================================
;; num2strWord2 - convierte un entero en un string no null terminated
;;==============================================================================
;; Argumentos:
;; -- placeholder por stack, 1er push.
;; -- el numero entero de 64 bit a convertir, pasado por stack (2do push)
;; Retorno:
;; -- rax = cantidad de caracteres escritos.
;; Altera unicamente rax, restantes registros los devuelve como los recibe.
;;==============================================================================

num2strWord2:
    push rbp
	mov rbp, rsp

	push rcx
	push rdx	

division_init:
	mov rcx, 10
	mov rdx, 0  			;; En cero la parte mas significativa del acum.
	mov rax, [rbp + 8 * 2]  ;; Numero a convertir.
    push word 0				;; Marca para dejar de popear durante write.

.division:
	div ecx
	or dl, 0x30				;; Convierto el resto  menor a 10 a ASCII.
	push dx  
	cmp eax, 0
	jz .write_init
	mov rdx, 0
	jmp .division

.write_init:
	mov rax, 0				;; Contara chars copiados para valor de retorno.
	mov rcx, [rbp + 8 * 3]	;; Placeholder.

.write:
	cmp word [rsp], 0
	je .end
    pop word [rcx + 2 * rax]
	inc rax
    jmp .write

.end:
	add rsp, 2	;; El cero que marcaba fin, elimino para popear regs.
	pop rdx
	pop rcx

	mov rsp, rbp
	pop rbp	 
	ret



;;==============================================================================
;; num2strWord - convierte un entero en un string null terminated
;;==============================================================================
;; Argumentos:
;; -- placeholder por stack, 1er push.
;; -- el numero entero de 64 bit a convertir, pasado por stack (2do push)
;; Retorno:
;; -- los caracteres ASCII (1 char = word) en rbx puntero al comienzo dentro del
;;    placeholder
;;==============================================================================

num2strWord:
    push rbp
	mov rbp, rsp

	push rax
	push rcx
	push rdx	

	mov rcx, 10
	mov rdx, 0  			;; En cero la parte mas significativa.
	mov rax, [rbp + 8 * 2]  ;; Cargo el numero a convertir.
	mov rbx, [rbp + 8 * 3]
    push word 0

.calcular:
	div ecx
	or dl, 0x30	;; Convierto el resto  menor a 10 a ASCII.
	push dx  
	cmp al, 0
	jz .write
	mov rdx, 0
	jmp .calcular

.write:
    pop word [rbx]
    cmp word [rbx], 0
    jne .avanza
    jmp .end
    
.avanza:
    add rbx, 2
    jmp .write
    
.end:
	pop rdx
	pop rcx
	pop rax

	mov rsp, rbp
	pop rbp	 
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

times 3 * 1024 - ($ - $$)	db 0
CODE_END:

;; section .data
;; Cuidado con la posicion de estas tablas, no se pudede cambiar porque por el m
;; omento estan hardcodeadas las posiciones relativas de la misma donde bootload
;; er.asm busca, por ejemplo, ACPI.
DATA:
EFI_IMAGE_HANDLE:	dq 0	; EFI gives this in RCX
EFI_SYSTEM_TABLE:	dq 0	; And this in RDX
EFI_IMG_RET_ADDR:	dq 0	; And this in RSP
EFI_BOOT_SERVICES:	dq 0	; Boot services
RTS:				dq 0	; Runtime services
CONFIG:				dq 0	; Config Table address
ACPI:				dq 0	; ACPI table address
TXT_OUT_INTERFACE:	dq 0	; Output services
TXT_IN_INTERFACE:	dq 0	; Input services
VIDEO:				dq 0	; Video services
EDID:				dq 0
FB:					dq 0	; Frame buffer base address
FB_SIZE:			dq 0	; Frame buffer size
HR:					dq 0	; Horizontal Resolution
VR:					dq 0	; Vertical Resolution
PPSL:				dq 0	; PixelsPerScanLine
BPP:				dq 0		; BitsPerPixel
memmap:				dq 0x220000	; Store the Memory Map from UEFI here
memmapsize:			dq 32768	; Max size we are expecting in bytes
memmapkey:			dq 0
memmapdescsize:		dq 0
memmapdescver:		dq 0
vid_orig:			dq 0
vid_index:			dq 0
vid_max:			dq 0
vid_size:			dq 0
vid_info:			dq 0

;; typedef struct {
;; UINT16	ScanCode;
;; CHAR16	UnicodeChar;
;; } EFI_INPUT_KEY;
EFI_INPUT_KEY		dd 0

STEP_MODE_FLAG		db 0	;; Lo activa presionar 's' al booteo.

;; Lo que pide al GOP por defecto si no encuentra EDID. Para qemu, cambiar esto 
;; va a cambiar la resolucion de la pantalla.
Horizontal_Resolution:	dd 1024
Vertical_Resolution:	dd 768

ACPI_TABLE_GUID:
dd 0xeb9d2d30
dw 0x2d88, 0x11d3
db 0x9a, 0x16, 0x00, 0x90, 0x27, 0x3f, 0xc1, 0x4d

EFI_EDID_ACTIVE_PROTOCOL_GUID:
dd 0xbd8c1056
dw 0x9f36, 0x44ec
db 0x92, 0xa8, 0xa6, 0x33, 0x7f, 0x81, 0x79, 0x86

EFI_EDID_DISCOVERED_PROTOCOL_GUID:
dd 0x1c0c34f6
dw 0xd380, 0x41fa
db 0xa0, 0x49, 0x8a, 0xd0, 0x6c, 0x1a, 0x66, 0xaa

EFI_GRAPHICS_OUTPUT_PROTOCOL_GUID:
dd 0x9042a9de
dw 0x23dc, 0x4a38
db 0x96, 0xfb, 0x7a, 0xde, 0xd0, 0x80, 0x51, 0x6a

;; Boot service para imprimir en pantalla requiere string en utf16.
msg_uefi_boot:				dw utf16("UEFI boot"), 13, 0xA, 0
msg_OK:						dw utf16("OK "), 0
msg_error:					dw utf16("Error"), 0
msg_badPayloadSignature:	dw utf16("Bad payload signature."), 0
Hex:						db "0123456789ABCDEF"
Num:						dw 0, 0
newline:					dw 13, 10, 0

;; Some new messages
msg_edid_found: dw utf16("EDID found"), 13, 0xA, 0;; Carriage return
msg_edid_not_found: dw utf16("EDID not found"), 13, 0xA, 0
msg_edid_fail_default: dw utf16("Fail out to GOP with default resolution"), 13, 0xA, 0
msg_resolution: dw utf16("Resolution "), 0
msg_graphics_mode_info_found: dw utf16("Graphics mode info found."), 13, 0xA, 0
msg_graphics_mode_info_not_found: dw utf16("Graphics mode: no mode matches."), 13, 0xA, 0
msg_graphics_success: dw utf16("Graphics mod sucess."), 13, 0xA, 0
msg_por: dw utf16(" x "), 0
msg_placeholder dw 0,0,0,0,0,0,0,0 ; Reserve 8 words for the buffer
msg_placeholder_len equ ($ - msg_placeholder)
msg_step_mode: dw utf16("Step mode"), 13, 0xA, 0
msg_efi_input_device_err: dw utf16("Input device hw error"), 13, 0xA, 0
msg_efi_success: dw utf16("EFI success"), 13, 0xA, 0
msg_efi_not_ready: dw utf16("EFI not ready"), 13, 0xA, 0
msg_max_txt_mode: dw utf16("Max txt mode = %d"), 0
msg_curr_txt_mode: dw utf16(" | Curr mode = %d"), 13, 0xA, 0

print_placeholder:
times	32 dw 0x0000

times 8 * 1024 - ($ - $$)	db 0
DATA_RUNTIME_END:



;;;;;;;;;;;;;;;;;;;;;;align 4096	;; Codigo util de BOOT64.EFI ocupa primeros 4K. Luego, la payload.
align 8 * 1024	;; Codigo + data de BOOT64.EFI ocupa primeros 8K. Luego, la payload.
PAYLOAD:

;; Esto cambiarlo por 256K para mas payload.
align 65536	; 64KiB para BOOT64.EFI + payload (bootloader + PackedKernel).
RAMDISK:

;; Suficientes 0x00 para obtener un tamano de archivo de 1MiB.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;times 65535 + 1048576 + $$ - $	db 0
times 1048576 - ($ - $$)	db 0
DATA_END:
END:

;; EFI_STATUS Success Codes (High Bit Clear)
EFI_SUCCESS					equ 0

;; EFI_STATUS Error Codes (High Bit Set)
EFI_LOAD_ERROR				equ 1
EFI_INVALID_PARAMETER		equ 2
EFI_UNSUPPORTED				equ 3
EFI_BAD_BUFFER_SIZE			equ 4
EFI_BUFFER_TOO_SMALL		equ 5
EFI_NOT_READY				equ 6
EFI_DEVICE_ERROR			equ 7
EFI_WRITE_PROTECTED			equ 8
EFI_OUT_OF_RESOURCES		equ 9
EFI_VOLUME_CORRUPTED		equ 10
EFI_VOLUME_FULL				equ 11
EFI_NO_MEDIA				equ 12
EFI_MEDIA_CHANGED			equ 13
EFI_NOT_FOUND				equ 14
;;EFI_ACCESS_DENIED 15 Access was denied.
;;EFI_NO_RESPONSE 16 The server was not found or did not respond to the request.
;;EFI_NO_MAPPING 17 A mapping to a device does not exist.
;;EFI_TIMEOUT 18 The timeout time expired.
;;EFI_NOT_STARTED 19 The protocol has not been started.
;;EFI_ALREADY_STARTED 20 The protocol has already been started.
;;EFI_ABORTED 21 The operation was aborted.
;;EFI_ICMP_ERROR 22 An ICMP error occurred during the network operation.
;;EFI_TFTP_ERROR 23 A TFTP error occurred during the network operation.
;;EFI_PROTOCOL_ERROR 24 A protocol error occurred during the network operation.
;;EFI_INCOMPATIBLE_VERSION 25 The function encountered an internal version that was
;;incompatible with a version requested by the caller.
;;EFI_SECURITY_VIOLATION 26 The function was not performed due to a security violation.
;;EFI_CRC_ERROR 27 A CRC error was detected.





;; EFI system table.
;; typedef struct {
;;		EFI_TABLE_HEADER				Hdr;					(8 * 3 bytes)
;;		CHAR16							*FirmwareVendor;		(8 bytes)
;;		UINT32							FirmwareRevision;		(8 bytes)
;;		EFI_HANDLE						ConsoleInHandle;		(8 bytes)
;;		SIMPLE_INPUT_INTERFACE			*ConIn;					(8 bytes)
;;		EFI_HANDLE						ConsoleOutHandle;		(8 bytes)
;;		SIMPLE_TEXT_OUTPUT_INTERFACE	*ConOut;				(8 bytes)
;;		EFI_HANDLE						StandardErrorHandle;	(8 bytes)
;;		SIMPLE_TEXT_OUTPUT_INTERFACE	*StdErr;				(8 bytes)
;;		EFI_RUNTIME_SERVICES			*RuntimeServices;		(8 bytes)
;;		EFI_BOOT_SERVICES				*BootServices;			(8 bytes)
;	;	UINTN							NumberOfTableEntries;	(8 bytes)
;;		EFI_CONFIGURATION_TABLE			*ConfigurationTable;
;; } EFI_SYSTEM_TABLE;

EFI_SYSTEM_TABLE_CONIN								equ 48
EFI_SYSTEM_TABLE_CONOUT								equ 64
EFI_SYSTEM_TABLE_RUNTIMESERVICES					equ 88
EFI_SYSTEM_TABLE_BOOTSERVICES						equ 96
EFI_SYSTEM_TABLE_NUMBEROFENTRIES					equ 104
EFI_SYSTEM_TABLE_CONFIGURATION_TABLE				equ 112

;; typedef struct _EFI_SIMPLE_TEXT_INPUT_PROTOCOL {
;; EFI_INPUT_RESET                       Reset;
;; EFI_INPUT_READ_KEY                    ReadKeyStroke;
;; EFI_EVENT                             WaitForKey;
;; } EFI_SIMPLE_TEXT_INPUT_PROTOCOL;
EFI_INPUT_RESET										equ 0
EFI_INPUT_READ_KEY									equ 8
EFI_EVENT											equ 16

;; typedef struct _EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL {
;; EFI_TEXT_RESET                           Reset;
;; EFI_TEXT_STRING                          OutputString;
;; EFI_TEXT_TEST_STRING                     TestString;
;; EFI_TEXT_QUERY_MODE                      QueryMode;
;; EFI_TEXT_SET_MODE                        SetMode;
;; EFI_TEXT_SET_ATTRIBUTE                   SetAttribute;
;; EFI_TEXT_CLEAR_SCREEN                    ClearScreen;
;; EFI_TEXT_SET_CURSOR_POSITION             SetCursorPosition;
;; EFI_TEXT_ENABLE_CURSOR                   EnableCursor;
;; SIMPLE_TEXT_OUTPUT_MODE                  *Mode;
;; } EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL;
EFI_OUT_RESET				equ 0
EFI_OUT_OUTPUTSTRING		equ 8
EFI_OUT_TEST_STRING			equ 16
EFI_OUT_QUERY_MODE			equ 24
EFI_OUT_SET_MODE			equ 32
EFI_OUT_SET_ATTRIBUTE		equ 40
EFI_OUT_CLEAR_SCREEN		equ 48
EFI_OUT_SET_CURSOR_POSITION	equ 56
EFI_OUT_ENABLE_CURSOR		equ 64
EFI_OUT_MODE				equ 72

EFI_BOOT_SERVICES_GETMEMORYMAP				equ 56
EFI_BOOT_SERVICES_LOCATEHANDLE				equ 176
EFI_BOOT_SERVICES_LOADIMAGE					equ 200
EFI_BOOT_SERVICES_EXIT						equ 216
EFI_BOOT_SERVICES_EXITBOOTSERVICES			equ 232
EFI_BOOT_SERVICES_STALL						equ 248
EFI_BOOT_SERVICES_SETWATCHDOGTIMER			equ 256
EFI_BOOT_SERVICES_LOCATEPROTOCOL			equ 320

EFI_GRAPHICS_OUTPUT_PROTOCOL_QUERY_MODE		equ 0
EFI_GRAPHICS_OUTPUT_PROTOCOL_SET_MODE		equ 8
EFI_GRAPHICS_OUTPUT_PROTOCOL_BLT			equ 16
EFI_GRAPHICS_OUTPUT_PROTOCOL_MODE			equ 24

EFI_RUNTIME_SERVICES_RESETSYSTEM			equ 104

