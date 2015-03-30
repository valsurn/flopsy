################################################################################
################################################################################
################################## flopsy.s ####################################
################################################################################
################################################################################
#
# A program for playing music using floppy drives or other devices
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
# This code was written for the PIC32MX370F512L.
# If using anything other than the PIC32MX370F512L, it may require modification.
# Many arrays assume contiguousness to another array, so don't reorder arrays.
# Make sure that any data that depends on a starting value is not altered.
#
################################################################################
################################## Constants ###################################
################################################################################
#
########################## These should be changeable ##########################
#
# Number of samples per FFT. Assumed to be a power of 2 greater than or equal to
# 8 and less than or equal to 16384 (pick the highest value that won't lag)
    .equ N, 2048
#
# Number of iterations for the CORDIC algorithm for determining magnitude and
# phase displacement (the higher the number, the better the accuracy)
# Assumed to be greater than 0 and less than or equal to 30
    .equ CORDIC_ITERATIONS, 30
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
    .equ SAMPLE_SPACE, N / 2
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
    .set noat
    .ent main
main:
    la $t0, sample_array_pointer_0
    la $t1, sample_array_0
    sw $t1, ($t0)
    la $t0, sample_array_pointer_1
    la $t1, sample_array_1
    sw $t1, ($t0)
    la $t0, sample_array_pointer_2
    la $t1, sample_array_2
    sw $t1, ($t0)
    la $t0, sample_array_pointer_3
    la $t1, sample_array_3
    sw $t1, ($t0)
    la $t0, sample_index
    sw $0, ($t0)
    addiu $sp, $sp, -4
    sw $ra, 4($sp)

    la $t0, test_array
    la $t1, sample_array_pointer_0
    lw $t1, ($t1)
    li $t2, SAMPLE_SPACE - 4
    li $t3, 0
main_transfer_loop_0:
    addu $t4, $t0, $t3
    lw $t4, ($t4)
    addu $t5, $t1, $t3
    sw $t4, ($t5)
    addu $at, $t3, $0
    addu $t3, $t3, 4
    bne $t2, $at, main_transfer_loop_0
    nop
    la $t1, sample_array_pointer_1
    lw $t1, ($t1)
    li $t2, 2 * SAMPLE_SPACE - 4
main_transfer_loop_1:
    addu $t4, $t0, $t3
    lw $t4, ($t4)
    addu $t5, $t1, $t3
    sw $t4, -SAMPLE_SPACE($t5)
    addu $at, $t3, $0
    addu $t3, $t3, 4
    bne $t2, $at, main_transfer_loop_1
    nop
    la $t1, sample_array_pointer_2
    lw $t1, ($t1)
    li $t2, 3 * SAMPLE_SPACE - 4
main_transfer_loop_2:
    addu $t4, $t0, $t3
    lw $t4, ($t4)
    addu $t5, $t1, $t3
    sw $t4, -2*SAMPLE_SPACE($t5)
    addu $at, $t3, $0
    addu $t3, $t3, 4
    bne $t2, $at, main_transfer_loop_2
    nop
    la $t1, sample_array_pointer_3
    lw $t1, ($t1)
    li $t2, 4 * SAMPLE_SPACE - 4
main_transfer_loop_3:
    addu $t4, $t0, $t3
    lw $t4, ($t4)
    addu $t5, $t1, $t3
    sw $t4, -3*SAMPLE_SPACE($t5)
    addu $at, $t3, $0
    addu $t3, $t3, 4
    bne $t2, $at, main_transfer_loop_3
    nop

    jal fft
    nop

    li $t0, 0
    la $t3, fft_array
    li $t2, FFT_SPACE - 8
main_angle_erase:
    addu $t4, $t0, $t3
    sw $0, 4($t4)
    sltu $at, $t0, $t2
    bne $at, $0, main_angle_erase
    addu $t0, $t0, 8

    lw $ra, 4($sp)
    jr $ra
    addiu $sp, $sp, 4
    .end main

################################################################################
# fft
# takes 4 arrays (N/8 words long) pointed to by sample_array_pointer_0,
# sample_array_pointer_1, sample_array_pointer_2, and sample_array_pointer_3 and
# returns an interleaved array (2N words long) containing the magnitude & phase
# angle of each frequency. Each phase angle is a word (signed or unsigned) where
# 2^32 is 2 pi radians. Assumes the samples are unsigned.
# uses: $t0, $t1, $t2, $t3, $t4, $t5, $t6, $t7, $t8, $t9, $a0, $a1, $a2, $a3
#       ($s0, $s1, $s2, $s3, $s4, $s5, %s6, %s7 are used, but preserved)
# input: values in max_fft_shift, sample_array_pointer_0,
#        sample_array_pointer_1, sample_array_pointer_2,
#        sample_array_pointer_3, and samples in the 4 arrays
# output: fft_array will contain the magnitude and phase of each frequency
################################################################################
fft:
    addiu $sp, $sp, -32             # push the s registers to the stack
    sw $s0, ($sp)
    sw $s1, 4($sp)
    sw $s2, 8($sp)
    sw $s3, 12($sp)
    sw $s4, 16($sp)
    sw $s5, 20($sp)
    sw $s6, 24($sp)
    sw $s7, 28($sp)
    la $s0, max_fft_shift           # contains the number of shifts to increase
    lw $s0, ($s0)                   # the resolution when multiplying
    la $a0, sample_array_pointer_0  # (load delay)
    lw $a0, ($a0)                   # load the addresses of the sample arrays
    la $a1, sample_array_pointer_1  # (load delay)
    lw $a1, ($a1)
    la $a2, sample_array_pointer_2  # (load delay)
    lw $a2, ($a2)
    la $a3, sample_array_pointer_3  # (load delay)
    lw $a3, ($a3)
    la $s2, fft_array               # address of the output array (load delay)
    li $t3, SAMPLE_SPACE            # $t3 is the virtual input index + 1 word
    li $t8, 32                      # $t8 is the output index (bit reversed)
    la $s7, hann_lookup             # load the address of the window function
fft_transfer_loop:
    addiu $t9, $t3, -4
    xor $s1, $t3, $t9               # $s1 = i ^ (i + 1) (always contiguous 1s)
    clz $s3, $s1                    # get the leading zeros
    addiu $s3, $s3, N_EXPONENT - 29 # N_EXPONENT for the size, 3 for the address
    sllv $s1, $s1, $s3              # -32 for the word length, then shift
    xor $t8, $t8, $s1               # xor the 1s onto the MSB side
    addu $t5, $s2, $t8              # determine the output address (bit reverse)
    addu $t4, $a0, $t9              # address of the element
    lw $t6, ($t4)                   # load current element into $t6
    addu $t0, $s7, $t9              # $t0 = address of the window function value
    lw $s6, ($t0)                   # load the window function value
    sllv $t6, $t6, $s0              # shift for maximal resolution w/o overflow
    mult $s6, $t6                   # multiply by the window function
    sw $0, 4($t5)                   # store a zero in the imaginary index
    mfhi $t6                        # move the value into $t6
    mflo $s6                        # move the fractional part into $s6
    srl $s6, $s6, 30                # two MSB of the fractional part
    addiu $s6, $s6, 1               # $s6 += 0.5
    srl $s6, $s6, 1                 # 00 -> 0, 01 -> 1, 10 -> 1, 11 -> 2
    sll $t6, $t6, 1                 # multiply by 2 because of the multiply
    addu $t6, $t6, $s6              # add the rounded fractional part in
    sw $t6, ($t5)                   # store the value in the real index
    sw $0, 8($t5)                   # zero pad the array, since each upper index
    sw $0, 12($t5)                  # is reversed to 1 + lower reversed
    addu $t4, $a1, $t9              # address of the element
    lw $t6, ($t4)                   # load current element into $t6
    addiu $t0, $t0, SAMPLE_SPACE    # move one array worth for the next value
    lw $s6, ($t0)                   # load the window function value
    sllv $t6, $t6, $s0              # shift for maximal resolution w/o overflow
    mult $s6, $t6                   # multiply by the window function
    sw $0, 36($t5)                  # store a zero in the imaginary index
    mfhi $t6                        # move the value into $t6
    mflo $s6                        # move the fractional part into $s6
    srl $s6, $s6, 30                # two MSB of the fractional part
    addiu $s6, $s6, 1               # $s6 += 0.5
    srl $s6, $s6, 1                 # 00 -> 0, 01 -> 1, 10 -> 1, 11 -> 2
    sll $t6, $t6, 1                 # multiply by 2 because of the multiply
    addu $t6, $t6, $s6              # add the rounded fractional part in
    sw $t6, 32($t5)                 # store the value in the real index
    sw $0, 40($t5)                  # zero pad the array, since each upper index
    sw $0, 44($t5)                  # is reversed to 1 + lower reversed
    addu $t4, $a2, $t9              # address of the element
    lw $t6, ($t4)                   # load current element into $t6
    addiu $t0, $t9, 4-2*SAMPLE_SPACE# symmetry of the window function
    subu $t0, $s7, $t0              # $t0 = address of the window function value
    lw $s6, ($t0)                   # load the window function value
    sllv $t6, $t6, $s0              # shift for maximal resolution w/o overflow
    mult $s6, $t6                   # multiply by the window function
    sw $t6, 16($t5)                 # store the value in the real index
    mfhi $t6                        # move the value into $t6
    mflo $s6                        # move the fractional part into $s6
    srl $s6, $s6, 30                # two MSB of the fractional part
    addiu $s6, $s6, 1               # $s6 += 0.5
    srl $s6, $s6, 1                 # 00 -> 0, 01 -> 1, 10 -> 1, 11 -> 2
    sll $t6, $t6, 1                 # multiply by 2 because of the multiply
    addu $t6, $t6, $s6              # add the rounded fractional part in
    sw $0, 20($t5)                  # store a zero in the imaginary index
    sw $0, 24($t5)                  # zero pad the array, since each upper index
    sw $0, 28($t5)                  # is reversed to 1 + lower reversed
    addu $t4, $a3, $t9              # address of the element
    lw $t6, ($t4)                   # load current element into $t6
    subu $t0, $t0, SAMPLE_SPACE     # move back 1 array worth for the next value
    lw $s6, ($t0)                   # load the window function value
    sllv $t6, $t6, $s0              # shift for maximal resolution w/o overflow
    mult $s6, $t6                   # multiply by the window function
    sw $0, 52($t5)                  # store a zero in the imaginary index
    mfhi $t6                        # move the value into $t6
    mflo $s6                        # move the fractional part into $s6
    srl $s6, $s6, 30                # two MSB of the fractional part
    addiu $s6, $s6, 1               # $s6 += 0.5
    srl $s6, $s6, 1                 # 00 -> 0, 01 -> 1, 10 -> 1, 11 -> 2
    sll $t6, $t6, 1                 # multiply by 2 because of the multiply
    addu $t6, $t6, $s6              # add the rounded fractional part in
    sw $t6, 48($t5)                 # store the value in the real index
    sw $0, 56($t5)                  # zero pad the array, since each upper index
    sw $0, 60($t5)                  # is reversed to 1 + lower reversed
    bne $0, $t9, fft_transfer_loop  # loop through the array
    addiu $t3, $t3, -4              # decrement $t3 (branch delay)
    la $t1, cos_lookup              # the pointer to the cosine lookup table
    li $t3, 2 * N                   # $t3 = difference between lookup indices
    li $t5, 8                       # amount to increment inner loop counter
    li $t6, N_EXPONENT - 1          # outer loop counter
    li $s6, 8 * N                   # inner loop maximum
fft_outer_loop:
    addu $t4, $t5, $0               # move increment amount to the index offset
    sll $t5, $t5, 1                 # double the increment amount
    li $t8, 2 * N                   # $t8 = lookup index
    addiu $t7, $t4, -8              # $t7 = middle loop counter
fft_middle_loop:
    subu $t8, $t8, $t3              # get next lookup index
    beq $t8, $0, fft_inner_loop_last   # special case for when the index = 0
    addu $t9, $t7, $0               # inner loop counter = middle (branch delay)
    addu $t2, $t1, $t8              # address of the element in the lookup table
    lw $t0, ($t2)                   # load the cosine value
    lw $s1, N($t2)                  # load the sine value
fft_inner_loop:
    addu $a0, $s2, $t9              # address of fft[index]
    addu $a1, $a0, $t4              # address of fft[index + offset]
    lw $s4, ($a1)                   # load re(fft[index + offset])
    lw $s5, 4($a1)                  # load im(fft[index + offset]) (load delay)
    mult $t0, $s4                   # cos * re(fft[index + offset]) (load delay)
    lw $s3, 4($a0)                  # load im(fft[index]) (multiply delay)
    msub $s1, $s5                   # sin * im(fft[index + offset]) (load delay)
    lw $t2, ($a0)                   # load re(fft[index]) (multiply delay)
    mfhi $a2                        # $a2 = (cos*re-sin*im)/2 (load delay)
    mflo $s7                        # $s7 = fractional part
    sll $a2, $a2, 1                 # $a2 = cos*re-sin*im
    srl $s7, $s7, 30                # two MSB of the fractional part
    mult $s1, $s4                   # sin * re(fft[index])
    addiu $s7, $s7, 1               # $s7 += 0.5 (multiply delay)
    srl $s7, $s7, 1                 # 00 -> 0, 01 -> 1, 10 -> 1, 11 -> 2
    madd $t0, $s5                   # cos * im(fft[index])
    addu $a2, $a2, $s7              # round cos*re-sin*im (multiply delay)
    mfhi $a3                        # $a3 = (sin*re+cos*im)/2
    mflo $s7                        # $s7 = fractional part
    srl $s7, $s7, 30                # two MSB of the fractional part
    addiu $s7, $s7, 1               # $s7 += 0.5
    srl $s7, $s7, 1                 # 00 -> 0, 01 -> 1, 10 -> 1, 11 -> 2
    sll $a3, $a3, 1                 # $a3 = sin*re+cos*im
    addu $a3, $a3, $s7              # round sin*re+cos*im
    subu $s7, $t2, $a2              # re(fft[index]) - (cos*re-sin*im)
    sw $s7, ($a1)                   # store the value
    subu $s7, $s3, $a3              # im(fft[index]) - (sin*re+cos*im)
    sw $s7, 4($a1)                  # store the value
    addu $s7, $t2, $a2              # re(fft[index]) + (cos*re-sin*im)
    sw $s7, ($a0)                   # store the value
    addu $s7, $s3, $a3              # im(fft[index]) + (sin*re+cos*im)
    sw $s7, 4($a0)                  # store the value
    sltu $at, $t9, $s6
    bne $at, $0, fft_inner_loop     # if inner loop counter < max value
    addu $t9, $t9, $t5              # increment inner loop counter(branch delay)
    b fft_middle_loop               # branch back to the middle loop
    addiu $t7, $t7, -8              # decrement middle loop count (branch delay)
fft_inner_loop_last:
    addu $a0, $s2, $t9              # special case since cos = 1 & sin = 0
    addu $a1, $a0, $t4              # 1 is too large to represent w/o changing
    lw $s5, 4($a1)                  # the scale of the cos lookup table
    lw $s4, ($a1)                   # (load delay)
    lw $t2, ($a0)                   # (load delay)
    lw $s3, 4($a0)                  # (load delay)
    subu $s7, $t2, $s4              # (load delay)
    sw $s7, ($a1)
    subu $s7, $s3, $s5
    sw $s7, 4($a1)
    addu $s7, $t2, $s4
    sw $s7, ($a0)
    addu $s7, $s3, $s5
    sw $s7, 4($a0)
    sltu $at, $t9, $s6
    bne $at, $0, fft_inner_loop_last
    addu $t9, $t9, $t5              # (branch delay)
    srl $t3, $t3, 1                 # halve the lookup index difference
    bne $0, $t6, fft_outer_loop     # since this is always the last middle loop
    addiu $t6, $t6, -1              # (branch delay)
    li $s1, 8 * (N - 1)             # array index and loop counter
fft_cordic_rectangular_to_polar_conversion_loop:
    addu $s3, $s1, $s2              # load the data for the conversion
    lw $t1, 4($s3)
    lw $t0, ($s3)                   # (load delay)
    bgez $t1, fft_cordic_rectangular_to_polar_check_x   # if y<0 (load delay)
    li $t3, 0                       # $t3=angle (branch delay)
    subu $t0, $0, $t0               # x=-x
    subu $t1, $0, $t1               # y=-y
    li $t3, 2147483648              # angle=pi
fft_cordic_rectangular_to_polar_check_x:
    bgez $t0, fft_cordic_rectangular_to_polar_loop_init # if x<0
    li $t5, CORDIC_ITERATIONS       # (branch delay)
    subu $t4, $0, $t0               # temp=-x
    addu $t0, $0, $t1               # x=y
    addu $t1, $0, $t4               # y=temp
    li $t4, 1073741824
    addu $t3, $t3, $t4              # angle+=pi/2
fft_cordic_rectangular_to_polar_loop_init:
# x and y are now both positive (and have at least one leading 0)
# shift x and y so that the largest has its left most bit as a 1 and store the
# number of shifts in $t6
    or $t6, $t0, $t1
    clz $t6, $t6
    sllv $t0, $t0, $t6
# shift x and y right 1 and divide by the CORDIC gain (to prevent overflow)
    li $t7, HALF_INVERSE_CORDIC_GAIN
    multu $t0, $t7
    sllv $t1, $t1, $t6              # (multiply delay)
    mfhi $t0
    multu $t1, $t7
# subtract one shift to account for the multiply
    addiu $t6, $t6, -1              # (multiply delay)
    mfhi $t1
# x and y should now be able to handle being multiplied by
# sqrt(2)*(CORDIC GAIN) then shifted right by $t6 (since $t6>=0)
    li $t4, 0                       # $t4=i=0
    la $t2, arctan_lookup           # pointer to current arctan value
fft_cordic_rectangular_to_polar_loop:
    bltz $t1, fft_cordic_rectangular_to_polar_y_negative    # if y>=0
    srlv $t7, $t0, $t4              # $t7=x>>i (branch delay)
    srlv $t8, $t1, $t4              # $t8=y>>i
    addu $t0, $t0, $t8              # x=x+(y>>i)
    subu $t1, $t1, $t7              # y=y-(x>>i)
    lw $t8, ($t2)                   # $t8 = arctan(2^-i)
    addiu $t2, $t2, 4               # increment arctan pointer (load delay)
    addiu $t4, $t4, 1               # increment loop count
    slt $at, $t4, $t5
    bne $at, $0, fft_cordic_rectangular_to_polar_loop  # if i < $t5 loop again
    addu $t3, $t3, $t8              # angle=angle+arctan(2^-i) (branch delay)
    b fft_cordic_rectangular_to_polar_end   # done looping
    srlv $t0, $t0, $t6              # shift x back to its original magnitude
fft_cordic_rectangular_to_polar_y_negative:
    subu $t8, $0, $t1               # $t8=-y (positive)
    srlv $t8, $t8, $t4              # $t8=(-y)>>i
    addu $t0, $t0, $t8              # x=x+((-y)>>i)
    addu $t1, $t1, $t7              # y=y+(x>>i)
    lw $t8, ($t2)                   # $t8 = arctan(2^-i)
    addiu $t2, $t2, 4               # increment arctan pointer (load delay)
    addiu $t4, $t4, 1               # increment loop count
    slt $at, $t4, $t5
    bne $at, $0, fft_cordic_rectangular_to_polar_loop  # if i < $t5 loop again
    subu $t3, $t3, $t8              # angle=angle-arctan(2^-i) (branch delay)
    srlv $t0, $t0, $t6              # shift x back to its original magnitude
fft_cordic_rectangular_to_polar_end:
    srlv $t0, $t0, $s0          # shift the value back to its proper magnitude
    sw $t0, ($s3)               # store the magnitude back in the array
    sw $t3, 4($s3)              # store the angle back in the array
    bne $0, $s1, fft_cordic_rectangular_to_polar_conversion_loop
    addiu $s1, $s1, -8







    lw $s0, ($sp)                   # pop the s registers back
    lw $s1, 4($sp)
    lw $s2, 8($sp)
    lw $s3, 12($sp)
    lw $s4, 16($sp)
    lw $s5, 20($sp)
    lw $s6, 24($sp)
    lw $s7, 28($sp)
    jr $ra                          # return
    addiu $sp, $sp, 32
################################################################################
# timer_isr
################################################################################
timer_isr:
# isr stuff
# loop through all the pins and the adc and increment their counts.
# for the output pins, set the output to their sign bits
# for the adc if the unsigned count is less than the increment, sample the adc
# insert the sample into the array pointed to by sample_array_pointer_adc
# at the position indicated by sample index
# update the min max and sum
# increment sample index
# if sample index == max value, rotate the array pointers, reset sample index,
# set the min, max, and sum to their starting values (max int, min int, 0)
# every other swap, initiate the fft routine to update the frequencies
# isr stuff
# return
################################################################################
# pin_change_isr
################################################################################
pin_change_isr:
# isr stuff
# loop through each input pin and set the corresponding increment to 0 or non 0
# if the increment is zero, set the count to zero
# if non zero, check the increment. if not 0, leave it alone otherwise make it 1
# count how many enabled output pins there are and store the value
# initiate the frequency update isr
# isr stuff
# return
################################################################################
#################################### Data ######################################
################################################################################
    .data
    .align 2
sample_index:
    .space 4
sample_array_pointer_0:
    .space 4
sample_array_pointer_1:
    .space 4
sample_array_pointer_2:
    .space 4
sample_array_pointer_3:
    .space 4
sample_array_pointer_adc:
    .space 4
sample_array_0:
    .space SAMPLE_SPACE
sample_array_0_max_min_sum:
    .space 12
sample_array_1:
    .space SAMPLE_SPACE
sample_array_1_max_min_sum:
    .space 12
sample_array_2:
    .space SAMPLE_SPACE
sample_array_2_max_min_sum:
    .space 12
sample_array_3:
    .space SAMPLE_SPACE
sample_array_3_max_min_sum:
    .space 12
sample_array_4:
    .space SAMPLE_SPACE
sample_array_4_max_min_sum:
    .space 12
fft_array:
    .space FFT_SPACE
input_pin_address:
    .space 100
output_pin_address:
    .space 100
output_pin_count:
    .space 100
adc_count:
    .space 4
output_pin_increment:
    .space 100
adc_increment:
    .space 4
number_of_active_pins:
    .space 4



test_array:
    .word 2549, 2630, 2693, 2736, 2757, 2754, 2727, 2675, 2598, 2497, 2374, 2231
    .word 2070, 1893, 1705, 1511, 1311, 1113, 919, 734, 562, 407, 274, 164, 80
    .word 25, 0, 5, 41, 107, 202, 324, 469, 636, 820, 1017, 1224, 1435, 1645
    .word 1852, 2050, 2235, 2403, 2552, 2678, 2779, 2853, 2899, 2918, 2908, 2872
    .word 2811, 2726, 2620, 2497, 2358, 2209, 2051, 1890, 1728, 1569, 1416, 1272
    .word 1139, 1020, 917, 829, 759, 707, 672, 654, 652, 665, 690, 727, 774, 828
    .word 888, 951, 1016, 1082, 1147, 1210, 1269, 1326, 1378, 1426, 1471, 1513
    .word 1551, 1588, 1624, 1659, 1695, 1732, 1771, 1813, 1856, 1902, 1949, 1998
    .word 2048, 2097, 2145, 2189, 2229, 2262, 2287, 2301, 2305, 2296, 2272, 2234
    .word 2180, 2110, 2026, 1926, 1812, 1687, 1551, 1409, 1260, 1109, 960, 814
    .word 677, 550, 438, 344, 269, 218, 190, 189, 214, 267, 345, 450, 578, 728
    .word 897, 1082, 1278, 1483, 1690, 1897, 2099, 2291, 2469, 2630, 2769, 2883
    .word 2971, 3029, 3058, 3055, 3022, 2959, 2867, 2749, 2607, 2445, 2266, 2074
    .word 1874, 1669, 1465, 1265, 1074, 895, 732, 589, 467, 369, 296, 248, 228
    .word 232, 262, 315, 389, 482, 591, 713, 845, 984, 1126, 1268, 1408, 1541
    .word 1668, 1784, 1889, 1981, 2059, 2123, 2173, 2208, 2230, 2240, 2239, 2228
    .word 2208, 2182, 2151, 2116, 2078, 2039, 2001, 1963, 1926, 1890, 1856, 1823
    .word 1792, 1760, 1728, 1695, 1659, 1621, 1579, 1533, 1483, 1427, 1366, 1300
    .word 1230, 1156, 1081, 1005, 929, 856, 788, 727, 674, 633, 604, 591, 593
    .word 613, 651, 708, 784, 878, 990, 1117, 1259, 1411, 1572, 1739, 1908, 2076
    .word 2239, 2393, 2534, 2660, 2766, 2850, 2910, 2943, 2948, 2925, 2873, 2793
    .word 2686, 2555, 2400, 2227, 2037, 1835, 1625, 1413, 1201, 995, 799, 617
    .word 453, 312, 194, 104, 43, 12, 12, 41, 101, 188, 300, 436, 591, 762, 945
    .word 1136, 1331, 1525, 1715, 1896, 2066, 2220, 2357, 2473, 2567, 2637, 2685
    .word 2708, 2708, 2685, 2642, 2581, 2502, 2410, 2306, 2194, 2077, 1956, 1836
    .word 1718, 1605, 1499, 1400, 1311, 1232, 1164, 1107, 1061, 1025, 998, 980
    .word 970, 966, 967, 972, 980, 990, 1001, 1012, 1023, 1034, 1045, 1056, 1067
    .word 1080, 1095, 1114, 1136, 1163, 1197, 1237, 1286, 1342, 1406, 1479, 1558
    .word 1645, 1739, 1837, 1937, 2039, 2139, 2236, 2327, 2408, 2479, 2536, 2578
    .word 2601, 2605, 2589, 2551, 2491, 2410, 2308, 2186, 2046, 1892, 1724, 1547
    .word 1366, 1181, 997, 820, 652, 499, 362, 246, 154, 88, 50, 41, 61, 112
    .word 192, 299, 432, 588, 764, 955, 1159, 1370, 1584, 1797, 2004, 2201, 2384
    .word 2548, 2690, 2808, 2899, 2962, 2995, 2998, 2973, 2919, 2838, 2733, 2606
    .word 2461, 2301, 2130, 1951, 1769, 1588, 1412, 1243, 1086, 942, 815, 707
    .word 618, 550, 504, 478, 473, 488, 520, 568, 630, 704, 787, 877, 972, 1068
    .word 1165, 1259, 1350, 1435, 1514, 1586, 1650, 1708, 1757, 1800, 1836, 1867
    .word 1893, 1915, 1935, 1952, 1968, 1984, 2000, 2016, 2033, 2049, 2066, 2081
    .word 2095, 2106, 2113, 2114, 2109, 2097, 2075, 2043, 2001, 1947, 1881, 1804
    .word 1716, 1618, 1511, 1396, 1275, 1151, 1025, 902, 783, 672, 571, 483, 412
    .word 359, 326, 316, 329, 367, 428, 514, 623, 753, 902, 1068, 1247, 1436
    .word 1631, 1828, 2024, 2213, 2391, 2555, 2700, 2823, 2922, 2993
max_fft_shift:
    .word 11
