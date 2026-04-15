OUTPUT_ARCH("riscv")
SECTIONS
{
    . = 0x80000000;
    .text.init : { crt.o(.text) }

    .tohost ALIGN(0x1000) : { *(.tohost) }

    .text : { *(.text) }

    .data : { *(.data) }

    .sdata : {
        _gp = . + 0x800;
        *(.srodata.cst16) *(.srodata.cst8) *(.srodata.cst4) *(.srodata.cst2) *(.srodata.cst1) *(.srodata*) *(.sdata .sdata.* .gnu.linkonce.s.*)
    }

    .sbss : {
        *(.sbss .sbss.* .gnu.linkonce.sb.*)
        *(.scommon)
    }

    .bss : { *(.bss) }

    .tdata : {
        _tls_data = .;
        crt.o(.tdata.begin)
        *(.tdata)
        crt.o(.tdata.end)
    }

    .tbss : {
        *(.tbss)
        crt.o(.tbss.end)
    }

    _end = .;
}
