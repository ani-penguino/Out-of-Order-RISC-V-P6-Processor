data = 0x1000                               #PC     #NPC    code
addi x4, x0, 4                              #0      4       00100213    0000 0000 0001 0000 0000 0010 0001 0011
#Init Registers
addi x1, x0, 1                              #4      8       00100093    0000 0000 0001 0000 0000 0000 1001 0011
addi x2, x0, 2                              #8      12      00200113    0000 0000 0010 0000 0000 0001 0001 0011

# x4 -> r1
# x1 -> f1
# x2 -> f0
# x3 -> f2

# inst dest, opA/rs1, opB/rs2
#Hazards Checking
j bad
lw x1, 0(x4)                                #12     16
mul     x3,     x2,     x1                  #16     20
sw      x3, 0x0(x4)                         #20     24
addi x4, x4, 4                              #24     28
beq     x4,     x4,     good
lw x1, 0(x4)                                #28     32
mul     x3,     x2,     x1                  #32     36
sw      x3, 0x100(x4)                       #36     40
wfi                                         #40     44
                           
bad: addi x4, x0, 800
addi x1, x0, 1000
addi x2, x0, 2000

good: addi x4, x0, 1600
addi x1, x0, 2000
addi x2, x0, 1200

wfi