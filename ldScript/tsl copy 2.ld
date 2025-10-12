OUTPUT_FORMAT("binary")

SECTIONS {
	
	code_start16_reloc = 0x7e00;
	code_start16_load = 0x0000;
	.text_start16 code_start16_reloc :	AT (code_start16_load) {
		./obj/start16.o (.text)
	}

	. = ALIGN(0x200); /* 0x8000 */
	code_start16_end_reloc_aligned = . ;
	code_start16_size_aligned = code_start16_end_reloc_aligned - code_start16_reloc;
	code_lo_start_reloc = . ;
	code_lo_start_load = code_start16_load + code_start16_size_aligned; /* 0x200 */
	.text_low code_lo_start_reloc :	AT (code_lo_start_load) {
		./obj/tsl_start.o (.text)
		./obj/bios16.o (.text)
		./obj/bios32.o (.text)
		./obj/tsl_ap.o (.text)
	}

	. = ALIGN(0x100); /* 0x8200 */
	code_lo_end_reloc_aligned = . ;
	code_lo_size_aligned = code_lo_end_reloc_aligned - code_lo_start_reloc;
	data_lo_start_reloc_aligned = . ;
	data_lo_start_load = code_lo_start_load + code_lo_size_aligned;
	.data_low data_lo_start_reloc_aligned : AT (data_lo_start_load) {
		./obj/tsl_ap.o (.data)
	}
data_lo_end_reloc_not_aligned = .;
	. = ALIGN(0x800);	/* 0x8800. Puede hacerse 0x400 pero dado que se le su */
						/* ma START16_SIZE quedan 0x600 y prefiero alineamint */
						/* o a 0x800 que a 0x200. Previo a ser relocalizado queda en 0xA00*/
	data_lo_end_reloc_aligned = . ;
	data_lo_size_aligned = data_lo_end_reloc_aligned - data_lo_start_reloc_aligned;
	code_hi_start_reloc = 0x800000;
	code_hi_start_load = data_lo_start_load + data_lo_size_aligned; /* 0x600 + 0x400 */
	.text code_hi_start_reloc : AT (code_hi_start_load) {
		*(.text)
	}

	. = ALIGN(0x1000); /* 0x802000 */
	code_hi_end_reloc_aligned = . ;
	code_hi_size_aligned = code_hi_end_reloc_aligned - code_hi_start_reloc;
	data_hi_start_reloc_aligned = . ;
	data_hi_start_load = code_hi_start_load + code_hi_size_aligned;
	.data data_hi_start_reloc_aligned : AT (data_hi_start_load) {
		*(.data)
	}

	/* data_size = SIZEOF (.data); */
	/* data_hi_end_addr = data_hi_start_addr + data_size;*/
	data_hi_end_reloc = . ;
	code_data_hi_size = data_hi_end_reloc - code_hi_start_reloc;

	. = ALIGN(0x1000);
	.bss : {
		bss = .;
		*(.bss)
		*(EXCLUDE_FILE (*.o) COMMON)
	}

/*	file_size = . - code_low_start;*/
}

