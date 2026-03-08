`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/03/2026 10:23:31 AM
// Design Name: 
// Module Name: cla_group_8b
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


module cla_group_8b(
  input  logic [7:0] a_i,
  input  logic [7:0] b_i,
  input  logic       cin_i,
  output logic [7:0] sum_o,
  output logic       cout_o,
  output logic       Gg_o,    // Group Generate:  carry produced regardless of cin
  output logic       Pg_o     // Group Propagate: cin propagated through all 8 bits
);

  logic [7:0] g, p;   // bit-level generate / propagate
  logic [8:0] c;      // c[0]=cin_i, c[1..8]=lookahead carries

  // Bit-level G and P
  assign g = a_i & b_i;    // gi = ai AND bi
  assign p = a_i ^ b_i;    // pi = ai XOR bi

  // Carry lookahead -- all combinational, fully parallel
  assign c[0] = cin_i;

  assign c[1] = g[0]
              | (p[0] & c[0]);

  assign c[2] = g[1]
              | (p[1] & g[0])
              | (p[1] & p[0] & c[0]);

  assign c[3] = g[2]
              | (p[2] & g[1])
              | (p[2] & p[1] & g[0])
              | (p[2] & p[1] & p[0] & c[0]);

  assign c[4] = g[3]
              | (p[3] & g[2])
              | (p[3] & p[2] & g[1])
              | (p[3] & p[2] & p[1] & g[0])
              | (p[3] & p[2] & p[1] & p[0] & c[0]);

  assign c[5] = g[4]
              | (p[4] & g[3])
              | (p[4] & p[3] & g[2])
              | (p[4] & p[3] & p[2] & g[1])
              | (p[4] & p[3] & p[2] & p[1] & g[0])
              | (p[4] & p[3] & p[2] & p[1] & p[0] & c[0]);

  assign c[6] = g[5]
              | (p[5] & g[4])
              | (p[5] & p[4] & g[3])
              | (p[5] & p[4] & p[3] & g[2])
              | (p[5] & p[4] & p[3] & p[2] & g[1])
              | (p[5] & p[4] & p[3] & p[2] & p[1] & g[0])
              | (p[5] & p[4] & p[3] & p[2] & p[1] & p[0] & c[0]);

  assign c[7] = g[6]
              | (p[6] & g[5])
              | (p[6] & p[5] & g[4])
              | (p[6] & p[5] & p[4] & g[3])
              | (p[6] & p[5] & p[4] & p[3] & g[2])
              | (p[6] & p[5] & p[4] & p[3] & p[2] & g[1])
              | (p[6] & p[5] & p[4] & p[3] & p[2] & p[1] & g[0])
              | (p[6] & p[5] & p[4] & p[3] & p[2] & p[1] & p[0] & c[0]);

  assign c[8] = g[7]
              | (p[7] & g[6])
              | (p[7] & p[6] & g[5])
              | (p[7] & p[6] & p[5] & g[4])
              | (p[7] & p[6] & p[5] & p[4] & g[3])
              | (p[7] & p[6] & p[5] & p[4] & p[3] & g[2])
              | (p[7] & p[6] & p[5] & p[4] & p[3] & p[2] & g[1])
              | (p[7] & p[6] & p[5] & p[4] & p[3] & p[2] & p[1] & g[0])
              | (p[7] & p[6] & p[5] & p[4] & p[3] & p[2] & p[1] & p[0] & c[0]);

  // Sum and carry-out
  assign sum_o  = p ^ c[7:0];
  assign cout_o = c[8];

  // Group Generate: carry out regardless of cin
  assign Gg_o = g[7]
              | (p[7] & g[6])
              | (p[7] & p[6] & g[5])
              | (p[7] & p[6] & p[5] & g[4])
              | (p[7] & p[6] & p[5] & p[4] & g[3])
              | (p[7] & p[6] & p[5] & p[4] & p[3] & g[2])
              | (p[7] & p[6] & p[5] & p[4] & p[3] & p[2] & g[1])
              | (p[7] & p[6] & p[5] & p[4] & p[3] & p[2] & p[1] & g[0]);

  // Group Propagate: cin ripples through all 8 bits
  assign Pg_o = p[7] & p[6] & p[5] & p[4] & p[3] & p[2] & p[1] & p[0];

endmodule