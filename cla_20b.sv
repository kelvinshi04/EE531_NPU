`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/26/2026 11:36:02 PM
// Design Name: 
// Module Name: cla_20b
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


module cla_20b(
    input  logic signed [18:0] a_i,      // 19-bit signed operand A
    input  logic signed [18:0] b_i,      // 19-bit signed operand B
    input  logic cin_i,    // carry-in (see overflow note above)
    
    output logic signed [19:0] sum_o,    // 20-bit signed result (always exact)
    output logic cout_o,   // carry out of bit 19
    output logic overflow_o// signed overflow in 20-bit domain

    );
    
    // ── Sign-extend inputs 19 → 20 bits ───────────────────────────────────────
    // Replicate the MSB (bit 18) into bit [19]
    logic signed [19:0] a20, b20;
    assign a20 = {a_i[18], a_i};   // sign-extend by 1 bit
    assign b20 = {b_i[18], b_i};   // sign-extend by 1 bit
    
    // ── Internal carry and group signals ──────────────────────────────────────
    logic       c_g0, c_g1, c_g2, c_g3;  // carry-in to each group
    logic       Gg0, Pg0;                 // group 0 generate/propagate
    logic       Gg1, Pg1;                 // group 1
    logic       Gg2, Pg2;                 // group 2
    logic       Gg3, Pg3;                 // group 3
    logic       cout_g0, cout_g1, cout_g2, cout_g3;
    
    // ── Top-level carry lookahead for group carries ───────────────────────────
    // All computed in parallel - no ripple between groups
    assign c_g0 = cin_i;
    
    // C_g1 = Gg0 | (Pg0 · C0)
    assign c_g1 = Gg0 | (Pg0 & c_g0);
    
    // C_g2 = Gg1 | (Pg1·Gg0) | (Pg1·Pg0·C0)
    assign c_g2 = Gg1
              | (Pg1 & Gg0)
              | (Pg1 & Pg0 & c_g0);
    
    // C_g3 = Gg2 | (Pg2·Gg1) | (Pg2·Pg1·Gg0) | (Pg2·Pg1·Pg0·C0)
    assign c_g3 = Gg2
              | (Pg2 & Gg1)
              | (Pg2 & Pg1 & Gg0)
              | (Pg2 & Pg1 & Pg0 & c_g0);
    
    // cout_o = Gg3 | (Pg3·Gg2) | ... | (Pg3·Pg2·Pg1·Pg0·C0)
    assign cout_o = Gg3
                | (Pg3 & Gg2)
                | (Pg3 & Pg2 & Gg1)
                | (Pg3 & Pg2 & Pg1 & Gg0)
                | (Pg3 & Pg2 & Pg1 & Pg0 & c_g0);
    
    // ── Four 5-bit CLA group instances ────────────────────────────────────────
    
    // Group 0 : bits [4:0]   - least significant
    cla_group_5b u_grp0 (
    .a_i   (a20[4:0]),
    .b_i   (b20[4:0]),
    .cin_i (c_g0),
    .sum_o (sum_o[4:0]),
    .cout_o(cout_g0),
    .Gg_o  (Gg0),
    .Pg_o  (Pg0)
    );
    
    // Group 1 : bits [9:5]
    cla_group_5b u_grp1 (
    .a_i   (a20[9:5]),
    .b_i   (b20[9:5]),
    .cin_i (c_g1),
    .sum_o (sum_o[9:5]),
    .cout_o(cout_g1),
    .Gg_o  (Gg1),
    .Pg_o  (Pg1)
    );
    
    // Group 2 : bits [14:10]
    cla_group_5b u_grp2 (
    .a_i   (a20[14:10]),
    .b_i   (b20[14:10]),
    .cin_i (c_g2),
    .sum_o (sum_o[14:10]),
    .cout_o(cout_g2),
    .Gg_o  (Gg2),
    .Pg_o  (Pg2)
    );
    
    // Group 3 : bits [19:15] - most significant group (contains sign bit [19])
    cla_group_5b u_grp3 (
    .a_i   (a20[19:15]),
    .b_i   (b20[19:15]),
    .cin_i (c_g3),
    .sum_o (sum_o[19:15]),
    .cout_o(cout_g3),
    .Gg_o  (Gg3),
    .Pg_o  (Pg3)
    );
    
    // ── Signed overflow detection (within 20-bit domain) ─────────────────────
    // Overflow iff carry INTO bit 19 ≠ carry OUT OF bit 19.
    // carry_out_bit19 = cout_g3.
    // carry_into_bit19 = carry out of bit 18 = c[4] inside group 3.
    // Reconstruct using group-3 bit-level g/p and its carry-in (c_g3):
    // Note: for legal 19-bit inputs this will always be 0.
    logic c_into_msb;
    logic [4:0] g3, p3;
    assign g3 = a20[19:15] & b20[19:15];
    assign p3 = a20[19:15] ^ b20[19:15];
    
    assign c_into_msb = g3[3]
                    | (p3[3] & g3[2])
                    | (p3[3] & p3[2] & g3[1])
                    | (p3[3] & p3[2] & p3[1] & g3[0])
                    | (p3[3] & p3[2] & p3[1] & p3[0] & c_g3);
    
    assign overflow_o = c_into_msb ^ cout_g3;
    
endmodule
