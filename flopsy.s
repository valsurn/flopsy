################################################################################
################################################################################
################################## flopsy.s ####################################
################################################################################
################################################################################
#
# A program for playing music using floppy drives or other devices.
#
################################################################################
################################### License ####################################
################################################################################
#
# The MIT License (MIT)
#
# Copyright (c) 2014 Erik Madson
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
#
################################################################################
#################################### Notes #####################################
################################################################################
#
# This code was written for the PIC32MX340F512H.
# If using anything other than the PIC32MX340F512H may require modification.
# many array assume contiguousness to another array, so don't reorder arrays
# make sure that any data that depends on a starting value is not altered
#
################################################################################
################################## Constants ###################################
################################################################################
#
########################## These should be changeable ##########################
#
# Number of samples per FFT. Assumed to be a power of 2 greater than or equal to
# 8 and less than or equal to 16384 (pick the highest value that won't lag)
    .equ N, 512
#
# Number of iterations for the CORDIC algorithm for determining magnitude and
# phase displacement (the higher the number, the better the accuracy)
# Assumed to be less than 32 (and greater than 0)
    .equ CORDIC_ITERATIONS, 15
#
######## These should not be changed unless you know what you're doing #########
#
# Constants for determining space requirements and number of iterations
    .set N_EXPONENT, N|(N>>1)
    .set N_EXPONENT, N_EXPONENT|(N_EXPONENT>>2)
    .set N_EXPONENT, N_EXPONENT|(N_EXPONENT>>4)
    .set N_EXPONENT, N_EXPONENT|(N_EXPONENT>>8)
    .set N_EXPONENT, N_EXPONENT|(N_EXPONENT>>16)
    .set N_EXPONENT, N_EXPONENT-((N_EXPONENT>>1)&0x55555555)
    .set N_EXPONENT, ((N_EXPONENT>>2)&0x33333333)+(N_EXPONENT&0x33333333)
    .set N_EXPONENT, ((N_EXPONENT>>4)+N_EXPONENT)&0x0F0F0F0F
    .set N_EXPONENT, ((N_EXPONENT>>8)+N_EXPONENT)&0x00FF00FF
    .equ N_EXPONENT, (((N_EXPONENT>>16)+N_EXPONENT)&0x0000FFFF)-1
# N_EXPONENT = floor(log2(N)) (for integers within the acceptable range of N)
#
################################################################################
############################## Program #########################################
################################################################################
    .text
    .globl main
    .set noreorder
    .ent main
main:
    addiu $sp, $sp, 8
    li $t0, 10
	sw $t0, 4($sp)
	li $t0, -10
	sw $t0, ($sp)
	jal cordic_rectangular_to_polar
	nop
    lw $t1, ($sp)
    lw $t0, 4($sp)
    nop
    nop
    .end main

################################################################################
# cordic_rectangular_to_polar
# converts a pair of numbers from rectangular to polar coordinates
# uses: $t0, $t1, $t2, $t3, $t4, $t5, $t6, $t7, $t8
# input: x and y, on the stack (($sp+4) = x and ($sp) = y)
# output: magnetude and angle on the stack (($sp+4) = mag and ($sp) = angle)
# x and y are signed words
# magnetude is an unsigned word and is on the same scale as the inputs
# angle is a word (signed or unsigned) where 2^32 ulp = 2 pi radians
################################################################################
cordic_rectangular_to_polar:
    lw $t1, ($sp)               # $t1=y
    lw $t0, 4($sp)              # $t0=x (load delay)
    bgez $t1, cordic_rectangular_to_polar_check_x   # if y<0 (load delay)
    li $t3, 0                   # $t3=angle (branch delay)
    neg $t0, $t0                # x=-x
    neg $t1, $t1                # y=-y
    li $t3, 2147483648          # angle=pi
cordic_rectangular_to_polar_check_x:
    bgez $t0, cordic_rectangular_to_polar_loop_init # if x<0
    li $t5, CORDIC_ITERATIONS   # (branch delay)
    neg $t4, $t0                # temp=-x
    move $t0, $t1               # x=y
    move $t1, $t4               # y=temp
    li $t4, 1073741824
    addu $t3, $t3, $t4          # angle+=pi/2
cordic_rectangular_to_polar_loop_init:
# x and y are now both positive (and have at leat one leading 0)
# shift x and y so that the largest has its left most bit as a 1 and store the
# number of shifts in $t6
    or $t6, $t0, $t1
    clz $t6, $t6
    sllv $t0, $t0, $t6
# shift x and y right 1 and divide by the CORDIC gain (to prevent overflow)
    li $t7, 1304065748
    multu $t0, $t7
    sllv $t1, $t1, $t6          # (multiply delay (?))
    mfhi $t0
    multu $t1, $t7
# subtract one shift to account for the multiply
    addiu $t6, $t6, -1          # (multiply delay (?))
    mfhi $t1
# x and y should now be able to handle being multiplied by
# sqrt(2)*(CORDIC GAIN) then shifted right by $t6 (since $t6>=0)
    li $t4, 0                   # $t4=i=0
    la $t2, arctan_lookup       # pointer to current arctan value
cordic_rectangular_to_polar_loop:
    bltz $t1, cordic_rectangular_to_polar_y_negative    # if y>=0
    srlv $t7, $t0, $t4          # $t7=x>>i (branch delay)
    srlv $t8, $t1, $t4          # $t8=y>>i
    addu $t0, $t0, $t8          # x=x+(y>>i)
    subu $t1, $t1, $t7          # y=y-(x>>i)
    lw $t8, ($t2)               # $t8 = arctan(2^-i)
    addiu $t2, $t2, 4           # increment arctan pointer (load delay)
    addiu $t4, $t4, 1           # increment loop count
    blt $t4, $t5, cordic_rectangular_to_polar_loop  # if i < $t5 loop again
    addu $t3, $t3, $t8          # angle=angle+arctan(2^-i) (branch delay)
    b cordic_rectangular_to_polar_end   # done looping
    srlv $t0, $t0, $t6          # shift x back to its original magnetude
cordic_rectangular_to_polar_y_negative:
    subu $t8, $0, $t1           # $t8=-y (positive)
    srlv $t8, $t8, $t4          # $t8=(-y)>>i
    addu $t0, $t0, $t8          # x=x+((-y)>>i)
    addu $t1, $t1, $t7          # y=y+(x>>i)
    lw $t8, ($t2)               # $t8 = arctan(2^-i)
    addiu $t2, $t2, 4           # increment arctan pointer (load delay)
    addiu $t4, $t4, 1           # increment loop count
    blt $t4, $t5, cordic_rectangular_to_polar_loop  # if i < $t5 loop again
    subu $t3, $t3, $t8          # angle=angle-arctan(2^-i) (branch delay)
    srlv $t0, $t0, $t6          # shift x back to its original magnetude
cordic_rectangular_to_polar_end:
    sw $t3, ($sp)               # store the angle
    sw $t0, 4($sp)              # and x (magnetude) on the stack
    jr $ra
    nop                         # I don't know if I should have a store here...
################################################################################
# fft
################################################################################
fft:

################################################################################
#################################### Data ######################################
################################################################################
    .data
    .include "trig_lookup.s"
