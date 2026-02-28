`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/26/2026 03:49:19 PM
// Design Name: 
// Module Name: csa_2b
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


module csa_2b(
    input logic [1:0] a,
    input logic [1:0] b,
    input logic [1:0] c,
    output logic [1:0] s,
    output logic [1:0] carry
    );
    
    full_adder x1(a[0], b[0], c[0], s[0], carry[0]);
    full_adder x2(a[1], b[1], c[1], s[1], carry[1]);
    
endmodule
