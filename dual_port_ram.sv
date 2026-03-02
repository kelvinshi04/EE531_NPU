`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/02/2026 11:28:39 AM
// Design Name: 
// Module Name: dual_port_ram
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


module dual_port_ram #(
  parameter int DATA_W = 32,
  parameter int DEPTH  = 1024,
  localparam int ADDR_W = $clog2(DEPTH)
) (
  input logic clk,
  
  // Port A
  input logic a_we,
  input logic [ADDR_W-1:0] a_addr,
  input logic [DATA_W-1:0] a_wdata,
  output logic [DATA_W-1:0] a_rdata,

  // Port B
  input logic b_we,
  input logic [ADDR_W-1:0] b_addr,
  input logic [DATA_W-1:0] b_wdata,
  output logic [DATA_W-1:0] b_rdata
);

  logic [DATA_W-1:0] mem [0:DEPTH-1];

  always_ff @(posedge clk) begin
    // Port A
    if (a_we) begin
      mem[a_addr] <= a_wdata;
      a_rdata <= a_wdata;         // write-first
    end else begin
      a_rdata <= mem[a_addr];
    end

    // Port B
    if (b_we) begin
      mem[b_addr] <= b_wdata;
      b_rdata <= b_wdata;         // write-first
    end else begin
      b_rdata <= mem[b_addr];
    end
  end
endmodule
