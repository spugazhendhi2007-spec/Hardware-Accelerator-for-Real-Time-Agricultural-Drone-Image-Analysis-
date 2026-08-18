//=============================================================================
// File: relu_activation.sv
// Description: Non-linear ReLU Activation Unit with zero-clamping and
//              positive saturation protection (S24 -> S16).
// Standard: SystemVerilog IEEE 1800
//=============================================================================

`timescale 1ns/1ps

module relu_activation (
    input  logic signed [23:0] data_in,
    output logic signed [15:0] data_out
);

    always_comb begin
        if (data_in <= 24'sd0) begin
            data_out = 16'sd0;
        end else if (data_in > 24'sd32767) begin
            data_out = 16'sd32767;
        end else begin
            data_out = data_in[15:0];
        end
    end

endmodule: relu_activation
