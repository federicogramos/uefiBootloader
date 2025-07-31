OUTPUT_FORMAT("binary")
SECTIONS
{
	.text 0x800000 : AT (0x800000) {
		*(.text)
	}

	. = ALIGN(0x1000);
	data_hi_start = .;
	.data : {
		*(.data)
	}
	data_hi_size = . - data_hi_start;

	. = ALIGN(0x1000);
	.bss : {
		bss = .;
		*(.bss)
		*(EXCLUDE_FILE (*.o) COMMON)
	}

/*	file_size = . - code_low_start;*/
}

