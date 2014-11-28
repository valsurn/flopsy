################################################################################
################################################################################
################################### Flopsy #####################################
################################################################################
################################################################################
#
# A program for playing music using floppy drives or other devices.
#
################################################################################
################################### Licenses ###################################
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
############################## Additional Notices ##############################
#
# For the sin, cos, and arctan algorithm and constants from fdlibm in main.s
#
# ====================================================
# Copyright (C) 1993 by Sun Microsystems, Inc. All rights reserved.
#
# Developed at SunSoft, a Sun Microsystems, Inc. business.
# Permission to use, copy, modify, and distribute this
# software is freely granted, provided that this notice
# is preserved.
# ====================================================
#
#
################################################################################
#################################### Notes #####################################
################################################################################
#
# This code was written for the PIC32MX340F512H.
# If using anything other than the PIC32MX340F512H may require modification.
# for simplicity only move $sp in multiples of 8 since doubles are on the stack
# cos_lookup overlaps sin_lookup, so make sure they are contiguous
# make sure that any data that depends on a starting value is not altered
#
################################################################################
################################## Constants ###################################
################################################################################
#
########################## These should be changeable ##########################
#
# Number of samples per FFT. Assumed to be a power of 2 greater than or equal to
# 8 (pick the highest value that won't lag)
    .equ N, 128
#
# Number of iterations for the CORDIC algorithm for determining magnitude and
# phase displacement (the higher the number, the better the accuracy)
# Assumed to be less than 32 (and greater than 0)
    .equ CORDIC_ITERATIONS, 15
#
######## These should not be changed unless you know what you're doing #########
#
# Constants for determining space requirements
    .equ N_OVER_2, N / 2
    .equ N_OVER_4, N / 4
    .equ N_OVER_8, N / 8
    .equ THREE_N_OVER_4, N_OVER_2 + N_OVER_4
    .equ THREE_N_OVER_8, N_OVER_4 + N_OVER_8
    .equ FIVE_N_OVER_8, N_OVER_4 + THREE_N_OVER_8
    .equ TWO_N, N * 2
    .equ FOUR_N, TWO_N * 2
    .equ EIGHT_N, FOUR_N * 2
    .equ COS_SPACE, TWO_N # N/4 doubles (actually N/2 but it overlaps with sin)
    .equ SIN_SPACE, FOUR_N # N/2 doubles
    .equ ARCTAN_SPACE, CORDIC_ITERATIONS * 8 # a double for each iteration
    .equ FFT_SPACE, EIGHT_N
#
# for indexing the array of constants needed in calculating sin, cos, and arctan
    .equ S0, 0
    .equ S1, 8
    .equ S2, 16
    .equ S3, 24
    .equ S4, 32
    .equ S5, 40
    .equ S6, 48
    .equ C0, 0
    .equ C1, 8
    .equ C2, 16
    .equ C3, 24
    .equ C4, 32
    .equ C5, 40
    .equ C6, 48
    .equ C7, 56
    .equ AT0, 0
    .equ AT1, 8
    .equ AT2, 16
    .equ AT3, 24
    .equ AT4, 32
    .equ AT5, 40
    .equ AT6, 48
    .equ AT7, 56
    .equ AT8, 64
    .equ AT9, 72
    .equ AT10, 80
    .equ ATAN_HALF_HIGH, 0
    .equ ATAN_HALF_LOW, 8
    .equ ATAN_ONE_HIGH, 16
    .equ ATAN_ONE_LOW, 24
    .equ ATAN_ONE_AND_HALF_HIGH, 32
    .equ ATAN_ONE_AND_HALF_LOW, 40
    .equ ATAN_INFINITY_HIGH, 48
    .equ ATAN_INFINITY_LOW, 56
    .equ NEGATIVE_ONE, 64
    .equ ONE, 72
    .equ ONE_AND_HALF, 80
    .equ TWO, 88
    .equ ZERO, 96
#
################################################################################
############################## Program #########################################
################################################################################

    .text
    .globl main
    .set noreorder
    .ent main
main:
# make sure the stack is double aligned by $sp -= $sp % 8
    li $t0, 8
    divu $sp, $t0
    la $t1, stack_offset
    mfhi $t0
    mflo $0
    subu $sp, $sp, $t0
    sb $t0, ($t1)

# generate -2 * PI / N for the generate_trig_lookup routine
# (MPASM doesn't like floating point calculations at assembly time)
    la $t4, lookup_table_constants
    ld $t0, 24($t4)
    sd $t0, -8($sp)
    jal arctan
    addiu $sp, $sp, -8
    ldc1 $f0, ($sp)
# $f0 = arctan(1) = pi/4
    li $t0, N_OVER_8
    mtc1 $t0, $f2
    cvt.d.w $f2, $f2
    neg.d $f2, $f2
    div.d $f0, $f0, $f2
# $f0 = arctan(1)/(-N/8) = -2 * pi / N
    sdc1 $f0, ($t4)
    addiu $sp, $sp, 8

# generate the trig look up table
    jal generate_trig_lookup
    nop

# mark both sample arrays as empty and start with sample_array_0
    li $t0, 0
    la $t1, sample_array_0_index
    sw $t0, ($t1)
    la $t1, sample_array_1_index
    sw $t0, ($t1)
    la $t0, sample_array_0
    la $t1, sample_array_pointer
    sw $t0, ($t1)

# test code (will eventually be deleted)
exit:
    la $t0, cos_lookup
    la $t1, lookup_table_constants
    la $a0, newline
print_loop:
    ble $t1, $t0, ender
    ldc1 $f12, ($t0)
    li $v0, 3
    syscall
    li $v0, 4
    syscall
    b print_loop
    addiu $t0, $t0, 8
ender:
    li $t0, 1
    mtc1 $t0, $f0
    cvt.d.w $f0, $f0
    sdc1 $f0, ($sp)
    li $t0, 1
    mtc1 $t0, $f0
    cvt.d.w $f0, $f0
    sdc1 $f0, 8($sp)
    jal cordic_rectangular_to_polar
    nop
    ldc1 $f12, ($sp)
    li $v0, 3
    syscall
    li $v0, 4
    syscall
    ldc1 $f12, 8($sp)
    li $v0, 3
    syscall
    li $v0, 4
    syscall

# restore the stack to its previous position
    la $t1, stack_offset
    lb $t0, ($t1)
    addu $sp, $sp, $t0
    li $v0, 10
    syscall
    .end main

################################################################################
# Uses $t0, $t1, $f0, $f1, $f2, $f3, $f4, $f5, $f6, $f7
# input: a double, x, on the stack
# output: sin(x) on the stack
# only valid for -pi/4 to pi/4
################################################################################
sin:
# load x from the stack
    ldc1 $f0, ($sp)        # $f0 = x
    mul.d $f2, $f0, $f0    # $f2 = x^2
# since only nice values will be put into the function,
# start calculating the Chebyshev polynomial
    la $t0, sin_co
    ldc1 $f4, S6($t0)
    mul.d $f6, $f2, $f4
    ldc1 $f4, S5($t0)
    add.d $f6, $f6, $f4
    mul.d $f6, $f6, $f2
    ldc1 $f4, S4($t0)
    add.d $f6, $f6, $f4
    mul.d $f6, $f6, $f2
    ldc1 $f4, S3($t0)
    add.d $f6, $f6, $f4
    mul.d $f6, $f6, $f2
    ldc1 $f4, S2($t0)
    add.d $f6, $f6, $f4
    mul.d $f6, $f6, $f2
    ldc1 $f4, S1($t0)
    add.d $f6, $f6, $f4
    mul.d $f6, $f6, $f2
    ldc1 $f4, S0($t0)
    add.d $f6, $f6, $f4
    mul.d $f6, $f6, $f0
# put the result back on the stack (overwriting x)
# $f6=x^2*(S0+x^2*(S1+x^2*(S2+x^2*(S3+x^2*(S4+x^2*(S5+x^2*S6))))))
    sdc1 $f6, ($sp)
    jr $ra
    nop

################################################################################
# Uses $t0, $t1, $f0, $f1, $f2, $f3, $f4, $f5
# input: a double, x, on the stack
# output: cos(x) on the stack
# only valid for -pi/4 to pi/4
################################################################################
cos:
# load x from the stack
    ldc1 $f0, ($sp)        #$f0 = x
    mul.d $f0, $f0, $f0    #$f0 = x^2
# since only nice values will be put into the function,
# start calculating the Chebyshev polynomial
    la $t0, cos_co
    ldc1 $f2, C7($t0)
    mul.d $f4, $f0, $f2
    ldc1 $f2, C6($t0)
    add.d $f4, $f4, $f2
    mul.d $f4, $f4, $f0
    ldc1 $f2, C5($t0)
    add.d $f4, $f4, $f2
    mul.d $f4, $f4, $f0
    ldc1 $f2, C4($t0)
    add.d $f4, $f4, $f2
    mul.d $f4, $f4, $f0
    ldc1 $f2, C3($t0)
    add.d $f4, $f4, $f2
    mul.d $f4, $f4, $f0
    ldc1 $f2, C2($t0)
    add.d $f4, $f4, $f2
    mul.d $f4, $f4, $f0
    ldc1 $f2, C1($t0)
    add.d $f4, $f4, $f2
    mul.d $f4, $f4, $f0
    ldc1 $f2, C0($t0)
    add.d $f4, $f4, $f2
# put the result back on the stack (overwriting x)
# $f4=C0+x^2*(C1+x^2*(C2+x^2*(C3+ x^2*(C4+x^2*(C5+x^2*(C6+x^2*C7))))))
    sdc1 $f4, ($sp)
    jr $ra
    nop

################################################################################
# Uses $t0, $t1, $t2, $t3, $f0, $f1, $f2, $f3, $f4, $f5, $f6, $f7, $f8, $f9,
# $f10, $f11, $f12, $f13, $f14, $f15
# input: a double, x, on the stack
# output: arctan(x) on the stack
# assumes the input will be a nice number
################################################################################
arctan:
# argument reduction
    lw $t0, 4($sp)
    li $t1, 0x7FFFFFFF
    slt $t2, $t0, $0    # $t2 = 1 if x is negative
    and $t0, $t0, $t1
    sw $t0, 4($sp)
    sll $t0, $t0, 1
    lui $t1, 0x7FB8
    ldc1 $f0, ($sp)     # $f0 = |x|
    la $t3, atan_const
    sltu $t1, $t0, $t1
    bnez $t1, arctan_0
    nop
    lui $t1, 0x7FCC
    sltu $t1, $t0, $t1
    bnez $t1, arctan_1
    lui $t1, 0x7FE6
    sltu $t1, $t0, $t1
    bnez $t1, arctan_2
    lui $t1, 0x8007
    sltu $t1, $t0, $t1
    bnez $t1, arctan_3
    lui $t1, 0x8820
    sltu $t1, $t0, $t1
    bnez $t1, arctan_4
    nop
# before entering arctan_poly, $f0 = argument reduced |x|,
# $f2 = high arctan constant, and $f4 = low arctan constant
# argument reduction uses the following properties to reduce the argument:
# arctan(|x|)=arctan(a)+arctan((|x|-a)/(1+a*|x|)) for a >= 0
arctan_5:           # if |x| >= 2^66, approximate with pi/4
    ldc1 $f0, ZERO($t3)
    ldc1 $f2, ATAN_INFINITY_HIGH($t3)
    b arctan_poly
    ldc1 $f4, ATAN_INFINITY_LOW($t3)
arctan_4:           # if 39/16 <= |x| < 2^66, lim a->?
    ldc1 $f2, NEGATIVE_ONE($t3)
    div.d $f0, $f2, $f0
    ldc1 $f2, ATAN_INFINITY_HIGH($t3)
    b arctan_poly
    ldc1 $f4, ATAN_INFINITY_LOW($t3)
arctan_3:           # if 19/16 <= |x| < 39/16, a=1.5
    ldc1 $f2, ONE_AND_HALF($t3)
    sub.d $f4, $f0, $f2
    mul.d $f0, $f0, $f2
    ldc1 $f2, ONE($t3)
    add.d $f0, $f2, $f0
    div.d $f0, $f4, $f0
    ldc1 $f2, ATAN_ONE_AND_HALF_HIGH($t3)
    b arctan_poly
    ldc1 $f4, ATAN_ONE_AND_HALF_LOW($t3)
arctan_2:           # if 11/16 <= |x| < 19/16, a=1
    ldc1 $f2, ONE($t3)
    add.d $f4, $f0, $f2
    sub.d $f0, $f0, $f2
    div.d $f0, $f0, $f4
    ldc1 $f2, ATAN_ONE_HIGH($t3)
    b arctan_poly
    ldc1 $f4, ATAN_ONE_LOW($t3)
arctan_1:           # if 7/16 <= |x| < 11/16, a=0.5
    ldc1 $f2, TWO($t3)
    add.d $f4, $f0, $f2
    mul.d $f0, $f0, $f2
    ldc1 $f2, ONE($t3)
    sub.d $f0, $f0, $f2
    div.d $f0, $f0, $f4
    ldc1 $f2, ATAN_HALF_HIGH($t3)
    b arctan_poly
    ldc1 $f4, ATAN_HALF_LOW($t3)
arctan_0:           # if 0 <= |x| < 7/16, no argument reduction nessisary (a=0)
    ldc1 $f2, ZERO($t3)
    ldc1 $f4, ZERO($t3)
arctan_poly:
# if t=(|x|-a)/(1+a*|x|)
    mul.d $f6, $f0, $f0 # $f6 = t^2
    mul.d $f8, $f6, $f6 # $f8 = t^4
    la $t3, atan_co
    ldc1 $f10, AT10($t3)
    mul.d $f12, $f8, $f10
    ldc1 $f10, AT8($t3)
    add.d $f12, $f12, $f10
    mul.d $f12, $f12, $f8
    ldc1 $f10, AT6($t3)
    add.d $f12, $f12, $f10
    mul.d $f12, $f12, $f8
    ldc1 $f10, AT4($t3)
    add.d $f12, $f12, $f10
    mul.d $f12, $f12, $f8
    ldc1 $f10, AT2($t3)
    add.d $f12, $f12, $f10
    mul.d $f12, $f12, $f8
    ldc1 $f10, AT0($t3)
    add.d $f12, $f12, $f10
    mul.d $f12, $f12, $f6
    ldc1 $f10, AT9($t3)
    mul.d $f14, $f8, $f10
    ldc1 $f10, AT7($t3)
    add.d $f14, $f14, $f10
    mul.d $f14, $f14, $f8
    ldc1 $f10, AT5($t3)
    add.d $f14, $f14, $f10
    mul.d $f14, $f14, $f8
    ldc1 $f10, AT3($t3)
    add.d $f14, $f14, $f10
    mul.d $f14, $f14, $f8
    ldc1 $f10, AT1($t3)
    add.d $f14, $f14, $f10
    mul.d $f14, $f14, $f8
    add.d $f6, $f12, $f14
    mul.d $f6, $f6, $f0
    sub.d $f6, $f6, $f4
    sub.d $f6, $f6, $f0
    sub.d $f6, $f2, $f6
# $f6=arctan(a)+t*(1-(t^2*(AT0+t^4*(AT2+t^4*(AT4+t^4*(AT6+t^4*(AT8+t^4*AT10)))))
# +t^4*(aT[1]+t^4*(aT[3]+t^4*(aT[5]+t^4*(aT[7]+t^4*aT[9]))))))
arctan_return:      # if x < 0, arctan(x) = -arctan(|x|)
    beqz $t2, arctan_positive
    nop
    neg.d $f6, $f6
arctan_positive:
    sdc1 $f6, ($sp)
    jr $ra
    nop

################################################################################
# Uses $t0, $t1, $t2, $t3, $t4, $t5, $t6, $f0, $f1, $f2, $f3, $f4, $f5,
# $f6, $f7, $f8, $f9, $f10, $f11, $f12, $f13, $f14, $f15, $f16, $f17,
# $f18, $f19, $f20, $f21, $f22, $f23
# output: the trigonometric lookup tables will be populated along with the
# CORDIC gain
################################################################################
generate_trig_lookup:
    addiu $sp, $sp, -16
    sw $ra, 12($sp)
    la $t6, lookup_table_constants
    ldc1 $f16, ($t6)        # $f16 = -2 pi / N
    ldc1 $f18, 8($t6)       # $f16 = 0
    la $t4, cos_lookup
    addiu $t5, $t4, N
sin_cos_loop_1:             # store cos(x) from 0 to -pi/4
    ble $t5, $t4, sin_cos_loop_2_init
    nop
    sdc1 $f18, ($sp)
    jal cos
    add.d $f18, $f18, $f16
    ldc1 $f0, ($sp)
    sdc1 $f0, ($t4)
    b sin_cos_loop_1
    addiu $t4, $t4, 8
sin_cos_loop_2_init:
    neg.d $f18, $f18
    addiu $t5, $t5, TWO_N
sin_cos_loop_2:             # store sin(x) from pi/4 to -pi/4
    ble $t5, $t4, sin_cos_loop_3_init
    nop
    sdc1 $f18, ($sp)
    jal sin
    add.d $f18, $f18, $f16
    ldc1 $f0, ($sp)
    sdc1 $f0, ($t4)
    b sin_cos_loop_2
    addiu $t4, $t4, 8
sin_cos_loop_3_init:
    addiu $t5, $t5, TWO_N
sin_cos_loop_3:             # store -cos(x) from -pi/4 to pi/4
    ble $t5, $t4, sin_cos_loop_4_init
    nop
    sdc1 $f18, ($sp)
    jal cos
    sub.d $f18, $f18, $f16
    ldc1 $f0, ($sp)
    neg.d $f0, $f0
    sdc1 $f0, ($t4)
    b sin_cos_loop_3
    addiu $t4, $t4, 8
sin_cos_loop_4_init:
    neg.d $f18, $f18
    addiu $t5, $t5, N
sin_cos_loop_4:             # store sin(x) from -pi/4 to 0
    ble $t5, $t4, arctan_loop_init
    nop
    sdc1 $f18, ($sp)
    jal sin
    sub.d $f18, $f18, $f16
    ldc1 $f0, ($sp)
    sdc1 $f0, ($t4)
    b sin_cos_loop_4
    addiu $t4, $t4, 8
arctan_loop_init:
    ldc1 $f16, 16($t6)
    ldc1 $f18, 24($t6)
    ldc1 $f20, 24($t6)
    la $t4, cordic_gain
    la $t5, arctan_lookup
arctan_loop:            # store arctan(2^-i) and calculate product(cos(2^-i))
    ble $t4, $t5, trig_lookup_end
    nop
    sdc1 $f18, ($sp)
    jal arctan
    nop
    ldc1 $f22, ($sp)
    jal cos
    mul.d $f18, $f18, $f16
    ldc1 $f0, ($sp)
    mul.d $f20, $f20, $f0
    sdc1 $f22, ($t5)
    b arctan_loop
    addiu $t5, $t5, 8
trig_lookup_end:
    sdc1 $f20, ($t4)
    lw $ra, 12($sp)
    addiu $sp, $sp, 16
    jr $ra
    nop

################################################################################
# Uses $t0, $t1, $t2, $t3, $f0, $f1, $f2, $f3, $f4, $f5, $f6, $f7, $f8, $f9,
# $f10, $f11
# input: two doubles on the stack, x at $sp and y at $sp+8
# output: two doubles on the stack, r at $sp and theta at $sp+8
# Increasing CORDIC_ITERATIONS increases the accuracy of this routine
################################################################################
cordic_rectangular_to_polar:
    ldc1 $f0, ($sp)             # $f0=x
    ldc1 $f2, 8($sp)            # $f2=y
    la $t0, arctan_lookup - 8
    la $t1, pi_constant
    ldc1 $f4, ($t0)             # $f4=angle=0
    ldc1 $f6, ($t0)
    c.lt.d $f2, $f6             # if y<0, x'=-x and y'=-y and angle=pi
    bc1f cordic_check_x
    nop
    neg.d $f0, $f0
    neg.d $f2, $f2
    ldc1 $f4, ($t1)
cordic_check_x:                 # if x<0, x'=y and y'=-x and angle+=pi/2
    c.lt.d $f0, $f6
    bc1f cordic_argument_reduced
    nop
    mov.d $f8, $f2
    neg.d $f2, $f0
    mov.d $f0, $f8
    ldc1 $f8, 8($t1)
    add.d $f4, $f4, $f8
cordic_argument_reduced:
    li $t1, 0
    li $t2, CORDIC_ITERATIONS
    li $t3, 1
cordic_loop:
    bge $t1, $t2, cordic_end
    c.le.d $f6, $f2
    bc1f cordic_loop_negative_y
# if y>=0, x'=x+y/(1<<i), y'=y-x/(1<<i), angle+=arctan(1/(1<<i))
    addiu $t0, $t0, 8
    mtc1 $t3, $f8
    cvt.d.w $f8, $f8
    div.d $f10, $f2, $f8
    add.d $f10, $f10, $f0
    div.d $f0, $f0, $f8
    sub.d $f2, $f2, $f0
    mov.d $f0, $f10
    ldc1 $f10, ($t0)
    add.d $f4, $f4, $f10
    sll $t3, $t3, 1
    b cordic_loop
    addiu $t1, $t1, 1
cordic_loop_negative_y:
# if y<0, x'=x-y/(1<<i), y'=y+x/(1<<i), angle-=arctan(1/(1<<i))
    mtc1 $t3, $f8
    cvt.d.w $f8, $f8
    div.d $f10, $f0, $f8
    add.d $f10, $f10, $f2
    div.d $f2, $f2, $f8
    sub.d $f0, $f0, $f2
    mov.d $f2, $f10
    ldc1 $f10, ($t0)
    sub.d $f4, $f4, $f10
    sll $t3, $t3, 1
    b cordic_loop
    addiu $t1, $t1, 1
cordic_end:
    la $t0, cordic_gain
    ldc1 $f2, ($t0)
    mul.d $f0, $f0, $f2     # y?0, x?gain*r
    sdc1 $f0, ($sp)
    sdc1 $f4, 8($sp)
    jr $ra
    nop

################################################################################
#################################### Data ######################################
################################################################################
    .data
newline:                .asciiz "\n" # used in the test code, will be deleted

stack_offset:           .byte 0
                        .align 2
sample_array_0_index:   .word 0
sample_array_1_index:   .word 0
sample_array_pointer:   .word 0
                        .align 3
sin_co:                 .word 0x00000000, 0x3FF00000, 0x55555549, 0xBFC55555
                        .word 0x1110F8A6, 0x3F811111, 0x19C161D5, 0xBF2A01A0
                        .word 0x57B1FE7D, 0x3EC71DE3, 0x8A2B9CEB, 0xBE5AE5E6
                        .word 0x5ACFD57C, 0x3DE5D93A
cos_co:                 .word 0x00000000, 0x3FF00000, 0x00000000, 0xBFE00000
                        .word 0x5555554C, 0x3FA55555, 0x16C15177, 0xBF56C16C
                        .word 0x19CB1590, 0x3EFA01A0, 0x809C52AD, 0xBE927E4F
                        .word 0xBDB4B1C4, 0x3E21EE9E, 0xBE8838D4, 0xBDA8FAE9
atan_co:                .word 0x5555550D, 0x3FD55555, 0x9998EBC4, 0xBFC99999
                        .word 0x920083FF, 0x3FC24924, 0xFE231671, 0xBFBC71C6
                        .word 0xC54C206E, 0x3FB745CD, 0xAF749A6D, 0xBFB3B0F2
                        .word 0xA0D03D51, 0x3FB10D66, 0x52DEFD9A, 0xBFADDE2D
                        .word 0x24760DEB, 0x3FA97B4B, 0x2C6A6C2F, 0xBFA2B444
                        .word 0xE322DA11, 0x3F90AD3A
atan_const:             .word 0x0561BB4F, 0x3FDDAC67, 0x222F65E2, 0x3C7A2B7F
                        .word 0x54442D18, 0x3FE921FB, 0x33145C07, 0x3C81A626
                        .word 0xD281F69B, 0x3FEF730B, 0x7AF0CBBD, 0x3C700788
                        .word 0x54442D18, 0x3FF921FB, 0x33145C07, 0x3C91A626
                        .word 0x00000000, 0xBFF00000, 0x00000000, 0x3FF00000
                        .word 0x00000000, 0x3FF80000, 0x00000000, 0x40000000
                        .word 0x00000000, 0x00000000
cos_lookup:             .space COS_SPACE
sin_lookup:             .space SIN_SPACE
                        .double 0
arctan_lookup:          .space ARCTAN_SPACE
cordic_gain:            .space 8
lookup_table_constants: .double 0, 0, 0.5, 1
pi_constant:            .double 3.141592653589793238462643383279502884
                        .double 1.570796326794896619231321691639751442
sample_array_0:         .space FFT_SPACE
sample_array_1:         .space FFT_SPACE
fft_array:              .space FFT_SPACE
