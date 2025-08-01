OUTPUT_FORMAT("binary")
SECTIONS
{
	text_hi_start_addr = 0x800000;
	.text 0x800000 : AT (0x800000) {
		*(.text)
	}
	text_size = SIZEOF (.text);

	. = ALIGN(0x1000);
	data_hi_start = .;
	.data : {
		*(.data)
	}
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

