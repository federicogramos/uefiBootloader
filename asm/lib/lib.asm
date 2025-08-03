;;==============================================================================
;; @file /asm/lib/lib.asm
;;==============================================================================


%include "./asm/include/lib.inc"

;; uefi.asm
extern PPSL
extern FB
extern FB_SIZE
extern STEP_MODE_FLAG


global print_cursor
global num2hexStr
global num2str
global print
global print_color
global memsetFramebuffer
global keyboard_command
global keyboard_get_key
global emptyKbBuffer


section .text


;;==============================================================================
; num2hexStr - escribe el hexadecimal de un nro, dentro de un placeholder utf8
;;==============================================================================
;; Argumentos:
;; -- placeholder por stack, 1er push.
;; -- el numero entero de 64 bit a convertir, pasado por stack (2do push)
;; Retorno:
;; -- rax = cantidad de caracteres escritos.
;;
;; Altera unicamente rax, restantes registros los devuelve como los recibe.
;;==============================================================================

num2hexStr:
    push rbp
	mov rbp, rsp

	push rcx
	push rdx	

.division_init:
	mov rcx, 16
	mov rdx, 0  			;; En cero la parte mas significativa del acum.
	mov rax, [rbp + 8 * 2]  ;; Numero a convertir.
    push qword 0			;; Marca para dejar de popear durante write.

.division:
	div rcx
	push qword [hexConvert8 + rdx]  
	cmp rax, 0
	jz .write_init
	mov rdx, 0
	jmp .division

.write_init:
	mov rax, 0				;; Contara chars copiados para valor de retorno.
	mov rcx, [rbp + 8 * 3]	;; Placeholder.

.write:
    pop rdx
	mov [rcx + rax], rdx
	cmp rdx, 0
	je .end
	inc rax
    jmp .write

.end:
	pop rdx
	pop rcx

	mov rsp, rbp
	pop rbp	 
	ret


;;==============================================================================
;; num2str - convierte un entero en un string null terminated
;;==============================================================================
;; Argumentos:
;; -- placeholder por stack, 1er push.
;; -- el numero entero de 64 bit a convertir, pasado por stack (2do push)
;; Retorno:
;; -- rax = cantidad de caracteres escritos.
;;
;; Altera unicamente rax, restantes registros los devuelve como los recibe.
;;==============================================================================

num2str:
    push rbp
	mov rbp, rsp

	push rcx
	push rdx	

.division_init:
	mov rcx, 10
	mov rdx, 0  			;; En cero la parte mas significativa del acum.
	mov rax, [rbp + 8 * 2]  ;; Numero a convertir.
    push qword 0			;; Marca para dejar de popear durante write.

.division:
	div rcx
	or dl, 0x30				;; Convierto el resto  menor a 10 a ASCII.
	push rdx  
	cmp rax, 0
	jz .write_init
	mov rdx, 0
	jmp .division

.write_init:
	mov rax, 0				;; Contara chars copiados para valor de retorno.
	mov rcx, [rbp + 8 * 3]	;; Placeholder.

.write:
    pop rdx
	mov [rcx + rax], dl
	cmp rdx, 0
	je .end
	inc rax
    jmp .write

.end:
	;;add rsp, 8	;; El cero que marcaba fin, elimino para popear regs.
	pop rdx
	pop rcx

	mov rsp, rbp
	pop rbp	 
	ret



;;==============================================================================
;; print - wrapper print_color, imprime por defecto con texto PRINT_COLOR_WHT.
;;==============================================================================
;; Argumentos:
;; -- r9 = cadena fmt
;; -- rsi = 2do argumento en caso de haber %.
;; Retorno:
;; -- rax = cursor (address fb) siguiente a la ultima posicion escrita.
;;==============================================================================

print:
	mov r11, PRINT_COLOR_WHT
	call print_color
	ret


;;==============================================================================
;; print_color - impresion utf8 a buffer de video luego de ExitBootSerivces()
;;==============================================================================
;; Argumentos:
;; -- r9 = cadena fmt
;; -- rsi = 2do argumento en caso de haber %.
;; -- r11 = text color in rgb32.
;; Retorno:
;; -- rax = cursor (address fb) siguiente a la ultima posicion escrita.
;;
;; El comportamiento si la cadena de fmt tiene % huerfano (no hay ninguna de las
;; siguientes a continuacion: d, h, c, s) es: ignora el % y sigue imprimiendo. S
;; i tiene muchos % siempre va a usar el mismo argumento para la conversion (el 
;; unico que recibe en rsi).
;;
;; El cursor para esta funcion, es la direccion del pixel superior izquierdo del
;; bounding box del caracter de la fuente.
;;
;; Aclaracion: de la memoria de video usa PPSL el cual puede ser indistintamente
;; qword (durante efi) o word (post-efi).
;;==============================================================================

print_color:
	mov rax, [print_cursor]
	mov rdi, [PPSL]
	and rdi, 0x0000FFFF	;; No necesario durante efi, pero si necesario durante 2
						;; do loader puesto que en 0x5F00 queda  HR, VR y PPSL e
						;; n tamanos de dato word.
	mov r8, 0	;; ix src str.
	
.loop_read_string_char:
	push rax	;; FB cursor, apunta a inicio de char (pixel exactamente) a come
				;; nzar imprimir.
	mov rcx, 0	;; Blanqueo de parte alta para uso en resolucion de addrress en 
				;; .print_next_font.
	mov cl, [r9 + r8]
	cmp cl, 0
	je .string_flush_end

	cmp cl, 0x0A
	je .linefeed
	cmp cl, '%'
	jne .print_next_font
	inc r8
	mov cl, [r9 + r8]
	mov [print_cursor], rax	;; Update cursor to current position.

	cmp cl, 'd'
	je .integer
	cmp cl, 'h'
	je .hexadecimal
	cmp cl, 'c'
	je .character
	cmp cl, 's'
	je .string
		
.print_next_font:
	lea r10, [font_data + 8 * rcx]	;; r10 p2fontLine 16px chars.
	lea r10, [r10 + 8 * rcx]
	mov rdx, 0

.loop_font_vertical_line:
	cmp rdx, font_height
	je .char_flush_end
	mov rcx, 0
	mov rbx, 0
	mov bl, [r10 + rdx]

.loop_font_horizontal_pixel:
	cmp rcx, 8
	je .next_line
	bt rbx, rcx
	jc .setPixel

.resetPixel:
	mov dword [rax + 4 * rcx], PRINT_COLOR_BLK
	jmp .nextPixel
.setPixel:
	mov dword [rax + 4 * rcx], r11d
.nextPixel:
	inc rcx
	jmp .loop_font_horizontal_pixel

.next_line:
	inc rdx
	lea rax, [rax + 4 * rdi]
	jmp .loop_font_vertical_line

.char_flush_end:
	add qword [rsp], 32	;; rax += 8px * 4bytes/px

.avance_next_char:
	pop rax
	inc r8
	jmp .loop_read_string_char

.linefeed:
	mov rdx, 0			;; rdx:rax = 0:rax
	sub rax, [FB]
	mov rbx, [PPSL]
	and rbx, 0x0000FFFF	;; No necesario durante efi, si en 2do loader.
	lea rbx, [4 * rbx]	;; 4b/px * ppsl
	div rbx				;; rdx = offset desde comienzo de linea.

	sub [rsp], rdx		;; Carriage return.

	mov rbx, [PPSL]
	and rbx, 0x0000FFFF	;; No necesario durante efi, si en 2do loader.

	mov rax, 4 * 16		;; Bajar 16px.
	mov rdx, 0
	mul rbx				;; rax = offset_bytes
	add [rsp], rax
	jmp .avance_next_char

.integer:
	push rdi
	push r8
	push r9
	
	push volatile_placeholder
	push rsi
	call num2str
	add rsp, 8 * 2
	mov r9, volatile_placeholder
	call print_color
	pop r9
	pop r8
	pop rdi

	mov [rsp], rax			;; Actualiza cursor.
	jmp .avance_next_char

.hexadecimal:
	push rdi
	push r8
	push r9
	
	push volatile_placeholder
	push rsi
	call num2hexStr
	add rsp, 8 * 2
	mov r9, volatile_placeholder
	call print_color
	pop r9
	pop r8
	pop rdi

	mov [rsp], rax			;; Actualiza cursor.
	jmp .avance_next_char

.character:
	;; No necesario por el momento.

.string:
	push rdi
	push r8
	push r9
	mov r9, rsi
	call print_color
	pop r9
	pop r8
	pop rdi

	mov [rsp], rax			;; Actualiza cursor.
	jmp .avance_next_char

.string_flush_end:
	add rsp, 8				;; Quita push de rax q se hace para cada caracter.
	mov [print_cursor], rax	;; Update cursor to current position.
	ret


;;==============================================================================
;; memsetFramebuffer
;;==============================================================================
;; Argumentos:
;; -- rax = 0x00RRGGBB
;;==============================================================================

memsetFramebuffer:
	mov rdi, [FB]
	mov rcx, [FB_SIZE]
	shr rcx, 2	;; FB_SIZE /= 4.
	rep stosd
	ret


;;==============================================================================
;; keyboard_command
;;==============================================================================
;; Argumentos:
;; -- al = command
;; -- ah = byte requerido por el comando (de ser necesario)
;; -- bit 16 de rax = 0 si comando no requiere ah, 1 si comando requiere enviar 
;;    ah a continuacion de al.
;;==============================================================================

keyboard_command:
	push rbp
	mov rbp, rsp

	out 0x64, al
	bt rax, 16
	jnc .fin
	mov al, ah
	out 0x60, al

.fin:
	mov rsp, rbp
	pop rbp
	ret


;;==============================================================================
;; keyboard_get_key | Se queda esperando tecla 'n'.
;;==============================================================================

keyboard_get_key:
	push rbp
	mov rbp, rsp

	cmp byte [STEP_MODE_FLAG], 0
	je .fin

	mov rax, 0
.loop:
	in al, 0x64
	and al, 0x01
	cmp al, 0
	je .loop
	in al, 0x60

;; TODO: revisar por que en pc fgr escritorio, llega a bootloader y cualga o se 
;; queda aleatoriamente.
;; Sin estas dos, pasa oka.
	cmp al, 0x31	;; Scancode tecla 'n'.
	jne .loop

.fin:
	mov rsp, rbp
	pop rbp
	ret


;;==============================================================================
;; emptyKbBuffer - Vacia el teclado, dejando ninguna tecla pendiente.
;;==============================================================================

emptyKbBuffer:
	push rbp
	mov rbp, rsp
	mov rax, 0
.loop:
	in al, 0x64
	and al, 0x01
	cmp al, 1
	jne .exit
	in al, 0x60
	jmp .loop
.exit:
	mov rsp, rbp
	pop rbp
	ret




section .data

hexConvert8:	db "0123456789ABCDEF"
print_cursor	dq 0 ;; El cursor es tan solo puntero a framebuffer.

;; Hay otro con el mismo nombre en uefi.asm pero ese pertenece a efi_print.
volatile_placeholder:
times			64 dw 0x0000

;;TODO: cuando genere la fuente, le recorte la linea inferior... o sea, por ejem
;; plo la letra g miniscula, tiene un chiquito recortada la curvatura inferior.
;; Regenerar la fuente.

font_height		equ 16
font_data:
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x00 uni0000
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x01 uni0001
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x02 uni0002
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x03 uni0003
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x04 uni0004
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x05 uni0005
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x06 uni0006
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x07 uni0007
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x08 uni0008
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x09 uni0009
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x0a uni000A
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x0b uni000B
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x0c uni000C
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x0d uni000D
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x0e uni000E
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x0f uni000F
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x10 uni0010
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x11 uni0011
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x12 uni0012
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x13 uni0013
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x14 uni0014
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x15 uni0015
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x16 uni0016
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x17 uni0017
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x18 uni0018
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x19 uni0019
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x1a uni001A
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x1b uni001B
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x1c uni001C
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x1d uni001D
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x1e uni001E
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x1f uni001F
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x20 space
	dd 0x08080000, 0x08080808, 0x00000808, 0x00000808 ;; 0x21 exclam
	dd 0x14140000, 0x00001414, 0x00000000, 0x00000000 ;; 0x22 quotedbl
	dd 0x48000000, 0x24FE4848, 0x127F2424, 0x00001212 ;; 0x23 numbersign
	dd 0x08080000, 0x0909493E, 0x4848380E, 0x08083E49 ;; 0x24 dollar
	dd 0x09060000, 0x30C60909, 0x9090630C, 0x00006090 ;; 0x25 percent
	dd 0x221C0000, 0x04040202, 0x41A1918A, 0x0000BC42 ;; 0x26 ampersand
	dd 0x08080000, 0x00000808, 0x00000000, 0x00000000 ;; 0x27 quotesingle
	dd 0x10200000, 0x04040808, 0x04040404, 0x20100808 ;; 0x28 parenleft
	dd 0x08040000, 0x20201010, 0x20202020, 0x04081010 ;; 0x29 parenright
	dd 0x08080000, 0x2A1C2A49, 0x00080849, 0x00000000 ;; 0x2a asterisk
	dd 0x00000000, 0x08080000, 0x08087F08, 0x00000008 ;; 0x2b plus
	dd 0x00000000, 0x00000000, 0x00000000, 0x0C181818 ;; 0x2c comma
	dd 0x00000000, 0x00000000, 0x00007E00, 0x00000000 ;; 0x2d hyphen
	dd 0x00000000, 0x00000000, 0x00000000, 0x00001818 ;; 0x2e period
	dd 0x40400000, 0x10102020, 0x04040808, 0x01010202 ;; 0x2f slash
	dd 0x221C0000, 0x49515161, 0x43454549, 0x00001C22 ;; 0x30 zero
	dd 0x0C080000, 0x0808090A, 0x08080808, 0x00003F08 ;; 0x31 one
	dd 0x221C0000, 0x20404041, 0x02040810, 0x00007F01 ;; 0x32 two
	dd 0x211E0000, 0x1E204040, 0x40404020, 0x00001E21 ;; 0x33 three
	dd 0x28300000, 0x22242428, 0x207F2122, 0x00002020 ;; 0x34 four
	dd 0x013F0000, 0x201F0101, 0x40404040, 0x00001E21 ;; 0x35 five
	dd 0x221C0000, 0x231D0102, 0x41414141, 0x00001C22 ;; 0x36 six
	dd 0x407F0000, 0x10102020, 0x04040808, 0x00000202 ;; 0x37 seven
	dd 0x221C0000, 0x1C224141, 0x41414122, 0x00001C22 ;; 0x38 eight
	dd 0x221C0000, 0x41414141, 0x40405C62, 0x00001C22 ;; 0x39 nine
	dd 0x00000000, 0x18180000, 0x00000000, 0x00001818 ;; 0x3a colon
	dd 0x00000000, 0x18180000, 0x00000000, 0x0C181818 ;; 0x3b semicolon
	dd 0x00000000, 0x0C30C000, 0x300C0303, 0x000000C0 ;; 0x3c less
	dd 0x00000000, 0x7F000000, 0x007F0000, 0x00000000 ;; 0x3d equal
	dd 0x00000000, 0x300C0300, 0x0C30C0C0, 0x00000003 ;; 0x3e greater
	dd 0x423C0000, 0x20404040, 0x00080810, 0x00000808 ;; 0x3f question
	dd 0x38000000, 0xC9B28244, 0x89898989, 0x0402B2C9 ;; 0x40 at
	dd 0x18180000, 0x24242424, 0x427E4242, 0x00008181 ;; 0x41 A
	dd 0x211F0000, 0x1F214141, 0x41414121, 0x00001F21 ;; 0x42 B
	dd 0x423C0000, 0x01010102, 0x02010101, 0x00003C42 ;; 0x43 C
	dd 0x211F0000, 0x41414141, 0x41414141, 0x00001F21 ;; 0x44 D
	dd 0x017F0000, 0x7F010101, 0x01010101, 0x00007F01 ;; 0x45 E
	dd 0x017F0000, 0x7F010101, 0x01010101, 0x00000101 ;; 0x46 F
	dd 0x423C0000, 0x01010102, 0x42414171, 0x00003C42 ;; 0x47 G
	dd 0x41410000, 0x7F414141, 0x41414141, 0x00004141 ;; 0x48 H
	dd 0x083E0000, 0x08080808, 0x08080808, 0x00003E08 ;; 0x49 I
	dd 0x40780000, 0x40404040, 0x40404040, 0x00003E41 ;; 0x4a J
	dd 0x41010000, 0x05091121, 0x21110907, 0x00008141 ;; 0x4b K
	dd 0x01010000, 0x01010101, 0x01010101, 0x00007F01 ;; 0x4c L
	dd 0x63630000, 0x49555555, 0x41414949, 0x00004141 ;; 0x4d M
	dd 0x43430000, 0x49494545, 0x61615151, 0x00004141 ;; 0x4e N
	dd 0x221C0000, 0x41414141, 0x41414141, 0x00001C22 ;; 0x4f O
	dd 0x211F0000, 0x21414141, 0x0101011F, 0x00000101 ;; 0x50 P
	dd 0x221C0000, 0x41414141, 0x49414141, 0x20101C2A ;; 0x51 Q
	dd 0x211F0000, 0x21414141, 0x4141211F, 0x00008141 ;; 0x52 R
	dd 0x413E0000, 0x3E010101, 0x40404040, 0x00003E41 ;; 0x53 S
	dd 0x087F0000, 0x08080808, 0x08080808, 0x00000808 ;; 0x54 T
	dd 0x41410000, 0x41414141, 0x41414141, 0x00001C22 ;; 0x55 U
	dd 0x81810000, 0x42424281, 0x24242442, 0x00001818 ;; 0x56 V
	dd 0x41410000, 0x49494941, 0x55555555, 0x00002222 ;; 0x57 W
	dd 0x41410000, 0x08142222, 0x22221408, 0x00004141 ;; 0x58 X
	dd 0x41410000, 0x14142222, 0x08080808, 0x00000808 ;; 0x59 Y
	dd 0x407F0000, 0x08101020, 0x02040408, 0x00007F01 ;; 0x5a Z
	dd 0x041C0000, 0x04040404, 0x04040404, 0x1C040404 ;; 0x5b bracketleft
	dd 0x01010000, 0x04040202, 0x10100808, 0x40402020 ;; 0x5c backslash
	dd 0x101C0000, 0x10101010, 0x10101010, 0x1C101010 ;; 0x5d bracketright
	dd 0x24180000, 0x00008142, 0x00000000, 0x00000000 ;; 0x5e asciicircum
	dd 0x00000000, 0x00000000, 0x00000000, 0xFF000000 ;; 0x5f underscore
	dd 0x10080400, 0x00000000, 0x00000000, 0x00000000 ;; 0x60 grave
	dd 0x00000000, 0x40423C00, 0x4141417E, 0x00005E61 ;; 0x61 a
	dd 0x01010000, 0x41231D01, 0x41414141, 0x00001D23 ;; 0x62 b
	dd 0x00000000, 0x01423C00, 0x01010101, 0x00003C42 ;; 0x63 c
	dd 0x40400000, 0x41625C40, 0x41414141, 0x00005C62 ;; 0x64 d
	dd 0x00000000, 0x41221C00, 0x01017F41, 0x00003C42 ;; 0x65 e
	dd 0x08700000, 0x08087E08, 0x08080808, 0x00000808 ;; 0x66 f
	dd 0x00000000, 0x41625C00, 0x41414141, 0x22405C62 ;; 0x67 g
	dd 0x01010000, 0x41231D01, 0x41414141, 0x00004141 ;; 0x68 h
	dd 0x08080000, 0x08080E00, 0x08080808, 0x00007F08 ;; 0x69 i
	dd 0x10100000, 0x10101C00, 0x10101010, 0x10101010 ;; 0x6a j
	dd 0x01010000, 0x09112101, 0x21110B05, 0x00008141 ;; 0x6b k
	dd 0x080F0000, 0x08080808, 0x08080808, 0x00007008 ;; 0x6c l
	dd 0x00000000, 0x49493F00, 0x49494949, 0x00004949 ;; 0x6d m
	dd 0x00000000, 0x41231D00, 0x41414141, 0x00004141 ;; 0x6e n
	dd 0x00000000, 0x41221C00, 0x41414141, 0x00001C22 ;; 0x6f o
	dd 0x00000000, 0x41231D00, 0x41414141, 0x01011D23 ;; 0x70 p
	dd 0x00000000, 0x41625C00, 0x41414141, 0x40405C62 ;; 0x71 q
	dd 0x00000000, 0x02463A00, 0x02020202, 0x00000202 ;; 0x72 r
	dd 0x00000000, 0x01413E00, 0x40403E01, 0x00003E41 ;; 0x73 s
	dd 0x08000000, 0x08087E08, 0x08080808, 0x00007008 ;; 0x74 t
	dd 0x00000000, 0x41414100, 0x41414141, 0x00005E61 ;; 0x75 u
	dd 0x00000000, 0x41414100, 0x14222222, 0x00000814 ;; 0x76 v
	dd 0x00000000, 0x49414100, 0x55555555, 0x00002222 ;; 0x77 w
	dd 0x00000000, 0x22414100, 0x22140814, 0x00004141 ;; 0x78 x
	dd 0x00000000, 0x42414100, 0x18242422, 0x08101018 ;; 0x79 y
	dd 0x00000000, 0x20407F00, 0x02040810, 0x00007F01 ;; 0x7a z
	dd 0x08300000, 0x08080808, 0x08080608, 0x08080808 ;; 0x7b braceleft
	dd 0x08080000, 0x08080808, 0x08080808, 0x08080808 ;; 0x7c bar
	dd 0x08060000, 0x08080808, 0x08083008, 0x08080808 ;; 0x7d braceright
	dd 0x00000000, 0x00000000, 0x0000324C, 0x00000000 ;; 0x7e asciitilde
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x7f uni007F





