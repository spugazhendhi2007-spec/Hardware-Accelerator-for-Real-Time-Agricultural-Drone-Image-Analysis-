//=============================================================================
// File: tb_image_buffer_25x25.sv
// Description: Self-checking testbench for image_buffer_25x25 adhering to the
//              standard 8-test verification suite (5 Corner + 2 Normal + 1 Stress).
// Standard: SystemVerilog IEEE 1800
//=============================================================================

`timescale 1ns/1ps

module tb_image_buffer_25x25;

    import tb_pkg::*;

    localparam int TOTAL_PIXELS = 625;
    localparam int ADDR_WIDTH   = 10;
    localparam int DATA_WIDTH   = 8;

    logic                  clk;
    logic                  rst_n;
    logic                  wr_en;
    logic [ADDR_WIDTH-1:0] wr_addr;
    logic [DATA_WIDTH-1:0] wr_data;
    logic                  rd_en;
    logic [ADDR_WIDTH-1:0] rd_addr;
    logic [DATA_WIDTH-1:0] rd_data;

    // Clock generator (100 MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // DUT
    image_buffer_25x25 #(
        .IMAGE_WIDTH(25),
        .IMAGE_HEIGHT(25)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(wr_en),
        .wr_addr(wr_addr),
        .wr_data(wr_data),
        .rd_en(rd_en),
        .rd_addr(rd_addr),
        .rd_data(rd_data)
    );

    // Test sequence
    initial begin
        reset_counters();
        rst_n   = 0;
        wr_en   = 0;
        wr_addr = '0;
        wr_data = '0;
        rd_en   = 0;
        rd_addr = '0;
        #20;
        rst_n = 1;
        #10;

        //---------------------------------------------------------------------
        // CORNER TEST 1: First address (0) write & read
        //---------------------------------------------------------------------
        @(posedge clk);
        wr_en = 1; wr_addr = 0; wr_data = 8'hA5;
        @(posedge clk);
        wr_en = 0; rd_en = 1; rd_addr = 0;
        @(posedge clk);
        #1;
        record_result("CORNER", (rd_data === 8'hA5), "TC1: Address 0 first pixel write/read verified");
        rd_en = 0;

        //---------------------------------------------------------------------
        // CORNER TEST 2: Boundary address 624 (last pixel) write & read
        //---------------------------------------------------------------------
        @(posedge clk);
        wr_en = 1; wr_addr = 624; wr_data = 8'h5A;
        @(posedge clk);
        wr_en = 0; rd_en = 1; rd_addr = 624;
        @(posedge clk);
        #1;
        record_result("CORNER", (rd_data === 8'h5A), "TC2: Address 624 perimeter pixel write/read verified");
        rd_en = 0;

        //---------------------------------------------------------------------
        // CORNER TEST 3: Out-of-bounds write attempt (>624)
        //---------------------------------------------------------------------
        @(posedge clk);
        wr_en = 1; wr_addr = 700; wr_data = 8'hFF;
        @(posedge clk);
        wr_en = 0; rd_en = 1; rd_addr = 624;
        @(posedge clk);
        #1;
        record_result("CORNER", (rd_data === 8'h5A), "TC3: Out-of-bounds write ignored safely");
        rd_en = 0;

        //---------------------------------------------------------------------
        // CORNER TEST 4: Simultaneous write and read at different addresses
        //---------------------------------------------------------------------
        @(posedge clk);
        wr_en = 1; wr_addr = 100; wr_data = 8'h33;
        rd_en = 1; rd_addr = 0;
        @(posedge clk);
        #1;
        record_result("CORNER", (rd_data === 8'hA5), "TC4: Dual-port simultaneous write/read matched");
        wr_en = 0; rd_en = 0;

        //---------------------------------------------------------------------
        // CORNER TEST 5: Back-to-back overwrite of same address
        //---------------------------------------------------------------------
        @(posedge clk);
        wr_en = 1; wr_addr = 50; wr_data = 8'h11;
        @(posedge clk);
        wr_en = 1; wr_addr = 50; wr_data = 8'h22;
        @(posedge clk);
        wr_en = 0; rd_en = 1; rd_addr = 50;
        @(posedge clk);
        #1;
        record_result("CORNER", (rd_data === 8'h22), "TC5: Overwrite updated correctly");
        rd_en = 0;

        //---------------------------------------------------------------------
        // NORMAL TEST 6: Complete 625-pixel sequential frame load and verify
        //---------------------------------------------------------------------
        begin
            bit full_frame_pass = 1;
            for (int i = 0; i < TOTAL_PIXELS; i++) begin
                @(posedge clk);
                wr_en = 1; wr_addr = i; wr_data = i[7:0];
            end
            @(posedge clk); wr_en = 0;

            for (int i = 0; i < TOTAL_PIXELS; i++) begin
                @(posedge clk);
                rd_en = 1; rd_addr = i;
                @(posedge clk);
                #1;
                if (rd_data !== i[7:0]) full_frame_pass = 0;
            end
            rd_en = 0;
            record_result("NORMAL", full_frame_pass, "TC6: Full 625-pixel sequential frame storage verified");
        end

        //---------------------------------------------------------------------
        // NORMAL TEST 7: 2D Spatial stride read pattern (row-by-row traversal)
        //---------------------------------------------------------------------
        begin
            bit stride_pass = 1;
            for (int r = 0; r < 25; r++) begin
                for (int c = 0; c < 25; c++) begin
                    int addr = r * 25 + c;
                    @(posedge clk);
                    rd_en = 1; rd_addr = addr;
                    @(posedge clk);
                    #1;
                    if (rd_data !== addr[7:0]) stride_pass = 0;
                end
            end
            rd_en = 0;
            record_result("NORMAL", stride_pass, "TC7: 2D stride matrix reading verified");
        end

        //---------------------------------------------------------------------
        // ULTIMATE STRESS TEST 8: 500 Randomized writes/reads vs Shadow Memory
        //---------------------------------------------------------------------
        begin
            logic [7:0] shadow_mem [TOTAL_PIXELS-1:0];
            bit stress_pass = 1;

            // Initialize shadow memory with current contents
            for (int i = 0; i < TOTAL_PIXELS; i++) shadow_mem[i] = i[7:0];

            for (int s = 0; s < 500; s++) begin
                int rand_wr_addr = $urandom_range(0, TOTAL_PIXELS-1);
                logic [7:0] rand_val = $urandom_range(0, 255);
                int rand_rd_addr = $urandom_range(0, TOTAL_PIXELS-1);
                bit do_wr = $urandom_range(0, 1);
                bit do_rd = $urandom_range(0, 1);

                @(posedge clk);
                wr_en   = do_wr;
                wr_addr = rand_wr_addr;
                wr_data = rand_val;
                rd_en   = do_rd;
                rd_addr = rand_rd_addr;

                if (do_wr) shadow_mem[rand_wr_addr] = rand_val;

                @(posedge clk);
                #1;
                if (do_rd && (rd_data !== shadow_mem[rand_rd_addr])) begin
                    stress_pass = 0;
                end
            end
            wr_en = 0; rd_en = 0;
            record_result("STRESS", stress_pass, "TC8: 500 randomized operations matched shadow memory");
        end

        #20;
        print_summary("image_buffer_25x25");
        $finish;
    end

endmodule: tb_image_buffer_25x25
