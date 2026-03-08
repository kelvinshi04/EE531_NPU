`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/02/2026 05:12:55 PM
// Design Name: 
// Module Name: reg_nb
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


module reg_nb #(parameter n=16) (
    input logic [n-1:0] data_in,
    input logic clk, 
	input logic clr, 
    output logic [n-1:0] data_out
); 

    always @(negedge clr, posedge clk) begin 
       if (~clr)
          data_out <= 0;
       else
          data_out <= data_in; 
    end
endmodule

