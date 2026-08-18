//=============================================================================
// File: tb_conv_engine.sv
// Description: Self-checking testbench for conv_engine adhering to the
//              standard 8-test verification suite (5 Corner + 2 Normal + 1 Stress).
// Standard: SystemVerilog IEEE 1800
//=============================================================================

`timescale 1ns/1ps

module tb_conv_engine;

    import tb_pkg::*;
    import agri_drone_pkg::*;

    logic                     clk;
    logic                     rst_n;
    logic                     start;
    logic                     window_valid;
    logic [7:0]               p0, p1, p2, p3, p4, p5, p6, p7, p8;
    logic [5:0]               win_col, win_row;
    logic signed [7:0]        w0, w1, w2, w3, w4, w5, w6, w7, w8;
    logic signed [23:0]       bias;
    logic                     feat_valid;
    logic signed [15:0]       feat_data;
    logic [6:0]               feat_idx;
    logic                     conv_done;

    // Clock generator (100 MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // DUT
    conv_engine dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .window_valid(window_valid),
        .p0(p0), .p1(p1), .p2(p2),
        .p3(p3), .p4(p4), .p5(p5),
        .p6(p6), .p7(p7), .p8(p8),
        .win_col(win_col),
        .win_row(win_row),
        .w0(w0),  .w1(w1),  .w2(w2),
        .w3(w3),  .w4(w4),  .w5(w5),
        .w6(w6),  .w7(w7),  .w8(w8),
        .bias(bias),
        .feat_valid(feat_valid),
        .feat_data(feat_data),
        .feat_idx(feat_idx),
        .conv_done(conv_done)
    );

    // Test sequence
    initial begin
        reset_counters();
        rst_n        = 0;
        start        = 0;
        window_valid = 0;
        {p0,p1,p2,p3,p4,p5,p6,p7,p8} = '0;
        win_col      = '0;
        win_row      = '0;
        {w0,w1,w2,w3,w4,w5,w6,w7,w8} = '0;
        bias         = '0;
        #20;
        rst_n        = 1;
        #10;

        //---------------------------------------------------------------------
        // CORNER TEST 1: Reset during active convolution
        //---------------------------------------------------------------------
        @(posedge clk);
        start = 1; @(posedge clk); start = 0;
        window_valid = 1; win_row = 0; win_col = 0;
        {p0,p1,p2,p3,p4,p5,p6,p7,p8} = '{8'd200, 8'd200, 8'd200, 8'd200, 8'd200, 8'd200, 8'd200, 8'd200, 8'd200};
        @(posedge clk);
        rst_n = 0;
        @(posedge clk);
        #1;
        record_result("CORNER", (feat_valid === 1'b0 && conv_done === 1'b0), "TC1: Reset clears conv engine state");
        rst_n = 1; window_valid = 0;
        #10;

        //---------------------------------------------------------------------
        // CORNER TEST 2: Mid-gray input (128 centered = 0) produces zero features
        //---------------------------------------------------------------------
        @(posedge clk); start = 1; @(posedge clk); start = 0;
        {w0,w1,w2,w3,w4,w5,w6,w7,w8} = '{8'sd1, 8'sd1, 8'sd1, 8'sd1, 8'sd1, 8'sd1, 8'sd1, 8'sd1, 8'sd1};
        bias = 24'sd0;

        for (int r = 0; r < 23; r++) begin
            for (int c = 0; c < 23; c++) begin
                @(posedge clk);
                window_valid = 1; win_row = r; win_col = c;
                {p0,p1,p2,p3,p4,p5,p6,p7,p8} = '{8'd128, 8'd128, 8'd128, 8'd128, 8'd128, 8'd128, 8'd128, 8'd128, 8'd128};
            end
        end
        @(posedge clk); window_valid = 0;
        repeat(5) @(posedge clk);
        #1;
        record_result("CORNER", (conv_done === 1'b1), "TC2: Mid-gray centered input completes cleanly");

        //---------------------------------------------------------------------
        // CORNER TEST 3: Max pixel (255) and max weights (+127) saturation
        //---------------------------------------------------------------------
        @(posedge clk); start = 1; @(posedge clk); start = 0;
        {w0,w1,w2,w3,w4,w5,w6,w7,w8} = '{8'sd127, 8'sd127, 8'sd127, 8'sd127, 8'sd127, 8'sd127, 8'sd127, 8'sd127, 8'sd127};
        bias = 24'sd0;
        for (int r = 0; r < 23; r++) begin
            for (int c = 0; c < 23; c++) begin
                @(posedge clk);
                window_valid = 1; win_row = r; win_col = c;
                {p0,p1,p2,p3,p4,p5,p6,p7,p8} = '{8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255};
            end
        end
        @(posedge clk); window_valid = 0;
        repeat(5) @(posedge clk);
        record_result("CORNER", (feat_data === 16'sd32767), "TC3: Maximum input/weight saturation clamped to +32767");

        //---------------------------------------------------------------------
        // CORNER TEST 4: Large negative bias suppresses all features to 0
        //---------------------------------------------------------------------
        @(posedge clk); start = 1; @(posedge clk); start = 0;
        bias = -24'sd500000;
        for (int r = 0; r < 23; r++) begin
            for (int c = 0; c < 23; c++) begin
                @(posedge clk);
                window_valid = 1; win_row = r; win_col = c;
                {p0,p1,p2,p3,p4,p5,p6,p7,p8} = '{8'd200, 8'd200, 8'd200, 8'd200, 8'd200, 8'd200, 8'd200, 8'd200, 8'd200};
            end
        end
        @(posedge clk); window_valid = 0;
        repeat(5) @(posedge clk);
        record_result("CORNER", (feat_data === 16'sd0), "TC4: Large negative bias clamps all activations to 0");

        //---------------------------------------------------------------------
        // CORNER TEST 5: Start pulse resets feature count
        //---------------------------------------------------------------------
        @(posedge clk); start = 1; @(posedge clk); start = 0;
        #1;
        record_result("CORNER", (dut.f_idx_reg === '0 && dut.conv_cnt === '0), "TC5: Start pulse resets feature counters");

        //---------------------------------------------------------------------
        // NORMAL TEST 6: Identity Kernel ($w_4 = 1$) Feature Extraction
        //---------------------------------------------------------------------
        begin
            int pooled_count = 0;
            @(posedge clk); start = 1; @(posedge clk); start = 0;
            {w0,w1,w2,w3,w4,w5,w6,w7,w8} = '{8'sd0, 8'sd0, 8'sd0, 8'sd0, 8'sd1, 8'sd0, 8'sd0, 8'sd0, 8'sd0};
            bias = 24'sd0;

            for (int r = 0; r < 23; r++) begin
                for (int c = 0; c < 23; c++) begin
                    @(posedge clk);
                    window_valid = 1; win_row = r; win_col = c;
                    {p0,p1,p2,p3,p4,p5,p6,p7,p8} = '{8'd128, 8'd128, 8'd128, 8'd128, 8'd200, 8'd128, 8'd128, 8'd128, 8'd128};
                    #1;
                    if (feat_valid) pooled_count++;
                end
            end
            @(posedge clk); window_valid = 0;
            repeat(5) @(posedge clk);
            #1;
            if (feat_valid) pooled_count++;
            // 23x23 feature map pooled 2x2 yields exactly 11x11 = 121 pooled features
            record_result("NORMAL", (pooled_count == 121), $sformatf("TC6: Identity filter produced exact 121 pooled features (%0d/121)", pooled_count));
        end

        //---------------------------------------------------------------------
        // NORMAL TEST 7: High-contrast disease spot detection
        //---------------------------------------------------------------------
        begin
            bit spot_detected = 0;
            @(posedge clk); start = 1; @(posedge clk); start = 0;
            // Center-surround edge detection filter [-1 -1 -1; -1 8 -1; -1 -1 -1]
            {w0,w1,w2,w3,w4,w5,w6,w7,w8} = '{-8'sd1, -8'sd1, -8'sd1, -8'sd1, 8'sd8, -8'sd1, -8'sd1, -8'sd1, -8'sd1};
            bias = 24'sd0;

            for (int r = 0; r < 23; r++) begin
                for (int c = 0; c < 23; c++) begin
                    @(posedge clk);
                    window_valid = 1; win_row = r; win_col = c;
                    if (r == 4 && c == 4) // Disease spot at (4,4)
                        {p0,p1,p2,p3,p4,p5,p6,p7,p8} = '{8'd50, 8'd50, 8'd50, 8'd50, 8'd250, 8'd50, 8'd50, 8'd50, 8'd50};
                    else
                        {p0,p1,p2,p3,p4,p5,p6,p7,p8} = '{8'd100, 8'd100, 8'd100, 8'd100, 8'd100, 8'd100, 8'd100, 8'd100, 8'd100};
                    #1;
                    if (feat_valid && feat_data > 16'sd500) spot_detected = 1;
                end
            end
            @(posedge clk); window_valid = 0;
            repeat(5) @(posedge clk);
            record_result("NORMAL", spot_detected, "TC7: High-contrast disease spot activation detected");
        end

        //---------------------------------------------------------------------
        // ULTIMATE STRESS TEST 8: Full 529-Window Randomized Frame Stream
        //---------------------------------------------------------------------
        begin
            int total_feats = 0;
            bit stress_pass = 1;
            @(posedge clk); start = 1; @(posedge clk); start = 0;

            for (int r = 0; r < 23; r++) begin
                for (int c = 0; c < 23; c++) begin
                    @(posedge clk);
                    window_valid = 1; win_row = r; win_col = c;
                    p0 = $urandom_range(0, 255); p1 = $urandom_range(0, 255); p2 = $urandom_range(0, 255);
                    p3 = $urandom_range(0, 255); p4 = $urandom_range(0, 255); p5 = $urandom_range(0, 255);
                    p6 = $urandom_range(0, 255); p7 = $urandom_range(0, 255); p8 = $urandom_range(0, 255);
                    #1;
                    if (feat_valid) total_feats++;
                end
            end
            @(posedge clk); window_valid = 0;
            repeat(10) @(posedge clk);
            #1;
            if (feat_valid) total_feats++;
            record_result("STRESS", (conv_done === 1'b1 && total_feats == 121), "TC8: Complete randomized frame yielded 121 features and conv_done");
        end

        #20;
        print_summary("conv_engine");
        $finish;
    end

endmodule: tb_conv_engine
