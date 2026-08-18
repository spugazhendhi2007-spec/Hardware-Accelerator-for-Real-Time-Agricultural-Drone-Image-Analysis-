//=============================================================================
// File: tb_agri_drone_csr.sv
// Description: Self-checking testbench for agri_drone_csr adhering to the
//              standard 8-test verification suite (5 Corner + 2 Normal + 1 Stress).
// Standard: SystemVerilog IEEE 1800
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
    initial begin
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
        @(posedge clk);
        csr_wr_en = 1; csr_addr = 6'h00; csr_wdata = 32'h00000009; // start=1, clk_gate=1
        @(posedge clk);
        #1;
        record_result("CORNER", (ctrl_start === 1'b1), "TC3: Start pulse asserted on cycle 1");
        @(posedge clk);
        csr_wr_en = 0;
        #1;
        record_result("CORNER", (ctrl_start === 1'b0), "TC3b: Start pulse auto-cleared on cycle 2");

        //---------------------------------------------------------------------
        // CORNER TEST 4: Read-Only Status Register (Write to 0x04 ignored)
        //---------------------------------------------------------------------
        hw_busy = 1; hw_disease_detected = 1;
        @(posedge clk);
        csr_wr_en = 1; csr_addr = 6'h04; csr_wdata = 32'hFFFFFFFF;
        @(posedge clk);
        csr_wr_en = 0; csr_addr = 6'h04;
        #1;
        record_result("CORNER", (csr_rdata === 32'h00000005), "TC4: Write to RO status register ignored");

        //---------------------------------------------------------------------
        // CORNER TEST 5: Soft reset control bit
        //---------------------------------------------------------------------
        @(posedge clk);
        csr_wr_en = 1; csr_addr = 6'h00; csr_wdata = 32'h00000002;
        @(posedge clk);
        csr_wr_en = 0;
        #1;
        record_result("CORNER", (ctrl_soft_rst === 1'b1), "TC5: Soft reset bit set and read cleanly");

        //---------------------------------------------------------------------
        // NORMAL TEST 6: Kernel Weights & Biases Programming
        //---------------------------------------------------------------------
        @(posedge clk);
        csr_wr_en = 1; csr_addr = 6'h10; csr_wdata = {8'sd4, 8'sd3, 8'sd2, 8'sd1};
        @(posedge clk);
        csr_wr_en = 1; csr_addr = 6'h0C; csr_wdata = 32'sd12345;
        @(posedge clk);
        csr_wr_en = 0; csr_addr = 6'h10;
        #1;
        record_result("NORMAL", (conv_w0 === 8'sd1 && conv_w1 === 8'sd2 && conv_w2 === 8'sd3 && conv_w3 === 8'sd4 && conv_bias === 24'sd12345),
                      "TC6: Packed 32-bit weight & bias programming verified");

        //---------------------------------------------------------------------
        // NORMAL TEST 7: Hardware Result Reflection (0x08)
        //---------------------------------------------------------------------
        hw_class = 2'b10; hw_confidence = 16'h00FE;
        csr_addr = 6'h08;
        #1;
        record_result("NORMAL", (csr_rdata === 32'h00FE0002), "TC7: Hardware class and confidence reflection matched");

        //---------------------------------------------------------------------
        // ULTIMATE STRESS TEST 8: 300 Randomized CSR Writes & Reads
        //---------------------------------------------------------------------
        begin
            bit stress_pass = 1;
            logic [31:0] shadow_dbias0, shadow_dbias1, shadow_dbias2, shadow_dbias3;

            for (int s = 0; s < 300; s++) begin
                logic [31:0] rand_val = $urandom();
                logic [5:0]  rand_reg = (s % 4 == 0) ? 6'h1C :
                                        (s % 4 == 1) ? 6'h20 :
                                        (s % 4 == 2) ? 6'h24 : 6'h28;

                @(posedge clk);
                csr_wr_en = 1; csr_addr = rand_reg; csr_wdata = rand_val;
                if (rand_reg == 6'h1C) shadow_dbias0 = {{8{rand_val[23]}}, rand_val[23:0]};
                if (rand_reg == 6'h20) shadow_dbias1 = {{8{rand_val[23]}}, rand_val[23:0]};
                if (rand_reg == 6'h24) shadow_dbias2 = {{8{rand_val[23]}}, rand_val[23:0]};
                if (rand_reg == 6'h28) shadow_dbias3 = {{8{rand_val[23]}}, rand_val[23:0]};

                @(posedge clk);
                csr_wr_en = 0; csr_addr = rand_reg;
                #1;
                if (rand_reg == 6'h1C && csr_rdata !== shadow_dbias0) stress_pass = 0;
                if (rand_reg == 6'h20 && csr_rdata !== shadow_dbias1) stress_pass = 0;
                if (rand_reg == 6'h24 && csr_rdata !== shadow_dbias2) stress_pass = 0;
                if (rand_reg == 6'h28 && csr_rdata !== shadow_dbias3) stress_pass = 0;
            end
            record_result("STRESS", stress_pass, "TC8: 300 randomized CSR accesses matched shadow state");
        end

        #20;
        print_summary("agri_drone_csr");
        $finish;
    end

endmodule: tb_agri_drone_csr
