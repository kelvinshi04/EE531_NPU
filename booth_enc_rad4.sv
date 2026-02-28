`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/19/2026 04:55:10 PM
// Design Name: 
// Module Name: booth_enc_rad4
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


module booth_enc_rad4(
    input logic signed [7:0] m,
    input logic [2:0] pattern,
    output logic signed [15:0] part_prod
    );
    
    logic signed [8:0] m_ext;
    always_comb begin
        m_ext = $signed(m);
        case (pattern)
            3'b000,
            3'b111:
                part_prod = $signed(0);
            
            3'b001,
            3'b010:
                part_prod = $signed(m_ext);
                
            3'b101,
            3'b110:
                part_prod = $signed(~m_ext + 1'b1);
        
            3'b011: begin
                part_prod = $signed(m_ext);
                part_prod = $signed(part_prod) <<< 1;
            end
        
            3'b100: begin
                part_prod = $signed(~m_ext + 1);
                part_prod = $signed(part_prod) <<< 1;
            end
        endcase
    end
endmodule
