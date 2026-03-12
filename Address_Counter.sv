`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/10/2026 03:12:10 PM
// Design Name: 
// Module Name: Address_Counter
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


module Address_Counter (
    input  logic        clk,
    input  logic        reset,
    input  logic        inc_addr,       // tie to acc_en from FSM
    input  logic [3:0]  vector_size,    // power-of-two vector length in bytes
    input  logic write_succ,

    output logic [8:0]  addr,           // SRAM read address → MAC
    output logic [8:0]  output_addr,    // output SRAM write address
    output logic        vec_done        // one-cycle pulse: vector complete, drain MAC
);

    // -------------------------------------------------------------------------
    // Internal signals
    // -------------------------------------------------------------------------
    logic [8:0]  vec_cnt;       // counts SRAM steps within current vector
    logic [8:0]  vec_len;       // number of SRAM steps per vector = 2^vector_size / 4

    // vec_len = 2^vector_size / 4 = 2^(vector_size-2)
    // e.g. vector_size=4 → 16/4 = 4 steps
    assign vec_len = (9'd1 << vector_size) >> 2;

    // -------------------------------------------------------------------------
    // Sequential logic
    // -------------------------------------------------------------------------
    always_ff @(posedge clk or negedge reset) begin
        if (~reset) begin
            vec_cnt     <= 9'd0;
            addr        <= 9'd0;
            output_addr <= 9'd0;
            vec_done    <= 1'b0;
        end else begin
            vec_done <= 1'b0;   // default: pulse low every cycle
            
            if (write_succ)
                output_addr <= output_addr + 9'd1;

            if (inc_addr) begin
                addr    <= addr + 9'd1;
                if (vec_cnt == vec_len - 9'd1) begin
                    // Vector complete
                    vec_cnt     <= 9'd0;
                    vec_done    <= 1'b1;    // pulse FSM to drain MAC
                end else begin
                    vec_cnt <= vec_cnt + 9'd1;
                end
            end
        end
    end

endmodule