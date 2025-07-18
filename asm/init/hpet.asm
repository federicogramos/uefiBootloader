; =============================================================================
; INIT HPET
; =============================================================================


init_hpet:
	; Verify there is a valid HPET address
	mov rax, [p_HPET_Address]
	jz os_hpet_init_error

	; Verify the capabilities of HPET
	mov ecx, HPET_GEN_CAP
	call os_hpet_read
	mov rbx, rax			; Save results for # of timers
	shr ebx, 8			; Bits 12:8 contain the # of timers
	and ebx, 11111b			; Save only the lower 5 bits
	inc bl				; Increment the number of timers by 1
	mov [p_HPET_Timers], bl		; Save the # of HPET timers
	shr rax, 32			; EAX contains the tick period in femtoseconds

	; Verify the Counter Clock Period is valid
	cmp eax, 0x05F5E100		; 100,000,000 femtoseconds is the maximum
	ja os_hpet_init_error
	cmp eax, 0			; The Period has to be greater than 1 femtosecond
	je os_hpet_init_error

	; Calculate the HPET frequency
	mov rbx, rax			; Move Counter Clock Period to RBX
	xor rdx, rdx
	mov rax, 1000000000000000	; femotoseconds per second
	div rbx				; RDX:RAX / RBX
	mov [p_HPET_Frequency], eax	; Save the HPET frequency

	; Disable interrupts on all timers
	xor ebx, ebx
	mov bl, [p_HPET_Timers]
	mov ecx, 0xE0			; HPET_TIMER_0_CONF - 0x20
os_hpet_init_disable_int:
	add ecx, 0x20
	call os_hpet_read
	btc ax, 2
	btc ax, 3
	call os_hpet_write
	dec bl
	jnz os_hpet_init_disable_int

	; Clear the main counter before it is enabled
	mov ecx, HPET_MAIN_COUNTER
	xor eax, eax
	call os_hpet_write

	; Enable HPET main counter (bit 0)
	mov eax, 1			; Bit 0 is set
	mov ecx, HPET_GEN_CONF
	call os_hpet_write

os_hpet_init_error:
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_hpet_read -- Read from a register in the High Precision Event Timer
;  IN:	ECX = Register to read
; OUT:	RAX = Register value
;	All other registers preserved
os_hpet_read:
	mov rax, [p_HPET_Address]
	mov rax, [rax + rcx]
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_hpet_write -- Write to a register in the High Precision Event Timer
;  IN:	ECX = Register to write
;	RAX = Value to write
; OUT:	All registers preserved
os_hpet_write:
	push rcx
	add rcx, [p_HPET_Address]
	mov [rcx], rax
	pop rcx
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_hpet_delay -- Delay by X microseconds
; IN:	RAX = Time microseconds
; OUT:	All registers preserved
; Note:	There are 1,000,000 microseconds in a second
;	There are 1,000 milliseconds in a second
os_hpet_delay:
	push rdx
	push rcx
	push rbx
	push rax

	mov rbx, rax			; Save delay to RBX
	xor edx, edx
	xor ecx, ecx
	call os_hpet_read		; Get HPET General Capabilities and ID Register
	shr rax, 32
	mov rcx, rax			; RCX = RAX >> 32 (timer period in femtoseconds)
	mov rax, 1000000000
	div rcx				; Divide 1000000000 (RDX:RAX) / RCX (converting from period in femtoseconds to frequency in MHz)
	mul rbx				; RAX *= RBX, should get number of HPET cycles to wait, save result in RBX
	mov rbx, rax
	mov ecx, HPET_MAIN_COUNTER
	call os_hpet_read		; Get HPET counter in RAX
	add rbx, rax			; RBX += RAX Until when to wait
os_hpet_delay_loop:			; Stay in this loop until the HPET timer reaches the expected value
	mov ecx, HPET_MAIN_COUNTER
	call os_hpet_read		; Get HPET counter in RAX
	cmp rax, rbx			; If RAX >= RBX then jump to end, otherwise jump to loop
	jae os_hpet_delay_end
	jmp os_hpet_delay_loop
os_hpet_delay_end:

	pop rax
	pop rbx
	pop rcx
	pop rdx
	ret
; -----------------------------------------------------------------------------


; Register list (64-bits wide)
HPET_GEN_CAP		equ 0x000 ; COUNTER_CLK_PERIOD (63:32), LEG_RT_CAP (15), COUNT_SIZE_CAP (13), NUM_TIM_CAP (12:8)
; 0x008 - 0x00F are Reserved
HPET_GEN_CONF		equ 0x010 ; LEG_RT_CNF (1), ENABLE_CNF (0)
; 0x018 - 0x01F are Reserved
HPET_GEN_INT_STATUS	equ 0x020
; 0x028 - 0x0EF are Reserved
HPET_MAIN_COUNTER	equ 0x0F0
; 0x0F8 - 0x0FF are Reserved
HPET_TIMER_0_CONF	equ 0x100
HPET_TIMER_0_COMP	equ 0x108
HPET_TIMER_0_INT	equ 0x110
; 0x118 - 0x11F are Reserved
HPET_TIMER_1_CONF	equ 0x120
HPET_TIMER_1_COMP	equ 0x128
HPET_TIMER_1_INT	equ 0x130
; 0x138 - 0x13F are Reserved
HPET_TIMER_2_CONF	equ 0x140
HPET_TIMER_2_COMP	equ 0x148
HPET_TIMER_2_INT	equ 0x150
; 0x158 - 0x15F are Reserved
; 0x160 - 0x3FF are Reserved for Timers 3-31


; =============================================================================
; EOF
