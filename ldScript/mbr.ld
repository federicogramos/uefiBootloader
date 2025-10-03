OUTPUT_FORMAT("binary")

SECTIONS {

	code_reloc = 0x7c00 ;
	code_load = 0x0000;
	.text code_reloc :	AT (code_load) {
		./obj/mbr.o (.text)
	}

	. = ALIGN(0x10);
	code_end_reloc_aligned = . ;
	code_size_aligned = code_end_reloc_aligned - code_reloc;
	data_start_reloc_aligned = . ;
	data_start_load = code_load + code_size_aligned;
	.data data_start_reloc_aligned : AT (data_start_load) {
		./obj/mbr.o (.data)
	}

}
