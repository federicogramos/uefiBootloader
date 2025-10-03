;;==============================================================================
;; Transient System Load | @file /asm/tsl_start.asm
;;=============================================================================
;; Recibe la informacion del sistema. Hace configuraciones basicas del mismo. Co
;; pia el kernel a su ubicacion final. Salta al punto de entrada _start del kern
;; el en 0x100000.
;;=============================================================================

;; Ubicacion en memoria los distintos fuentes que componen esta parte de inicial
;; izacion del sistema.
;;  +----------+---------+----------------+--/ /---+--------------+
;;  | start    | tsl_sta |      tsl_      | 00..00 |   tsl.asm    |
;;  | 16.asm   | rt.asm  |      ap.asm    | 00..00 |              |
;;  | .text_   | .text_  | .text_ | .data | 00..00 | .text |.data |
;;  |  start16 |  low    |  low   | _low  | 00..00 |       |      |
;;  +----------+---------+--------+-------+--/ /---+-------+------+
;;  |^         |^                 |^      |^       |^      |^     |^
;; 0x7E00    0x8000            0x8200  0x8800  0x800000  802000  803000
;;  |<- 512 -->|<--------- 4KiB --------->|        |<--- 12KiB --->|
;;  (solo bios)

%include "./asm/include/tsl.inc"

;; tsl_ap.asm
extern bootmode_branch

;; 1 pagina en 0x8000 utilizada para booteo en 16 bits de los ap. Terminado ese
;; codigo, se salta a 0x800000.


section .text


start:
	jmp bootmode_branch	;; Pisado con "nop" para q comiencen los ap aqui (patch_
						;; ap_code).
	nop
	db "BOOTLOAD"		;; Marca para un simple chequeo de que hay payload.
	nop
	nop

