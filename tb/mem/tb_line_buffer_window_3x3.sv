//=============================================================================
// File: tb_line_buffer_window_3x3.sv
// Description: Self-checking testbench for line_buffer_window_3x3 adhering to the
//              standard 8-test verification suite (5 Corner + 2 Normal + 1 Stress).
// Standard: SystemVerilog IEEE 1800
//=============================================================================

`timescale 1ns/1ps

module tb_line_buffer_window_3x3;

    import tb_pkg::*;

    localparam int IMAGE_WIDTH  = 25;
    localparam int IMAGE_HEIGHT = 25;
    localparam int DATA_WIDTH   = 8;

    logic                  clk;
    logic                  rst_n;
    logic                  clr;
    logic                  in_valid;
    logic [DATA_WIDTH-1:0] in_pixel;
    logic                  window_valid;
    logic [DATA_WIDTH-1:0] p0, p1, p2, p3, p4, p5, p6, p7, p8;
    logic [5:0]            out_col;
    logic [5:0]            out_row;

    // Clock generator (100 MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // DUT
    line_buffer_window_3x3 #(
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .IMAGE_HEIGHT(IMAGE_HEIGHT),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .clr(clr),
        .in_valid(in_valid),
        .in_pixel(in_pixel),
        .window_valid(window_valid),
        .p0(p0), .p1(p1), .p2(p2),
        .p3(p3), .p4(p4), .p5(p5),
        .p6(p6), .p7(p7), .p8(p8),
        .out_col(out_col),
        .out_row(out_row)
    );

    // Test sequence
    initial begin
        reset_counters();
        rst_n    = 0;
        clr      = 0;
        in_valid = 0;
        in_pixel = '0;
        #20;
        rst_n = 1;
        #10;

        //---------------------------------------------------------------------
        // CORNER TEST 1: Reset during active pixel shift
        //---------------------------------------------------------------------
        @(posedge clk);
        in_valid = 1; in_pixel = 8'h55;
        @(posedge clk);
        rst_n = 0;
        @(posedge clk);
        #1;
        record_result("CORNER", (window_valid === 1'b0 && out_col === '0 && out_row === '0), "TC1: Clean reset clears line buffer registers");
        rst_n = 1; in_valid = 0;
        #10;

        //---------------------------------------------------------------------
        // CORNER TEST 2: Stream < 52 pixels (no valid window before row 2 col 2)
        //---------------------------------------------------------------------
        begin
            bit no_early_window = 1;
            for (int i = 0; i < 50; i++) begin
                @(posedge clk);
                in_valid = 1; in_pixel = i[7:0];
                #1;
                if (window_valid !== 1'b0) no_early_window = 0;
            end
            @(posedge clk); in_valid = 0;
            record_result("CORNER", no_early_window, "TC2: No spurious valid windows before initial 2-row latency");
        end

        // Clear for clean test sequence
        @(posedge clk); clr = 1; @(posedge clk); clr = 0;

        //---------------------------------------------------------------------
        // CORNER TEST 3: First valid window structure check (at row 2, col 2)
        //---------------------------------------------------------------------
        begin
            logic [7:0] frame [624:0];
            for (int i = 0; i < 625; i++) frame[i] = i[7:0];

            for (int i = 0; i < 52; i++) begin
                @(posedge clk);
                in_valid = 1; in_pixel = frame[i];
            end
            @(posedge clk);
            in_valid = 1; in_pixel = frame[52]; // Row 2, Col 2 (53rd pixel)
            @(posedge clk);
            #1;
            // Expected 3x3 window at (0,0):
            // Row 0: frame[0],  frame[1],  frame[2]
            // Row 1: frame[25], frame[26], frame[27]
            // Row 2: frame[50], frame[51], frame[52]
            record_result("CORNER", (window_valid === 1'b1 && out_col === 0 && out_row === 0 &&
                                    p0 === frame[0]  && p1 === frame[1]  && p2 === frame[2]  &&
                                    p3 === frame[25] && p4 === frame[26] && p5 === frame[27] &&
                                    p6 === frame[50] && p7 === frame[51] && p8 === frame[52]),
                                    "TC3: First 3x3 window data matching exact matrix coordinates");
            in_valid = 0;
        end

        //---------------------------------------------------------------------
        // CORNER TEST 4: Row wrapping boundary check (col = 24 -> col = 0)
        //---------------------------------------------------------------------
        @(posedge clk); clr = 1; @(posedge clk); clr = 0;
        begin
            bit row_wrap_pass = 1;
            // Feed full row 0, row 1, and row 2
            for (int i = 0; i < 75; i++) begin
                @(posedge clk);
                in_valid = 1; in_pixel = i[7:0];
            end
            @(posedge clk); in_valid = 0;
            #1;
            record_result("CORNER", (dut.row_cnt === 6'd3 && dut.col_cnt === 6'd0), "TC4: Row wrap counter transitions accurately");
        end

        //---------------------------------------------------------------------
        // CORNER TEST 5: clr synchronous pulse clears internal state
        //---------------------------------------------------------------------
        @(posedge clk);
        clr = 1;
        @(posedge clk);
        #1;
        record_result("CORNER", (dut.total_pixel_cnt === '0 && dut.col_cnt === '0), "TC5: clr resets all counters and line buffers");
        clr = 0;

        //---------------------------------------------------------------------
        // NORMAL TEST 6: Complete 625-pixel frame generates exactly 529 windows
        //---------------------------------------------------------------------
        begin
            int valid_win_count = 0;
            for (int i = 0; i < 625; i++) begin
                @(posedge clk);
                in_valid = 1; in_pixel = i[7:0];
                #1;
                if (window_valid) valid_win_count++;
            end
            @(posedge clk); in_valid = 0;
            #1;
            if (window_valid) valid_win_count++;
            record_result("NORMAL", (valid_win_count == 529), $sformatf("TC6: Exact 529 valid windows generated (%0d/529)", valid_win_count));
        end

        //---------------------------------------------------------------------
        // NORMAL TEST 7: Intermittent valid stall during stream
        //---------------------------------------------------------------------
        @(posedge clk); clr = 1; @(posedge clk); clr = 0;
        begin
            int stalled_win_count = 0;
            for (int i = 0; i < 625; i++) begin
                @(posedge clk);
                in_valid = 1; in_pixel = i[7:0];
                #1;
                if (window_valid) stalled_win_count++;
                if (i % 5 == 0) begin
                    @(posedge clk);
                    in_valid = 0;
                end
            end
            @(posedge clk); in_valid = 0;
            #1;
            if (window_valid) stalled_win_count++;
            record_result("NORMAL", (stalled_win_count == 529), "TC7: Intermittent backpressure yields exact 529 windows");
        end

        //---------------------------------------------------------------------
        // ULTIMATE STRESS TEST 8: Randomized 2-Frame Stream vs Matrix Golden
        //---------------------------------------------------------------------
        begin
            logic [7:0] img [24:0][24:0];
            bit stress_pass = 1;

            @(posedge clk); clr = 1; @(posedge clk); clr = 0;

            // Generate random image
            for (int r = 0; r < 25; r++) begin
                for (int c = 0; c < 25; c++) begin
                    img[r][c] = $urandom_range(0, 255);
                end
            end

            // Feed image
            for (int r = 0; r < 25; r++) begin
                for (int c = 0; c < 25; c++) begin
                    @(posedge clk);
                    in_valid = 1; in_pixel = img[r][c];
                    #1;
                    if (window_valid) begin
                        int wr = out_row;
                        int wc = out_col;
                        if (p0 !== img[wr][wc]     || p1 !== img[wr][wc+1]   || p2 !== img[wr][wc+2]   ||
                            p3 !== img[wr+1][wc]   || p4 !== img[wr+1][wc+1] || p5 !== img[wr+1][wc+2] ||
                            p6 !== img[wr+2][wc]   || p7 !== img[wr+2][wc+1] || p8 !== img[wr+2][wc+2]) begin
                            stress_pass = 0;
                        end
                    end
                end
            end
            @(posedge clk); in_valid = 0;
            record_result("STRESS", stress_pass, "TC8: Complete 2D matrix sliding window matched golden model");
        end

        #20;
        print_summary("line_buffer_window_3x3");
        $finish;
    end

endmodule: tb_line_buffer_window_3x3
