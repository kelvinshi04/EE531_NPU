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
    
    // DMA Input Signals
    input  logic [31:0] SRC_DATA,
    input  logic        SRC_VALID,
    output logic        SRC_READY,
    
    output logic [31:0] DST_DATA,
    output logic        DST_VALID,
    input  logic        DST_READY,
    
    input logic [31:0] BIAS,
    input logic [3:0] VECTOR_SIZE
    
    
    );
    
    // =========================================================================
    // FSM Control Signals
    // =========================================================================
    
    
    
    // =========================================================================
    // DMA Instantiation
    // =========================================================================
    
    //DMA Variables
    logic direction, target_sel, start, done;
    logic [8:0] start_addr, transfer_len;
    
    
    //Scratchpad Signals
    logic        csb0_a, web0_a, csb0_b, web0_b;
    logic [3:0]  wmask0_a, wmask0_b;
    logic [8:0]  addr0_a, addr0_b;
    logic [31:0] din0_a, din0_b;
    logic        csb1_out;
    logic [8:0]  addr1_out;
    logic [31:0] out_rd_data;
    logic        data_rd_en;
    logic [8:0]  data_rd_addr;
    logic        acc_en, load;
    logic signed [31:0] bias;
    logic        out_wr_en;
    logic [8:0]  out_wr_addr;
    logic [31:0] out_wr_data;
    
        // Internal Signals
    logic [8:0] k_addr;
    logic [31:0] data_rd_data;
    logic [31:0] wgt_dout;
    logic signed [7:0] wgt_to_mac [4];
    logic signed [7:0] data_to_mac [4];
    logic signed [31:0] mac_result;
    logic signed [31:0] sat_result;
    logic overflow;
    
    
    dma dma_main (
        .clk          (CLK),
        .reset        (RESET),
       
        .direction    (direction),
        
        // Transfer configuration - set before asserting start
        .target_sel   (target_sel),     // 0=SRAM A, 1=SRAM B
        .start_addr   (start_addr),     // [8:0] destination start address
        .transfer_len (transfer_len),   // [8:0] number of words to transfer
        .start        (start),          // pulse high for one cycle to begin
        .done         (done),           // one-cycle pulse when transfer complete
    
        // Source data stream - from main memory
        .src_data     (SRC_DATA),       // [31:0] incoming data word
        .src_valid    (SRC_VALID),      // data on src_data is valid
        .src_ready    (SRC_READY),      // DMA is ready to accept data
    
        // Output data stream - to main memory
        .dst_data     (DST_DATA),       // [31:0] outgoing data word
        .dst_valid    (DST_VALID),      // data on dst_data is valid
        .dst_ready    (DST_READY),      // Ext mem ready to accept data
    
        // SRAM A write port (port 0) - connect to data_sram
        .csb0_a       (csb0_a),  
        .web0_a       (web0_a),    
        .wmask0_a     (wmask0_a), 
        .addr0_a      (addr0_a),    
        .din0_a       (din0_a),      
    
        // SRAM B write port (port 1) - connect to wgt_sram
        .csb0_b       (csb0_b),   
        .web0_b       (web0_b),  
        .wmask0_b     (wmask0_b),  
        .addr0_b      (addr0_b),    
        .din0_b       (din0_b),
        
        // SRAM C write port (port 2) - connect to out_sram
        .csb1_out       (csb1_out),   
        .addr1_out      (addr1_out),    
        .dout1_out      (out_rd_data)
    );
    
    
    sky130_sram_2kbyte_1rw1r_32x512_8 data_sram (
        // Port 0 - DMA write
        .clk0   (CLK),
        .csb0   (csb0_a),
        .web0   (web0_a),
        .wmask0 (wmask0_a),
        .addr0  (addr0_a),
        .din0   (din0_a),
        .dout0  (),

        // Port 1 - To MAC
        .clk1   (CLK),
        .csb1   (~data_rd_en),
        .addr1  (data_rd_addr),
        .dout1  (data_rd_data)
    );
    
    // Unpack 32-bit SRAM word into 4 x INT8
    assign data_to_mac[0] = signed'(data_rd_data[7:0]);
    assign data_to_mac[1] = signed'(data_rd_data[15:8]);
    assign data_to_mac[2] = signed'(data_rd_data[23:16]);
    assign data_to_mac[3] = signed'(data_rd_data[31:24]);

    // Advance Weight Address when Accumulating
    always_ff @(posedge CLK) begin
        if (RESET || load)
            k_addr <= '0;
        else if (acc_en)
            k_addr <= k_addr + 1'b1;
    end
    

    // Weight Buffer SRAM
    sky130_sram_2kbyte_1rw1r_32x512_8 wgt_buffer (
        // Port 0 - DMA write
        .clk0   (CLK),
        .csb0   (csb0_b),
        .web0   (web0_b),
        .wmask0 (wmask0_b),
        .addr0  (addr0_b),
        .din0   (din0_b),
        .dout0  (),

        // Port 1 - MAC read
        .clk1   (CLK),
        .csb1   (~acc_en),
        .addr1  (k_addr),
        .dout1  (wgt_dout)
    );
    
    // Unpack 32-bit SRAM word into 4 x INT8
    assign wgt_to_mac[0] = signed'(wgt_dout[7:0]);
    assign wgt_to_mac[1] = signed'(wgt_dout[15:8]);
    assign wgt_to_mac[2] = signed'(wgt_dout[23:16]);
    assign wgt_to_mac[3] = signed'(wgt_dout[31:24]);
    
    // MAC
     MAC_pip_4ln_8b MAC (
        .clk     (CLK),
        .reset   (RESET),
        .bias    (BIAS),
        .data    (data_to_mac),
        .weight  (wgt_to_mac),
        .acc_en  (acc_en),
        .load    (load),
        .result  (mac_result),
        .cout    (overflow)
    );   
    
    // Deal with Overflow from MAC - Lowkey Didn't know if this was the right way of dealing with this
    always_comb begin
        if (overflow)
            sat_result = mac_result[31] ? 32'sh80000000 : 32'sh7FFFFFFF;
        else
            sat_result = mac_result;
    end
    
    
 
    // Output SRAM
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
        .csb1   (csb1_out),
        .addr1  (addr1_out),
        .dout1  (out_rd_data)
    );
    
endmodule

