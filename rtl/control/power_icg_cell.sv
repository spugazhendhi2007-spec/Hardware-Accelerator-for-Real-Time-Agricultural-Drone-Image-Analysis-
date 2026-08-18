//=============================================================================
// File: power_icg_cell.sv
// Description: Integrated Clock Gating (ICG) cell using a glitch-free
//              negative-latch structure for dynamic power reduction.
// Standard: SystemVerilog IEEE 1800
//=============================================================================

`timescale 1ns/1ps

module power_icg_cell (
    input  logic clk,       // Free-running master clock
    input  logic en,        // Functional clock enable
    input  logic test_en,   // Scan / DFT test bypass enable
    output logic gclk       // Gated clock output
);

    // Negative latch to capture enable during clk LOW phase (prevents glitches)
    logic latch_en;

    always_latch begin
        if (~clk) begin
            latch_en <= en | test_en;
        end
    end

    // Gated clock generation
    assign gclk = clk & latch_en;

endmodule: power_icg_cell
