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

	. = ALIGN(0x200);
	codeStart = .;

	.text :
	{
		text = .;
		*(.text)
	}
	
	codeEnd = .;
	codeSize = . - codeStart;

	.data ALIGN(0x1000):
	{
		dataStart = .;
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
