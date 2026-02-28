`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/19/2026 01:02:06 PM
// Design Name: 
// Module Name: booth_mult_8b
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


module booth_mult_8b(
    input logic signed [7:0] m,
    input logic signed [7:0] q,
    output logic signed [15:0] prod
    );
    
    logic signed [15:0] pp [3:0];
    
    booth_enc_rad4 pp1(m, {q[1:0], 1'b0}, pp[0]);
    booth_enc_rad4 pp2(m, q[3:1], pp[1]);
    booth_enc_rad4 pp3(m, q[5:3], pp[2]);
    booth_enc_rad4 pp4(m, q[7:5], pp[3]);
    assign prod = pp[0] + (pp[1] <<< 2) + (pp[2] <<< 4) + (pp[3] <<< 6);
    
endmodule