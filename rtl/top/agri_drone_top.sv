//=============================================================================
// File: agri_drone_top.sv
// Description: Top-Level Integration Wrapper for the 25x25 Real-Time
//              Agricultural Drone Image Analysis Hardware Accelerator.
// Standard: SystemVerilog IEEE 1800
//=============================================================================

`timescale 1ns/1ps

module agri_drone_top #(
    parameter int IMAGE_WIDTH  = 25,
    parameter int IMAGE_HEIGHT = 25,
    parameter int TOTAL_PIXELS = IMAGE_WIDTH * IMAGE_HEIGHT // 625
)(
    input  logic                     clk,
    input  logic                     rst_n,
    input  logic                     test_en, // Scan / DFT bypass enable

    // Direct Control / Host Trigger
    input  logic                     start,
    output logic                     busy,
    output logic                     done,
    output logic [1:0]               disease_class,
    output logic                     disease_detected,
    output logic [15:0]              confidence,

    // AXI4-Stream Slave Interface (Pixel Streaming)
    input  logic [7:0]               s_axis_tdata,
    input  logic                     s_axis_tvalid,
    output logic                     s_axis_tready,
    input  logic                     s_axis_tlast,

    // Host CSR Register Management Interface
    input  logic                     csr_wr_en,
    input  logic                     csr_rd_en,
    input  logic [5:0]               csr_addr,
    input  logic [31:0]              csr_wdata,
    output logic [31:0]              csr_rdata
);

    import agri_drone_pkg::*;

    //-------------------------------------------------------------------------
    // Internal Interconnect Signals
    //-------------------------------------------------------------------------
    // CSR Controls
    logic                     ctrl_start;
    logic                     ctrl_soft_rst;
    logic                     ctrl_clk_gate_en;
    logic signed [23:0]       conv_bias;
    logic signed [7:0]        conv_w0, conv_w1, conv_w2;
    logic signed [7:0]        conv_w3, conv_w4, conv_w5;
    logic signed [7:0]        conv_w6, conv_w7, conv_w8;
    logic signed [23:0]       dense_bias0, dense_bias1, dense_bias2, dense_bias3;

    // Combined Start & Soft Reset
    wire start_combined = start | ctrl_start;
    wire rst_n_combined = rst_n & (~ctrl_soft_rst);

    // FSM Control Signals
    logic [2:0]  fsm_state;
    logic        fsm_busy;
    logic        fsm_done;
    logic        fsm_fifo_pop_en;
    logic        fsm_img_wr_en;
    logic [9:0]  fsm_img_wr_addr;
    logic        fsm_lb_clr;
    logic        fsm_conv_start;
    logic        fsm_cls_start;
    logic        fsm_argmax_en;
    logic        fsm_gclk_load_en;
    logic        fsm_gclk_conv_en;
    logic        fsm_gclk_cls_en;

    // FIFO Outputs
    logic [7:0]  fifo_m_data;
    logic        fifo_m_last;
    logic        fifo_m_valid;
    logic        fifo_full;
    logic        fifo_empty;
    logic [5:0]  fifo_count;

    // Image Buffer Outputs
    logic [7:0]  img_rd_data;

    // Line Buffer Window Outputs
    logic        lb_win_valid;
    logic [7:0]  lb_p0, lb_p1, lb_p2;
    logic [7:0]  lb_p3, lb_p4, lb_p5;
    logic [7:0]  lb_p6, lb_p7, lb_p8;
    logic [5:0]  lb_win_col;
    logic [5:0]  lb_win_row;

    // 2D Conv & Pool Outputs
    logic signed [15:0]       conv_feat_data;
    logic                     conv_feat_valid;
    logic [6:0]               conv_feat_idx;
    logic                     conv_done_sig;

    // Dense Classifier Outputs
    logic signed [23:0]       cls_score0, cls_score1, cls_score2, cls_score3;
    logic                     cls_done_sig;

    // ArgMax Outputs
    logic [1:0]               arg_class_id;
    logic                     arg_disease_det;
    logic signed [23:0]       arg_max_score;
    logic [15:0]              arg_confidence;
    logic                     arg_valid_out;

    // Clock Gating Signals
    logic gclk_load, gclk_conv, gclk_cls;

    // Output assignments
    assign busy             = fsm_busy;
    assign done             = fsm_done;
    assign disease_class    = arg_class_id;
    assign disease_detected = arg_disease_det;
    assign confidence       = arg_confidence;

    //-------------------------------------------------------------------------
    // 1. Clock Gating Cells (PPA Power Optimization)
    //-------------------------------------------------------------------------
    power_icg_cell u_icg_load (
        .clk(clk),
        .en(ctrl_clk_gate_en ? (fsm_gclk_load_en | start_combined) : 1'b1),
        .test_en(test_en),
        .gclk(gclk_load)
    );

    power_icg_cell u_icg_conv (
        .clk(clk),
        .en(ctrl_clk_gate_en ? (fsm_gclk_conv_en | start_combined) : 1'b1),
        .test_en(test_en),
        .gclk(gclk_conv)
    );

    power_icg_cell u_icg_cls (
        .clk(clk),
        .en(ctrl_clk_gate_en ? (fsm_gclk_cls_en | start_combined) : 1'b1),
        .test_en(test_en),
        .gclk(gclk_cls)
    );

    //-------------------------------------------------------------------------
    // 2. AXI-Stream Input FIFO
    //-------------------------------------------------------------------------
    axis_input_fifo #(
        .DATA_WIDTH(8),
        .DEPTH(32)
    ) u_input_fifo (
        .clk(clk),
        .rst_n(rst_n_combined),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast),
        .m_data(fifo_m_data),
        .m_last(fifo_m_last),
        .m_valid(fifo_m_valid),
        .m_ready(fsm_fifo_pop_en),
        .fifo_full(fifo_full),
        .fifo_empty(fifo_empty),
        .fifo_count(fifo_count)
    );

    //-------------------------------------------------------------------------
    // 3. 25x25 Image Buffer
    //-------------------------------------------------------------------------
    image_buffer_25x25 #(
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .IMAGE_HEIGHT(IMAGE_HEIGHT)
    ) u_image_buffer (
        .clk(gclk_load),
        .rst_n(rst_n_combined),
        .wr_en(fsm_img_wr_en),
        .wr_addr(fsm_img_wr_addr),
        .wr_data(fifo_m_data),
        .rd_en(1'b0),
        .rd_addr(10'd0),
        .rd_data(img_rd_data)
    );

    //-------------------------------------------------------------------------
    // 4. 3x3 Line Buffer Window Generator
    //-------------------------------------------------------------------------
    line_buffer_window_3x3 #(
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .IMAGE_HEIGHT(IMAGE_HEIGHT),
        .DATA_WIDTH(8)
    ) u_line_buffer (
        .clk(gclk_conv),
        .rst_n(rst_n_combined),
        .clr(fsm_lb_clr),
        .in_valid(fsm_img_wr_en),
        .in_pixel(fifo_m_data),
        .window_valid(lb_win_valid),
        .p0(lb_p0), .p1(lb_p1), .p2(lb_p2),
        .p3(lb_p3), .p4(lb_p4), .p5(lb_p5),
        .p6(lb_p6), .p7(lb_p7), .p8(lb_p8),
        .out_col(lb_win_col),
        .out_row(lb_win_row)
    );

    //-------------------------------------------------------------------------
    // 5. 2D Convolution & MaxPool Engine
    //-------------------------------------------------------------------------
    conv_engine #(
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .IMAGE_HEIGHT(IMAGE_HEIGHT),
        .KERNEL_SIZE(3)
    ) u_conv_engine (
        .clk(gclk_conv),
        .rst_n(rst_n_combined),
        .start(fsm_conv_start),
        .window_valid(lb_win_valid),
        .p0(lb_p0), .p1(lb_p1), .p2(lb_p2),
        .p3(lb_p3), .p4(lb_p4), .p5(lb_p5),
        .p6(lb_p6), .p7(lb_p7), .p8(lb_p8),
        .win_col(lb_win_col),
        .win_row(lb_win_row),
        .w0(conv_w0), .w1(conv_w1), .w2(conv_w2),
        .w3(conv_w3), .w4(conv_w4), .w5(conv_w5),
        .w6(conv_w6), .w7(conv_w7), .w8(conv_w8),
        .bias(conv_bias),
        .feat_valid(conv_feat_valid),
        .feat_data(conv_feat_data),
        .feat_idx(conv_feat_idx),
        .conv_done(conv_done_sig)
    );

    //-------------------------------------------------------------------------
    // 6. Dense Classification Layer
    //-------------------------------------------------------------------------
    dense_classifier #(
        .NUM_FEATURES(121),
        .NUM_CLASSES(4)
    ) u_dense_classifier (
        .clk(gclk_cls),
        .rst_n(rst_n_combined),
        .start(fsm_cls_start),
        .feat_valid(conv_feat_valid),
        .feat_data(conv_feat_data),
        .feat_idx(conv_feat_idx),
        .w_cls0(8'sd1), .w_cls1(8'sd2), .w_cls2(8'sd1), .w_cls3(-8'sd1),
        .bias0(dense_bias0), .bias1(dense_bias1),
        .bias2(dense_bias2), .bias3(dense_bias3),
        .score0(cls_score0), .score1(cls_score1),
        .score2(cls_score2), .score3(cls_score3),
        .cls_done(cls_done_sig)
    );

    //-------------------------------------------------------------------------
    // 7. ArgMax & Confidence Estimator
    //-------------------------------------------------------------------------
    argmax_confidence u_argmax (
        .clk(clk),
        .rst_n(rst_n_combined),
        .enable(fsm_argmax_en),
        .score0(cls_score0), .score1(cls_score1),
        .score2(cls_score2), .score3(cls_score3),
        .class_id(arg_class_id),
        .disease_detected(arg_disease_det),
        .max_score(arg_max_score),
        .confidence(arg_confidence),
        .valid_out(arg_valid_out)
    );

    //-------------------------------------------------------------------------
    // 8. Control & Status Register Bank
    //-------------------------------------------------------------------------
    agri_drone_csr u_csr (
        .clk(clk),
        .rst_n(rst_n),
        .csr_wr_en(csr_wr_en),
        .csr_rd_en(csr_rd_en),
        .csr_addr(csr_addr),
        .csr_wdata(csr_wdata),
        .csr_rdata(csr_rdata),
        .hw_busy(fsm_busy),
        .hw_done(fsm_done),
        .hw_class(arg_class_id),
        .hw_disease_detected(arg_disease_det),
        .hw_confidence(arg_confidence),
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

    //-------------------------------------------------------------------------
    // 9. Master Sequencing FSM Controller
    //-------------------------------------------------------------------------
    agri_fsm_controller #(
        .TOTAL_PIXELS(TOTAL_PIXELS),
        .NUM_FEATURES(121)
    ) u_fsm (
        .clk(clk),
        .rst_n(rst_n_combined),
        .start_pulse(start_combined),
        .soft_rst(ctrl_soft_rst),
        .fifo_empty(fifo_empty),
        .fifo_m_valid(fifo_m_valid),
        .conv_engine_done(conv_done_sig),
        .classifier_done(cls_done_sig),
        .argmax_done(arg_valid_out),
        .fifo_pop_en(fsm_fifo_pop_en),
        .img_buf_wr_en(fsm_img_wr_en),
        .img_buf_wr_addr(fsm_img_wr_addr),
        .line_buf_clr(fsm_lb_clr),
        .conv_start(fsm_conv_start),
        .cls_start(fsm_cls_start),
        .argmax_en(fsm_argmax_en),
        .gclk_load_en(fsm_gclk_load_en),
        .gclk_conv_en(fsm_gclk_conv_en),
        .gclk_cls_en(fsm_gclk_cls_en),
        .busy(fsm_busy),
        .done(fsm_done),
        .current_state(fsm_state)
    );

endmodule: agri_drone_top
