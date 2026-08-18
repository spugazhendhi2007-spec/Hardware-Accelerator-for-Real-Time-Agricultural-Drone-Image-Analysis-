//=============================================================================
// File: tb_agri_fsm_controller.sv
// Description: Self-checking testbench for agri_fsm_controller adhering to the
//              standard 8-test verification suite (5 Corner + 2 Normal + 1 Stress).
// Standard: SystemVerilog IEEE 1800
//=============================================================================

`timescale 1ns/1ps

module tb_agri_fsm_controller;

    import tb_pkg::*;
    import agri_drone_pkg::*;

    logic       clk;
    logic       rst_n;
    logic       start_pulse;
    logic       soft_rst;
    logic       fifo_empty;
    logic       fifo_m_valid;
    logic       conv_engine_done;
    logic       classifier_done;
    logic       argmax_done;

    logic       fifo_pop_en;
    logic       img_buf_wr_en;
    logic [9:0] img_buf_wr_addr;
    logic       line_buf_clr;
    logic       conv_start;
    logic       cls_start;
    logic       argmax_en;

    logic       gclk_load_en;
    logic       gclk_conv_en;
    logic       gclk_cls_en;

    logic       busy;
    logic       done;
    logic [2:0] current_state;

    // Clock generator (100 MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // DUT
    agri_fsm_controller #(
        .TOTAL_PIXELS(625),
        .NUM_FEATURES(121)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start_pulse(start_pulse),
        .soft_rst(soft_rst),
        .fifo_empty(fifo_empty),
        .fifo_m_valid(fifo_m_valid),
        .conv_engine_done(conv_engine_done),
        .classifier_done(classifier_done),
        .argmax_done(argmax_done),
        .fifo_pop_en(fifo_pop_en),
        .img_buf_wr_en(img_buf_wr_en),
        .img_buf_wr_addr(img_buf_wr_addr),
        .line_buf_clr(line_buf_clr),
        .conv_start(conv_start),
        .cls_start(cls_start),
        .argmax_en(argmax_en),
        .gclk_load_en(gclk_load_en),
        .gclk_conv_en(gclk_conv_en),
        .gclk_cls_en(gclk_cls_en),
        .busy(busy),
        .done(done),
        .current_state(current_state)
    );

    // Test sequence
    initial begin
        reset_counters();
        rst_n            = 0;
        start_pulse      = 0;
        soft_rst         = 0;
        fifo_empty       = 1;
        fifo_m_valid     = 0;
        conv_engine_done = 0;
        classifier_done  = 0;
        argmax_done      = 0;
        #20;
        rst_n            = 1;
        #10;

        //---------------------------------------------------------------------
        // CORNER TEST 1: Initial IDLE state verified
        //---------------------------------------------------------------------
        #1;
        record_result("CORNER", (current_state === 3'd0 && busy === 1'b0), "TC1: Initial state is IDLE and not busy");

        //---------------------------------------------------------------------
        // CORNER TEST 2: Reset during LOAD_STREAM state
        //---------------------------------------------------------------------
        @(posedge clk);
        start_pulse = 1;
        @(posedge clk);
        start_pulse = 0;
        @(posedge clk);
        #1;
        if (current_state === 3'd1) begin
            rst_n = 0;
            @(posedge clk);
            #1;
            record_result("CORNER", (current_state === 3'd0), "TC2: Hard reset returns FSM from LOAD to IDLE");
            rst_n = 1;
        end else begin
            record_result("CORNER", 0, "TC2: Failed transition to LOAD state");
        end

        //---------------------------------------------------------------------
        // CORNER TEST 3: Soft reset during CLASSIFY state
        //---------------------------------------------------------------------
        @(posedge clk);
        start_pulse = 1;
        @(posedge clk);
        start_pulse = 0;
        // Fast-forward to CLASSIFY
        fifo_m_valid = 1;
        repeat(625) @(posedge clk);
        fifo_m_valid = 0;
        conv_engine_done = 1;
        @(posedge clk);
        conv_engine_done = 0;
        @(posedge clk);
        #1;
        soft_rst = 1;
        @(posedge clk);
        soft_rst = 0;
        #1;
        record_result("CORNER", (current_state === 3'd0), "TC3: Soft reset aborts execution to IDLE");

        //---------------------------------------------------------------------
        // CORNER TEST 4: FIFO empty stalls in LOAD_STREAM
        //---------------------------------------------------------------------
        @(posedge clk);
        start_pulse = 1;
        @(posedge clk);
        start_pulse = 0;
        fifo_m_valid = 0; // Stalled
        repeat(5) @(posedge clk);
        #1;
        record_result("CORNER", (img_buf_wr_addr === '0 && fifo_pop_en === 1'b0), "TC4: FIFO empty stalls stream loading");

        //---------------------------------------------------------------------
        // CORNER TEST 5: Single cycle DONE pulse check
        //---------------------------------------------------------------------
        fifo_m_valid = 1;
        repeat(625) @(posedge clk);
        fifo_m_valid = 0;
        conv_engine_done = 1; @(posedge clk); conv_engine_done = 0;
        classifier_done = 1;  @(posedge clk); classifier_done = 0;
        argmax_done = 1;      @(posedge clk); argmax_done = 0;
        @(posedge clk);
        #1;
        record_result("CORNER", (done === 1'b1), "TC5: Done pulse asserted on frame finish");
        @(posedge clk);
        #1;
        record_result("CORNER", (done === 1'b0 && current_state === 3'd0), "TC5b: Done pulse auto-cleared after 1 cycle");

        //---------------------------------------------------------------------
        // NORMAL TEST 6: Complete Standard Single-Frame Sequence
        //---------------------------------------------------------------------
        begin
            bit normal_pass = 1;
            @(posedge clk); start_pulse = 1;
            @(posedge clk); start_pulse = 0;
            if (current_state !== 3'd1) normal_pass = 0;

            fifo_m_valid = 1;
            repeat(625) @(posedge clk);
            fifo_m_valid = 0;
            if (current_state !== 3'd2) normal_pass = 0;

            conv_engine_done = 1; @(posedge clk); conv_engine_done = 0;
            if (current_state !== 3'd3) normal_pass = 0;

            classifier_done = 1;  @(posedge clk); classifier_done = 0;
            if (current_state !== 3'd4) normal_pass = 0;

            argmax_done = 1;      @(posedge clk); argmax_done = 0;
            @(posedge clk);
            if (done !== 1'b1) normal_pass = 0;
            @(posedge clk);
            if (current_state !== 3'd0) normal_pass = 0;

            record_result("NORMAL", normal_pass, "TC6: Full 6-state pipeline sequence executed cleanly");
        end

        //---------------------------------------------------------------------
        // NORMAL TEST 7: Consecutive Back-to-Back 2-Frame Pipeline
        //---------------------------------------------------------------------
        begin
            bit b2b_pass = 1;
            for (int f = 0; f < 2; f++) begin
                @(posedge clk); start_pulse = 1; @(posedge clk); start_pulse = 0;
                fifo_m_valid = 1;
                repeat(625) @(posedge clk);
                fifo_m_valid = 0;
                conv_engine_done = 1; @(posedge clk); conv_engine_done = 0;
                classifier_done = 1;  @(posedge clk); classifier_done = 0;
                argmax_done = 1;      @(posedge clk); argmax_done = 0;
                @(posedge clk);
                if (done !== 1'b1) b2b_pass = 0;
                @(posedge clk);
            end
            record_result("NORMAL", b2b_pass, "TC7: Back-to-back 2-frame execution completed");
        end

        //---------------------------------------------------------------------
        // ULTIMATE STRESS TEST 8: 10 Full Inference Cycles with Random Delays
        //---------------------------------------------------------------------
        begin
            bit stress_pass = 1;
            for (int c = 0; c < 10; c++) begin
                @(posedge clk); start_pulse = 1; @(posedge clk); start_pulse = 0;

                // Stream pixels with random stalls
                for (int p = 0; p < 625; p++) begin
                    @(posedge clk);
                    fifo_m_valid = 1;
                    if ($urandom_range(0, 5) == 0) begin
                        @(posedge clk); fifo_m_valid = 0;
                    end
                end
                @(posedge clk); fifo_m_valid = 0;

                // Random delay in conv
                repeat($urandom_range(1, 5)) @(posedge clk);
                conv_engine_done = 1; @(posedge clk); conv_engine_done = 0;

                // Random delay in cls
                repeat($urandom_range(1, 5)) @(posedge clk);
                classifier_done = 1; @(posedge clk); classifier_done = 0;

                // Random delay in argmax
                repeat($urandom_range(1, 3)) @(posedge clk);
                argmax_done = 1; @(posedge clk); argmax_done = 0;

                @(posedge clk);
                if (done !== 1'b1) stress_pass = 0;
                @(posedge clk);
            end
            record_result("STRESS", stress_pass, "TC8: 10 randomized inference cycles executed without deadlock");
        end

        #20;
        print_summary("agri_fsm_controller");
        $finish;
    end

endmodule: tb_agri_fsm_controller
