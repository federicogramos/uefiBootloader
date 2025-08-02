OUTPUT_FORMAT("binary")
SECTIONS
{
	code_lo_start_reloc = 0x8000;
	code_lo_start_load = 0x0000;
	.text_low code_lo_start_reloc :	AT (code_lo_start_load) {
		./obj/tsl_start.o (.text)
		./obj/tsl_ap.o (.text)
	}

	. = ALIGN(0x100); /* 0x8200 */
	data_lo_start_reloc_aligned = . ;
	data_lo_start_load = data_lo_start_reloc_aligned - code_lo_start_reloc;
	.data_low data_lo_start_reloc_aligned : AT (data_lo_start_load) {
		./obj/tsl_ap.o (.data)
	}

	. = ALIGN(0x400); /* 0x8400 */
	data_lo_end_reloc_aligned = . ;
	text_hi_start_reloc = 0x800000;
	text_hi_start_load = data_lo_end_reloc_aligned - code_lo_start_reloc; /* 0x400 */
	.text text_hi_start_reloc : AT (text_hi_start_load) {
		*(.text)
	}

	. = ALIGN(0x1000); /* 0x
	data_hi_start_reloc_aligned = . ;
	data_hi_start_load = 
	.data data_hi_start_reloc_aligned : AT (data_hi_start_load) {
		*(.data)
	}
	/* data_size = SIZEOF (.data); */
	/* data_hi_end_addr = data_hi_start_addr + data_size;*/
	data_hi_end_addr = . ;
	code_data_hi_size = data_hi_end_addr - text_hi_start_addr;

	. = ALIGN(0x1000);
	.bss : {
		bss = .;
		*(.bss)
		*(EXCLUDE_FILE (*.o) COMMON)
	}

/*	file_size = . - code_low_start;*/
}

