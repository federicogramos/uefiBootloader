# Bootloader UEFI para procesadores Intel x86-64

## Uso
./build.sh
Genera la imagen ./img/x64_arq.img

## Referencias y documentacion

### Codigo

#### Asm

[Pure64 loader](https://github.com/ReturnInfinity/Pure64)

[Simple Assembly UEFI Application - Can't Exit Boot Services](https://forum.osdev.org/viewtopic.php?t=33666)
El el ultimo posteo (pagina 1) tiene codigo ejemplo en asm.

[UEFI codigo](https://stackoverflow.com/questions/72947069/how-to-write-hello-world-efi-application-in-nasm)

[UEFI bootloader para extraer ideas](https://github.com/charlesap/nasm-uefi/tree/master)
Va directo a usar GOP, no revisa EDID.

#### Cpp

[Implementacion C++ con UEFI boot services](https://github.com/kiznit/rainbow-os)
Ver /boot/src/boot.cpp

### Documentos

[Pagina oficial de la especificacion UEFI](https://uefi.org/uefi)

[EFI Specification Version 1.10](https://www.intel.com/content/dam/www/public/us/en/zip/efi-110.zip)

[EFI Specification Version 2.8](https://uefi.org/sites/default/files/resources/UEFI_Spec_2_8_final.pdf)

[Repositorio EDKII con los protocolos](https://github.com/tianocore/edk2/tree/master/MdePkg/Include/Protocol)


### Info extra varia

[Buen resumen de todo lo necesario para uso de UEFI](https://uefi.org/specs/UEFI/2.10/02_Overview.html)

[Introduction to UEFI](http://x86asm.net/articles/introduction-to-uefi/index.html)
Util lectura para introducirse en el tema.

[VESA osdev.org](https://wiki.osdev.org/User:Omarrx024/VESA_Tutorial)
Informacion VESA en general: breve historia, vbe_info_structure, vbe_mode_info_structure, codigo asm para una funcion vbe_set_mode.

[VESA delorie.com](https://delorie.com/djgpp/doc/ug/graphics/vbe20.html)
Informacion de bajo nivel para setear VESA.

[VESA kernel.org](https://www.kernel.org/doc/html/latest/fb/vesafb.html)
Informacion especifica de Linux acerca de VESA.

[PE format microsoft.com](https://learn.microsoft.com/en-us/windows/win32/debug/pe-format)
Encabezado y sus partes en detalle.

[PE format osdev.org](https://wiki.osdev.org/PE)
Menos detalle que el anterior, pero buenas referencias al fondo de la pagina. Algunos links rotos.

[GOP](https://wiki.osdev.org/GOP)

[cpuid web 1](https://www.felixcloutier.com/x86/cpuid)

[cpuid web 2](https://eun.github.io/Intel-Pentium-Instruction-Set-Reference/data/cpuid.html)

[Paginacion: linda tabla que indica flags y modos](https://shell-storm.org/blog/Paging-modes-for-the-x86-32-bits-architectures/)

[Other nice paging web](https://connormcgarr.github.io/paging/)

[x86asm.net](http://x86asm.net/articles/x86-64-tour-of-intel-manuals/index.html)
Info en general de caracteristicas Intel.

[ftp.gnu.org](https://ftp.gnu.org/old-gnu/Manuals/ld-2.9.1/html_chapter/ld_3.html)
Some reference for ld scripts.

### Info no demasiado relevante

[pdf de UEFI plugfest](https://uefi.org/sites/default/files/resources/Driver%20Development%20with%20EDKII_Final.pdf)

[aeb.win.tue.nl](https://aeb.win.tue.nl/linux/kbd/scancodes-10.html)
Scancode different sets reference.