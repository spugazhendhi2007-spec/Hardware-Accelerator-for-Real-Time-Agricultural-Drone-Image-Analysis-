//=============================================================================
// File: agri_fsm_controller.sv
// Description: Master Multi-Stage Sequencing Controller FSM for orchestrating
//              loading, 2D convolution, pooling, classification, and output.
// Standard: SystemVerilog IEEE 1800
//=============================================================================

`timescale 1ns/1ps

module agri_fsm_controller #(
    parameter int TOTAL_PIXELS = 625,
    parameter int NUM_FEATURES = 121
)(
    input  logic                     clk,
    input  logic                     rst_n,

    // Host / CSR Control
    input  logic                     start_pulse,
    input  logic                     soft_rst,

    // Subsystem Status Feedback
    input  logic                     fifo_empty,
    input  logic                     fifo_m_valid,
    input  logic                     conv_engine_done,
    input  logic                     classifier_done,
    input  logic                     argmax_done,

    // Subsystem Control Strobes
    output logic                     fifo_pop_en,
    output logic                     img_buf_wr_en,
    output logic [9:0]               img_buf_wr_addr,
    output logic                     line_buf_clr,
    output logic                     conv_start,
    output logic                     cls_start,
    output logic                     argmax_en,

    // Subsystem Clock Gating Enables (PPA Power Optimization)
    output logic                     gclk_load_en,
    output logic                     gclk_conv_en,
    output logic                     gclk_cls_en,

    // Accelerator Top Status
    output logic                     busy,
    output logic                     done,
    output logic [2:0]               current_state
);

    import agri_drone_pkg::*;

    fsm_state_e state_q, state_d;
    logic [9:0] pixel_cnt_q, pixel_cnt_d;
    logic       done_q;

    assign current_state   = state_q;
    assign busy            = (state_q != STATE_IDLE && state_q != STATE_DONE);
    assign done            = done_q;
    assign img_buf_wr_addr = pixel_cnt_q;

    // FSM State Transition Logic
    always_comb begin
        state_d         = state_q;
        pixel_cnt_d     = pixel_cnt_q;
        fifo_pop_en     = 1'b0;
        img_buf_wr_en   = 1'b0;
        line_buf_clr    = 1'b0;
        conv_start      = 1'b0;
        cls_start       = 1'b0;
        argmax_en       = 1'b0;
        gclk_load_en    = 1'b0;
        gclk_conv_en    = 1'b0;
        gclk_cls_en     = 1'b0;

        case (state_q)
            STATE_IDLE: begin
                if (start_pulse) begin
                    state_d      = STATE_LOAD_STREAM;
                    pixel_cnt_d  = '0;
                    line_buf_clr = 1'b1;
                    conv_start   = 1'b1;
                    cls_start    = 1'b1;
                end
            end

            STATE_LOAD_STREAM: begin
                gclk_load_en = 1'b1;
                gclk_conv_en = 1'b1; // Line buffer + Conv Engine
                gclk_cls_en  = 1'b1; // Dense Classifier receives streaming features

                if (fifo_m_valid) begin
                    fifo_pop_en   = 1'b1;
                    img_buf_wr_en = 1'b1;
                    pixel_cnt_d   = pixel_cnt_q + 1'b1;

                    if (pixel_cnt_q == TOTAL_PIXELS - 1) begin
                        state_d = STATE_CONV_POOL;
                    end
                end
            end

            STATE_CONV_POOL: begin
                gclk_conv_en = 1'b1;
                gclk_cls_en  = 1'b1;

                if (conv_engine_done) begin
                    state_d = STATE_CLASSIFY;
                end
            end

            STATE_CLASSIFY: begin
                gclk_cls_en = 1'b1;

                if (classifier_done) begin
                    state_d   = STATE_ARGMAX_CONF;
                    argmax_en = 1'b1;
                end
            end

            STATE_ARGMAX_CONF: begin
                argmax_en = 1'b1;
                if (argmax_done) begin
                    state_d = STATE_DONE;
                end
            end

            STATE_DONE: begin
                state_d = STATE_IDLE;
            end

            default: state_d = STATE_IDLE;
        endcase
    end

    // Sequential Register Updates
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_q     <= STATE_IDLE;
            pixel_cnt_q <= '0;
            done_q      <= 1'b0;
        end else if (soft_rst) begin
            state_q     <= STATE_IDLE;
            pixel_cnt_q <= '0;
            done_q      <= 1'b0;
        end else begin
            state_q     <= state_d;
            pixel_cnt_q <= pixel_cnt_d;
            done_q      <= (state_q == STATE_DONE);
        end
    end

endmodule: agri_fsm_controller
