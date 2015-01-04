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
# takes the array (N words long) pointed to by sample_array_pointer and returns
# an interleaved array (2N words long) containing the magntude and phase angle
# of each frequency. Each phase angle is a word (signed or unsigned) where 2^32
# is 2 pi radians
# Assumes the samples are unsigned.
# uses: $t0, $t1, $t2, $t3, $t4, $t5, $t6, $t7, $t8, $t9, $a0, $a1, $a2, $a3
#       ($s0, $s1, $s2, $s3, $s4, $s5, %s6, %s7 are used, but preserved)
# input: values in max_fft_shift, sample_array_pointer, and samples in the array
# output: fft_array will contain the magnetude and phase of each frequency
################################################################################
fft:
    addiu $sp, $sp, -32
    sw $s0, ($sp)
    sw $s1, 4($sp)
    sw $s2, 8($sp)
    sw $s3, 12($sp)
    sw $s4, 16($sp)
    sw $s5, 20($sp)
    sw $s6, 24($sp)
    sw $s7, 28($sp)
    la $s0, max_fft_shift
    lw $s0, ($s0)
    la $t1, sample_array_pointer_3    # (load delay)
    lw $t1, ($t1)
    la $s2, fft_array               # (load delay)
    li $t3, 4 * N
    li $t8, 4
    li $t7, 3 * N
fft_transfer_loop_0:
    addiu $t9, $t3, -4
    addu $t4, $t1, $t9
    lw $t6, -3*N($t4)
    xor $s1, $t3, $t9
    clz $s3, $s1
    addiu $s3, $s3, N_EXPONENT - 29
    sllv $s1, $s1, $s3
    xor $t8, $t8, $s1
    addu $t5, $s2, $t8
    sllv $t6, $t6, $s0
    sw $t6, ($t5)
    sw $0, 4($t5)
    bne $t7, $t9, fft_transfer_loop_0
    addiu $t3, $t3, -4              # (branch delay)
    la $t1, sample_array_pointer_2
    lw $t1, ($t1)
    li $t7, 2 * N
fft_transfer_loop_1:
    addiu $t9, $t3, -4
    addu $t4, $t1, $t9
    lw $t6, -2*N($t4)
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
    lw $t1, ($t1)
fft_transfer_loop_3:
    addiu $t9, $t3, -4
    addu $t4, $t1, $t9
    lw $t6, ($t4)
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
    addiu $t3, $t3, -4
    la $t1, cos_lookup
    li $t3, 2 * N
    li $t5, 8
    li $t6, N_EXPONENT - 1
    li $s6, 8 * N
fft_outer_loop:
    addu $t4, $t5, $0
    sll $t5, $t5, 1
    li $t8, 2 * N
    addiu $t7, $t4, -8
fft_middle_loop:
    subu $t8, $t8, $t3
    beqz $t8, fft_inner_loop_last
    addu $t9, $t7, $0   # (branch delay)
    addu $t2, $t1, $t8
    lw $t0, ($t2) # error here
    lw $s1, N($t2)
fft_inner_loop:
    addu $a0, $s2, $t9
    addu $a1, $a0, $t4
    lw $s4, ($a1)
    lw $s5, 4($a1)      # (load delay)
    mult $t0, $s4       # (load delay)
    lw $s3, 4($a0)      # (multiply delay)
    msub $s1, $s5       # (load delay)
    lw $t2, ($a0)       # (multiply delay)
    mfhi $a2            # (load delay)
    mflo $s7
    sll $a2, $a2, 1
    srl $s7, $s7, 30
    mult $s1, $s4
    addiu $s7, $s7, 1   # (multiply delay)
    madd $t0, $s5
    addu $a2, $a2, $s7  # (multiply delay)
    mfhi $a3
    mflo $s7
    srl $s7, $s7, 30
    addiu $s7, $s7, 1
    srl $s7, $s7, 1
    sll $a3, $a3, 1
    addu $a3, $a3, $s7
    subu $s7, $t2, $a2
    sw $s7, ($a1)
    subu $s7, $s3, $a3
	sw $s7, 4($a1)
	addu $s7, $t2, $a2
    sw $s7, ($a0)
    addu $s7, $s3, $a3
    sw $s7, 4($a0)
    blt $t9, $s6, fft_inner_loop
    addu $t9, $t9, $t5  # (branch delay)
    b fft_middle_loop
    addiu $t7, $t7, -8  # (branch delay)
fft_inner_loop_last:
    addu $a0, $s2, $t9
    addu $a1, $a0, $t4
    lw $s5, 4($a1)
    lw $s4, ($a1)       # (load delay)
    lw $t2, ($a0)       # (load delay)
    lw $s3, 4($a0)      # (load delay)
    subu $s7, $t2, $s4
    sw $s7, ($a1)
    subu $s7, $s3, $s5
    sw $s7, 4($a1)
    addu $s7, $t2, $s4
    sw $s7, ($a0)
    addu $s7, $s3, $s5
    sw $s7, 4($a0)
    blt $t9, $s6, fft_inner_loop_last
    addu $t9, $t9, $t5  # (branch delay)
    srl $t3, $t3, 1
    bne $0, $t6, fft_outer_loop
    addiu $t6, $t6, -1  # (branch delay)
    li $s1, 8 * (N - 1)
fft_cordic_rectangular_to_polar_conversion_loop:
    addu $s3, $s1, $s2
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
    srlv $t0, $t0, $s0
    sw $t0, ($s3)
    sw $t3, 4($s3)
    bne $0, $s1, fft_cordic_rectangular_to_polar_conversion_loop
    addiu $s1, $s1, -8
    lw $s0, ($sp)
    lw $s1, 4($sp)
    lw $s2, 8($sp)
    lw $s3, 12($sp)
    lw $s4, 16($sp)
    lw $s5, 20($sp)
    lw $s6, 24($sp)
    lw $s7, 28($sp)
    jr $ra
    addiu $sp, $sp, 32

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
    .word 2522, 2532, 2542, 2552, 2562, 2572, 2581, 2591, 2601, 2610, 2620, 2629
    .word 2639, 2648, 2657, 2666, 2675, 2684, 2693, 2702, 2710, 2719, 2727, 2735
    .word 2743, 2751, 2759, 2767, 2774, 2782, 2789, 2796, 2803, 2810, 2817, 2823
    .word 2830, 2836, 2842, 2848, 2853, 2859, 2864, 2869, 2874, 2879, 2884, 2888
    .word 2892, 2896, 2900, 2903, 2907, 2910, 2913, 2916, 2918, 2921, 2923, 2925
    .word 2926, 2928, 2929, 2930, 2931, 2932, 2932, 2932, 2932, 2932, 2931, 2930
    .word 2929, 2928, 2927, 2925, 2923, 2921, 2919, 2916, 2913, 2910, 2907, 2903
    .word 2899, 2895, 2891, 2887, 2882, 2877, 2872, 2867, 2861, 2855, 2849, 2843
    .word 2836, 2830, 2823, 2816, 2808, 2801, 2793, 2785, 2777, 2768, 2760, 2751
    .word 2742, 2733, 2723, 2714, 2704, 2694, 2684, 2673, 2663, 2652, 2641, 2630
    .word 2619, 2607, 2596, 2584, 2572, 2560, 2548, 2536, 2523, 2510, 2498, 2485
    .word 2472, 2458, 2445, 2432, 2418, 2404, 2391, 2377, 2363, 2349, 2334, 2320
    .word 2306, 2291, 2277, 2262, 2248, 2233, 2218, 2203, 2188, 2173, 2158, 2143
    .word 2128, 2113, 2097, 2082, 2067, 2052, 2036, 2021, 2006, 1990, 1975, 1960
    .word 1944, 1929, 1914, 1898, 1883, 1868, 1853, 1838, 1822, 1807, 1792, 1777
    .word 1762, 1748, 1733, 1718, 1703, 1689, 1674, 1660, 1645, 1631, 1617, 1603
    .word 1589, 1575, 1561, 1548, 1534, 1521, 1507, 1495, 1482, 1469, 1456, 1443
    .word 1431, 1418, 1406, 1394, 1382, 1370, 1358, 1347, 1336, 1324, 1313, 1302
    .word 1292, 1281, 1271, 1260, 1250, 1240, 1231, 1221, 1212, 1203, 1194, 1185
    .word 1176, 1168, 1160, 1151, 1144, 1136, 1128, 1121, 1114, 1107, 1100, 1094
    .word 1087, 1081, 1075, 1069, 1064, 1059, 1053, 1048, 1044, 1039, 1035, 1030
    .word 1026, 1022, 1019, 1015, 1012, 1009, 1006, 1003, 1001, 999, 996, 994
    .word 993, 991, 989, 988, 987, 986, 985, 985, 984, 984, 984, 984, 984, 985
    .word 985, 986, 987, 988, 989, 990, 991, 993, 995, 996, 998, 1000, 1002
    .word 1005, 1007, 1010, 1012, 1015, 1018, 1021, 1024, 1027, 1030, 1033, 1037
    .word 1040, 1044, 1047, 1051, 1054, 1058, 1062, 1066, 1070, 1074, 1078, 1082
    .word 1086, 1090, 1094, 1099, 1103, 1107, 1111, 1116, 1120, 1124, 1128, 1133
    .word 1137, 1141, 1146, 1150, 1154, 1158, 1162, 1166, 1170, 1175, 1179, 1182
    .word 1186, 1190, 1194, 1198, 1201, 1205, 1209, 1212, 1215, 1219, 1222, 1225
    .word 1228, 1231, 1234, 1237, 1239, 1242, 1244, 1247, 1249, 1251, 1253, 1255
    .word 1257, 1258, 1260, 1261, 1262, 1264, 1265, 1265, 1266, 1267, 1267, 1267
    .word 1268, 1268, 1267, 1267, 1267, 1266, 1265, 1264, 1263, 1262, 1260, 1259
    .word 1257, 1255, 1253, 1251, 1249, 1246, 1243, 1240, 1237, 1234, 1231, 1227
    .word 1223, 1219, 1215, 1211, 1207, 1202, 1197, 1193, 1187, 1182, 1177, 1171
    .word 1166, 1160, 1154, 1147, 1141, 1135, 1128, 1121, 1114, 1107, 1100, 1092
    .word 1085, 1077, 1069, 1061, 1053, 1045, 1036, 1028, 1019, 1010, 1001, 992
    .word 983, 974, 964, 955, 945, 935, 926, 916, 906, 895, 885, 875, 864, 854
    .word 843, 833, 822, 811, 800, 789, 778, 767, 756, 745, 734, 723, 711, 700
    .word 689, 677, 666, 654, 643, 632, 620, 609, 597, 586, 574, 563, 551, 540
    .word 529, 517, 506, 495, 483, 472, 461, 450, 439, 428, 417, 406, 395, 384
    .word 374, 363, 353, 342, 332, 322, 312, 302, 292, 282, 272, 263, 253, 244
    .word 235, 226, 217, 208, 199, 191, 182, 174, 166, 158, 150, 143, 135, 128
    .word 121, 114, 107, 101, 95, 88, 82, 77, 71, 66, 61, 56, 51, 46, 42, 38, 34
    .word 30, 26, 23, 20, 17, 14, 12, 10, 8, 6, 4, 3, 2, 1, 1, 0, 0, 0, 0, 1, 2
    .word 3, 4, 5, 7, 9, 11, 14, 16, 19, 22, 26, 29, 33, 37, 41, 46, 50, 55, 61
    .word 66, 72, 77, 84, 90, 96, 103, 110, 117, 124, 132, 140, 148, 156, 164
    .word 173, 182, 191, 200, 209, 219, 228, 238, 248, 259, 269, 280, 290, 301
    .word 312, 324, 335, 347, 358, 370, 382, 394, 407, 419, 431, 444, 457, 470
    .word 483, 496, 509, 522, 536, 549, 563, 576, 590, 604, 618, 632, 646, 660
    .word 674, 689, 703, 717, 732, 746, 760, 775, 789, 804, 819, 833, 848, 862
    .word 877, 891, 906, 921, 935, 950, 964, 979, 993, 1008, 1022, 1036, 1051
    .word 1065, 1079, 1093, 1107, 1121, 1135, 1149, 1163, 1177, 1191, 1204, 1218
    .word 1231, 1244, 1258, 1271, 1284, 1297, 1309, 1322, 1335, 1347, 1359, 1372
    .word 1384, 1396, 1407, 1419, 1431, 1442, 1453, 1464, 1475, 1486, 1497, 1506
    .word 1516, 1527, 1537, 1546, 1556, 1566, 1575, 1584, 1593, 1602, 1611, 1619
    .word 1627, 1635, 1643, 1651, 1659, 1666, 1673, 1680, 1687, 1694, 1700, 1707
    .word 1713, 1719, 1724, 1730, 1735, 1740, 1745, 1750, 1755, 1759, 1764, 1768
    .word 1771, 1775, 1779, 1782, 1785, 1788, 1791, 1794, 1796, 1798, 1800, 1802
    .word 1804, 1806, 1807, 1808, 1809, 1810, 1811, 1811, 1812, 1812, 1812, 1812
    .word 1812, 1812, 1811, 1811, 1810, 1809, 1808, 1807, 1805, 1804, 1802, 1801
    .word 1799, 1797, 1795, 1793, 1791, 1788, 1786, 1783, 1781, 1778, 1775, 1772
    .word 1769, 1766, 1763, 1760, 1757, 1753, 1750, 1746, 1743, 1739, 1736, 1732
    .word 1728, 1725, 1721, 1717, 1713, 1709, 1706, 1702, 1698, 1694, 1690, 1686
    .word 1682, 1678, 1674, 1671, 1667, 1663, 1659, 1655, 1652, 1648, 1644, 1641
    .word 1637, 1634, 1630, 1627, 1623, 1620, 1617, 1614, 1611, 1608, 1605, 1602
    .word 1599, 1596, 1594, 1591, 1589, 1587, 1584, 1582, 1580, 1579, 1577, 1575
    .word 1574, 1572, 1571, 1570, 1569, 1568, 1568, 1567, 1566, 1566, 1566, 1566
    .word 1566, 1566, 1567, 1567, 1568, 1569, 1570, 1571, 1573, 1574, 1576, 1578
    .word 1580, 1582, 1585, 1587, 1590, 1593, 1596, 1599, 1602, 1606, 1610, 1613
    .word 1618, 1622, 1626, 1631, 1636, 1641, 1646, 1651, 1656, 1662, 1668, 1674
    .word 1680, 1686, 1693, 1699, 1706, 1713, 1720, 1728, 1735, 1743, 1751, 1759
    .word 1767, 1775, 1783, 1792, 1801, 1809, 1818, 1828, 1837, 1846, 1856, 1866
    .word 1875, 1885, 1895, 1906, 1916, 1926, 1937, 1948, 1958, 1969, 1980, 1991
    .word 2003, 2014, 2025, 2037, 2048, 2060, 2072, 2084, 2096, 2108, 2120, 2132
    .word 2144, 2156, 2168, 2181, 2193, 2205, 2218, 2230, 2243, 2255, 2268, 2281
    .word 2293, 2306, 2318, 2331, 2344, 2356, 2369, 2381, 2394, 2407, 2419, 2432
    .word 2444, 2456, 2469, 2481, 2494, 2506, 2518, 2530, 2542, 2554, 2566, 2578
    .word 2590, 2602, 2613, 2625, 2636, 2647, 2659, 2670, 2681, 2692, 2703, 2713
    .word 2724, 2734, 2744, 2755, 2765, 2775, 2784, 2794, 2803, 2813, 2822, 2831
    .word 2839, 2848, 2857, 2865, 2873, 2881, 2889, 2896, 2904, 2911, 2918, 2925
    .word 2931, 2938, 2944, 2950, 2956, 2961, 2967, 2972, 2977, 2982, 2986, 2991
    .word 2995, 2999, 3002, 3006
max_fft_shift:
    .word 9
