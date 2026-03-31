.section .text
.globl _start

# -----------------------------------------------------------------------------
# stress_test_ooo.S
# -----------------------------------------------------------------------------
# Purpose:
#   Microarchitectural stress program for OoO/dual-issue validation.
#
# What this test exercises:
#   1) WAW pressure: repeated writes to the same architectural destination.
#   2) WAR pressure: read-after-rename overwrite scenarios.
#   3) RAW depth: long dependency chain through the same destination.
#   4) Pairing opportunities: independent operations that can dual-issue.
#   5) Rename pressure: same-destination updates across close instructions.
#
# End-of-test contract with the testbench:
#   - After the loop finishes, software stores signature 0x00000001 at
#     physical address 0x8001FFFC.
#   - The testbench watches this address/data pair and ends simulation as PASS.
#
# Notes:
#   - The infinite loop at 'done' is intentional. The testbench should terminate
#     first when it sees the PASS signature.
# -----------------------------------------------------------------------------

_start:
    # Initialize source operands and loop trip count.
    # x31 is the loop counter: 64 full stress iterations.
    addi x1,  x0, 1
    addi x2,  x0, 2
    addi x3,  x0, 3
    addi x4,  x0, 4
    addi x6,  x0, 6
    addi x10, x0, 10
    addi x11, x0, 11
    addi x31, x0, 64

loop:
    # -------------------------------------------------------------------------
    # Phase A: WAW density on x5.
    # Multiple back-to-back writes to the same destination without intervening
    # reads, stressing destination rename and commit bookkeeping.
    # -------------------------------------------------------------------------
    addi x5,  x0, 1
    addi x5,  x0, 2
    addi x5,  x0, 3
    addi x5,  x0, 4

    # -------------------------------------------------------------------------
    # Phase B: WAR pressure on x6.
    # Read x6, then overwrite x6, then consume x6 again. This pattern stresses
    # operand version selection and anti-dependency handling.
    # -------------------------------------------------------------------------
    add  x7,  x6, x1
    addi x6,  x0, 0x11
    sub  x8,  x6, x2
    addi x6,  x0, 0x12
    xor  x9,  x6, x3
    addi x6,  x0, 0x13

    # -------------------------------------------------------------------------
    # Phase C: Long RAW chain through x13.
    # Each instruction depends on the previous x13 value, forcing dependency
    # tracking and forwarding behavior across many operations.
    # -------------------------------------------------------------------------
    add  x13, x1,  x2
    add  x13, x13, x3
    add  x13, x13, x4
    add  x13, x13, x5
    add  x13, x13, x6
    add  x13, x13, x7
    add  x13, x13, x8
    add  x13, x13, x9
    add  x13, x13, x10
    add  x13, x13, x11

    # -------------------------------------------------------------------------
    # Phase D: Independent updates intended to be dual-issue friendly.
    # -------------------------------------------------------------------------
    addi x20, x0, 10
    addi x21, x0, 20
    addi x20, x0, 30
    addi x21, x0, 40

    # -------------------------------------------------------------------------
    # Phase E: Same-destination writes in close proximity (rename stress).
    # -------------------------------------------------------------------------
    addi x22, x0, 1
    addi x22, x0, 2
    addi x23, x0, 3
    addi x23, x0, 4

    # -------------------------------------------------------------------------
    # Phase F: Mixed RAW/WAR interactions across x20/x22 and consumers.
    # -------------------------------------------------------------------------
    add  x24, x20, x21
    addi x20, x0, 50
    add  x25, x22, x23
    addi x22, x0, 5

    # -------------------------------------------------------------------------
    # Phase G: Additional WAW pressure on x26 to diversify destination stress.
    # -------------------------------------------------------------------------
    addi x26, x0, 7
    addi x26, x0, 8
    addi x26, x0, 9

    # Loop control: decrement and iterate until zero.
    addi x31, x31, -1
    bne  x31, x0, loop

    # -------------------------------------------------------------------------
    # PASS signature write:
    #   x28 <- 0x8001FFFC, x29 <- 1, then store word 1 to [x28].
    # -------------------------------------------------------------------------
    lui  x28, 0x80020
    addi x28, x28, -4
    addi x29, x0, 1
    sw   x29, 0(x28)

done:
    # Intentional terminal loop; TB should have already ended simulation on PASS.
    jal  x0, done
