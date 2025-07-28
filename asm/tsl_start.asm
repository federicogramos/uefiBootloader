;;==============================================================================
;; Transient System Load | @file /asm/tsl.asm
;;=============================================================================
;; Recibe la informacion del sistema. Hace configuraciones basicas del mismo. Co
;; pia el kernel a su ubicacion final. Salta al punto de entrada _start del kern
;; el en 0x100000.
;;=============================================================================

;; Como se estructura en memoria los distintos fuentes que componen esta parte d
;; e inicializacion del sistema.
;; tsl_start.asm  tsl_ap.asm                             tsl.asm
;; 0x8000                                                0x800000



%include "./asm/include/tsl.inc"


section .text


;; tsl_ap.asm
extern bootmode_branch


;; 1 pagina reservada en 0x8000 para booteo en 16 bits de los ap. Terminado ese
;; codigo, se salta a 0x800000.


section .text

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;BITS 64

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;TSL_BASE_ADDRESS equ 0x800000
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;ORG TSL_BASE_ADDRESS

start:
	jmp bootmode_branch	;; Overwritten with 'NOP's before AP's are started.
	nop
	db "UEFIBOOT"		;; Marca para un simple chequeo de que hay payload.
	nop
	nop

