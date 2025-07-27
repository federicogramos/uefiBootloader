OUTPUT_FORMAT("binary")
SECTIONS
{
	. = 0x8000;
	codeLowerStart = .;
	.text_lower :	{
		text = .;
		./obj/tsl_start.o (.text)
		./obj/tsl_ap.o (.text)
		BYTE (0xFE);
		BYTE (0xFE);
		BYTE (0xFE);
		BYTE (0xFE);
		BYTE (0xFE);
	}
	codeLowerSize = . - codeLowerStart;


	. = ALIGN(0x200);
	dataStart = .;
	.data : {
		data = .;
		*(.data)
	}
	dataSize = . - dataStart;




/*	. = ALIGN(0x4000);*/
	. = 0x800000;
	codeUpperStart = .;
/*	.text 0x4000 :	AT (0x800000) { */
	.text : { 
		text = .;
		*(.text)
	}
	codeUpperSize = . - codeUpperStart;



	. = ALIGN(0x1000);
	.bss : {
		bss = .;
		*(.bss)
		*(EXCLUDE_FILE (*.o) COMMON)
	}

	fileSize = . - codeLowerStart;
}
