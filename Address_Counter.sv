module Address_Counter (
    input  logic        clk,
    input  logic        reset,
    input  logic        reset_fsm,
    input  logic        inc_addr,
    input  logic [3:0]  vector_size,
    input  logic [3:0]  num_nodes,
    input  logic [3:0]  iter,
    input  logic        write_succ,

    output logic [8:0]  data_addr,
    output logic [8:0]  wgts_addr,
    output logic [8:0]  output_addr,
    output logic        vec_done
);

    logic [8:0] vec_cnt;
    logic [8:0] vec_len;

    assign vec_len = vector_size;

    always_ff @(posedge clk or negedge reset) begin
        if (~reset) begin
            // Full reset - initialise everything
            vec_cnt     <= 9'd0;
            data_addr   <= 9'd0;
            output_addr <= 9'd0;
            wgts_addr   <= 9'd0;
            vec_done    <= 1'b0;
        end
        else begin
            vec_done <= 1'b0;

            // reset_fsm is now a synchronous partial reset
            if (~reset_fsm) begin
                vec_cnt   <= 9'd0;
                data_addr <= 9'd0;
                wgts_addr <= 9'(vector_size) * 9'(iter);  // safe synchronously
                vec_done  <= 1'b0;
                // output_addr intentionally NOT reset here - holds across vectors
            end
            else begin
                if (write_succ)
                    output_addr <= output_addr + 9'd1;

                if (inc_addr) begin
                    data_addr <= data_addr + 9'd1;
                    wgts_addr <= wgts_addr + 9'd1;
                    if (vec_cnt == vec_len - 9'd1) begin
                        vec_cnt  <= 9'd0;
                        vec_done <= 1'b1;
                    end else begin
                        vec_cnt <= vec_cnt + 9'd1;
                    end
                end
            end
        end
    end

endmodule