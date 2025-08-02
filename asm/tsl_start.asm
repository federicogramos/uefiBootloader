;;==============================================================================
;; Transient System Load | @file /asm/tsl_start.asm
;;=============================================================================
;; Recibe la informacion del sistema. Hace configuraciones basicas del mismo. Co
;; pia el kernel a su ubicacion final. Salta al punto de entrada _start del kern
;; el en 0x100000.
;;=============================================================================

;; Ubicacion en memoria los distintos fuentes que componen esta parte de inicial
;; izacion del sistema.
;;  +---------------+------------+-------+---..---+----------+------+
;;  | tsl_start.asm | tsl_ap.asm | .data | 00..00 | tsl.asm  |.data |
;;  | .text_low     | .text_low  | _low  | 00..00 | .text    |      |
;;  +---------------+------------+-------+---..---+----------+------+
;;  |^              |            |       |        |          |      |
;;  |<-------------- 4KiB -------------->|        |<----   KiB ---->|
;; 0x8000                      0x8200  0x2000   0x800000
;; 
;; code 0 a 0x200 , data 0x200 a 300\
;; y en 0x300 aparece tsl que se carga en 800000

%include "./asm/include/tsl.inc"

;; tsl_ap.asm
extern bootmode_branch


;; 1 pagina reservada en 0x8000 para booteo en 16 bits de los ap. Terminado ese
;; codigo, se salta a 0x800000.


section .text

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;BITS 64

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;TSL_BASE_ADDRESS equ 0x800000
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;ORG TSL_BASE_ADDRESS

start:
;;db 0xAA
;;dq start
	jmp bootmode_branch	;; Overwritten with 'NOP's before AP's are started.
	nop
	db "UEFIBOOT"		;; Marca para un simple chequeo de que hay payload.
	nop
	nop

