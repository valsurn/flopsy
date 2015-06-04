###############################################################################
###############################################################################
################################## flopsy.s ###################################
###############################################################################
###############################################################################
#
# A program for playing music using floppy drives or other devices
#
###############################################################################
################################### License ###################################
###############################################################################
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
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
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
###############################################################################
#################################### Notes ####################################
###############################################################################
#
# This code was written for the PIC32MX370F512L
# If using anything other than the PIC32MX370F512L, it may require modification
# Many arrays assume contiguousness to another array, so don't reorder arrays
# Make sure that any data that depends on a starting value is not altered
#
###############################################################################
################################## Constants ##################################
###############################################################################
#
########################## These should be changeable #########################
#
# Number of samples per FFT. Assumed to be a power of 2 greater than or equal
# to 8 and less than or equal to 16384 (pick the highest value that won't lag)
# Half of these positions will be filled with zeros
    .equ N, 1024
#
# Number of iterations for the CORDIC algorithm for determining magnitude and
# phase displacement (the higher the number, the better the accuracy)
# Assumed to be greater than 0 and less than or equal to 30
    .equ CORDIC_ITERATIONS, 30
#
######## These should not be changed unless you know what you're doing ########
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
###############################################################################
################################## Includes ###################################
###############################################################################
#
   .include "lookup_tables.s"
#
###############################################################################
################################### Program ###################################
###############################################################################
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
    or $at, $t3, $0
    bne $t2, $at, main_transfer_loop_0
    addiu $t3, $t3, 4
    la $t1, sample_array_pointer_1
    lw $t1, ($t1)
    li $t2, 2 * SAMPLE_SPACE - 4
main_transfer_loop_1:
    addu $t4, $t0, $t3
    lw $t4, ($t4)
    addu $t5, $t1, $t3
    sw $t4, -SAMPLE_SPACE($t5)
    or $at, $t3, $0
    bne $t2, $at, main_transfer_loop_1
    addiu $t3, $t3, 4
    la $t1, sample_array_pointer_2
    lw $t1, ($t1)
    li $t2, 3 * SAMPLE_SPACE - 4
main_transfer_loop_2:
    addu $t4, $t0, $t3
    lw $t4, ($t4)
    addu $t5, $t1, $t3
    sw $t4, -2*SAMPLE_SPACE($t5)
    or $at, $t3, $0
    bne $t2, $at, main_transfer_loop_2
    addiu $t3, $t3, 4
    la $t1, sample_array_pointer_3
    lw $t1, ($t1)
    li $t2, 4 * SAMPLE_SPACE - 4
main_transfer_loop_3:
    addu $t4, $t0, $t3
    lw $t4, ($t4)
    addu $t5, $t1, $t3
    sw $t4, -3*SAMPLE_SPACE($t5)
    or $at, $t3, $0
    bne $t2, $at, main_transfer_loop_3
    addiu $t3, $t3, 4

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
    addiu $t0, $t0, 8

    lw $ra, 4($sp)
    jr $ra
    addiu $sp, $sp, 4
    .end main

###############################################################################
# fft
# Takes 4 arrays (N/8 words long) pointed to by sample_array_pointer_0,
# sample_array_pointer_1, sample_array_pointer_2, and sample_array_pointer_3
# and populates an interleaved array (2N words long) containing the magnitude
# and phase angle of each frequency. Each phase angle is a word
# (signed or unsigned) where 2^32 would be 2 pi radians.
# uses: $t0, $t1, $t2, $t3, $t4, $t5, $t6, $t7, $t8, $t9, $a0, $a1, $a2, $a3
#       ($s0, $s1, $s2, $s3, $s4, $s5, %s6, %s7 are used, but preserved)
# input: values in max_fft_shift, sample_array_pointer_0,
#        sample_array_pointer_1, sample_array_pointer_2,
#        sample_array_pointer_3, and samples in the 4 arrays
# output: fft_array will contain the magnitude and phase of each frequency
###############################################################################
fft:
# since this routine needs a lot of registers, push all the s registers to the
# stack
    addiu $sp, $sp, -32
    sw $s0, ($sp)
    sw $s1, 4($sp)
    sw $s2, 8($sp)
    sw $s3, 12($sp)
    sw $s4, 16($sp)
    sw $s5, 20($sp)
    sw $s6, 24($sp)
    sw $s7, 28($sp)

# max_fft_shift is the number of shifts the fft routine will shift the value in
# order to have the highest possible resolution during the integer calculations
    la $s0, max_fft_shift
    lw $s0, ($s0)

# load the addresses of the array pointers then load the addresses of the
# arrays
    la $a0, sample_array_pointer_0                          # load delay
    lw $a0, ($a0)
    la $a1, sample_array_pointer_1                          # load delay
    lw $a1, ($a1)
    la $a2, sample_array_pointer_2                          # load delay
    lw $a2, ($a2)
    la $a3, sample_array_pointer_3                          # load delay
    lw $a3, ($a3)

# load the address of the fft array
# this will be where fft calculations are done
    la $s2, fft_array                                       # load delay

# load the number of samples before zero extending (this is an index)
    li $t3, SAMPLE_SPACE

# load the staring value for bit reversed indices
# this would normally be the bit reversal of SAMPLE_SPACE
# the last two zeros are for the fact that the words are 4 bytes long
# the other two zeros (during the first iteration there will be a third zero)
# are taking advantage of the fact that 8 loops can be made into one, since
# each sample array is one eighth of the total array and partitioning the array
# into eight parts will always have the parts follow the sequence
# 0, 4, 2, 6, 1, 5, 3, 7 and in this case 4, 5, 6, and 7 are all zeros
# adding an offset of 0 to 60 completes the bit reversal
    li $t8, 32

# load the address of the lookup table containing the Hann window function
    la $s7, hann_lookup

# begin the loop for transferring samples from the sample arrays, bit reversing
# the index, multiplying by the Hann window function, and storing the sample in
# an array
fft_transfer_loop:

# subtract 4 from the index and put it in a new register
    addiu $t9, $t3, -4
# n xor (n +- 2^m) always gives contiguous 1s
# this means the result of the xor can always be bit reversed by shifting
# xor the shifted result with the bit-reversed index to perform the subtraction
    xor $s1, $t3, $t9
# in order to know how far to shift, count the leading zeros
# 32 - N_EXPONENT <= number of leading zeros <= 29
    clz $s3, $s1
# if the result is 29, it needs to shift over N_EXPONENT times
# if it is 29 that means only the LSB changed; shifting it N_EXPONENT - 1 times
# puts it in the MSB position
# add one more shift because of the interleaved imaginary values
# for each additional 1, there is one less leading 0, which means one less
# shift
# the number of leading zeros - 29 + N_EXPONENT gives the number of shifts
    addiu $s3, $s3, N_EXPONENT-29
    sllv $s1, $s1, $s3
# xor the result into the bit-reversed number
# this changes the MSB of the bit-reversed index just like subtraction does
# to the LSB of the original index
    xor $t8, $t8, $s1
# add the bit-reversed index to the fft array address
# (valid for the rest of the iteration of the transfer loop)
    addu $t5, $s2, $t8

# add the index to array 0's address and load the word
    addu $t4, $a0, $t9
    lw $t6, ($t4)
# add the index to the address of the window function array and load the word
    addu $t0, $s7, $t9                                      # load delay
    lw $s6, ($t0)
# shift to increase the resolution of the multiplication without overflowing
    sllv $t6, $t6, $s0                                      # load delay
# multiply the sample by the window function value (hi contains the product/2)
    mult $s6, $t6
# store the interleaved imaginary portion of the sample (always zero)
    sw $0, 4($t5)                                           # multiply delay
# move the product into the general purpose registers
    mfhi $t6
    mflo $s6
# shifting the fractional part over 30 leaves just the 2 MSBs
    srl $s6, $s6, 30
# the MSBs can be 00, 01, 10, or 11
# to round add 0 if 00, 1 if 01 or 10, and 2 if 11
# this is the same as adding 1 and right shifting 1
# (or adding 0.5 and flooring)
    addiu $s6, $s6, 1
    srl $s6, $s6, 1
# since the multiplication done earlier gives half the product, left shift once
    sll $t6, $t6, 1
# add the rounded part into the product and store it in the fft array
    addu $t6, $t6, $s6
    sw $t6, ($t5)
# store a zero (0+0i) to pad the array
    sw $0, 8($t5)
    sw $0, 12($t5)

# The code above essentially repeats 3 more times with some constants changed

# add the index to array 1's address and load the word
    addu $t4, $a1, $t9
    lw $t6, ($t4)
# add the size of a sample array to the previous window function address and
# load the word
    addiu $t0, $t0, SAMPLE_SPACE                            # load delay
    lw $s6, ($t0)
# shift to increase the resolution of the multiplication without overflowing
    sllv $t6, $t6, $s0                                      # load delay
# multiply the sample by the window function value (hi contains the product/2)
    mult $s6, $t6
# store the interleaved imaginary portion of the sample (always zero)
    sw $0, 36($t5)                                          # multiply delay
# move the product into the general purpose registers
    mfhi $t6
    mflo $s6
# shifting the fractional part over 30 leaves just the 2 MSBs
    srl $s6, $s6, 30
# the MSBs can be 00, 01, 10, or 11
# to round add 0 if 00, 1 if 01 or 10, and 2 if 11
# this is the same as adding 1 and right shifting 1
# (or adding 0.5 and flooring)
    addiu $s6, $s6, 1
    srl $s6, $s6, 1
# since the multiplication done earlier gives half the product, left shift once
    sll $t6, $t6, 1
# add the rounded part into the product and store it in the fft array
# because of the bit reversal these get stored in 0,4,2,6,1,5,3,7 order
# (4, 5, 6, and 7 are the zero padded arrays)
    addu $t6, $t6, $s6
    sw $t6, 32($t5)
# store a zero (0+0i) to pad the array
    sw $0, 40($t5)
    sw $0, 44($t5)

# The code above essentially repeats 2 more times with some constants changed

# add the index to array 2's address and load the word
    addu $t4, $a2, $t9
    lw $t6, ($t4)
# since the window function is symmetrical, only half of it needs to be stored
# the halfway point is located at the end of the array
# the array is twice as long as a sample array so the last element is at
# (window function array address)+2*(size of a sample array)-4
# subtract the index to get the window function value
    addiu $t0, $s7, 2*SAMPLE_SPACE-4                        # load delay
    subu $t0, $t0, $t9
    lw $s6, ($t0)
# shift to increase the resolution of the multiplication without overflowing
    sllv $t6, $t6, $s0                                      # load delay
# multiply the sample by the window function value (hi contains the product/2)
    mult $s6, $t6
# store the interleaved imaginary portion of the sample (always zero)
    sw $0, 20($t5)                                          # multiply delay
# move the product into the general purpose registers
    mfhi $t6
    mflo $s6
# shifting the fractional part over 30 leaves just the 2 MSBs
    srl $s6, $s6, 30
# the MSBs can be 00, 01, 10, or 11
# to round add 0 if 00, 1 if 01 or 10, and 2 if 11
# this is the same as adding 1 and right shifting 1
# (or adding 0.5 and flooring)
    addiu $s6, $s6, 1
    srl $s6, $s6, 1
# since the multiplication done earlier gives half the product, left shift once
    sll $t6, $t6, 1
# add the rounded part into the product and store it in the fft array
# because of the bit reversal these get stored in 0,4,2,6,1,5,3,7 order
# (4, 5, 6, and 7 are the zero padded arrays)
    addu $t6, $t6, $s6
    sw $t6, 16($t5)
# store a zero (0+0i) to pad the array
    sw $0, 24($t5)
    sw $0, 28($t5)

# The code above essentially repeats 1 more time with some constants changed

# add the index to array 3's address and load the word
    addu $t4, $a3, $t9
    lw $t6, ($t4)
# subtract the size of a sample array (because of symmetry) and load the word
    subu $t0, $t0, SAMPLE_SPACE                             # load delay
    lw $s6, ($t0)
# shift to increase the resolution of the multiplication without overflowing
    sllv $t6, $t6, $s0                                      # load delay
# multiply the sample by the window function value (hi contains the product/2)
    mult $s6, $t6
# store the interleaved imaginary portion of the sample (always zero)
    sw $0, 52($t5)                                          # multiply delay
# move the product into the general purpose registers
    mfhi $t6
    mflo $s6
# shifting the fractional part over 30 leaves just the 2 MSBs
    srl $s6, $s6, 30
# the MSBs can be 00, 01, 10, or 11
# to round add 0 if 00, 1 if 01 or 10, and 2 if 11
# this is the same as adding 1 and right shifting 1
# (or adding 0.5 and flooring)
    addiu $s6, $s6, 1
    srl $s6, $s6, 1
# since the multiplication done earlier gives half the product, left shift once
    sll $t6, $t6, 1
# add the rounded part into the product and store it in the fft array
    addu $t6, $t6, $s6
    sw $t6, 48($t5)
# store a zero (0+0i) to pad the array
    sw $0, 56($t5)
    sw $0, 60($t5)

# this is the end of the fft transfer loop
# if the index isn't zero, do another iteration
    bne $0, $t9, fft_transfer_loop
# decrement the previous index (independant of the branch instruction)
    addiu $t3, $t3, -4                                      # branch delay


# initialize registers for the main fft loops
# load the address of the cosine and sine lookup tables
# the sine lookup table overlaps the cosine lookup table and starts an offset
# of N after the cosine
    la $t1, cos_lookup
# initialize the amount to decrement the lookup index
# each time through the outer loop this will be halved
    li $t3, 2 * N
# load the amount to increment the inner loop counter
# this doubles each time through the outer loop
    li $t5, 8
# initialize the outer loop counter
# the outer loop ends after this is zero
    li $t6, N_EXPONENT
# initialize the inner loop maximum
    li $s6, FFT_SPACE

# the fft outer loop runs N_EXPONENT times and determines how far appart each
# pair of elements is appart in the array
fft_outer_loop:

# set the index offset to the amount that the inner loop increments by
    or $t4, $t5, $0
# then double the increment amount
    sll $t5, $t5, 1
# initialize the lookup index
    li $t8, 2 * N
# initialize the middle loop counter
    addiu $t7, $t4, -8

# the fft middle loop increments a counter that between the offset and zero
# it also loads sine and cosine values
fft_middle_loop:

# decrement the lookup index
    subu $t8, $t8, $t3
# if this is the final iteration of the middle loop then branch to the last
# fft inner loop (this is because of how the cosine values are represented;
# a 1 would be 2147483648 which with signed multiplication is -2147483648)
    beq $t8, $0, fft_inner_loop_last
# set the inner loop counter to match the middle loop counter
    or $t9, $t7, $0                                         # branch delay
# since this is not the last iteration of the middle loop, get the cosine and
# sine values from the lookup table
    addu $t2, $t1, $t8
    lw $t0, ($t2)
    lw $s1, N($t2)                                          # load delay

# the inner loop gets the elements from the fft array performs the
# multiplications and additions for each group of elements
fft_inner_loop:

# get the address of the specified index
# this will be referred to as fft[i]
    addu $a0, $s2, $t9                                      # load delay
# get the address of the specified index + the offset
# this will be referred to as fft[i+o]
    addu $a1, $a0, $t4
# load the real and imaginary values of fft[i+o]
    lw $s4, ($a1)
    lw $s5, 4($a1)                                          # load delay
# multiply the real value of fft[i+o] by the cosine value
    mult $t0, $s4                                           # load delay
# load the imaginary value of fft[i]
    lw $s3, 4($a0)                                          # multiply delay
# multiply the imaginary part of fft[i+o] by the sine value and subtract it
# from the previous multiplication
    msub $s1, $s5                                           # load delay
# load the real value of fft[i]
    lw $t2, ($a0)                                           # multiply delay
# the result in hi is (cosine*Re(fft[i+o])-sine*Im(fft[i+o]))/2
# lo is the fractional part
# move both into the general purpose registers
    mfhi $a2                                                # load delay
    mflo $s7
# shift the result over to account for the product being halved
    sll $a2, $a2, 1
# shift the fractional part right 30 times to get the two MSBs
    srl $s7, $s7, 30
# multiply the real value of fft[i] by the sine value
    mult $s1, $s4
# take the two MSB from the previous fractional part and add 1 and shift right
# 00 -> 0, 01 -> 1, 10 -> 1, 11 -> 2
    addiu $s7, $s7, 1                                       # multiply delay
    srl $s7, $s7, 1
# multiply the imaginary part of fft[i] by the cosine value
    madd $t0, $s5
# add the rounded fractional part into the product
    addu $a2, $a2, $s7                                      # multiply delay
# the result in hi is (sine*Re(fft[i])+cosine*Im(fft[i]))/2
# lo is the fractional part
# move both into the general purpose registers
    mfhi $a3
    mflo $s7
# shift the fractional part right 30 times to get the two MSBs
    srl $s7, $s7, 30
# take the two MSB from the previous fractional part and add 1 and shift right
# 00 -> 0, 01 -> 1, 10 -> 1, 11 -> 2
    addiu $s7, $s7, 1
    srl $s7, $s7, 1
# shift the result over to account for the product being halved
    sll $a3, $a3, 1
# add the rounded fractional part into the product
    addu $a3, $a3, $s7
# store Re(fft[i])-(cosine*Re(fft[i+o])-sine*Im(fft[i+o])) to Re(fft[i+o])
    subu $s7, $t2, $a2
    sw $s7, ($a1)
# store Im(fft[i])-(sine*Re(fft[i])+cosine*Im(fft[i])) to Im(fft[i+o])
    subu $s7, $s3, $a3
    sw $s7, 4($a1)
# store Re(fft[i])+(cosine*Re(fft[i+o])-sine*Im(fft[i+o])) to Re(fft[i])
    addu $s7, $t2, $a2
    sw $s7, ($a0)
# calculate Im(fft[i])+(sine*Re(fft[i])+cosine*Im(fft[i]))
    addu $s7, $s3, $a3
# increment the inner loop counter
    addu $t9, $t9, $t5
# if the inner loop counter is less than the length of the array, loop again
    sltu $at, $t9, $s6
    bne $at, $0, fft_inner_loop
# store Im(fft[i])+(sine*Re(fft[i])+cosine*Im(fft[i])) to Im(fft[i])
    sw $s7, 4($a0)                                          # branch delay
# the inner loop is done and this is not the last iteration of the middle loop
# so decrement the middle loop counter and branch back to the middle loop
    b fft_middle_loop
    addiu $t7, $t7, -8                                      # branch delay

# the last fft inner loop is mostly the same as the previous inner loops
# except the cosine value = 1 which can't be represented the same way as the
# others
# no multiplication is necessary, though, since the sine value = 0
fft_inner_loop_last:

# get the address of the specified index
# this will be referred to as fft[i]
    addu $a0, $s2, $t9
# get the address of the specified index + the offset
# this will be referred to as fft[i+o]
    addu $a1, $a0, $t4
# load the real and imaginary parts of fft[i] and fft[i+o]
    lw $s5, 4($a1)
    lw $s4, ($a1)                                           # load delay
    lw $t2, ($a0)                                           # load delay
    lw $s3, 4($a0)                                          # load delay
# store Re(fft[i])-(1*Re(fft[i+o])-0*Im(fft[i+o])) to Re(fft[i+o])
    subu $s7, $t2, $s4                                      # load delay
    sw $s7, ($a1)
# store Im(fft[i])-(0*Re(fft[i])+1*Im(fft[i])) to Im(fft[i+o])
    subu $s7, $s3, $s5
    sw $s7, 4($a1)
# store Re(fft[i])+(1*Re(fft[i+o])-0*Im(fft[i+o])) to Re(fft[i])
    addu $s7, $t2, $s4
    sw $s7, ($a0)
# calculate Im(fft[i])+(0*Re(fft[i])+1*Im(fft[i])) to Im(fft[i])
    addu $s7, $s3, $s5
# increment the inner loop counter
    addu $t9, $t9, $t5
# if the inner loop counter is less than the length of the array, loop again
    sltu $at, $t9, $s6
    bne $at, $0, fft_inner_loop_last
# store Im(fft[i])+(0*Re(fft[i])+1*Im(fft[i])) to Im(fft[i])
    sw $s7, 4($a0)                                          # branch delay
# since the middle loop is done, decrement the outer loop counter
# if it equals zero the loop is done, otherwise loop again
    addiu $t6, $t6, -1
    bne $0, $t6, fft_outer_loop
# halve the amount to increment the lookup index
    srl $t3, $t3, 1                                         # branch delay

# initalize the loop counter
    li $s1, 8 * N

# loop though the fft array and convert each element from rectangular to polar
cordic_rectangular_to_polar_conversion_loop:

# decrement the loop counter
    addiu $s1, $s1, -8
# add the array index to the fft address
    addu $s3, $s1, $s2
# load the real and imaginary components
    lw $t1, 4($s3)
    lw $t0, ($s3)                                           # load delay

# if the imaginary component is less than zero,
    bgez $t1, cordic_rectangular_to_polar_check_real        # load delay
# set the phase angle to zero
    or $t3, $0, $0                                          # branch delay
# since the algorithm only works in the first quadrant, rotate pi radians
# this is the same as flipping the signs of both components
    subu $t0, $0, $t0
    subu $t1, $0, $t1
# set the angle to pi
    li $t3, 2147483648

# the imaginary component is now non-negative
cordic_rectangular_to_polar_check_real:
# if the real component is less than zero,
    bgez $t0, cordic_rectangular_to_polar_loop_init
# load the number of iterations
    li $t5, CORDIC_ITERATIONS                               # branch delay
# since the algorithm only works in the first quadrant, rotate pi/2 radians
# this is the same as x'=y and y'=-x
    subu $t4, $0, $t0
    or $t0, $t1, $0
    or $t1, $t4, $0
# load pi/2 and add it to the angle
    li $t4, 1073741824
    addu $t3, $t3, $t4

# the real and imaginary components are now both positive
# they are now have at least one leading 0
cordic_rectangular_to_polar_loop_init:
# shift the real and imaginary components so that the largest has its left most
# bit as a 1 and store the number of shifts
    or $t6, $t0, $t1
    clz $t6, $t6
    sllv $t0, $t0, $t6
# divide the real and imaginary components by 2 times the CORDIC gain
# this is the same as multiplying by a value less than or equal to sqrt(2)/4
# the actual value depends on the number of iterations.
# the magnetude can be as high as sqrt(2) times as much as the largest input
# so by dividing by 2, there will be an extra bit to hold any overflow
    li $t7, HALF_INVERSE_CORDIC_GAIN
    multu $t0, $t7
    sllv $t1, $t1, $t6                                      # multiply delay
    mfhi $t0
    multu $t1, $t7
# subtract one shift to account for the dividing by 2 (guaranteed non negative)
    addiu $t6, $t6, -1                                      # multiply delay
    mfhi $t1
# x and y should now be able to handle being multiplied by at most
# sqrt(2)*(CORDIC gain) then shifted right the correct ammount
# initialize the loop counter
    li $t4, 0
# load the address of the arctangent lookup table
    la $t2, arctan_lookup

# perform the CORDIC algorithm
cordic_rectangular_to_polar_loop:

# check wheather the imaginary component is positive or negative
    bltz $t1, cordic_rectangular_to_polar_imaginary_negative
# shift the real value over an ammount equal to the loop counter
    srlv $t7, $t0, $t4                                      # branch delay
# the imaginary component is greater than or equal to 0
# shift the imaginary value over an ammount equal to the loop counter
    srlv $t8, $t1, $t4
# add the shifted imaginary value to the real value
    addu $t0, $t0, $t8
# subtract the shifted real value from the imaginary value
    subu $t1, $t1, $t7
# load the arctan(2^-i) where i is the loop counter
    lw $t8, ($t2)
# point to the next arctangent value
    addiu $t2, $t2, 4                                       # load delay
# increment the loop counter
    addiu $t4, $t4, 1
# if the loop counter is less than the number of iterations, loop again
    slt $at, $t4, $t5
    bne $at, $0, cordic_rectangular_to_polar_loop
# add the arctan(2^-i) to the angle
    addu $t3, $t3, $t8                                      # branch delay
# if the loop counter is greater than or equal,
# shift the real component back to its original magnetude and go to the end
    b cordic_rectangular_to_polar_end
    srlv $t0, $t0, $t6                                      # branch delay

# if the imaginary component is negative
cordic_rectangular_to_polar_imaginary_negative:

# make the imaginary component positive
    subu $t8, $0, $t1
# shift the imaginary value over an ammount equal to the loop counter
    srlv $t8, $t8, $t4
# add the shifted imaginary value to the real value (essentally subtraction)
    addu $t0, $t0, $t8
# add the shifted real value to the imaginary value
    addu $t1, $t1, $t7
# load the arctan(2^-i) where i is the loop counter
    lw $t8, ($t2)
# point to the next arctangent value
    addiu $t2, $t2, 4                                       # load delay
# increment the loop counter
    addiu $t4, $t4, 1
# if the loop counter is less than the number of iterations, loop again
    slt $at, $t4, $t5
    bne $at, $0, cordic_rectangular_to_polar_loop
# subtract the arctan(2^-i) from the angle
    subu $t3, $t3, $t8                                      # branch delay
# shift the real component back to its original magnetude
    srlv $t0, $t0, $t6

# finish manipuulating the values and store them back into the fft array
cordic_rectangular_to_polar_end:

# shift the value back to it's original magnitude in the sample arrays
    srlv $t0, $t0, $s0
# store the magnitude and angle back into the fft array
    sw $t0, ($s3)
# if the loop counter doesn't equal zero, loop again
    bne $s1, $0, cordic_rectangular_to_polar_conversion_loop
    sw $t3, 4($s3)                                          # branch delay

# pop the s registers off the stack
    lw $s0, ($sp)
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
