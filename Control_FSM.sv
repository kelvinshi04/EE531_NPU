module Control_FSM(
    input  logic clk,
    input  logic reset,
    input  logic start_npu,
    output logic npu_done,
    output logic inc_addr,
    output logic write_succ,
    input  logic [8:0] addr,
    input  logic vec_done,
    input  logic [3:0] num_nodes,
    output logic [3:0] iter,
    input  logic [3:0] transfer_len,
    output logic [8:0] transfer_len_out,
    output logic reset_addr,
    input  logic read_output,

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
    output logic load_input,
    output logic out_wr_en
);

    // =========================================================================
    // Declarations
    // =========================================================================
    logic [2:0] drain_cnt, wait_cycle;
    logic [3:0] nodes, comp_nodes, mac_init_cnt;
    
    // =========================================================================
    // State definition
    // =========================================================================
    typedef enum logic [3:0] {
        IDLE        = 4'b0000,
        LOAD_BIAS   = 4'b0001,
        LOAD_DATA   = 4'b0010,
        LOAD_WGTS   = 4'b0011,
        COMPUTE     = 4'b0101,
        DRAIN_MAC   = 4'b0110,
        COLLECT     = 4'b0111,
        COLL_WAIT   = 4'b0100,
        WRITEBACK   = 4'b1000,
        DONE        = 4'b1001
    } state_t;

    state_t pres_state, next_state;

    // =========================================================================
    // State register - sequential
    // =========================================================================
    always_ff @(posedge clk or negedge reset) begin
        if (~reset) begin
            pres_state   <= IDLE;
            drain_cnt    <= '0;
            mac_init_cnt <= '0;
            nodes        <= '0;
            comp_nodes   <= '0;
            iter         <= '0;
            wait_cycle   <= '0;
        end else begin
            pres_state <= next_state;
            
            // drain counter
            if (pres_state == DRAIN_MAC)
                drain_cnt <= drain_cnt + 1'b1;
            else
                drain_cnt <= '0;
                
            // mac init counter
            if (pres_state == COMPUTE)
                mac_init_cnt <= mac_init_cnt + 1'b1;
            else
                mac_init_cnt <= '0;

            // nodes / comp_nodes / iter / wait_cycle - registered here, not in comb
            case (pres_state)
                IDLE: begin
                    if (start_npu && (transfer_len > 0)) begin
                        nodes      <= num_nodes;
                        comp_nodes <= '0;
                        iter       <= '0;
                        wait_cycle <= 3'd5 - transfer_len[2:0];
                    end
                end
                COMPUTE: begin
                    if (vec_done) begin
                        comp_nodes <= comp_nodes + 1'b1;
                        iter       <= comp_nodes + 1'b1;
                    end
                end
                DRAIN_MAC: begin
                    if (transfer_len < 3'd5 && wait_cycle != 3'd0)
                        wait_cycle <= wait_cycle - 1'b1;
                end
                COLL_WAIT: begin
                    wait_cycle <= 3'd5 - transfer_len[2:0];
                end
                default: ;
            endcase
        end
    end

    // =========================================================================
    // Next state logic - combinational
    // =========================================================================
    always_comb begin
        // --- defaults (every signal assigned here prevents latches) ---
        direction        = 1'b0;
        start_dma        = 1'b0;
        bias_csb         = 1'b0;
        data_csb         = 1'b0;
        wgt_csb          = 1'b0;
        bus_csb1         = 1'b0;
        bias_rd_en       = 1'b0;
        data_rd_en       = 1'b0;
        wgt_rd_en        = 1'b0;
        acc_en           = 1'b0;
        load             = 1'b0;
        load_input       = 1'b0;
        out_wr_en        = 1'b0;
        inc_addr         = 1'b0;      // was missing in many branches - fixed
        npu_done         = 1'b0;
        transfer_len_out = '0;
        bias_latch       = 1'b0;
        write_succ       = 1'b0;
        reset_addr       = 1'b1;
        next_state       = pres_state;
    
        case (pres_state)
            IDLE: begin
                if (start_npu && (transfer_len > 0))
                    next_state = LOAD_BIAS;
                else if (read_output)
                    next_state = WRITEBACK;
            end
            
            LOAD_BIAS: begin
                direction        = 1'b0;
                bias_csb         = 1'b1;
                transfer_len_out = 9'(nodes);
                start_dma        = 1'b1;
                next_state       = done ? LOAD_DATA : LOAD_BIAS;
            end
            
            LOAD_DATA: begin
                data_csb         = 1'b1;
                transfer_len_out = 9'(transfer_len);
                start_dma        = 1'b1;
                next_state       = done ? LOAD_WGTS : LOAD_DATA;
            end
            
            LOAD_WGTS: begin
                wgt_csb          = 1'b1;
                transfer_len_out = 9'(transfer_len) * 9'(nodes);
                start_dma        = 1'b1;
                if (done) begin
                    reset_addr = 1'b0;
                    next_state = COMPUTE;
                end else begin
                    next_state = LOAD_WGTS;
                end
            end
            
            COMPUTE: begin
                acc_en     = (mac_init_cnt == 3'd4 || mac_init_cnt == 3'd5) ? 1'b0 : 1'b1;
                bias_latch = 1'b1;
                load_input = 1'b1;
                load       = 1'b1;
                inc_addr   = 1'b1;
                bias_rd_en = 1'b1;
                data_rd_en = 1'b1;
                wgt_rd_en  = 1'b1;
                next_state = vec_done ? DRAIN_MAC : COMPUTE;
            end
            
            DRAIN_MAC: begin
                acc_en     = (transfer_len < 3'd5 && wait_cycle != 3'd0) ? 1'b0 : 1'b1;
                load       = 1'b1;
                next_state = (drain_cnt == 3'd4) ? COLLECT : DRAIN_MAC;
            end
            
            COLLECT: begin
                out_wr_en  = 1'b1;
                write_succ = 1'b1;
                next_state = (comp_nodes == nodes) ? DONE : COLL_WAIT;
            end
            
            COLL_WAIT: begin
                reset_addr = 1'b0;
                next_state = COMPUTE;
            end
            
            WRITEBACK: begin
                direction        = 1'b1;
                bus_csb1         = 1'b1;
                start_dma        = 1'b1;
                transfer_len_out = 9'(nodes);
                next_state       = done ? DONE : WRITEBACK;
            end
            
            DONE: begin
                npu_done   = 1'b1;
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule