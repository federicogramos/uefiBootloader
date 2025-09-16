OUTPUT_FORMAT("binary")
SECTIONS
{
	. = 0x400000;
	headerStart = .;
	.header : {
		aux = .;
		header = .;
		*(.header)
	}

	headerSize = . - headerStart;

	. = ALIGN(0x200);
	codeStart = .;
	codeOffset = codeStart - headerStart;

	.text :	{
		text = .;
		*(.text)
	}

	codeSize = . - codeStart;

	. = ALIGN(0x1000);
	dataStart = .;
	dataOffset = dataStart - headerStart;

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

	fileSize = . - headerStart;
}
