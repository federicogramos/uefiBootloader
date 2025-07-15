;;==============================================================================
;; @file /asm/lib/lib_efi.asm
;;==============================================================================


%include "./asm/include/efi.inc"
%define utf16(x) __utf16__(x)

global efi_print
global ventana_modo_step
global efi_prompt_step_mode

extern STEP_MODE_FLAG


;; efi vars
extern CONOUT_INTERFACE
extern CONIN_INTERFACE
extern EFI_INPUT_KEY




section .text


;;==============================================================================
;; Muestrea buscando si apretaron 's' (senalizacion  inicio modo step)
;;==============================================================================

ventana_modo_step:
	mov rcx, [CONIN_INTERFACE]
	mov rdx, EFI_INPUT_KEY	
	call [rcx + EFI_INPUT_READ_KEY]	;; SIMPLE_INPUT.ReadKeyStroke()
	cmp eax, EFI_NOT_READY			;; No hubo ingreso, sigo normalmente. Descar
									;; ta bit 63, de otro modo compararia mal
	je .continue_no_step_mode

	cmp rax, EFI_SUCCESS
	je .get_key

	mov rcx, [CONOUT_INTERFACE]	
	lea rdx, [msg_efi_input_device_err]	;; Notificar, rax = EFI_DEVICE_ERROR
	call [rcx + EFI_OUT_OUTPUTSTRING]
	jmp .continue_no_step_mode			;; Sigo, a pesar del error.
	
.get_key:
	mov dx, [EFI_INPUT_KEY + 2]
	cmp dx, utf16('s')
	jne .continue_no_step_mode
	mov byte [STEP_MODE_FLAG], 1

	mov rcx, [CONOUT_INTERFACE]	
	lea rdx, [msg_step_mode]
	call [rcx + EFI_OUT_OUTPUTSTRING]

.continue_no_step_mode:
	mov rcx, [CONOUT_INTERFACE]	
	lea rdx, [msg_uefi_boot]			
	call [rcx + EFI_OUT_OUTPUTSTRING]


;;==============================================================================
;; efi_print - impresion con formato (unicamente 1 solo %: %d, %h, %c, %s)
;;==============================================================================
;; Argumentos:
;; -- rdx = cadena fmt
;; -- rsi = 2do argumento en caso de haber %.
;;
;; El comportamiento si la cadena de fmt tiene % huerfano (no hay ninguna de las
;; siguientes a continuacion: d, h, c, s) es: ignora el % y sigue imprimiendo. S
;; i tiene muchos % siempre va a usar el mismo argumento para la conversion (el 
;; unico que recibe en rsi).
;;==============================================================================

efi_print:
	push rbp
	mov rbp, rsp

	mov rcx, 0	;; Ix fmt.
	mov rdi, 0	;; Ix placeholder.

.parse:
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
	cmp word [rdx + 2 * rcx], utf16('s')
	je .string
	jmp .parse

.integer:
	inc rcx
	lea rax, [volatile_placeholder + 2 * rdi]
	push rax
	push rsi
	call efi_num2str
	add rsp, 8 * 2
	add rdi, rax
	jmp .parse

.hexadecimal:
	inc rcx
	lea rax, [volatile_placeholder + 2 * rdi]
	push rax
	push rsi
	call efi_printhex
	add rsp, 8 * 2
	add rdi, rax
	jmp .parse
	
.character:
	inc rcx
	jmp .parse

.string:
	inc rcx
	push rsi
	call efi_strlen
	add rsp, 8

.str_copy_init:
	mov [rbp - 8], rax	;; Cantidad a copiar al stack.
	mov rax, 0

.str_copy:
	cmp rax, [rbp - 8]
	je .parse
	mov bx, [rsi + 2 * rax]
	mov [volatile_placeholder + 2 * rdi], bx
	inc rax
	inc rdi
	jmp .str_copy

.copyChar:
	push word [rdx + 2 * rcx]
	pop word [volatile_placeholder + 2 * rdi]
	inc rcx
	inc rdi
	jmp .parse

.end_placeholder:
	mov word [volatile_placeholder + 2 * rdi], 0x0000
	mov rdx, volatile_placeholder
	mov rcx, [CONOUT_INTERFACE]

	sub rsp, 8 * 4
	call [rcx + EFI_OUT_OUTPUTSTRING]
	add rsp, 8 * 2

	mov rsp, rbp
	pop rbp
	ret


;;==============================================================================
; efi_printhex - Display a 64-bit value in hex (string utf16)
;;==============================================================================
;; Argumentos:
;; -- placeholder por stack, 1er push.
;; -- el numero entero de 64 bit a convertir, pasado por stack (2do push)
;; Retorno:
;; -- rax = cantidad de caracteres escritos.
;;
;; Altera unicamente rax, restantes registros los devuelve como los recibe.
;;==============================================================================

efi_printhex:
    push rbp
	mov rbp, rsp

	push rcx
	push rdx	

.division_init:
	mov rcx, 16
	mov rdx, 0  			;; En cero la parte mas significativa del acum.
	mov rax, [rbp + 8 * 2]  ;; Numero a convertir.
    push word 0				;; Marca para dejar de popear durante write.

.division:
	div ecx
	push word [hexConvert + 2 * rdx]  
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
;; efi_strlen - cantidad de caracteres de un string utf16 (no cuenta NULL)
;;==============================================================================
;; Argumentos:
;; -- cadena por stack.
;; Retorno:
;; -- rax = longitud.
;;
;; Altera unicamente rax, restantes registros los devuelve como los recibe.
;;==============================================================================

efi_strlen:
	push rbp
	mov rbp, rsp

	push rsi

	mov rax, 0
	mov rsi, [rbp + 8 * 2]

.lookForNull:
	cmp word [rsi + 2 * rax], 0
	je .end
	inc rax
	jmp .lookForNull

.end:
	pop rsi

	mov rsp, rbp
	pop rbp
	ret


;;==============================================================================
;; Parada en el modo step.
;;==============================================================================
;; Con la tecla 'n' se avanza.
;;==============================================================================

efi_prompt_step_mode:
	cmp byte [STEP_MODE_FLAG], 0
	je .fin
	
.pedir_tecla:
	mov rcx, [CONIN_INTERFACE]
	mov rdx, EFI_INPUT_KEY	
	sub rsp, 8 * 4
	call [rcx + EFI_INPUT_READ_KEY]	;; SIMPLE_INPUT.ReadKeyStroke()
	add rsp, 8 * 4
	cmp eax, EFI_NOT_READY			;; No hubo ingreso, me quedo poleando.
	je .pedir_tecla

	cmp rax, EFI_SUCCESS
	je .get_key

	mov rcx, [CONOUT_INTERFACE]	
	lea rdx, [msg_efi_input_device_err]	;; Notificar, rax = EFI_DEVICE_ERROR
	sub rsp, 8 * 4
	call [rcx + EFI_OUT_OUTPUTSTRING]
	add rsp, 8 * 4
	jmp .pedir_tecla

;; EFI_INPUT_KEY
;; UINT16	ScanCode;
;; CHAR16	UnicodeChar;
.get_key:
	mov dx, [EFI_INPUT_KEY + 2]
	cmp dx, utf16('n')
	jne .pedir_tecla			;; Posible salida a siguiente paso.

.fin:
	ret


;;==============================================================================
;; efi_num2str - convierte un entero en un string no null terminated
;;==============================================================================
;; Argumentos:
;; -- placeholder por stack, 1er push.
;; -- el numero entero de 64 bit a convertir, pasado por stack (2do push)
;; Retorno:
;; -- rax = cantidad de caracteres escritos.
;;
;; Altera unicamente rax, restantes registros los devuelve como los recibe.
;;==============================================================================

efi_num2str:
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


section .data

;; Hay otro con el mismo nombre en lib.asm pero ese pertenece a print.
volatile_placeholder:
times	64 dw 0x0000

hexConvert:					dw utf16("0123456789ABCDEF")

msg_efi_input_device_err:	dw utf16("Input device hw error"), 13, 0xA, 0
msg_step_mode:	dw utf16("Step mode active, presione <n> para avanzar"), 13, 0xA, 0
msg_uefi_boot:	dw utf16("UEFI boot"), 13, 0xA, 0


