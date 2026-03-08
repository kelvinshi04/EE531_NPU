`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/03/2026 10:23:31 AM
// Design Name: 
// Module Name: cla_32b
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


module cla_32b(
  input  logic signed [31:0] a_i,        // Accumulator register (operand A)
  input  logic signed [31:0] b_i,        // Multiplier product   (operand B)
  input  logic               cin_i,      // Carry-in (tie to 1'b0 for MAC)

  output logic signed [31:0] sum_o,      // 32-bit signed result
  output logic               cout_o,     // Carry out of bit 31
  output logic               overflow_o // Signed overflow -- drive saturation mux

);

  // Group carry signals
  logic c_g0, c_g1, c_g2, c_g3;
  logic Gg0, Pg0, Gg1, Pg1, Gg2, Pg2, Gg3, Pg3;
  logic cout_g0, cout_g1, cout_g2, cout_g3;

  // Top-level CLA: all group carries computed in parallel, no inter-group ripple
  assign c_g0 = cin_i;

  // C8 -- carry into group 1
  assign c_g1 = Gg0
              | (Pg0 & c_g0);

  // C16 -- carry into group 2
  assign c_g2 = Gg1
              | (Pg1 & Gg0)
              | (Pg1 & Pg0 & c_g0);

  // C24 -- carry into group 3
  assign c_g3 = Gg2
              | (Pg2 & Gg1)
              | (Pg2 & Pg1 & Gg0)
              | (Pg2 & Pg1 & Pg0 & c_g0);

  // Carry out of bit 31
  assign cout_o = Gg3
                | (Pg3 & Gg2)
                | (Pg3 & Pg2 & Gg1)
                | (Pg3 & Pg2 & Pg1 & Gg0)
                | (Pg3 & Pg2 & Pg1 & Pg0 & c_g0);

  // Group 0: bits [7:0] -- LSB group
  cla_group_8b u_grp0 (
    .a_i   (a_i[7:0]),    .b_i   (b_i[7:0]),
    .cin_i (c_g0),
    .sum_o (sum_o[7:0]),  .cout_o(cout_g0),
    .Gg_o  (Gg0),         .Pg_o  (Pg0)
  );

  // Group 1: bits [15:8]
  cla_group_8b u_grp1 (
    .a_i   (a_i[15:8]),   .b_i   (b_i[15:8]),
    .cin_i (c_g1),
    .sum_o (sum_o[15:8]), .cout_o(cout_g1),
    .Gg_o  (Gg1),         .Pg_o  (Pg1)
  );

  // Group 2: bits [23:16]
  cla_group_8b u_grp2 (
    .a_i   (a_i[23:16]),   .b_i   (b_i[23:16]),
    .cin_i (c_g2),
    .sum_o (sum_o[23:16]), .cout_o(cout_g2),
    .Gg_o  (Gg2),          .Pg_o  (Pg2)
  );

  // Group 3: bits [31:24] -- MSB group, contains sign bit [31]
  cla_group_8b u_grp3 (
    .a_i   (a_i[31:24]),   .b_i   (b_i[31:24]),
    .cin_i (c_g3),
    .sum_o (sum_o[31:24]), .cout_o(cout_g3),
    .Gg_o  (Gg3),          .Pg_o  (Pg3)
  );

  // -------------------------------------------------------------------------
  // Signed overflow: V = carry_into_bit31 XOR carry_out_of_bit31
  //
  // carry_out_of_bit31 = cout_g3
  // carry_into_bit31   = c[7] inside group 3 (carry out of bit 30)
  // Reconstruct c[7] from group-3 bit-level g/p signals and c_g3:
  // -------------------------------------------------------------------------
  logic c_into_msb;
  logic [7:0] g3, p3;
  assign g3 = a_i[31:24] & b_i[31:24];
  assign p3 = a_i[31:24] ^ b_i[31:24];

  assign c_into_msb = g3[6]
                    | (p3[6] & g3[5])
                    | (p3[6] & p3[5] & g3[4])
                    | (p3[6] & p3[5] & p3[4] & g3[3])
                    | (p3[6] & p3[5] & p3[4] & p3[3] & g3[2])
                    | (p3[6] & p3[5] & p3[4] & p3[3] & p3[2] & g3[1])
                    | (p3[6] & p3[5] & p3[4] & p3[3] & p3[2] & p3[1] & g3[0])
                    | (p3[6] & p3[5] & p3[4] & p3[3] & p3[2] & p3[1] & p3[0] & c_g3);

  assign overflow_o = c_into_msb ^ cout_g3;

endmodule