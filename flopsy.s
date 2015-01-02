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
# Copyright (c) 2015 Erik Madson
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
# many arrays assume contiguousness to another array, so don't reorder arrays
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
    .equ N, 1024
#
# Number of iterations for the CORDIC algorithm for determining magnitude and
# phase displacement (the higher the number, the better the accuracy)
# Assumed to be greater than 0 and less than or equal to 30
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
    .equ SAMPLE_SPACE, 4 * N
    .equ FFT_SPACE, 8 * N
#
################################################################################
################################## Includes ####################################
################################################################################
#
   .include "lookup_tables.s"
#
################################################################################
################################### Program ####################################
################################################################################
    .text
    .globl main
    .set noreorder
    .ent main
main:
    la $t0, sample_array_pointer
    la $t1, sample_array_0
    sw $t1, ($t0)
    sw $0, 4($t0)
    sw $0, 8($t0)
    addiu $sp, $sp, -4
    sw $ra, 4($sp)

    lw $ra, 4($sp)
    jr $ra
    addiu $sp, $sp, 4
    .end main

################################################################################
# cordic_rectangular_to_polar
# converts a pair of numbers from rectangular to polar coordinates
# uses: $t0, $t1, $t2, $t3, $t4, $t5, $t6, $t7, $t8
# input: x and y, on the stack (($sp+4) = x and ($sp) = y)
# output: magnetude and angle on the stack (($sp+4) = mag and ($sp) = angle)
# x and y are signed words
# magnetude is an unsigned word and is on the same scale as the inputs
# angle is a word (signed or unsigned) where 2^32 = 2 pi radians
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
    li $t7, HALF_INVERSE_CORDIC_GAIN
    multu $t0, $t7
    sllv $t1, $t1, $t6          # (multiply delay)
    mfhi $t0
    multu $t1, $t7
# subtract one shift to account for the multiply
    addiu $t6, $t6, -1          # (multiply delay)
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
    addiu $sp, $sp, 32
    sw $s0, ($sp)
    sw $s1, 4($sp)
    sw $s2, 8($sp)
    sw $s3, 12($sp)
    sw $s4, 16($sp)
    sw $s5, 20($sp)
    sw $s6, 24($sp)
    sw $s7, 28($sp)
    la $t0, max_fft_shift
    lw $t0, ($t0)                   # $t0 = number of shifts to do
    la $t1, sample_array_pointer    # (load delay)
    lw $t1, ($t1)                   # $t1 = sample array
    la $t2, fft_array               # $t2 = fft arrays (load delay)
    li $t3, 4 * (N - 1)             # $t3 = loop counter
fft_transfer_loop:
    addu $t4, $t1, $t3
    lw $t6, ($t4)                   # $t6 = fft_array[i]
    addu $t5, $t2, $t3              # (load delay)
    addu $t5, $t2, $t3              # 2nd for alternating real and imaginary
    sllv $t6, $t6, $t0              # shift over to increase the resolution
    sw $t6, ($t5)                   # store the shifted value in the real array
    sw $0, 4($t5)                   # store zero in the imaginary array
    bne $0, $t3, fft_transfer_loop
    addiu $t3, $t3, -4              # decrement the loop count (branch delay)
    la $t1, cos_lookup
    li $t3, 1 << (N_EXPONENT - 1 + 2)
    li $t5, 8
    li $t6, N_EXPONENT - 1
    li $s6, 8 * N
# $t0=number of shifts back (shift)
# $t1=cosine lookup table (clt)
# $t2=fft arrays  (ffta)
# $t3=cosine lookup table index incrementor value (a1)
# $t4=difference between indexes in inner loop (offset)
# $t5=fft array index incrementor value (multiplier)
# $t6=outer loop counter (i)
# $t7=middle loop counter (j)
# $t8=cosine lookup table index (a)
# $t9=inner loop counter (k)
# $s0=cos
# $s1=sin
# $s2=address of cos[a] (middle), real[inner loop counter] (inner)
# $s3=imaginary[inner loop counter]
# $s4=real[inner loop counter + difference between indexes in inner loop]
# $s5=imaginary[inner loop counter + difference between indexes in inner loop]
# $s6=max inner loop count
# $s7=temp
# $a0=addres real[inner loop counter]
# $a1=addres real[inner loop counter + difference between indexes in inner loop]
# $a2=$s0*$s4-$s1*$s5
# $a3=$s1*$s4+$s0*$s5
fft_outer_loop:
    addu $t4, $t5, $0
    sll $t5, $t5, 1
    li $t8, 2 * N
    addiu $t7, $t4, -8
fft_middle_loop:
    subu $t8, $t8, $t3
    beqz $t8, fft_inner_loop_last
    addu $t9, $t7, $0   # (branch delay)
    addu $s2, $t1, $t8
    lw $s0, ($s2)
    lw $s1, N($s2)
fft_inner_loop:
    addu $a0, $t2, $t9
    addu $a1, $a0, $t4
    lw $s4, ($a1)
    lw $s5, 4($a1)      # (load delay)
    mult $s0, $s4       # (load delay)
    lw $s3, 4($a0)      # (multiply delay)
    msub $s1, $s5       # (load delay)
    lw $s2, ($a0)       # (multiply delay)
    mfhi $a2            # (load delay)
    mflo $s7
    srl $s7, $s7, 30
    mult $s1, $s4
    addiu $s7, $s7, 1   # (multiply delay)
    madd $s0, $s5
    addu $a2, $a2, $s7  # (multiply delay)
    mfhi $a3
    mflo $s7
    srl $s7, $s7, 30
    addiu $s7, $s7, 1
    srl $s7, $s7, 1
    addu $a3, $a3, $s7
    subu $s7, $s2, $a2
    sw $s7, ($a1)
    subu $s7, $s3, $a3
	sw $s7, 4($a1)
	addu $s7, $s2, $a2
    sw $s7, ($a0)
    addu $s7, $s3, $a3
    sw $s7, 4($a0)
    blt $t9, $s6, fft_inner_loop
    addu $t9, $t9, $t5  # (branch delay)
    b fft_middle_loop
    addiu $t7, $t7, -8  # (branch delay)
fft_inner_loop_last:
    addu $a0, $t2, $t9
    addu $a1, $a0, $t4
    lw $s5, 4($a1)
    lw $s4, ($a1)       # (load delay)
    lw $s2, ($a0)       # (load delay)
    lw $s3, 4($a0)      # (load delay)
    subu $s7, $s2, $s4
    sw $s7, ($a1)
    subu $s7, $s3, $s5
    sw $s7, 4($a1)
    addu $s7, $s2, $s4
    sw $s7, ($a0)
    addu $s7, $s3, $s5
    sw $s7, 4($a0)
    blt $t9, $s6, fft_inner_loop
    addu $t9, $t9, $t5  # (branch delay)
    srl $t3, $t3, 1
    bne $0, $t6, fft_outer_loop
    addiu $t6, $t6, -1  # (branch delay)
# add the CORDIC routine here
# pop the s registers off the stack

# I am planning on integrating this into the ADC read iterrupt
reverse_bits:
    la $t0, sample_index
    lw $t1, ($t0)       # load the previous index
    lw $t3, 4($t0)      # and the previous bit-reversed index
    li $t4, FFT_SPACE - 4   # load the maximum value
    beq $t4, $t1, reverse_bits_reset    # if the maximum value, reset to zero
    addiu $t2, $t1, 4   # else, increment the value (word length) (branch delay)
    xor $t4, $t1, $t2   # all ones after the xor are always contiguous
    clz $t5, $t4        # determine how far to shift the ones over
    addiu $t5, $t5, N_EXPONENT + 2 - 32
    sllv $t5, $t4, $t5  # shift the ones over the ammount determined.
    xor $t3, $t3, $t5   # xor the same number of bits in the bit-reversed word
    sw $t2, ($t0)       # store the new index
    sw $t3, 4($t0)      # store the new bit-reversed index
    jr $ra
    nop
reverse_bits_reset:
    sw $0, ($t0)        # reset the index and the bit reversed index to zero
    sw $0, 4($t0)
    jr $ra
    nop




################################################################################
#################################### Data ######################################
################################################################################
    .data
    .align 2
max_fft_shift:
    .space 4
sample_array_pointer:
    .space 4
sample_index:
    .space 8
sample_array_0:
    .space SAMPLE_SPACE
sample_array_1:
    .space SAMPLE_SPACE
fft_array:
    .space FFT_SPACE
