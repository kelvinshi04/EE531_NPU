`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: dma
// Description: Simple register-based DMA to load data/weights into scratchpad
//              SRAMs for NPU MAC operation.
//
// Host pushes 32-bit words via src_valid/src_ready handshake.
// target_sel chooses which SRAM (0=data, 1=weights).
// Internal FSM sequences writes to the selected SRAM port 0.
//
// Pipeline:
//   IDLE  -> wait for start pulse
//   LOAD  -> accept words from host, write to SRAM, increment address
//   DONE  -> assert done for one cycle, return to IDLE
//////////////////////////////////////////////////////////////////////////////////

module dma (
    input  logic        clk,
    input  logic        reset,

    input  logic [31:0] src_data,
    input  logic        src_valid,
    output logic        src_ready,

    input  logic        target_sel,
    input  logic [8:0]  start_addr,
    input  logic [8:0]  transfer_len,
    input  logic        start,

    output logic        done,

    output logic        csb0_a,
    output logic        web0_a,
    output logic [3:0]  wmask0_a,
    output logic [8:0]  addr0_a,
    output logic [31:0] din0_a,

    output logic        csb0_b,
    output logic        web0_b,
    output logic [3:0]  wmask0_b,
    output logic [8:0]  addr0_b,
    output logic [31:0] din0_b
);

    typedef enum logic [1:0] {
        IDLE = 2'b00,
        LOAD = 2'b01,
        DONE = 2'b10
    } state_t;

    state_t state, next_state;

    logic [8:0] addr_cnt;
    logic [8:0] words_remaining;
    logic       target_sel_r;

    // -------------------------------------------------------------------------
    // FSM State Register
    // -------------------------------------------------------------------------
    always_ff @(posedge clk or posedge reset) begin
        if (reset) state <= IDLE;
        else       state <= next_state;
    end

    // -------------------------------------------------------------------------
    // FSM Next State Logic
    // No dependency on src_ready - breaks the combinational loop
    // -------------------------------------------------------------------------
    always_comb begin
        next_state = state;
        case (state)
            IDLE: if (start)                                        next_state = LOAD;
            // Transition when last word handshakes:
            // words_remaining==1 means this is the last word,
            // src_valid confirms host is presenting it,
            // state==LOAD confirms we are accepting (ready is high in LOAD when cnt>0)
            LOAD: if (words_remaining == 9'd1 && src_valid && src_ready)         next_state = DONE;
            DONE:                                                   next_state = IDLE;
            default:                                                next_state = IDLE;
        endcase
    end

    // -------------------------------------------------------------------------
    // Address Counter and Transfer Control
    // -------------------------------------------------------------------------
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            addr_cnt        <= '0;
            words_remaining <= '0;
            target_sel_r    <= '0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        addr_cnt        <= start_addr;
                        words_remaining <= transfer_len;
                        target_sel_r    <= target_sel;
                    end
                end

                LOAD: begin
                    if (src_valid && src_ready) begin
                        addr_cnt        <= addr_cnt + 9'd1;
                        words_remaining <= words_remaining - 9'd1;
                    end
                end

                default: ;
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // Output Logic
    // src_ready: simple - high in LOAD as long as words remain
    // No combinational dependency on next_state
    // -------------------------------------------------------------------------
    assign src_ready = (state == LOAD) && (words_remaining != 9'd0);
    assign done      = (state == DONE);

    // Write enable: only when handshake is valid
    logic write_en_a, write_en_b;
    assign write_en_a = src_valid && src_ready && ~target_sel_r;
    assign write_en_b = src_valid && src_ready &&  target_sel_r;

    assign csb0_a   = ~write_en_a;
    assign web0_a   = ~write_en_a;
    assign wmask0_a = 4'b1111;
    assign addr0_a  = addr_cnt;
    assign din0_a   = src_data;

    assign csb0_b   = ~write_en_b;
    assign web0_b   = ~write_en_b;
    assign wmask0_b = 4'b1111;
    assign addr0_b  = addr_cnt;
    assign din0_b   = src_data;

endmodule