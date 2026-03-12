`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/09/2026 09:09:29 AM
// Design Name: 
// Module Name: Control_FSM
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


module Control_FSM(
    input  logic clk,
    input  logic reset,
    input  logic start_npu,
    output logic npu_done,
    output logic inc_addr,
    output logic write_succ,
    input  logic [8:0] addr,
    input  logic vec_done,

    output logic direction,
    output logic start_dma,
    input  logic done,
    
    output logic bias_csb,
    output logic data_csb,
    output logic wgt_csb,
    output logic bus_csb1,
    output logic bias_latch,

    output logic bias_rd_en,
    output logic data_rd_en,
    output logic wgt_rd_en,
    
    output logic acc_en,
    output logic load,
    output logic out_wr_en

    );
    // =========================================================================
    // Declarations
    // =========================================================================
    logic [2:0] drain_cnt, mac_init_cnt;
    
    // =========================================================================
    // State definition
    // =========================================================================
    typedef enum logic [3:0] {
        IDLE        = 4'b0000,
        LOAD_BIAS   = 4'b0001,
        LOAD_DATA   = 4'b0010,
        LOAD_WGTS   = 4'b0011,
//        MAC_INIT    = 4'b0100,
        COMPUTE     = 4'b0101,
        DRAIN_MAC   = 4'b0110,
        COLLECT     = 4'b0111,
        WRITEBACK   = 4'b1000,
        DONE        = 4'b1001
    } state_t;

    state_t pres_state, next_state;

    // =========================================================================
    // State register - sequential
    // =========================================================================
    always_ff @(posedge clk or negedge reset) begin
        if (~reset) begin
            pres_state <= IDLE;
            drain_cnt <= '0;
            mac_init_cnt <= '0;
        end else begin
            pres_state <= next_state;
            
            if (pres_state == DRAIN_MAC)
                drain_cnt <= drain_cnt + 1'b1;
            else
                drain_cnt <= '0;
                
            if (pres_state == COMPUTE)
                mac_init_cnt <= mac_init_cnt + 1'b1;
            else
                mac_init_cnt <= '0;
        end
    end
    

    // =========================================================================
    // Next state logic - combinational
    // =========================================================================
    always_comb begin
    
        direction  = 1'b0;      // 0 = load into scratchpad (write direction)
        start_dma  = 1'b0;
        bias_csb   = 1'b0;      // SRAM chip selects - 0 = deselected (active high convention)
        data_csb   = 1'b0;      // matches ~csb0 inversion in top module
        wgt_csb    = 1'b0;
        bus_csb1   = 1'b0;      // output SRAM port 1 - 1 = deselected (active low, no inversion)
        bias_rd_en = 1'b0;      // MAC data/bias read - off by default
        data_rd_en = 1'b0;      // MAC data/bias read - off by default
        wgt_rd_en  = 1'b0;      // MAC data/bias read - off by default
        acc_en     = 1'b0;      // MAC accumulator - off by default
        load       = 1'b0;      // MAC load enable - off by default
        out_wr_en  = 1'b0;      // output SRAM write - off by default
        npu_done   = 1'b0;
        bias_latch = 1'b0;
        write_succ = 1'b0;
        next_state = pres_state;
    
        case (pres_state)
            IDLE: begin
                if (start_npu) begin
                    next_state = LOAD_BIAS;
                end else begin 
                    next_state = IDLE;
                end
            end
            
            LOAD_BIAS: begin
                direction   = 1'b0;
                bias_csb    = 1'b1;
                start_dma   = 1'b1;
                if (done)begin
                    next_state = LOAD_DATA;
                end else begin 
                    next_state = LOAD_BIAS;
                end
            end
            
            LOAD_DATA: begin
                direction   = 1'b0;
                bias_csb    = 1'b0;
                data_csb    = 1'b1;
                start_dma   = 1'b1;
                if (done)begin
                    next_state = LOAD_WGTS;
                end else begin 
                    next_state = LOAD_DATA;
                end
            end
            
            LOAD_WGTS: begin
                direction   = 1'b0;
                data_csb    = 1'b0;
                wgt_csb     = 1'b1;
                start_dma   = 1'b1;
                if (done)begin
                    next_state = COMPUTE;
                end else begin 
                    next_state = LOAD_WGTS;
                end
            end
            
//            MAC_INIT: begin
//                acc_en      = 1'b0;
//                bias_rd_en  = 1'b1;
//                inc_addr   = 1'b1;
//                data_rd_en = 1'b1;
//                wgt_rd_en  = 1'b1;
//                bias_latch = 1'b1;
//                if (mac_init_cnt == 3'd4)begin
//                    load        = 1'b1;
//                    next_state = COMPUTE;
//                end else begin
//                    next_state = MAC_INIT;
//                end
//            end
            
            
            COMPUTE: begin
                if (mac_init_cnt == 3'd4 || mac_init_cnt == 3'd3)begin
                    acc_en      = 1'b0;
                    bias_latch = 1'b1;
                end else begin
                    acc_en      = 1'b1;
                    bias_latch = 1'b0;
                end
                load       = 1'b1;
                inc_addr   = 1'b1;
                bias_rd_en  = 1'b1;
                data_rd_en = 1'b1;
                wgt_rd_en  = 1'b1;
                if (vec_done) begin
                    next_state = DRAIN_MAC;
                end else begin
                    next_state = COMPUTE;
                end     
            end
            
            DRAIN_MAC: begin
                load       = 1'b1;
                acc_en     = 1'b1;
                inc_addr   = 1'b0;
                if (drain_cnt == 3'd4)begin
                    
                    next_state = COLLECT;
                end else begin
                    next_state = DRAIN_MAC;
                end
            end
            
            
            COLLECT: begin
                load       = 1'b0;
                acc_en     = 1'b0;
                inc_addr   = 1'b0;
                out_wr_en  = 1'b1;
                write_succ = 1'b1;
                next_state = WRITEBACK;
            end
            
            
            WRITEBACK: begin
                direction = 1'b1;
                bus_csb1  = 1'b1;
                start_dma = 1'b1;
                if (done)begin
                    next_state = DONE;
                end else begin 
                    next_state = WRITEBACK;
                end
            end
            
            DONE: begin
                npu_done   = 1'b1;
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end


endmodule