`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/05/2026 07:18:28 PM
// Design Name: 
// Module Name: mux_2t1_32b
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


module mux_2t1_32b(
    input logic [31:0] a,
    input logic [31:0] b, 
    input logic sel,
    output logic [31:0] y
    );
    
    always_comb begin
        if (~sel)
            y = a;
        else
            y = b;
    end
    
    
    
    
    
    
    
endmodule
