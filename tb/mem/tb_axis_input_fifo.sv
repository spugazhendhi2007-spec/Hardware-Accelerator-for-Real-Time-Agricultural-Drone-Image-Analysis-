//=============================================================================
// File: tb_axis_input_fifo.sv
// Description: Self-checking testbench for axis_input_fifo adhering to the
//              standard 8-test verification suite (5 Corner + 2 Normal + 1 Stress).
// Standard: SystemVerilog IEEE 1800
//=============================================================================

`timescale 1ns/1ps

module tb_axis_input_fifo;

    import tb_pkg::*;

    localparam int DATA_WIDTH = 8;
    localparam int DEPTH      = 16;
    localparam int ADDR_WIDTH = $clog2(DEPTH);

    logic                  clk;
    logic                  rst_n;
    logic [DATA_WIDTH-1:0] s_axis_tdata;
    logic                  s_axis_tvalid;
    logic                  s_axis_tready;
    logic                  s_axis_tlast;
    logic [DATA_WIDTH-1:0] m_data;
    logic                  m_last;
    logic                  m_valid;
    logic                  m_ready;
    logic                  fifo_full;
    logic                  fifo_empty;
    logic [ADDR_WIDTH:0]   fifo_count;

    // Clock generator (100 MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // DUT
    axis_input_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast),
        .m_data(m_data),
        .m_last(m_last),
        .m_valid(m_valid),
        .m_ready(m_ready),
        .fifo_full(fifo_full),
        .fifo_empty(fifo_empty),
        .fifo_count(fifo_count)
    );

    // Test sequence
    initial begin
        reset_counters();
        rst_n         = 0;
        s_axis_tdata  = '0;
        s_axis_tvalid = 0;
        s_axis_tlast  = 0;
        m_ready       = 0;
        #20;
        rst_n = 1;
        #10;

        //---------------------------------------------------------------------
        // CORNER TEST 1: Reset during active operation
        //---------------------------------------------------------------------
        @(posedge clk);
        s_axis_tdata = 8'hAA; s_axis_tvalid = 1;
        @(posedge clk);
        rst_n = 0;
        @(posedge clk);
        #1;
        record_result("CORNER", (fifo_empty === 1'b1 && fifo_count === '0), "TC1: Clean reset clears FIFO state");
        rst_n = 1;
        s_axis_tvalid = 0;
        #10;

        //---------------------------------------------------------------------
        // CORNER TEST 2: Read attempt on empty FIFO
        //---------------------------------------------------------------------
        @(posedge clk);
        m_ready = 1;
        @(posedge clk);
        #1;
        record_result("CORNER", (m_valid === 1'b0 && fifo_empty === 1'b1), "TC2: Empty read protected without underflow");
        m_ready = 0;

        //---------------------------------------------------------------------
        // CORNER TEST 3: Fill to capacity & overflow attempt
        //---------------------------------------------------------------------
        for (int i = 0; i < DEPTH; i++) begin
            @(posedge clk);
            s_axis_tdata  = i;
            s_axis_tvalid = 1;
        end
        @(posedge clk);
        #1;
        s_axis_tdata = 8'hFF;
        record_result("CORNER", (fifo_full === 1'b1 && s_axis_tready === 1'b0), "TC3: FIFO full de-asserts tready");
        s_axis_tvalid = 0;

        // Flush FIFO
        m_ready = 1;
        repeat(DEPTH) @(posedge clk);
        m_ready = 0;
        #10;

        //---------------------------------------------------------------------
        // CORNER TEST 4: Simultaneous push and pop at steady state
        //---------------------------------------------------------------------
        @(posedge clk);
        s_axis_tdata = 8'h55; s_axis_tvalid = 1;
        @(posedge clk);
        s_axis_tdata = 8'h66; m_ready = 1;
        @(posedge clk);
        #1;
        record_result("CORNER", (fifo_count === 1'd1), "TC4: Simultaneous push and pop maintains exact count");
        s_axis_tvalid = 0; m_ready = 0;
        @(posedge clk); m_ready = 1; @(posedge clk); m_ready = 0;

        //---------------------------------------------------------------------
        // CORNER TEST 5: Alternating single-cycle push/pop ping-pong
        //---------------------------------------------------------------------
        begin
            bit ping_pong_pass = 1;
            for (int i = 0; i < 5; i++) begin
                @(posedge clk);
                s_axis_tdata = 8'h10 + i; s_axis_tvalid = 1; m_ready = 0;
                @(posedge clk);
                s_axis_tvalid = 0; m_ready = 1;
                #1;
                if (m_data !== (8'h10 + i)) ping_pong_pass = 0;
            end
            record_result("CORNER", ping_pong_pass, "TC5: Single-cycle ping-pong verified");
        end
        m_ready = 0;

        //---------------------------------------------------------------------
        // NORMAL TEST 6: Continuous 8-byte streaming burst
        //---------------------------------------------------------------------
        begin
            bit burst_pass = 1;
            for (int i = 0; i < 8; i++) begin
                @(posedge clk);
                s_axis_tdata = 8'hA0 + i; s_axis_tvalid = 1;
            end
            @(posedge clk); s_axis_tvalid = 0;
            for (int i = 0; i < 8; i++) begin
                @(posedge clk);
                m_ready = 1;
                #1;
                if (m_data !== (8'hA0 + i)) burst_pass = 0;
            end
            @(posedge clk); m_ready = 0;
            record_result("NORMAL", burst_pass, "TC6: Continuous 8-byte burst data integrity confirmed");
        end

        //---------------------------------------------------------------------
        // NORMAL TEST 7: Packet tlast end-of-frame propagation
        //---------------------------------------------------------------------
        @(posedge clk);
        s_axis_tdata = 8'hEE; s_axis_tlast = 1; s_axis_tvalid = 1;
        @(posedge clk);
        s_axis_tvalid = 0; s_axis_tlast = 0;
        @(posedge clk);
        m_ready = 1;
        #1;
        record_result("NORMAL", (m_data === 8'hEE && m_last === 1'b1), "TC7: tlast boundary correctly transferred");
        @(posedge clk); m_ready = 0;

        //---------------------------------------------------------------------
        // ULTIMATE STRESS TEST 8: 200 Randomized Operations vs Golden Queue
        //---------------------------------------------------------------------
        begin
            logic [8:0] golden_q[$];
            bit stress_pass = 1;

            for (int step = 0; step < 200; step++) begin
                bit do_push = $urandom_range(0, 1);
                bit do_pop  = $urandom_range(0, 1);
                logic [7:0] rand_val = $urandom_range(0, 255);
                logic       rand_last = ($urandom_range(0, 10) == 0);

                @(posedge clk);
                s_axis_tvalid = do_push;
                s_axis_tdata  = rand_val;
                s_axis_tlast  = rand_last;
                m_ready       = do_pop;

                #1;
                if (do_push && s_axis_tready) begin
                    golden_q.push_back({rand_last, rand_val});
                end
                if (do_pop && m_valid) begin
                    logic [8:0] exp_val = golden_q.pop_front();
                    if ({m_last, m_data} !== exp_val) begin
                        stress_pass = 0;
                    end
                end
            end
            record_result("STRESS", stress_pass, "TC8: 200 randomized stimulus operations matched golden queue");
        end

        #20;
        print_summary("axis_input_fifo");
        $finish;
    end

endmodule: tb_axis_input_fifo
