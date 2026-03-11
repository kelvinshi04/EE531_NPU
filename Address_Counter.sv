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

    output logic [8:0]  addr,           // SRAM read address → MAC
    output logic [8:0]  output_addr,    // output SRAM write address
    output logic        vec_done        // one-cycle pulse: vector complete, drain MAC
);

    // -------------------------------------------------------------------------
    // Internal signals
    // -------------------------------------------------------------------------
    logic [1:0]  sub_cnt;       // counts acc_en pulses 0→3
    logic [8:0]  vec_cnt;       // counts SRAM steps within current vector
    logic [8:0]  vec_len;       // number of SRAM steps per vector = 2^vector_size / 4

    // vec_len = 2^vector_size / 4 = 2^(vector_size-2)
    // e.g. vector_size=4 → 16/4 = 4 steps
    assign vec_len = (9'd1 << vector_size) >> 2;

    // -------------------------------------------------------------------------
    // Sequential logic
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (reset) begin
            sub_cnt     <= 2'd0;
            vec_cnt     <= 9'd0;
            addr        <= 9'd0;
            output_addr <= 9'd0;
            vec_done    <= 1'b0;
        end else begin
            vec_done <= 1'b0;   // default: pulse low every cycle

            if (inc_addr) begin
                // Every 4 acc_en pulses → advance SRAM address
                if (sub_cnt == 2'd3) begin
                    sub_cnt <= 2'd0;
                    addr    <= addr + 9'd1;
                    if (vec_cnt == vec_len - 9'd1) begin
                        // Vector complete
                        vec_cnt     <= 9'd0;
                        output_addr <= output_addr + 9'd1;
                        vec_done    <= 1'b1;    // pulse FSM to drain MAC
                    end else begin
                        vec_cnt <= vec_cnt + 9'd1;
                    end

                end else begin
                    sub_cnt <= sub_cnt + 2'd1;
                end
            end
        end
    end

endmodule
