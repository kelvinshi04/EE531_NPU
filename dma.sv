`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: dma
// Description: Bidirectional DMA for NPU scratchpad SRAMs.
//
// direction=0 (LOAD):
//   Host pushes words via src_valid/src_ready into SRAM A (data) or B (weights)
//
// direction=1 (WRITEBACK):
//   DMA reads output SRAM via Port 1 and pushes words to host via dst_valid/dst_ready
//
// SRAM read latency: 1 cycle (addr presented on posedge, data valid after negedge)
// FSM accounts for this with READ_WAIT state
//////////////////////////////////////////////////////////////////////////////////

module dma (
    input  logic        clk,
    input  logic        reset,

    input  logic        direction,
    input  logic        target_sel,
    input  logic [8:0]  start_addr,
    input  logic [8:0]  transfer_len,
    input  logic        start,

    output logic        done,

    input  logic [31:0] src_data,
    input  logic        src_valid,
    output logic        src_ready,

    output logic [31:0] dst_data,
    output logic        dst_valid,
    input  logic        dst_ready,

    output logic        csb0_a,
    output logic        web0_a,
    output logic [3:0]  wmask0_a,
    output logic [8:0]  addr0_a,
    output logic [31:0] din0_a,

    output logic        csb0_b,
    output logic        web0_b,
    output logic [3:0]  wmask0_b,
    output logic [8:0]  addr0_b,
    output logic [31:0] din0_b,

    output logic        csb1_out,
    output logic [8:0]  addr1_out,
    input  logic [31:0] dout1_out
);

    typedef enum logic [2:0] {
        IDLE      = 3'b000,
        LOAD      = 3'b001,
        READ_REQ  = 3'b010,
        READ_WAIT = 3'b011,
        WRITEBACK = 3'b100,
        DONE      = 3'b101
    } state_t;

    state_t state, next_state;

    logic [8:0] addr_cnt;
    logic [8:0] words_remaining;
    logic       target_sel_r;
    logic       direction_r;

    // -------------------------------------------------------------------------
    // FSM State Register + registered done
    // -------------------------------------------------------------------------
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            done  <= 1'b0;
        end else begin
            state <= next_state;
            done  <= (next_state == DONE);  // stable full cycle, testbench can't miss it
        end
    end

    // -------------------------------------------------------------------------
    // FSM Next State Logic
    // -------------------------------------------------------------------------
    always_comb begin
        next_state = state;
        case (state)
            IDLE:
                if (start)
                    next_state = direction ? READ_REQ : LOAD;

            LOAD:
                if (words_remaining == 9'd1 && src_valid && src_ready)
                    next_state = DONE;

            READ_REQ:
                next_state = READ_WAIT;

            READ_WAIT:
                next_state = WRITEBACK;

            WRITEBACK:
                if (dst_ready && dst_valid) begin
                    if (words_remaining == 9'd1)
                        next_state = DONE;
                    else
                        next_state = READ_REQ;
                end

            DONE:
                next_state = IDLE;

            default:
                next_state = IDLE;
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
            direction_r     <= '0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        addr_cnt        <= start_addr;
                        words_remaining <= transfer_len;
                        target_sel_r    <= target_sel;
                        direction_r     <= direction;
                    end
                end

                LOAD: begin
                    if (src_valid && src_ready) begin
                        addr_cnt        <= addr_cnt + 9'd1;
                        words_remaining <= words_remaining - 9'd1;
                    end
                end

                WRITEBACK: begin
                    if (dst_ready && dst_valid && words_remaining != 9'd0) begin
                        addr_cnt        <= addr_cnt + 9'd1;
                        words_remaining <= words_remaining - 9'd1;
                    end
                end

                default: ;
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // LOAD Output Logic
    // -------------------------------------------------------------------------
    assign src_ready = (state == LOAD) && (words_remaining != 9'd0);

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

    // -------------------------------------------------------------------------
    // WRITEBACK Output Logic
    // -------------------------------------------------------------------------
    assign csb1_out  = ~(state == READ_REQ || state == READ_WAIT);
    assign addr1_out = addr_cnt;
    assign dst_valid = (state == WRITEBACK);
    assign dst_data  = dout1_out;

endmodule