//=============================================================================
// File: agri_drone_pkg.sv
// Description: Global definitions, parameters, and types for the 25x25
//              Agricultural Drone Image Analysis Hardware Accelerator.
// Standard: SystemVerilog IEEE 1800
//=============================================================================

`timescale 1ns/1ps

package agri_drone_pkg;

    //-------------------------------------------------------------------------
    // Spatial & Architectural Dimensions
    //-------------------------------------------------------------------------
    localparam int IMAGE_WIDTH         = 25;
    localparam int IMAGE_HEIGHT        = 25;
    localparam int TOTAL_PIXELS        = IMAGE_WIDTH * IMAGE_HEIGHT; // 625 pixels
    localparam int ADDR_WIDTH          = $clog2(TOTAL_PIXELS);       // 10 bits

    localparam int KERNEL_SIZE         = 3;
    localparam int KERNEL_ELEMENTS     = KERNEL_SIZE * KERNEL_SIZE;  // 9 elements

    localparam int CONV_OUT_WIDTH      = IMAGE_WIDTH - KERNEL_SIZE + 1;  // 23
    localparam int CONV_OUT_HEIGHT     = IMAGE_HEIGHT - KERNEL_SIZE + 1; // 23
    localparam int TOTAL_CONV_PIXELS   = CONV_OUT_WIDTH * CONV_OUT_HEIGHT; // 529

    localparam int POOL_SIZE           = 2;
    localparam int POOL_STRIDE         = 2;
    localparam int POOL_OUT_WIDTH      = CONV_OUT_WIDTH / POOL_STRIDE;   // 11
    localparam int POOL_OUT_HEIGHT     = CONV_OUT_HEIGHT / POOL_STRIDE;  // 11
    localparam int TOTAL_POOLED_PIXELS = POOL_OUT_WIDTH * POOL_OUT_HEIGHT; // 121

    localparam int NUM_CLASSES         = 4;
    localparam int CLASS_WIDTH         = $clog2(NUM_CLASSES); // 2 bits

    //-------------------------------------------------------------------------
    // Disease Classification Enumeration
    //-------------------------------------------------------------------------
    typedef enum logic [1:0] {
        CLASS_HEALTHY            = 2'b00,
        CLASS_LEAF_BLIGHT        = 2'b01,
        CLASS_LEAF_RUST          = 2'b10,
        CLASS_NUTRIENT_DEFICIENT = 2'b11
    } disease_class_e;

    //-------------------------------------------------------------------------
    // Arithmetic Precision Types
    //-------------------------------------------------------------------------
    typedef logic [7:0]         pixel_u8_t;     // 8-bit unsigned pixel [0, 255]
    typedef logic signed [7:0]  pixel_s8_t;     // 8-bit signed centered pixel [-128, +127]
    typedef logic signed [7:0]  weight_s8_t;    // 8-bit signed weight
    typedef logic signed [15:0] prod_s16_t;     // 16-bit signed multiplication product
    typedef logic signed [23:0] acc_s24_t;      // 24-bit signed accumulator
    typedef logic signed [15:0] act_s16_t;      // 16-bit clamped activation
    typedef logic signed [23:0] score_s24_t;    // 24-bit classification score
    typedef logic [15:0]        conf_q8_8_t;    // 16-bit Q8.8 fixed-point confidence

    //-------------------------------------------------------------------------
    // Top-Level State Machine Enumeration
    //-------------------------------------------------------------------------
    typedef enum logic [2:0] {
        STATE_IDLE        = 3'd0,
        STATE_LOAD_STREAM = 3'd1,
        STATE_CONV_POOL   = 3'd2,
        STATE_CLASSIFY    = 3'd3,
        STATE_ARGMAX_CONF = 3'd4,
        STATE_DONE        = 3'd5,
        STATE_ERROR       = 3'd6
    } fsm_state_e;

    //-------------------------------------------------------------------------
    // Helper Function: 8-bit Unsigned to Signed Centering (u - 128)
    //-------------------------------------------------------------------------
    function automatic pixel_s8_t center_pixel(input pixel_u8_t px_in);
        return pixel_s8_t'($signed({1'b0, px_in}) - 9'sd128);
    endfunction

    //-------------------------------------------------------------------------
    // Helper Function: Clamped ReLU Activation
    //-------------------------------------------------------------------------
    function automatic act_s16_t relu_clamp(input acc_s24_t val_in);
        if (val_in <= 24'sd0) begin
            return 16'sd0;
        end else if (val_in > 24'sd32767) begin
            return 16'sd32767;
        end else begin
            return act_s16_t'(val_in[15:0]);
        end
    endfunction

endpackage: agri_drone_pkg
