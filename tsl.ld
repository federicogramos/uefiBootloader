OUTPUT_FORMAT("binary")
SECTIONS
{
	. = 0x8000;
	code_low_start = .;
	.text_low :	{
		/*text = .;*/
		./obj/tsl_start.o (.text)
		./obj/tsl_ap.o (.text)
	}
	code_low_size = . - code_low_start;

	. = ALIGN(0x200);
	data_low_start = .;
	.data_low : {
		/*data = .;*/
		./obj/tsl_ap.o (.data)
	}
	data_low_size = . - data_low_start;

	. = ALIGN(0x800000);
	codeUpperStart = .;
	.text : { 
		text = .;
		*(.text)
	}
	codeUpperSize = . - codeUpperStart;

	. = ALIGN(0x1000);
	dataStart = .;
	.data : {
		data = .;
		*(.data)
	}
	dataSize = . - dataStart;



	. = ALIGN(0x1000);
	.bss : {
		bss = .;
		*(.bss)
		*(EXCLUDE_FILE (*.o) COMMON)
	}

	fileSize = . - code_low_start;
}
