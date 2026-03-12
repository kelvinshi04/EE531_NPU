`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: dma
// Description: Bidirectional DMA for NPU scratchpad SRAMs.
//
// Shared write bus architecture:
//   - DMA drives addr, din, web, wmask onto shared bus
//   - FSM externally controls csb[3:0] to select which SRAM is active
//   - DMA has no knowledge of which SRAM it is talking to
//
// direction=0 (LOAD):
//   Host pushes words via src_valid/src_ready handshake
//   DMA drives shared write bus
//   FSM asserts appropriate csb
//
// direction=1 (WRITEBACK):
//   DMA reads output SRAM Port 1 via dedicated read path
//   DMA pushes words to host via dst_valid/dst_ready handshake
//   FSM asserts csb1 for output SRAM Port 1
//
// SRAMs on shared bus:
//   csb[0] = SRAM 0 (data)
//   csb[1] = SRAM 1 (weights)
//   csb[2] = SRAM 2 (bias)
//   csb[3] = SRAM 3 (output) -- writeback source via Port 1
//
// Pipeline:
//   IDLE      -> wait for start
//   LOAD      -> accept words from host, drive write bus
//   READ_REQ  -> present address to output SRAM Port 1
//   READ_WAIT -> wait one cycle for SRAM read latency
//   WRITEBACK -> push data to host
//   DONE      -> pulse done, return to IDLE
//////////////////////////////////////////////////////////////////////////////////

module dma (
    input  logic        clk,
    input  logic        reset,

    // -------------------------------------------------------------------------
    // Host control interface
    // -------------------------------------------------------------------------
    input  logic        direction,      // 0=load, 1=writeback
    input  logic [8:0]  start_addr,     // SRAM start address
    input  logic [8:0]  transfer_len,   // number of 32-bit words
    input  logic        start,          // pulse high to begin
    output logic        done,           // pulses high one cycle when complete

    // -------------------------------------------------------------------------
    // LOAD interface (host -> DMA)
    // -------------------------------------------------------------------------
    input  logic [31:0] src_data,
    input  logic        src_valid,
    output logic        src_ready,

    // -------------------------------------------------------------------------
    // WRITEBACK interface (DMA -> host)
    // -------------------------------------------------------------------------
    output logic [31:0] dst_data,
    output logic        dst_valid,
    input  logic        dst_ready,

    // -------------------------------------------------------------------------
    // Shared write bus (driven by DMA, csb controlled by FSM externally)
    // -------------------------------------------------------------------------
    output logic [8:0]  bus_addr,       // write address
    output logic [31:0] bus_din,        // write data
    output logic        bus_web,        // active low write enable
    output logic [3:0]  bus_wmask,      // byte write mask

    // -------------------------------------------------------------------------
    // Output SRAM Port 1 read path (writeback source)
    // -------------------------------------------------------------------------
    output logic [8:0]  bus_addr1,      // read address to output SRAM Port 1
    input  logic [31:0] bus_dout1       // read data from output SRAM Port 1
);

    // -------------------------------------------------------------------------
    // FSM State Encoding
    // -------------------------------------------------------------------------
    typedef enum logic [2:0] {
        IDLE      = 3'b000,
        LOAD      = 3'b001,
        READ_REQ  = 3'b010,
        READ_WAIT = 3'b011,
        WRITEBACK = 3'b100,
        DONE      = 3'b101,
        LOAD_WAIT = 3'b110
    } state_t;

    state_t state, next_state;

    // -------------------------------------------------------------------------
    // Internal Registers
    // -------------------------------------------------------------------------
    logic [8:0] addr_cnt;
    logic [8:0] words_remaining;
    logic       direction_r;

    // -------------------------------------------------------------------------
    // FSM State Register + registered done
    // -------------------------------------------------------------------------
    always_ff @(posedge clk or negedge reset) begin
        if (~reset) begin
            state <= IDLE;
            done  <= 1'b0;
        end else begin
            state <= next_state;
            done  <= (next_state == DONE);
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
                    next_state = direction ? READ_REQ : LOAD_WAIT;
            LOAD_WAIT:
                next_state = LOAD;
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
    always_ff @(posedge clk or negedge reset) begin
        if (~reset) begin
            addr_cnt        <= '0;
            words_remaining <= '0;
            direction_r     <= '0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        addr_cnt        <= start_addr;
                        words_remaining <= transfer_len;
                        direction_r     <= direction;
                    end
                end
                
                LOAD_WAIT:
                    ;

                LOAD: begin
                    if (src_valid && src_ready) begin
                        addr_cnt        <= addr_cnt + 9'd1;
                        words_remaining <= words_remaining - 9'd1;
                    end
                end

                WRITEBACK: begin
                    if (dst_ready && dst_valid) begin
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
    // src_ready: high during LOAD when words remain
    // bus_web:   active low, asserted only during valid handshake
    // bus_addr:  always driven from addr_cnt
    // bus_din:   always driven from src_data
    // bus_wmask: always full word write
    // NOTE: bus_web being low AND the FSM asserting csb together form
    //       a valid write - neither alone causes a write
    // -------------------------------------------------------------------------
    assign src_ready = (state == LOAD || state == LOAD_WAIT) && (words_remaining != 9'd0);

    assign bus_web   = ~(src_valid && src_ready);  // active low
    assign bus_addr  = addr_cnt;
    assign bus_din   = src_data;
    assign bus_wmask = 4'b1111;

    // -------------------------------------------------------------------------
    // WRITEBACK Output Logic
    // bus_csb1:  active low, asserted during READ_REQ and READ_WAIT
    // bus_addr1: driven from addr_cnt during read states
    // dst_valid: high when data is ready in WRITEBACK state
    // dst_data:  directly from SRAM Port 1 output
    // -------------------------------------------------------------------------
    assign bus_addr1 = addr_cnt;
    assign dst_valid = (state == WRITEBACK);
    assign dst_data  = bus_dout1;

endmodule