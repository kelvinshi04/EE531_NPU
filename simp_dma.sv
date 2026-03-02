`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/02/2026 11:16:21 AM
// Design Name: 
// Module Name: simp_dma
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


module simp_dma #(
  parameter int ADDR_W = 16,   // word address width
  parameter int DATA_W = 32,
  parameter int LEN_W  = 16    // len_words width
) (
  input logic clk,
  input logic rst_n,

  // Control interface
  input logic start,
  input logic [ADDR_W-1:0] src_addr,   // word address in mm
  input logic [ADDR_W-1:0] dst_addr,   // word address in scratchpad
  input logic [LEN_W-1:0] len_words,   // number of words
  output logic busy,
  output logic done, // 1-cycle pulse

  // Main memory read port (sync read)
  output logic [ADDR_W-1:0] mm_addr,
  input  logic [DATA_W-1:0] mm_rdata,

  // Scratchpad write port
  output logic sp_we,
  output logic [ADDR_W-1:0] sp_addr,
  output logic [DATA_W-1:0] sp_wdata
);

  typedef enum logic [1:0] {S_IDLE, S_ISSUE_RD, S_CAPTURE, S_DONE} state_t;
  state_t state, nstate;

  logic [ADDR_W-1:0] src_base_q, dst_base_q;
  logic [LEN_W-1:0]  len_q;
  logic [LEN_W-1:0]  idx_q;

  // defaults
  always_comb begin
    busy = (state != S_IDLE);
    done = 1'b0;

    mm_addr = src_base_q + idx_q;

    sp_we   = 1'b0;
    sp_addr = dst_base_q + idx_q;
    sp_wdata= mm_rdata;

    nstate  = state;

    case (state)
      S_IDLE: begin
        if (start)
            nstate = S_ISSUE_RD;
      end

      S_ISSUE_RD: begin
        // Present mm_addr for this idx (data will be valid next cycle)
        nstate = S_CAPTURE;
      end

      S_CAPTURE: begin
        // mm_rdata is valid now for address issued in prior cycle
        sp_we   = 1'b1;
        // sp_addr/sp_wdata already set
        if (idx_q + 1 >= len_q)
            nstate = S_DONE;
        else
            nstate = S_ISSUE_RD;
      end

      S_DONE: begin
        done   = 1'b1;
        nstate = S_IDLE;
      end
    endcase
  end

  // sequential
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= S_IDLE;
      src_base_q  <= '0;
      dst_base_q  <= '0;
      len_q       <= '0;
      idx_q       <= '0;
    end else begin
      state <= nstate;

      if (state == S_IDLE && start) begin
        src_base_q <= src_addr;
        dst_base_q <= dst_addr;
        len_q      <= len_words;
        idx_q      <= '0;
      end else if (state == S_CAPTURE) begin
        // increment after write
        if (idx_q + 1 < len_q) idx_q <= idx_q + 1;
      end
    end
  end
endmodule
