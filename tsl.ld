OUTPUT_FORMAT("binary")
SECTIONS
{
	tsl_low_reloc_addr = 0x8000;
	.text_low tsl_low_reloc_addr :	AT (0x0000) {
		./obj/tsl_start.o (.text)
		./obj/tsl_ap.o (.text)
	}

	. = ALIGN(0x100);
	.data_low : {
		./obj/tsl_ap.o (.data)
	}

	align = 0x400;
	addr_tsl_hi_align = (. - tsl_low_reloc_addr + align - 1) & ~(align - 1);
	.text 0x800000 : AT (addr_tsl_hi_align) {
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

