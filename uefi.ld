OUTPUT_FORMAT("binary")
SECTIONS
{
	.header 0x400000:
	{
		loadAddressPosition = .;
		header = .;
		*(.header)
		endOfHeader = .;
	}		

	.text :
	{
		. = ALIGN(0x200);
		text = .;
		*(.text)
		endOfCode = .;

	}

	.data :
	{
		dataStart = .;
		. = ALIGN(0x1000);
		data = .;
		*(.data)

		. = ALIGN(0x4000);
		payload = .;
		*(.payload)

		endOfData = .;
	}

	.bss ALIGN(0x1000) : AT(ADDR(.bss))
	{
		bss = .;
		*(.bss)
		*(EXCLUDE_FILE (*.o) COMMON)
	}

	endOfUefi = .;
}
