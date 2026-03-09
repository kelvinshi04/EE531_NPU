`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/08/2026 10:35:05 PM
// Design Name: 
// Module Name: PE
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


module PE(
    input logic clk,
    input logic reset,
    
    input logic signed [31:0] bias,
    input logic signed [7:0] data_in [4],
    
    input logic acc_en, 
    input logic load,
    input logic [8:0]  wgt_wr_addr,
    input logic [31:0] wgt_wr_data,
    input logic wgt_wr_en,                       
    
    output logic signed [31:0] sat_result
    );
   
    // Internal Signals
    logic [8:0] k_addr;
    logic [31:0] wgt_dout;
    logic signed [7:0] wgt_to_mac [4];
    logic signed [31:0] result;
    logic overflow;

    // Advance Weight Address when Accumulating
    always_ff @(posedge clk) begin
        if (reset || load)
            k_addr <= '0;
        else if (acc_en)
            k_addr <= k_addr + 1'b1;
    end
    

    // Weight Buffer SRAM
    sky130_sram_2kbyte_1rw1r_32x512_8 wgt_buffer (
        // Port 0 - DMA write
        .clk0   (clk),
        .csb0   (~wgt_wr_en),
        .web0   (1'b0),
        .wmask0 (4'b1111),
        .addr0  (wgt_wr_addr),
        .din0   (wgt_wr_data),
        .dout0  (),

        // Port 1 - MAC read
        .clk1   (clk),
        .csb1   (~acc_en),
        .addr1  (k_addr),
        .dout1  (wgt_dout)
    );
    
    // Unpack 32-bit SRAM word into 4 x INT8
    assign wgt_to_mac[0] = signed'(wgt_dout[7:0]);
    assign wgt_to_mac[1] = signed'(wgt_dout[15:8]);
    assign wgt_to_mac[2] = signed'(wgt_dout[23:16]);
    assign wgt_to_mac[3] = signed'(wgt_dout[31:24]);
    
    // MAC
     MAC_pip_4ln_8b MAC (
        .clk     (clk),
        .reset   (reset),
        .bias    (bias),
        .data    (data_in),
        .weight  (wgt_to_mac),
        .acc_en  (acc_en),
        .load    (load),
        .result  (result),
        .cout    (overflow)
    );   
    
    // Deal with Overflow from MAC
    always_comb begin
        if (overflow)
            sat_result = result[31] ? 32'sh80000000 : 32'sh7FFFFFFF;
        else
            sat_result = result;
    end
    
    
endmodule
