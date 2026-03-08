`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/07/2026 07:04:30 PM
// Design Name: 
// Module Name: reg_ld_nb
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


module reg_ld_nb #(parameter n=16) (
    input logic [n-1:0] data_in,
    input logic clk, 
	input logic clr,
	input logic ld, 
    output logic [n-1:0] data_out
); 

    always @(negedge clr, posedge clk) begin 
       if (~clr)
          data_out <= 0;
       else if (ld)
          data_out <= data_in;
       else
          data_out <= data_out; 
    end
endmodule
