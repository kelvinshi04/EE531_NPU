`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/12/2026 01:29:17 PM
// Design Name: 
// Module Name: tb_npu_max
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


module tb_npu_max();

    // =========================================================================
    // Parameters
    // =========================================================================
    // Each word packs 4 × 8-bit elements.
    // vec_len (words) = 2^VECTOR_SIZE / 4
    localparam int VECTOR_SIZE  = 4;            // → 4 words per vector
    localparam int VEC_LEN_WORDS= VECTOR_SIZE; // = 4
    localparam int NUM_OUTPUTS  = 4;            // number of output neurons
    localparam int TOTAL_WORDS  = VEC_LEN_WORDS;
    localparam int NUM_NODES = 4;

    localparam int START_ADDR   = 0;
    localparam int CLK_PERIOD   = 10; // ns

    // =========================================================================
    // DUT Port Signals
    // =========================================================================
    logic        CLK;
    logic        RESET;
    logic [3:0]  VECTOR_SIZE_IN;
    logic        START_NPU;
    logic        NPU_DONE;

    logic [8:0]  START_ADDR_IN;

    // Source stream (TB → NPU)
    logic [31:0] SRC_DATA;
    logic        SRC_VALID;
    logic        SRC_READY;

    // Destination stream (NPU → TB)
    logic [31:0] DST_DATA;
    logic        DST_VALID;
    logic        DST_READY;
    logic        READ_OUTPUT;
    

    // =========================================================================
    // DUT Instantiation
    // =========================================================================
    NPU_topmodule dut (
        .CLK          (CLK),
        .RESET        (RESET),
        .VECTOR_SIZE  (VECTOR_SIZE_IN),
        .NUM_NODES    (NUM_NODES),
        .START_NPU    (START_NPU),
        .NPU_DONE     (NPU_DONE),
        .READ_OUTPUT  (READ_OUTPUT),
        .START_ADDR   (START_ADDR_IN),
        .SRC_DATA     (SRC_DATA),
        .SRC_VALID    (SRC_VALID),
        .SRC_READY    (SRC_READY),
        .DST_DATA     (DST_DATA),
        .DST_VALID    (DST_VALID),
        .DST_READY    (DST_READY)
    );

    // =========================================================================
    // Clock Generation
    // =========================================================================
    initial CLK = 0;
    always #(CLK_PERIOD/2) CLK = ~CLK;

    // =========================================================================
    // Test Data Arrays
    //   Data and weights are 8-bit signed values packed 4-per-word.
    //   Bias is a 32-bit signed initial accumulator value.
    //
    //   Layout:  word[i] = {byte3, byte2, byte1, byte0}
    //            Matches MAC_pip_4ln_8b lane ordering:
    //              lane 0: bits  [7:0]
    //              lane 1: bits [15:8]
    //              lane 2: bits [23:16]
    //              lane 3: bits [31:24]
    // =========================================================================
    logic signed [31:0] bias_mem  [0:NUM_OUTPUTS-1];
    logic signed [31:0] data_mem  [0:TOTAL_WORDS-1];
    logic signed [31:0] wgt_mem   [0:TOTAL_WORDS*NUM_NODES-1];
    logic signed [31:0] golden    [0:NUM_OUTPUTS-1];
    logic signed [31:0] received  [0:NUM_OUTPUTS-1];

    // =========================================================================
    // Golden Model Task
    //   Computes expected result for each output neuron.
    //   result[n] = bias[n] + sum_over_words( dot4(data[n*VL+w], wgt[n*VL+w]) )
    //   where dot4 sums the four 8-bit × 8-bit signed lane products.
    // =========================================================================
    task automatic compute_golden();
        logic signed [31:0] acc;
        logic signed  [7:0] d0, d1, d2, d3;
        logic signed  [7:0] w0, w1, w2, w3;
        int base;
        for (int n = 0; n < NUM_OUTPUTS; n++) begin
            acc  = bias_mem[n];
            base = n * VEC_LEN_WORDS;
            for (int w = 0; w < VEC_LEN_WORDS; w++) begin
                d0 = data_mem[w][ 7: 0];
                d1 = data_mem[w][15: 8];
                d2 = data_mem[w][23:16];
                d3 = data_mem[w][31:24];
                w0 = wgt_mem [base+w][ 7: 0];
                w1 = wgt_mem [base+w][15: 8];
                w2 = wgt_mem [base+w][23:16];
                w3 = wgt_mem [base+w][31:24];
                acc = acc + (32'(d0*w0) + 32'(d1*w1) + 32'(d2*w2) + 32'(d3*w3));
            end
            golden[n] = acc;
        end
    endtask

    // =========================================================================
    // Source Stream Driver Task
    //   Sends 'len' words from mem[] to the DUT via SRC_VALID/SRC_READY.
    // =========================================================================
    task automatic stream_send(
        input logic signed [31:0] mem[],
        input int                  len
    );
        for (int i = 0; i < len; i++) begin
            @(posedge CLK);
            SRC_DATA  = mem[i];
            SRC_VALID = 1'b1;
            // Wait for handshake
            while (!SRC_READY) @(posedge CLK);
            @(posedge CLK);
            SRC_VALID = 1'b0;
        end
    endtask

    // =========================================================================
    // Destination Stream Receiver Task
    //   Accepts 'len' words from the DUT via DST_VALID/DST_READY.
    // =========================================================================
    task automatic stream_recv(
        input  int           len
    );
        READ_OUTPUT = 1'b1;
        DST_READY = 1'b1;
        for (int i = 0; i < len; i++) begin
            // Wait for DST_VALID
            while (!DST_VALID) @(posedge CLK);
            received[i] = DST_DATA;
            @(posedge CLK);
        end
        DST_READY = 1'b0;
        READ_OUTPUT = 1'b0;
    endtask

    // =========================================================================
    // Timeout watchdog
    // =========================================================================
    initial begin
        #50000000;
        $display("TIMEOUT: NPU_DONE never asserted.");
        $finish;
    end

    // =========================================================================
    // Main Test
    // =========================================================================
    int fail_count;

    initial begin
        // ------------------------------------------------------------
        // Initialise inputs
        // ------------------------------------------------------------
        RESET         = 1'b1;
        START_NPU     = 1'b0;
        SRC_DATA      = '0;
        SRC_VALID     = 1'b0;
        DST_READY     = 1'b0;
        VECTOR_SIZE_IN= VECTOR_SIZE[3:0];
        START_ADDR_IN = START_ADDR[8:0];
        fail_count    = 0;
        READ_OUTPUT   = '0;

        // ------------------------------------------------------------
        // Populate test vectors (simple pattern - easy to hand-check)
        //   bias[n]         = n+1         (e.g. 1, 2, 3, 4)
        //   data bytes      = 1 (all lanes, all words)
        //   weight bytes    = 1 (all lanes, all words)
        //   → each lane product = 1, 4 lanes × VEC_LEN_WORDS products
        //   → result[n] = bias[n] + 4*VEC_LEN_WORDS
        // ------------------------------------------------------------
        for (int n = 0; n < NUM_OUTPUTS; n++) begin
            bias_mem[n] = n + 1;
            data_mem[n] = $urandom();
        end
        for (int n = 0; n < NUM_OUTPUTS*VECTOR_SIZE; n++) begin
            wgt_mem[n] = $urandom();
        end
       
        compute_golden();

        $display("----------------------------------------------------");
        $display(" NPU Testbench");
        $display("----------------------------------------------------");
        $display(" VECTOR_SIZE  = %0d  (%0d words/vector)",
                  VECTOR_SIZE, VEC_LEN_WORDS);
        $display(" NUM_OUTPUTS  = %0d", NUM_OUTPUTS);
        $display(" TOTAL_WORDS  = %0d", TOTAL_WORDS);
        $display("");
        for (int n = 0; n < NUM_OUTPUTS; n++)
            $display(" golden[%0d] = %0d", n, golden[n]);
        $display("----------------------------------------------------");

        // ------------------------------------------------------------
        // Reset
        // ------------------------------------------------------------
        @(posedge CLK);
        RESET = 1'b0;
        #1;
        RESET = 1'b1;
        @(posedge CLK);

        // ------------------------------------------------------------
        // Assert START_NPU for one cycle to kick off the FSM.
        // The FSM will sequence LOAD_BIAS → LOAD_DATA → LOAD_WGTS
        // automatically; the testbench must supply all three streams
        // back-to-back because the DMA start_dma is asserted
        // continuously in each LOAD state.
        // ------------------------------------------------------------
        @(posedge CLK);
        START_NPU = 1'b1;
        @(posedge CLK);
        START_NPU = 1'b0;

        // Stream: BIAS
        $display("[%0t] Streaming BIAS...", $time);
        SRC_VALID = 1'b1;
        @(posedge CLK);
        stream_send(bias_mem, NUM_OUTPUTS);

        // Stream: DATA
        
        $display("[%0t] Streaming DATA...", $time);
        @(posedge CLK);
        stream_send(data_mem, TOTAL_WORDS);

        // Stream: WEIGHTS
        $display("[%0t] Streaming WEIGHTS...", $time);
        @(posedge CLK);
        stream_send(wgt_mem, TOTAL_WORDS*NUM_NODES);

        
        // ------------------------------------------------------------
        // Wait for COMPUTE → WRITEBACK → DONE
        // ------------------------------------------------------------
        $display("[%0t] Waiting for NPU_DONE...", $time);
        while (!NPU_DONE) @(posedge CLK);
        $display("[%0t] NPU_DONE asserted.", $time);

        // ------------------------------------------------------------
        // Receive writeback data
        // ------------------------------------------------------------
        $display("[%0t] Receiving output...", $time);
        stream_recv(NUM_OUTPUTS);

        // ------------------------------------------------------------
        // Check results
        // ------------------------------------------------------------
        $display("----------------------------------------------------");
        $display(" Results");
        $display("----------------------------------------------------");
        for (int n = 0; n < NUM_OUTPUTS; n++) begin
            if (received[n] === golden[n]) begin
                $display(" [PASS] output[%0d] = %0d (expected %0d)",
                          n, received[n], golden[n]);
            end else begin
                $display(" [FAIL] output[%0d] = %0d (expected %0d) *** MISMATCH ***",
                          n, received[n], golden[n]);
                fail_count++;
            end
        end
        $display("----------------------------------------------------");
        if (fail_count == 0)
            $display(" ALL TESTS PASSED");
        else
            $display(" %0d TEST(S) FAILED", fail_count);
        $display("----------------------------------------------------");

        $finish;
    end

endmodule

