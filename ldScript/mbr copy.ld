OUTPUT_FORMAT("binary")

SECTIONS {
	. = 0x7C00;
	codeStart = .;




	.text :	{
		text = .;
		*(.text)
	}

	codeSize = . - codeStart;

	. = ALIGN(0x1000);
	dataStart = .;
	dataOffset = dataStart - codeStart;

	.data : {
		data = .;
		*(.data)

		. = ALIGN(0x4000);
		payload = .;
		*(.payload)
	}

	dataSize = . - dataStart;
	. = ALIGN(0x1000);

	.bss : {
		bss = .;
		*(.bss)
		*(EXCLUDE_FILE (*.o) COMMON)
	}

	fileSize = . - codeStart;
}
