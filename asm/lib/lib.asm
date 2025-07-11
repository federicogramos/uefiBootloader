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
;; print - impresion utf8 a buffer de video luego de ExitBootSerivces()
;;==============================================================================
;; Argumentos:
;; -- r9 = cadena fmt
;; -- rsi = 2do argumento en caso de haber %.
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
;;==============================================================================

print:
	mov rax, [print_cursor]
	mov rdi, [PPSL]
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
	mov dword [rax + 4 * rcx], 0x00000000
	jmp .nextPixel
.setPixel:
	mov dword [rax + 4 * rcx], 0x00E0E0E0
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
	lea rbx, [4 * rbx]	;; 4b/px * ppsl
	div rbx				;; rdx = offset desde comienzo de linea.

	sub [rsp], rdx		;; Carriage return.

	mov rbx, [PPSL]
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
	call print
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
	call print
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
	mov r9, msg_test8
	call print
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

;; TODO: revisar por que en pc fgr escritorio, llega a bootloader y cualga o se queda aleatoriamente.
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
