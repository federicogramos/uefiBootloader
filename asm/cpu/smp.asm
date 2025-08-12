;;==============================================================================
;; @file /asm/cpu/smp.asm
;;==============================================================================
;; Intel multiprocessor spec, info relevante: B.2 Operating System Booting and S
;; elf-configuration, B.4 Application Processor Startup., B.3 Interrupt Mode Ini
;; tialization and Handling.
;;==============================================================================


;; Revisar diagrama de pagina 20. Ruteo de senales de activacion de local apic.

init_smp:
	cmp byte [cfg_smpinit], 1	;; Check if SMP should be enabled.
	jne no_mp					;; If not then skip SMP init.

	;; Start the AP's one by one.
	xor eax, eax
	xor edx, edx
	mov rsi, [p_LocalAPICAddress]
	mov eax, [rsi + 0x20]		;; Add the offset for the APIC ID location.
	shr rax, 24					;; APIC ID is stored in bits 31:24.
	mov dl, al					;; Store BSP APIC ID in dl.

	mov esi, IM_DetectedCoreIDs
	xor eax, eax
	xor ecx, ecx
	mov cx, [p_cpu_detected]

smp_send_INIT:
	cmp cx, 0
	je smp_send_INIT_done
	lodsb

	cmp al, dl						;; Check if it is the bsp.
	je smp_send_INIT_skipcore

	;; Send "INIT" IPI to APIC ID in al. Sets ap to known state before start of 
	;; execution.
	mov rdi, [p_LocalAPICAddress]
	shl eax, 24
	mov dword [rdi + 0x310], eax	;; Irq Command Register (ICR); bits 63-32
	mov eax, 0x00004500				;; 10:8 = 101 (delivery mode = init)
									;; 11 = 0 (dest mode = fisico)
									;; 15 = 1 (level triggered)
									;; 14 = 1 (level = assert)
	mov dword [rdi + 0x300], eax	;; Irq Command Register (ICR); bits 31-0
									

smp_send_INIT_verify:
	mov eax, [rdi + 0x300]			;; Irq Command Register (ICR); bits 31-0
	bt eax, 12						;; Poll delivery status until dispatched. TO
									;; DO: should not happen, but intel manual s
									;; uggests break and report error if t > 20u
									;; s (o reintentar). El error se puede gener
									;; ar porque ningun apic responde en el bus.
	jc smp_send_INIT_verify

smp_send_INIT_skipcore:
	dec cl
	jmp smp_send_INIT

smp_send_INIT_done:

	mov eax, 500					;; Wait 500us.
	call os_hpet_delay

	mov esi, IM_DetectedCoreIDs
	xor ecx, ecx
	mov cx, [p_cpu_detected]

smp_send_SIPI:
	cmp cx, 0
	je smp_send_SIPI_done
	lodsb

	cmp al, dl						;; Check if it is the bsp.
	je smp_send_SIPI_skipcore

	;; Send "Startup" IPI to destination using vector 0x08 to specify entry-poin
	;; t is at the memory-address 0x8000
	mov rdi, [p_LocalAPICAddress]
	shl eax, 24
	mov dword [rdi + 0x310], eax	;; Irq Command Register (ICR); bits 63-32
	mov eax, 0x00004608				;; 7:0 = 8 (vector 0x08).
									;; 10:8 = 110 (delivery mode)
									;; 11 = 0 (dest mode = fisico)
									;; 15 = 1 (edge triggered)
									;; 14 = 1 (level = assert)
	mov dword [rdi + 0x300], eax	;; Irq Command Register (ICR); bits 31-0

smp_send_SIPI_verify:
	mov eax, [rdi + 0x300]			;; Irq Command Register (ICR); bits 31-0
	bt eax, 12						;; Verify that the command completed.
	jc smp_send_SIPI_verify

smp_send_SIPI_skipcore:
	dec cl
	jmp smp_send_SIPI

smp_send_SIPI_done:
	mov eax, 10000					;; Wait 10000us for the AP's to finish.
	call os_hpet_delay

no_mp:
	;; Gather and store the APIC ID of the BSP.
	xor eax, eax
	mov rsi, [p_LocalAPICAddress]
	add rsi, 0x20		;; Add the offset for the APIC ID location.
	lodsd				;; APIC ID is stored in bits 31:24.
	shr rax, 24			;; AL now holds the CPU's APIC ID (0 - 255).
	mov [p_BSP], eax	;; Store the BSP APIC ID.

	;; Calculate base speed of cpu.
	cpuid
	xor edx, edx
	xor eax, eax
	rdtsc
	push rax
	mov rax, 1024
	call os_hpet_delay
	rdtsc
	pop rdx
	sub rax, rdx
	xor edx, edx
	mov rcx, 1024
	div rcx
	mov [p_cpu_speed], ax

	ret
