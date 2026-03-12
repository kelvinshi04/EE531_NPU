`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/08/2026 07:18:31 AM
// Design Name: 
// Module Name: NPU_topmodule
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


module NPU_topmodule (
    input logic CLK,
    input logic RESET,
    input logic [3:0] VECTOR_SIZE,
    input logic [3:0] NUM_NODES,
    input logic START_NPU,
    input logic READ_OUTPUT,
    output logic NPU_DONE,
    
    input [8:0] START_ADDR,
    
    // DMA Input Signals
    input  logic [31:0] SRC_DATA,
    input  logic        SRC_VALID,
    output logic        SRC_READY,
    
    output logic [31:0] DST_DATA,
    output logic        DST_VALID,
    input  logic        DST_READY
    );
    
    // =========================================================================
    // FSM Control Signals
    // =========================================================================
    
    // DMA Control Varibles
    logic direction, start_dma, done, reset_addr;
    
    //Scratchpad Signals
    logic bias_csb, data_csb, wgt_csb, bus_csb1;
    logic bias_rd_en, data_rd_en, wgt_rd_en;
    logic write_succ;
    
    //MAC Variables
    logic acc_en, load, bias_latch, ld_input;
    logic inc_addr;
    
    //Output SRAM
    logic out_wr_en;
    logic vec_done;
    
    logic [3:0] iter;
    logic [8:0] tran_out;
    
    
    // =========================================================================
    // Internal Signals
    // =========================================================================
    
    //Scratchpad Signals
    logic bus_web;
    logic [3:0]  bus_wmask;
    logic [8:0]  bus_addr;
    logic [31:0] bus_din;
    logic [8:0]  bus_addr1;
    logic signed [31:0] bias_dout, data_dout, wgt_dout;
    
    //MAC Variables
    logic [8:0] MAC_addr, wgts_addr; // Controlled  by Addr Counter
    logic signed [31:0] mac_result;
    logic signed [31:0] sat_result;
    logic overflow; 
    
    //Output SRAM
    logic [8:0]  out_wr_addr; // Controlled by Addr Counter
    logic [31:0] bus_dout1, out_stream;
    
    // =========================================================================
    // Control
    // =========================================================================
    Control_FSM fsm (
        .clk        (CLK),
        .reset      (RESET),
        .start_npu  (START_NPU),
        .npu_done   (NPU_DONE),
        .inc_addr   (inc_addr),
        .addr       (MAC_addr),
        .vec_done   (vec_done),
        .num_nodes  (NUM_NODES),
        .transfer_len (VECTOR_SIZE),
        .transfer_len_out (tran_out),
        .read_output  (READ_OUTPUT),
        .iter       (iter),
        .direction  (direction),
        .start_dma  (start_dma),
        .done       (done),
        .bias_csb   (bias_csb),
        .data_csb   (data_csb),
        .wgt_csb    (wgt_csb),
        .bus_csb1   (bus_csb1),
        .bias_latch (bias_latch),
        .bias_rd_en (bias_rd_en),
        .data_rd_en (data_rd_en),
        .wgt_rd_en  (wgt_rd_en),
        .acc_en     (acc_en),
        .load       (load),
        .load_input  (ld_input),
        .out_wr_en  (out_wr_en),
        .write_succ (write_succ),
        .reset_addr (reset_addr)
    );
    
    
        // Address Counter
    Address_Counter addr_cnt (
        .clk         (CLK),
        .reset       (RESET),
        .reset_fsm   (reset_addr),
        .inc_addr    (inc_addr),   
        .vector_size (VECTOR_SIZE),
        .write_succ (write_succ),
        .num_nodes  (NUM_NODES),
        .iter       (iter),
    
        .data_addr   (MAC_addr),
        .wgts_addr   (wgts_addr),
        .output_addr (out_wr_addr), 
        .vec_done    (vec_done) 
    );
    
    // =========================================================================
    // DMA
    // =========================================================================
    
    dma dma_main (
        .clk          (CLK),
        .reset        (RESET),
        .direction    (direction),
        
        // Transfer configuration - set before asserting start
        .start_addr   (START_ADDR),     // [8:0] destination start address
        .transfer_len (tran_out),   // [8:0] number of words to transfer
        .start        (start_dma),      // pulse high for one cycle to begin
        .done         (done),           // one-cycle pulse when transfer complete
    
        // Source data stream - from main memory
        .src_data     (SRC_DATA),       // [31:0] incoming data word
        .src_valid    (SRC_VALID),      // data on src_data is valid
        .src_ready    (SRC_READY),      // DMA is ready to accept data
    
        // Output data stream - to main memory
        .dst_data     (out_stream),       // [31:0] outgoing data word
        .dst_valid    (DST_VALID),      // data on dst_data is valid
        .dst_ready    (DST_READY),      // Ext mem ready to accept data
        
        // SRAM write BUS
        .bus_addr     (bus_addr),  
        .bus_din      (bus_din),    
        .bus_web      (bus_web), 
        .bus_wmask    (bus_wmask),    
        
        // Output SRAM access
        .bus_addr1    (bus_addr1),
        .bus_dout1    (bus_dout1)
    );
    
    // =========================================================================
    // Scratchpad Memories
    // =========================================================================
    
    sky130_sram_2kbyte_1rw1r_32x512_8 bias_sram (
        // Port 0 - DMA write
        .clk0   (CLK),
        .csb0   (~bias_csb),
        .web0   (bus_web),
        .wmask0 (bus_wmask),
        .addr0  (bus_addr),
        .din0   (bus_din),
        .dout0  (),

        // Port 1 - To MAC
        .clk1   (CLK),
        .csb1   (~bias_rd_en),
        .addr1  (out_wr_addr),
        .dout1  (bias_dout)
    );
    
    
    sky130_sram_2kbyte_1rw1r_32x512_8 data_sram (
        // Port 0 - DMA write
        .clk0   (CLK),
        .csb0   (~data_csb),
        .web0   (bus_web),
        .wmask0 (bus_wmask),
        .addr0  (bus_addr),
        .din0   (bus_din),
        .dout0  (),

        // Port 1 - To MAC
        .clk1   (CLK),
        .csb1   (~data_rd_en),
        .addr1  (MAC_addr),
        .dout1  (data_dout)
    );
    
    
    sky130_sram_2kbyte_1rw1r_32x512_8 wgt_buffer (
        // Port 0 - DMA write
        .clk0   (CLK),
        .csb0   (~wgt_csb),
        .web0   (bus_web),
        .wmask0 (bus_wmask),
        .addr0  (bus_addr),
        .din0   (bus_din),
        .dout0  (),

        // Port 1 - MAC read
        .clk1   (CLK),
        .csb1   (~wgt_rd_en),
        .addr1  (wgts_addr),
        .dout1  (wgt_dout)
    );
   

    // =========================================================================
    // MAC
    // =========================================================================
  
    // MAC
     MAC_pip_4ln_8b MAC (
        .clk     (CLK),
        .reset   (RESET),
        .bias    (bias_dout),
        .data    (data_dout),
        .weight  (wgt_dout),
        .acc_en  (acc_en),
        .load    (load),
        .ld_input (ld_input),
        .ltch_bias (bias_latch),
        .result  (mac_result),
        .cout    ()
    );   
    
    assign sat_result = mac_result;
 
    // =========================================================================
    // Output SRAM
    // =========================================================================
    
    sky130_sram_2kbyte_1rw1r_32x512_8 out_sram (
        // Port 0 - FSM writes collected results
        .clk0   (CLK),
        .csb0   (~out_wr_en),
        .web0   (1'b0),
        .wmask0 (4'b1111),
        .addr0  (out_wr_addr),
        .din0   (sat_result),
        .dout0  (),

        // Port 1 - DMA reads for writeback
        .clk1   (CLK),
        .csb1   (~bus_csb1),
        .addr1  (bus_addr1),
        .dout1  (bus_dout1)
    );
    
    reg_ld_nb #(.n(32)) output_stream (out_stream, CLK, RESET, READ_OUTPUT, DST_DATA);
endmodule
