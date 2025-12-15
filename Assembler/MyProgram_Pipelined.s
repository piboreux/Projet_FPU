/************* CODE SECTION *************/
@ FPU Test Program
.text

.balign 4
.global main

B main
.balign 128

/************* MAIN SECTION *************/

main:
    SUB R0, R15, R15          @ R0 = 0 (base address)

    STR R0, [R0, #0x500]      @ Clear LEDs

    @-----------------------------------
    @ Read operands and opcode from SPI
    @-----------------------------------
    LDR R1, [R0, #0x400]      @ R1 = Operand A
    LDR R2, [R0, #0x404]      @ R2 = Operand B
    LDR R3, [R0, #0x408]      @ R3 = Opcode (1=ADD,2=SUB,3=MUL)

    @-----------------------------------
    @ Write operands to FPU
    @-----------------------------------
    STR R1, [R0, #0x600]      @ FPU Operand A
    STR R2, [R0, #0x604]      @ FPU Operand B

    @-----------------------------------
    @ Launch computation
    @-----------------------------------
    STR R3, [R0, #0x608]      @ FPU Command (executes)

    @-----------------------------------
    @ Read FPU result
    @-----------------------------------
    LDR R4, [R0, #0x60C]      @ R4 = FPU Result

    @-----------------------------------
    @ Send result back via SPI
    @-----------------------------------
    STR R4, [R0, #0x40C]      @ SPI output register

    @-----------------------------------
    @ Display result (LSB only) on LEDs
    @-----------------------------------
    STR R4, [R0, #0x500]

end:
    B end                     @ Infinite loop

.end
