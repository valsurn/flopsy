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
    .equ N, 32
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
    .equ SAMPLE_SPACE, N
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
    li $t2, N - 4
    li $t3, 0
main_transfer_loop_0:
    addu $t4, $t0, $t3
    lw $t4, ($t4)
    addu $t5, $t1, $t3
    sw $t4, ($t5)
    bne $t2, $t3, main_transfer_loop_0
    addu $t3, $t3, 4
    la $t1, sample_array_pointer_1
    lw $t1, ($t1)
    li $t2, 2 * N - 4
main_transfer_loop_1:
    addu $t4, $t0, $t3
    lw $t4, ($t4)
    addu $t5, $t1, $t3
    sw $t4, -N($t5)
    bne $t2, $t3, main_transfer_loop_1
    addu $t3, $t3, 4
    la $t1, sample_array_pointer_2
    lw $t1, ($t1)
    li $t2, 3 * N - 4
main_transfer_loop_2:
    addu $t4, $t0, $t3
    lw $t4, ($t4)
    addu $t5, $t1, $t3
    sw $t4, -2*N($t5)
    bne $t2, $t3, main_transfer_loop_2
    addu $t3, $t3, 4
    la $t1, sample_array_pointer_3
    lw $t1, ($t1)
    li $t2, 4 * N - 4
main_transfer_loop_3:
    addu $t4, $t0, $t3
    lw $t4, ($t4)
    addu $t5, $t1, $t3
    sw $t4, -3*N($t5)
    bne $t2, $t3, main_transfer_loop_3
    addu $t3, $t3, 4

    jal fft
    nop

    li $t0, 0
    la $t3, fft_array
    li $t2, FFT_SPACE - 8
main_angle_erase:
    addu $t4, $t0, $t3
    sw $0, 4($t4)
    blt $t0, $t2, main_angle_erase
    addu $t0, $t0, 8


    lw $ra, 4($sp)
    jr $ra
    addiu $sp, $sp, 4
    .end main

################################################################################
# fft
# takes 4 arrays (N / 4 words long) pointed to by sample_array_pointer_0,
# sample_array_pointer_1, sample_array_pointer_2, and sample_array_pointer_3 and
# returns an interleaved array (2N words long) containing the magntude and phase
# angle of each frequency. Each phase angle is a word (signed or unsigned) where
# 2^32 is 2 pi radians. Assumes the samples are unsigned.
# uses: $t0, $t1, $t2, $t3, $t4, $t5, $t6, $t7, $t8, $t9, $a0, $a1, $a2, $a3
#       ($s0, $s1, $s2, $s3, $s4, $s5, %s6, %s7 are used, but preserved)
# input: values in max_fft_shift, sample_array_pointer, and samples in the array
# output: fft_array will contain the magnetude and phase of each frequency
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
    la $t1, sample_array_pointer_3  # (load delay)
    lw $t1, ($t1)                   # load the address of the first sample array
    la $s2, fft_array               # address of the output array (load delay)
    li $t3, 4 * N                   # $t3 is the virtual input index + 1 word
    li $t8, 4                       # $t8 is the output index (bit reversed)
    li $t7, 3 * N                   # $t7 is the final index for this array
fft_transfer_loop_0:
    addiu $t9, $t3, -4
    addu $t4, $t1, $t9              # address of the element + $t7
    lw $t6, -3*N($t4)               # load current element into $t6 (minus $t7)
    xor $s1, $t3, $t9               # $s1 = i ^ (i + 1) (always contiguous 1s)
    clz $s3, $s1                    # get the leading zeros
    addiu $s3, $s3, N_EXPONENT - 29 # N_EXPONENT for the size, 3 for the address
    sllv $s1, $s1, $s3              # -32 for the word length, then shift
    xor $t8, $t8, $s1               # xor the 1s onto the MSB side
    addu $t5, $s2, $t8              # determine the output address (bit reverse)
    sllv $t6, $t6, $s0              # shift for maximal resolution w/o overflow
    sw $t6, ($t5)                   # store the value in the real index
    sw $0, 4($t5)                   # store a zero in the imaginary index
    bne $t7, $t9, fft_transfer_loop_0   # loop through this partial array
    addiu $t3, $t3, -4              # decrement $t3 (branch delay)
    la $t1, sample_array_pointer_2  # switch to the next sub array
    lw $t1, ($t1)
    li $t7, 2 * N                   # change the final index
fft_transfer_loop_1:
    addiu $t9, $t3, -4
    addu $t4, $t1, $t9
    lw $t6, -2*N($t4)               # the offset is also changed here
    xor $s1, $t3, $t9
    clz $s3, $s1
    addiu $s3, $s3, N_EXPONENT - 29
    sllv $s1, $s1, $s3
    xor $t8, $t8, $s1
    addu $t5, $s2, $t8
    sllv $t6, $t6, $s0
    sw $t6, ($t5)
    sw $0, 4($t5)
    bne $t7, $t9, fft_transfer_loop_1
    addiu $t3, $t3, -4              # (branch delay)
    la $t1, sample_array_pointer_1
    lw $t1, ($t1)
    li $t7, N
fft_transfer_loop_2:
    addiu $t9, $t3, -4
    addu $t4, $t1, $t9
    lw $t6, -N($t4)
    xor $s1, $t3, $t9
    clz $s3, $s1
    addiu $s3, $s3, N_EXPONENT - 29
    sllv $s1, $s1, $s3
    xor $t8, $t8, $s1
    addu $t5, $s2, $t8
    sllv $t6, $t6, $s0
    sw $t6, ($t5)
    sw $0, 4($t5)
    bne $t7, $t9, fft_transfer_loop_2
    addiu $t3, $t3, -4              # (branch delay)
    la $t1, sample_array_pointer_0
    lw $t1, ($t1)                   # $t7 no longer needed to track final ($0)
fft_transfer_loop_3:
    addiu $t9, $t3, -4
    addu $t4, $t1, $t9
    lw $t6, ($t4)                   # no offset required either
    xor $s1, $t3, $t9
    clz $s3, $s1
    addiu $s3, $s3, N_EXPONENT - 29
    sllv $s1, $s1, $s3
    xor $t8, $t8, $s1
    addu $t5, $s2, $t8
    sllv $t6, $t6, $s0
    sw $t6, ($t5)
    sw $0, 4($t5)
    bne $0, $t9, fft_transfer_loop_3
    addiu $t3, $t3, -4              # array is populated after (branch delay)
    la $t1, cos_lookup              # the pointer to the cosine lookup table
    li $t3, 2 * N                   # $t3 = difference between lookup indecies
    li $t5, 8                       # ammount to increment inner loop counter
    li $t6, N_EXPONENT - 1          # outer loop counter
    li $s6, 8 * N                   # inner loop maximum
fft_outer_loop:
    addu $t4, $t5, $0               # move increment ammount to the index offset
    sll $t5, $t5, 1                 # double the increment ammount
    li $t8, 2 * N                   # $t8 = lookup index
    addiu $t7, $t4, -8              # $t7 = middle loop counter
fft_middle_loop:
    subu $t8, $t8, $t3              # get next lookup index
    beqz $t8, fft_inner_loop_last   # special case for when the index = 0
    addu $t9, $t7, $0               # inner loop counter = middle (branch delay)
    addu $t2, $t1, $t8              # address of the element in the lookup table
    lw $t0, ($t2)                   # load the cosine value
    lw $s1, N($t2)                  # load the sine value
fft_inner_loop:
    addu $a0, $s2, $t9              # adress of fft[index]
    addu $a1, $a0, $t4              # adress of fft[index + offset]
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
    addu $t9, $t9, $t5              # increment the inner loop counter
    blt $t9, $s6, fft_inner_loop    # if inner loop counter < max value
    sw $s7, 4($a0)                  # store the value (branch delay)
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
    addu $t9, $t9, $t5
    blt $t9, $s6, fft_inner_loop_last
    sw $s7, 4($a0)                  # (branch delay)
    srl $t3, $t3, 1                 # halve the lookup index difference
    bne $0, $t6, fft_outer_loop     # since this is always the last middle loop
    addiu $t6, $t6, -1              # (branch delay)
    li $s1, 8 * (N - 1)             # array index and loop counter
fft_cordic_rectangular_to_polar_conversion_loop:
    addu $s3, $s1, $s2          # load the data for the conversion
    lw $t1, 4($s3)
    lw $t0, ($s3)               # (load delay)
    bgez $t1, fft_cordic_rectangular_to_polar_check_x   # if y<0 (load delay)
    li $t3, 0                   # $t3=angle (branch delay)
    neg $t0, $t0                # x=-x
    neg $t1, $t1                # y=-y
    li $t3, 2147483648          # angle=pi
fft_cordic_rectangular_to_polar_check_x:
    bgez $t0, fft_cordic_rectangular_to_polar_loop_init # if x<0
    li $t5, CORDIC_ITERATIONS   # (branch delay)
    neg $t4, $t0                # temp=-x
    move $t0, $t1               # x=y
    move $t1, $t4               # y=temp
    li $t4, 1073741824
    addu $t3, $t3, $t4          # angle+=pi/2
fft_cordic_rectangular_to_polar_loop_init:
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
fft_cordic_rectangular_to_polar_loop:
    bltz $t1, fft_cordic_rectangular_to_polar_y_negative    # if y>=0
    srlv $t7, $t0, $t4          # $t7=x>>i (branch delay)
    srlv $t8, $t1, $t4          # $t8=y>>i
    addu $t0, $t0, $t8          # x=x+(y>>i)
    subu $t1, $t1, $t7          # y=y-(x>>i)
    lw $t8, ($t2)               # $t8 = arctan(2^-i)
    addiu $t2, $t2, 4           # increment arctan pointer (load delay)
    addiu $t4, $t4, 1           # increment loop count
    blt $t4, $t5, fft_cordic_rectangular_to_polar_loop  # if i < $t5 loop again
    addu $t3, $t3, $t8          # angle=angle+arctan(2^-i) (branch delay)
    b fft_cordic_rectangular_to_polar_end   # done looping
    srlv $t0, $t0, $t6          # shift x back to its original magnetude
fft_cordic_rectangular_to_polar_y_negative:
    subu $t8, $0, $t1           # $t8=-y (positive)
    srlv $t8, $t8, $t4          # $t8=(-y)>>i
    addu $t0, $t0, $t8          # x=x+((-y)>>i)
    addu $t1, $t1, $t7          # y=y+(x>>i)
    lw $t8, ($t2)               # $t8 = arctan(2^-i)
    addiu $t2, $t2, 4           # increment arctan pointer (load delay)
    addiu $t4, $t4, 1           # increment loop count
    blt $t4, $t5, fft_cordic_rectangular_to_polar_loop  # if i < $t5 loop again
    subu $t3, $t3, $t8          # angle=angle-arctan(2^-i) (branch delay)
    srlv $t0, $t0, $t6          # shift x back to its original magnetude
fft_cordic_rectangular_to_polar_end:
    srlv $t0, $t0, $s0          # shift the value back to its proper magnetude
    sw $t0, ($s3)               # store the magnetude back in the array
    sw $t3, 4($s3)              # store the angle back in the array
    bne $0, $s1, fft_cordic_rectangular_to_polar_conversion_loop
    addiu $s1, $s1, -8
    lw $s0, ($sp)               # pop the s registers back
    lw $s1, 4($sp)
    lw $s2, 8($sp)
    lw $s3, 12($sp)
    lw $s4, 16($sp)
    lw $s5, 20($sp)
    lw $s6, 24($sp)
    lw $s7, 28($sp)
    jr $ra                      # return
    addiu $sp, $sp, 32

################################################################################
#################################### Data ######################################
################################################################################
    .data
    .align 2
max_fft_shift:
    .word 15
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
sample_array_0:
    .space SAMPLE_SPACE
sample_array_1:
    .space SAMPLE_SPACE
sample_array_2:
    .space SAMPLE_SPACE
sample_array_3:
    .space SAMPLE_SPACE
sample_array_4:
    .space SAMPLE_SPACE
fft_array:
    .space FFT_SPACE
test_array:
    .word 2514, 2795, 2923, 2828, 2515, 2059, 1581, 1204, 1004, 990, 1099, 1223
    .word 1254, 1127, 846, 487, 166, 0, 58, 339, 767, 1223, 1585, 1777, 1791
    .word 1690, 1581, 1572, 1727, 2040, 2436, 2795
