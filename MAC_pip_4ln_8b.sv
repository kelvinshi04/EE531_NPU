`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/07/2026 06:33:30 PM
// Design Name: 
// Module Name: MAC_pip_4ln_8b
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


module MAC_pip_4ln_8b(
    input logic clk,
    input logic reset,
    
    input logic signed [31:0] bias,
    input logic signed [7:0] data [4],
    input logic signed [7:0] weight [4],
    
    input logic acc_en,
    input logic load,
    
    output logic signed [31:0] result,
    output logic cout
    );
    
    logic signed [15:0] prod_in [4];
    logic signed [15:0] prod_out [4];
    
    logic signed [15:0] s1_pp_in, s1_carry_in;
    logic signed [15:0] s1_pp_out, s1_carry_out;
    logic signed [15:0] s1_pp_to_s2;
    
    logic signed [17:0] s2_s_in, s2_c_in;
    logic signed [17:0] s2_s_out, s2_c_out;
    
    logic signed [19:0] s3_sum_in, s3_s_out;
    
    logic signed [31:0] out;
    
    // Parallel 4-lane multiplication
    booth_mult_8b m1 (data[0], weight[0], prod_in[0]);
    booth_mult_8b m2 (data[1], weight[1], prod_in[1]);
    booth_mult_8b m3 (data[2], weight[2], prod_in[2]);
    booth_mult_8b m4 (data[3], weight[3], prod_in[3]);

    // Multiplier Pipeline Register
    reg_nb #(.n(16)) pip_m1 (prod_in[0], clk, reset, prod_out[0]);
    reg_nb #(.n(16)) pip_m2 (prod_in[1], clk, reset, prod_out[1]);
    reg_nb #(.n(16)) pip_m3 (prod_in[2], clk, reset, prod_out[2]);
    reg_nb #(.n(16)) pip_m4 (prod_in[3], clk, reset, prod_out[3]);
    
    // Stage 1 Adder
    csa_16b a1 (prod_out[0], prod_out[1], prod_out[2], s1_pp_in, s1_carry_in);
    
    // Stage 1 Pipeline Register
    reg_nb #(.n(16)) pip_s1a_1 (s1_pp_in, clk, reset, s1_pp_out);
    reg_nb #(.n(16)) pip_s1a_2 (s1_carry_in, clk, reset, s1_carry_out);
    reg_nb #(.n(16)) pip_s1a_3 (prod_out[3], clk, reset, s1_pp_to_s2);
    
    // Stage 2 Adder
    logic signed [17:0] s1_pp1, s1_pp2, s1_carry;
    assign s1_pp1 = 18'(signed'(s1_pp_out));
    assign s1_carry = 18'(signed'(s1_carry_out)) <<< 1;
    assign s1_pp2 = 18'(signed'(s1_pp_to_s2));
    
    csa_18b a5 (s1_pp1, s1_carry, s1_pp2, s2_s_in, s2_c_in);
    
    // Stage 2 Pipeline Register
    reg_nb #(.n(18)) pip_s2a_1 (s2_s_in, clk, reset, s2_s_out);
    reg_nb #(.n(18)) pip_s2a_2 (s2_c_in, clk, reset, s2_c_out);

    
    // Stage 3 Adder
    logic signed [18:0] s3_carry, s3_s;
    assign s3_carry = 19'(signed'(s2_c_out)) <<< 1;
    assign s3_s = 19'(signed'(s2_s_out));
    
    cla_20b a33 (s3_s, s3_carry, 1'b0, s3_sum_in);
    
    // Stage 3 Pipeline Register
    reg_nb #(.n(20)) pip_s2a_2d (s3_sum_in, clk, reset, s3_s_out);
    
    // Accumulate Stage
    logic signed [31:0] s3_sum;
    logic signed [31:0] fin_add, accum_out;
    assign s3_sum = {{12{s3_s_out[19]}}, s3_s_out};
    
    cla_32b a9 (s3_sum, out, 1'b0, accum_out, cout);
    
    // select between bias input or accumulation
    mux_2t1_32b x1(bias, accum_out, acc_en, fin_add);
    
    reg_ld_nb #(.n(32)) accum (fin_add, clk, reset, load, out);
    assign result = out;
endmodule
