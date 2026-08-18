//=============================================================================
// File: tb_agri_drone_csr.sv
// Description: Self-checking testbench for agri_drone_csr adhering to the
//              standard 8-test verification suite (5 Corner + 2 Normal + 1 Stress).
// Standard: SystemVerilog IEEE 1800 (Clean 0-warning compilation)
//=============================================================================

`timescale 1ns/1ps

module tb_agri_drone_csr;

    import tb_pkg::*;

    logic                     clk;
    logic                     rst_n;
    logic                     csr_wr_en;
    logic                     csr_rd_en;
    logic [5:0]               csr_addr;
    logic [31:0]              csr_wdata;
    logic [31:0]              csr_rdata;

    logic                     hw_busy;
    logic                     hw_done;
    logic [1:0]               hw_class;
    logic                     hw_disease_detected;
    logic [15:0]              hw_confidence;

    logic                     ctrl_start;
    logic                     ctrl_soft_rst;
    logic                     ctrl_clk_gate_en;
    logic signed [23:0]       conv_bias;
    logic signed [7:0]        conv_w0, conv_w1, conv_w2;
    logic signed [7:0]        conv_w3, conv_w4, conv_w5;
    logic signed [7:0]        conv_w6, conv_w7, conv_w8;
    logic signed [23:0]       dense_bias0, dense_bias1, dense_bias2, dense_bias3;

    // Clock generator (100 MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // DUT
    agri_drone_csr dut (
        .clk(clk),
        .rst_n(rst_n),
        .csr_wr_en(csr_wr_en),
        .csr_rd_en(csr_rd_en),
        .csr_addr(csr_addr),
        .csr_wdata(csr_wdata),
        .csr_rdata(csr_rdata),
        .hw_busy(hw_busy),
        .hw_done(hw_done),
        .hw_class(hw_class),
        .hw_disease_detected(hw_disease_detected),
        .hw_confidence(hw_confidence),
        .ctrl_start(ctrl_start),
        .ctrl_soft_rst(ctrl_soft_rst),
        .ctrl_clk_gate_en(ctrl_clk_gate_en),
        .conv_bias(conv_bias),
        .conv_w0(conv_w0), .conv_w1(conv_w1), .conv_w2(conv_w2),
        .conv_w3(conv_w3), .conv_w4(conv_w4), .conv_w5(conv_w5),
        .conv_w6(conv_w6), .conv_w7(conv_w7), .conv_w8(conv_w8),
        .dense_bias0(dense_bias0), .dense_bias1(dense_bias1),
        .dense_bias2(dense_bias2), .dense_bias3(dense_bias3)
    );

    // Test sequence
    initial begin : test_seq
        automatic bit stress_pass = 1;

        reset_counters();
        rst_n               = 0;
        csr_wr_en           = 0;
        csr_rd_en           = 0;
        csr_addr            = '0;
        csr_wdata           = '0;
        hw_busy             = 0;
        hw_done             = 0;
        hw_class            = '0;
        hw_disease_detected = 0;
        hw_confidence       = '0;
        #20;
        rst_n               = 1;
        #10;

        //---------------------------------------------------------------------
        // CORNER TEST 1: Default Reset Values Verification
        //---------------------------------------------------------------------
        csr_addr = 6'h00; #1;
        record_result("CORNER", (csr_rdata === 32'h00000008 && conv_w4 === 8'sd8), "TC1: Default reset registers verified");

        //---------------------------------------------------------------------
        // CORNER TEST 2: Invalid Address Read (0x3C -> 0xDEADBEEF)
        //---------------------------------------------------------------------
        csr_addr = 6'h3C; #1;
        record_result("CORNER", (csr_rdata === 32'hDEADBEEF), "TC2: Unmapped address returns 0xDEADBEEF");

        //---------------------------------------------------------------------
        // CORNER TEST 3: Auto-clearing start pulse in bit 0
        //---------------------------------------------------------------------
        @(negedge clk);
        csr_wr_en = 1; csr_addr = 6'h00; csr_wdata = 32'h00000001;
        @(posedge clk);
        #1;
        record_result("CORNER", (ctrl_start === 1'b1), "TC3: Start bit generated 1-cycle pulse");
        @(negedge clk);
        csr_wr_en = 0;
        @(posedge clk);
        #1;
        record_result("CORNER", (ctrl_start === 1'b0), "TC3b: Start bit auto-cleared cleanly");

        //---------------------------------------------------------------------
        // CORNER TEST 4: Read-Only Status & Result Register Protection
        //---------------------------------------------------------------------
        @(negedge clk);
        hw_busy = 1; hw_done = 1; hw_disease_detected = 1;
        csr_wr_en = 1; csr_addr = 6'h04; csr_wdata = 32'h00000000; // Attempt write to RO
        @(posedge clk);
        #1;
        record_result("CORNER", (csr_rdata === 32'h00000007), "TC4: Write to STATUS_REG ignored (Read-Only)");
        @(negedge clk);
        csr_wr_en = 0;

        //---------------------------------------------------------------------
        // CORNER TEST 5: Reset clears modified configuration registers
        //---------------------------------------------------------------------
        @(negedge clk);
        csr_wr_en = 1; csr_addr = 6'h0C; csr_wdata = 32'h00123456;
        @(posedge clk);
        #1;
        rst_n = 0;
        @(posedge clk);
        #1;
        record_result("CORNER", (conv_bias === 24'sd0), "TC5: Hard reset restores default bias");
        @(negedge clk);
        rst_n = 1; csr_wr_en = 0;

        //---------------------------------------------------------------------
        // NORMAL TEST 6: Kernel Weights Programming and Read-Back
        //---------------------------------------------------------------------
        @(negedge clk);
        csr_wr_en = 1; csr_addr = 6'h10; csr_wdata = 32'h04030201; // w0=1, w1=2, w2=3, w3=4
        @(posedge clk);
        @(negedge clk);
        csr_wr_en = 1; csr_addr = 6'h14; csr_wdata = 32'h08070605; // w4=5, w5=6, w6=7, w7=8
        @(posedge clk);
        @(negedge clk);
        csr_wr_en = 1; csr_addr = 6'h18; csr_wdata = 32'h00000009; // w8=9
        @(posedge clk);
        @(negedge clk);
        csr_wr_en = 0;
        #1;
        record_result("NORMAL", (conv_w0 === 8'sd1 && conv_w1 === 8'sd2 && conv_w2 === 8'sd3 &&
                                conv_w3 === 8'sd4 && conv_w4 === 8'sd5 && conv_w5 === 8'sd6 &&
                                conv_w6 === 8'sd7 && conv_w7 === 8'sd8 && conv_w8 === 8'sd9),
                                "TC6: Packed kernel weights programmed and verified");

        //---------------------------------------------------------------------
        // NORMAL TEST 7: Dense Bias Vector Programming & Status Read-Back
        //---------------------------------------------------------------------
        @(negedge clk);
        csr_wr_en = 1; csr_addr = 6'h1C; csr_wdata = 32'sd100;
        @(posedge clk);
        @(negedge clk);
        csr_wr_en = 1; csr_addr = 6'h20; csr_wdata = -32'sd200;
        @(posedge clk);
        @(negedge clk);
        csr_wr_en = 0;
        #1;
        record_result("NORMAL", (dense_bias0 === 24'sd100 && dense_bias1 === -24'sd200), "TC7: Signed dense bias registers programmed correctly");

        //---------------------------------------------------------------------
        // ULTIMATE STRESS TEST 8: 300 Randomized CSR Writes and Verified Read-Backs
        //---------------------------------------------------------------------
        stress_pass = 1;
        for (int s = 0; s < 300; s++) begin
            automatic logic [5:0] rand_a = ($urandom_range(3, 10)) * 4; // 0x0C, 0x10, 0x14, 0x18, 0x1C, 0x20, 0x24, 0x28
            automatic logic [31:0] rand_d = $urandom();
            automatic logic [31:0] exp_rdata;

            case (rand_a)
                6'h0C:                   exp_rdata = {{8{rand_d[23]}}, rand_d[23:0]};
                6'h10:                   exp_rdata = rand_d;
                6'h14:                   exp_rdata = rand_d;
                6'h18:                   exp_rdata = {24'h0, rand_d[7:0]};
                6'h1C, 6'h20, 6'h24, 6'h28: exp_rdata = {{8{rand_d[23]}}, rand_d[23:0]};
                default:                 exp_rdata = rand_d;
            endcase

            @(negedge clk);
            csr_wr_en = 1; csr_addr = rand_a; csr_wdata = rand_d;
            @(posedge clk);
            @(negedge clk);
            csr_wr_en = 0;
            #1;
            if (csr_rdata !== exp_rdata) stress_pass = 0;
        end
        record_result("STRESS", stress_pass, "TC8: 300 randomized CSR writes/reads matched exact bitfields");

        #20;
        print_summary("agri_drone_csr");
        $finish;
    end : test_seq

endmodule: tb_agri_drone_csr
