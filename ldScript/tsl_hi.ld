OUTPUT_FORMAT("binary")
SECTIONS
{
	code_hi_start_reloc = 0x800000;


	.text 0x800000 : AT (0x800000) {
		*(.text)
	}
	text_size = SIZEOF (.text);


	. = ALIGN(0x1000); /* 0x
	data_hi_start_reloc_aligned = . ;
	data_hi_start_load = 0x8000;
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

