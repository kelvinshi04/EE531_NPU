`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/26/2026 02:32:55 PM
// Design Name: 
// Module Name: MAC_8ln_8b
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


module MAC_8ln_8b(
    input logic signed [7:0] [7:0] data,
    input logic signed [7:0] [7:0] weight,
    output logic signed [19:0] result,
    output logic cout
    );
    
    logic signed [7:0] [15:0] products;
    logic signed [2:0] [15:0] s1_pp, s1_carry;
    logic signed [15:0] s2_pp1, s2_carry1;
    logic signed [17:0] s2_pp2, s2_carry2;
    logic signed [17:0] s3_pp, s3_carry;
    logic signed [17:0] s4_pp, s4_carry;

    
    // Parallel 8-lane multiplication
    booth_mult_8b m1 (data[0], weight[0], products[0]);
    booth_mult_8b m2 (data[1], weight[1], products[1]);
    booth_mult_8b m3 (data[2], weight[2], products[2]);
    booth_mult_8b m4 (data[3], weight[3], products[3]);
    booth_mult_8b m5 (data[4], weight[4], products[4]);
    booth_mult_8b m6 (data[5], weight[5], products[5]);
    booth_mult_8b m7 (data[6], weight[6], products[6]);
    booth_mult_8b m8 (data[7], weight[7], products[7]);
    
    // Stage 1 Adder
    csa_16b a1 (products[0], products[1], products[2], s1_pp[0], s1_carry[0]);
    csa_16b a2 (products[3], products[4], products[5], s1_pp[1], s1_carry[1]);
    csa_16b a3 (products[6], products[7], 16'b0, s1_pp[2], s1_carry[2]);
    
    // Stage 2 Adder
    logic signed [2:0] [17:0] s1_carry2;
    csa_16b a4 (s1_pp[0], s1_pp[1], s1_pp[2], s2_pp1, s2_carry1);
    
    assign s1_carry2[0] = 18'(signed'(s1_carry[0])) << 1;
    assign s1_carry2[1] = 18'(signed'(s1_carry[1])) << 1;
    assign s1_carry2[2] = 18'(signed'(s1_carry[2])) << 1;
    csa_18b a5 (s1_carry2[0], s1_carry2[1], s1_carry2[2], s2_pp2, s2_carry2);
    
    // Stage 3 Adder
    logic signed [17:0] s2_carry;
    assign s2_carry = 18'(signed'(s2_carry1)) << 1;
    csa_18b a6 ({{2{s2_pp1[15]}}, s2_pp1}, s2_pp2, s2_carry, s3_pp, s3_carry);
    
    // Stage 4 Adder
    csa_18b a7 (s3_pp, (s3_carry << 1), (s2_carry2 << 1), s4_pp, s4_carry);
    
    // Final Adder
    logic signed [18:0] s4_carry1;
    assign s4_carry1 = 19'(signed'(s4_carry)) << 1;
    cla_20b a8 ({s4_pp[17], s4_pp}, s4_carry1, 1'b0, result, cout);
    
endmodule
