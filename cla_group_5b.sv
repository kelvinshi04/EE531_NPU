`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/26/2026 11:32:31 PM
// Design Name: 
// Module Name: cla_group_5b
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


module cla_group_5b(
    input  logic [4:0] a_i,
    input  logic [4:0] b_i,
    input  logic cin_i,
    output logic [4:0] sum_o,
    output logic cout_o,
    output logic Gg_o,     // Group Generate
    output logic Pg_o      // Group Propagate
    );

    logic [4:0] g, p;    // bit-level generate / propagate
    logic [5:0] c;       // c[0]=cin_i, c[1..5]=lookahead carries, c[5]=cout

  // ── Bit-level G and P ─────────────────────────────────────────────────────
    assign g = a_i & b_i;   // gi = ai · bi
    assign p = a_i ^ b_i;   // pi = ai ⊕ bi

  // ── Carry lookahead (fully parallel, no ripple within group) ──────────────
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

  // ── Sum bits ──────────────────────────────────────────────────────────────
    assign sum_o  = p ^ c[4:0];   // si = pi ⊕ ci
    assign cout_o = c[5];

  // ── Group-level G and P (fed to top-level CLA) ───────────────────────────
  // Gg: this group generates a carry regardless of cin
    assign Gg_o = g[4]
              | (p[4] & g[3])
              | (p[4] & p[3] & g[2])
              | (p[4] & p[3] & p[2] & g[1])
              | (p[4] & p[3] & p[2] & p[1] & g[0]);

  // Pg: this group propagates cin all the way through
    assign Pg_o = p[4] & p[3] & p[2] & p[1] & p[0];
endmodule
