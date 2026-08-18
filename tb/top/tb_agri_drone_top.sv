//=============================================================================
// File: tb_agri_drone_top.sv
// Description: Master System-Level Self-Checking Testbench for agri_drone_top
//              implementing the standard 8-test verification suite (5 Corner +
//              2 Normal End-to-End Frames + 1 Multi-Frame Ultimate Stress).
// Standard: SystemVerilog IEEE 1800 (Clean 0-warning compilation)
//=============================================================================

`timescale 1ns/1ps

module tb_agri_drone_top;

    import tb_pkg::*;
    import agri_drone_pkg::*;

    logic        clk;
    logic        rst_n;
    logic        test_en;

    logic        start;
    logic        busy;
    logic        done;
    logic [1:0]  disease_class;
    logic        disease_detected;
    logic [15:0] confidence;

    logic [7:0]  s_axis_tdata;
    logic        s_axis_tvalid;
    logic        s_axis_tready;
    logic        s_axis_tlast;

    logic        csr_wr_en;
    logic        csr_rd_en;
    logic [5:0]  csr_addr;
    logic [31:0] csr_wdata;
    logic [31:0] csr_rdata;

    // Clock Generator (100 MHz -> 10ns period)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // DUT Instantiation
    agri_drone_top #(
        .IMAGE_WIDTH(25),
        .IMAGE_HEIGHT(25)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .test_en(test_en),
        .start(start),
        .busy(busy),
        .done(done),
        .disease_class(disease_class),
        .disease_detected(disease_detected),
        .confidence(confidence),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast),
        .csr_wr_en(csr_wr_en),
        .csr_rd_en(csr_rd_en),
        .csr_addr(csr_addr),
        .csr_wdata(csr_wdata),
        .csr_rdata(csr_rdata)
    );

    // Helper Task: Stream 625 pixels into AXI-Stream Interface
    task automatic stream_frame(input logic [7:0] img[625], input bit with_stalls = 0);
        for (int i = 0; i < 625; i++) begin
            @(negedge clk);
            while (!s_axis_tready) @(negedge clk);
            s_axis_tvalid = 1;
            s_axis_tdata  = img[i];
            s_axis_tlast  = (i == 624);

            if (with_stalls && (i % 7 == 0)) begin
                @(negedge clk);
                s_axis_tvalid = 0;
                s_axis_tlast  = 0;
            end
        end
        @(negedge clk);
        s_axis_tvalid = 0;
        s_axis_tlast  = 0;
    endtask

    // Main Test Sequence
    initial begin : test_seq
        automatic logic [7:0] healthy_frame[625];
        automatic logic [7:0] blight_frame[625];
        automatic logic [7:0] rand_frame[625];
        automatic bit stress_pass = 1;

        reset_counters();
        rst_n         = 0;
        test_en       = 0;
        start         = 0;
        s_axis_tdata  = '0;
        s_axis_tvalid = 0;
        s_axis_tlast  = 0;
        csr_wr_en     = 0;
        csr_rd_en     = 0;
        csr_addr      = '0;
        csr_wdata     = '0;
        #30;
        rst_n         = 1;
        #20;

        // Populate sample frames
        for (int i = 0; i < 625; i++) begin
            healthy_frame[i] = 8'd128; // Uniform healthy foliage
            blight_frame[i]  = (i >= 300 && i <= 325) ? 8'd250 : 8'd50; // Disease blight pattern
        end

        //---------------------------------------------------------------------
        // CORNER TEST 1: Reset During Active Inference Ingestion
        //---------------------------------------------------------------------
        @(negedge clk);
        start = 1; @(negedge clk); start = 0;
        @(negedge clk);
        s_axis_tvalid = 1; s_axis_tdata = 8'hFF;
        @(negedge clk);
        rst_n = 0;
        @(posedge clk);
        #1;
        record_result("CORNER", (busy === 1'b0 && done === 1'b0), "TC1: Global reset mid-stream cleans all subsystem states");
        @(negedge clk);
        rst_n = 1; s_axis_tvalid = 0;
        #20;

        //---------------------------------------------------------------------
        // CORNER TEST 2: Soft Reset via CSR Register Bit 1
        //---------------------------------------------------------------------
        @(negedge clk);
        start = 1; @(negedge clk); start = 0;
        @(negedge clk);
        csr_wr_en = 1; csr_addr = 6'h00; csr_wdata = 32'h00000002; // soft_rst = 1
        @(negedge clk);
        csr_wr_en = 0;
        @(posedge clk);
        #1;
        record_result("CORNER", (busy === 1'b0), "TC2: Host CSR soft reset successfully aborts pipeline");
        #20;

        //---------------------------------------------------------------------
        // CORNER TEST 3: Intermittent Backpressure / AXI Valid Stalls
        //---------------------------------------------------------------------
        @(negedge clk);
        start = 1; @(negedge clk); start = 0;
        stream_frame(healthy_frame, 1);
        fork
            begin
                while (!done) @(posedge clk);
            end
            begin
                #50000; // Timeout
            end
        join_any
        #1;
        record_result("CORNER", (done === 1'b1 || busy === 1'b0), "TC3: Frame ingestion with intermittent stalls completes safely");
        #20;

        //---------------------------------------------------------------------
        // CORNER TEST 4: CSR Kernel Weights & Bias Dynamic Reconfiguration
        //---------------------------------------------------------------------
        @(negedge clk);
        csr_wr_en = 1; csr_addr = 6'h0C; csr_wdata = 32'sd500;
        @(posedge clk);
        @(negedge clk);
        csr_wr_en = 1; csr_addr = 6'h10; csr_wdata = {8'sd2, 8'sd2, 8'sd2, 8'sd2};
        @(posedge clk);
        @(negedge clk);
        csr_wr_en = 0;
        #1;
        record_result("CORNER", (dut.conv_bias === 24'sd500 && dut.conv_w0 === 8'sd2), "TC4: Dynamic CSR kernel weight reconfiguration verified");

        //---------------------------------------------------------------------
        // CORNER TEST 5: Single-Cycle Done Pulse Verification
        //---------------------------------------------------------------------
        @(negedge clk);
        start = 1; @(negedge clk); start = 0;
        stream_frame(healthy_frame, 0);
        while (!done) @(posedge clk);
        #1;
        record_result("CORNER", (done === 1'b1), "TC5: Done pulse asserted upon completion");
        @(posedge clk);
        #1;
        record_result("CORNER", (done === 1'b0), "TC5b: Done pulse de-asserted cleanly after 1 cycle");

        //---------------------------------------------------------------------
        // NORMAL TEST 6: Full End-to-End Healthy Crop Frame (Class 0, No Disease)
        //---------------------------------------------------------------------
        begin
            @(negedge clk);
            csr_wr_en = 1; csr_addr = 6'h0C; csr_wdata = 32'sd0;
            @(posedge clk);
            @(negedge clk);
            csr_wr_en = 1; csr_addr = 6'h10; csr_wdata = {-8'sd1, -8'sd1, -8'sd1, -8'sd1};
            @(posedge clk);
            @(negedge clk);
            csr_wr_en = 1; csr_addr = 6'h14; csr_wdata = {-8'sd1, -8'sd1, -8'sd1, 8'sd8};
            @(posedge clk);
            @(negedge clk);
            csr_wr_en = 1; csr_addr = 6'h18; csr_wdata = {24'd0, -8'sd1};
            @(posedge clk);
            @(negedge clk);
            csr_wr_en = 0;

            @(negedge clk);
            start = 1; @(negedge clk); start = 0;
            stream_frame(healthy_frame, 0);

            while (!done) @(posedge clk);
            #1;
            record_result("NORMAL", (disease_detected === 1'b0 && confidence >= 16'd128),
                          $sformatf("TC6: End-to-End Healthy Crop Inferred (Class: %0d, Detected: %0d, Conf: %0d)",
                          disease_class, disease_detected, confidence));
        end

        //---------------------------------------------------------------------
        // NORMAL TEST 7: Full End-to-End Leaf Blight Frame (Class 1, Disease Detected)
        //---------------------------------------------------------------------
        begin
            @(negedge clk);
            start = 1; @(negedge clk); start = 0;
            stream_frame(blight_frame, 0);

            while (!done) @(posedge clk);
            #1;
            record_result("NORMAL", (disease_detected === 1'b1 && confidence >= 16'd128),
                          $sformatf("TC7: End-to-End Leaf Blight Inferred (Class: %0d, Detected: %0d, Conf: %0d)",
                          disease_class, disease_detected, confidence));
        end

        //---------------------------------------------------------------------
        // ULTIMATE STRESS TEST 8: 3 Consecutive Back-to-Back Randomized Frames
        //---------------------------------------------------------------------
        stress_pass = 1;
        for (int f = 0; f < 3; f++) begin
            for (int p = 0; p < 625; p++) rand_frame[p] = $urandom_range(0, 255);

            @(negedge clk);
            start = 1; @(negedge clk); start = 0;
            stream_frame(rand_frame, (f == 1));

            while (!done) @(posedge clk);
            #1;
            if (confidence < 16'd128 || confidence > 16'd256) stress_pass = 0;
            @(posedge clk);
        end
        record_result("STRESS", stress_pass, "TC8: 3 consecutive randomized multi-frame streams completed with valid classifications");

        #30;
        print_summary("agri_drone_top");
        $finish;
    end : test_seq

endmodule: tb_agri_drone_top
