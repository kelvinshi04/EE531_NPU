`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/26/2026 03:47:42 PM
// Design Name: 
// Module Name: csa_18b
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


module csa_18b(
    input logic [17:0] a,
    input logic [17:0] b,
    input logic [17:0] c,
    output logic [17:0] s,
    output logic [17:0] carry
    );
    
    csa_16b x1 (a[15:0], b[15:0], c[15:0], s[15:0], carry[15:0]);
    csa_2b x2 (a[17:16], b[17:16], c[17:16], s[17:16], carry[17:16]);

endmodule
