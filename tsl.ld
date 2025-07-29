OUTPUT_FORMAT("binary")
SECTIONS
{
	. = 0x8000;
	code_low_start = .;
	.text_low :	{
		./obj/tsl_start.o (.text)
		./obj/tsl_ap.o (.text)
	}
	code_low_size = . - code_low_start;

	. = ALIGN(0x200);
	data_low_start = .;
	.data_low : {
		./obj/tsl_ap.o (.data)
	}
	data_low_size = . - data_low_start;

	. = ALIGN(0x800000);
	code_hi_start = .;
	.text : { 
		*(.text)
	}
	code_hi_size = . - code_hi_start;

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

	file_size = . - code_low_start;
}
