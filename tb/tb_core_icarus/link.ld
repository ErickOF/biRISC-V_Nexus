/* biriscv TCM linker script — matches test.elf memory map */
OUTPUT_ARCH("riscv")
ENTRY(boot_vector)

MEMORY
{
    TCM (rwx) : ORIGIN = 0x80000000, LENGTH = 128K
}

SECTIONS
{
    .text : {
        *(.boot)
        *(.text .text.*)
    } > TCM

    .rodata : {
        *(.rodata .rodata.*)
    } > TCM

    .data : {
        *(.data .data.*)
    } > TCM

    .bss : {
        __bss_start = .;
        *(.bss .bss.*)
        *(COMMON)
        __bss_end = .;
    } > TCM

    . = ALIGN(16);
    _sp = . + 0x1000;    /* 4KB stack */
    _end = .;
}
