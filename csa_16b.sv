`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/20/2026 11:58:10 AM
// Design Name: 
// Module Name: csa_16b
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module csa_16b(
    input logic [15:0] a,
    input logic [15:0] b,
    input logic [15:0] c,
    output logic [15:0] s,
    output logic [15:0] carry
    );
   
    full_adder x1(a[0], b[0], c[0], s[0], carry[0]);
    full_adder x2(a[1], b[1], c[1], s[1], carry[1]);
    full_adder x3(a[2], b[2], c[2], s[2], carry[2]);
    full_adder x4(a[3], b[3], c[3], s[3], carry[3]);
    full_adder x5(a[4], b[4], c[4], s[4], carry[4]);
    full_adder x6(a[5], b[5], c[5], s[5], carry[5]);
    full_adder x7(a[6], b[6], c[6], s[6], carry[6]);
    full_adder x8(a[7], b[7], c[7], s[7], carry[7]);
    full_adder x9(a[8], b[8], c[8], s[8], carry[8]);
    full_adder x10(a[9], b[9], c[9], s[9], carry[9]);
    full_adder x11(a[10], b[10], c[10], s[10], carry[10]);
    full_adder x12(a[11], b[11], c[11], s[11], carry[11]);
    full_adder x13(a[12], b[12], c[12], s[12], carry[12]);
    full_adder x14(a[13], b[13], c[13], s[13], carry[13]);
    full_adder x15(a[14], b[14], c[14], s[14], carry[14]);
    full_adder x16(a[15], b[15], c[15], s[15], carry[15]);
    
endmodule
