/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * License); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * AS IS BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

/*
 * Copyright (c) 2018, Open AI Lab
 * Author: chunyinglv@openailab.com
 */

// register definition
// x0        bias start address
// x1        input start address
// x2        kernel start address
// x3        output start address
// x4        in_hw
// x5        c_in
//           activation

// r0 = cIn/4   loop4_idx
//


// v0 input[j][0,1,2,3]
// v1 input[j+1][0,1,2,3]
// v2 input[j+2][0,1,2,3]
// v3 input[j+3][0,1,2,3]

// v4 ker[i][0,1,2,3]    
// v5 ker[i+1][0,1,2,3]
// v6 ker[i+2][0,1,2,3]
// v7 ker[i+3][0,1,2,3]

// q8  output[i][0,1,2,3]
// q9  output[i+1][0,1,2,3]
// q10 output[i+2][0,1,2,3]
// q11 output[i+3][0,1,2,3]

	.section .text,"ax"
	.align 5

	.type direct_k1s1p0_4x4_a17 STT_FUNC
	.global direct_k1s1p0_4x4_a17
	.hidden direct_k1s1p0_4x4_a17

direct_k1s1p0_4x4_a17:
    pld		[r1,#0x80]
    // context save & load parameter
	push		{r4 - r8, lr}               // [6 num]
	vpush		{d8 - d15}                  //  [8dx2=16 num]
	ldr		r4,[sp, #0x58]	// r4 = in_hw    [88=22num*4]
    ldr		r5,[sp, #0x5c]	// r5 = c_in     [92 = 88+4]

	teq	r0, #0x0
    beq none_biases
        vld4.32		{d16[], d18[], d20[], d22[]}, [r0]!
        vmov		d17,  d16
        vmov		d19, d18
        vmov		d21, d20
        vmov		d23, d22

	    b convolution_start

none_biases:
	vmov.i64	q8,  #0x0
	vmov.i64	q9,  #0x0
	vmov.i64	q10, #0x0
	vmov.i64	q11, #0x0


convolution_start:
    lsl r4,r4, #0x2
    cmp r5,#0x4                          // if c_in <4, go to loop4_end
    blt loop4_end
   
    lsr	r0, r5, #0x2                          // X0 = c_in / 4
    add r6, r1, r4
    add r7, r6, r4
    add r8, r7, r4
loop4:                                                                              
    vldr		d8,  [r2]
    vldm	    r1, {d0-d1}
    subs        r0, r0, #0x1  
    vmla.f32    q8, q0, d8[0]	
    vldr		d9,  [r2,#0x8]
    vmla.f32    q9, q0, d8[1]
    vldm	    r6,{d2-d3}
    vmla.f32    q10, q0, d9[0]	
    vldr		d10,  [r2,#0x10]  
    vmla.f32    q11, q0, d9[1]	
    vldr		d11,  [r2,#0x18]
    vmla.f32    q8,  q1, d10[0]	
    vldm	    r7,{d4-d5}
    vmla.f32    q9,  q1, d10[1]	
    vmla.f32    q10, q1, d11[0]	
    vldr		d12,  [r2,#0x20]
    vmla.f32    q11, q1, d11[1]	
    vldr		d13,  [r2,#0x28]
    vmla.f32    q8,  q2, d12[0]	
    vldm	    r8,{d6-d7}
    vmla.f32    q9,  q2, d12[1]	
    vmla.f32    q10, q2, d13[0]	
    vldr		d14,  [r2,#0x30]
    vmla.f32    q11, q2, d13[1]	
    vldr		d15,  [r2,#0x38]
        
    add  r1,r1,r4, LSL #0x2
    pld		[r1, #0x20]
    vmla.f32    q8,  q3, d14[0]
    pld		[r2, #0x180]	
    add r2,r2,#0x40
    add  r6,r6,r4, LSL #0x2  
    pld		[r6, #0x20]
    vmla.f32    q9,  q3, d14[1]	
    add  r7,r7,r4, LSL #0x2 
    pld		[r7, #0x20]
    vmla.f32    q10, q3, d15[0]
    add  r8,r8,r4, LSL #0x2  
    pld		[r8,#0x20]
    vmla.f32    q11, q3, d15[1]	                         
                                      
	bne	loop4

loop4_end:
	ldr		r0, [sp, #0x60]   // activation
    ands r6,r5,#0x3 
    beq activation

loop1:
    vldm		r1,{d0-d1}                                              
    vldm        r2!,{d8-d9}                                      
    subs r6,r6,#0x1
	vmla.f32    q8, q0, d8[0]	
    vmla.f32    q9, q0, d8[1]	
    add         r1,r1,r4
    vmla.f32    q10, q0, d9[0]	
    vmla.f32    q11, q0, d9[1]	
    bne loop1

activation:
	cmp         r0, #0x0
	
        blt         save_result

	vmov.i64	q0, #0x0
	vmax.f32	q8, q8, q0
	vmax.f32	q9, q9, q0
	vmax.f32	q10,q10,q0
	vmax.f32	q11,q11,q0

        beq         save_result

	vdup.32         q0, r0
        vcvt.f32.s32    q0, q0
	vmin.f32	q8, q8, q0
	vmin.f32	q9, q9, q0
	vmin.f32	q10,q10,q0
	vmin.f32	q11,q11,q0

save_result:
                                // r3
    add     r0, r3, r4          // r0  + hw
    add     r5, r3, r4, LSL #0x1    // r5  + 2*hw
    add     r6, r0, r4, LSL #0x1    // r6  + 3*hw

	vstm		r3, {d16,d17}
    vstm		r0, {d18,d19}
    vstm		r5, {d20,d21}
    vstm		r6, {d22,d23}

	// restore content
	vpop	{d8 - d15}    
	pop		{r4 - r8, pc}
	
        .end

