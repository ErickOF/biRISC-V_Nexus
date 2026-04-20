# biriscv bare-metal startup — matches the test.elf conventions

.section .boot, "ax"
.global boot_vector

boot_vector:
    j       _start

    .align 4
_start:
    # Set up stack pointer
    la      sp, _sp

    # Clear .bss
    la      t0, __bss_start
    la      t1, __bss_end
bss_clear:
    bge     t0, t1, bss_done
    sw      zero, 0(t0)
    addi    t0, t0, 4
    j       bss_clear
bss_done:

    # Call main
    jal     ra, main

    # _exit_loop: spin forever (testbench detects stuck PC)
_exit_loop:
    j       _exit_loop
