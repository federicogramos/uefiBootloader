/* En este ld script es importante mantener diferenciados con el prefijo "mbr_"
 * los simbolos code_end, code_size, etc porque todos los simbolos de mbr son ex
 * portados ya que se usan en la linkedicion de tsl.sys */

OUTPUT_FORMAT("binary")

SECTIONS {

	mbr_code_reloc = 0x7c00 ;
	mbr_code_load = 0x0000;
	.text mbr_code_reloc :	AT (mbr_code_load) {
		./obj/mbr.o (.text)
	}

	. = ALIGN(0x10);
	mbr_code_end_reloc_aligned = . ;
	mbr_code_size_aligned = mbr_code_end_reloc_aligned - mbr_code_reloc;
	mbr_data_start_reloc_aligned = . ;
	mbr_data_start_load = mbr_code_load + mbr_code_size_aligned;
	.data mbr_data_start_reloc_aligned : AT (mbr_data_start_load) {
		./obj/mbr.o (.data)
	}

}
