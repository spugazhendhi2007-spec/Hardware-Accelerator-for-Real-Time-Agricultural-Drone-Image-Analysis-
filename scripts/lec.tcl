#==============================================================================
# File: lec.tcl
# Description: Cadence Conformal LEC Script comparing RTL (Golden) vs
#              Synthesized Netlist (Revised) for Formal Equivalence.
# Execute from work/ directory: lec -dofile ../scripts/lec.tcl -nogui
#==============================================================================

set REPORT_DIR "../reports/lec"
file mkdir $REPORT_DIR

# 1. Setup Golden (Reference SystemVerilog RTL)
read design \
    ../rtl/defs/agri_drone_pkg.sv \
    ../rtl/control/power_icg_cell.sv \
    ../rtl/mem/axis_input_fifo.sv \
    ../rtl/mem/image_buffer_25x25.sv \
    ../rtl/mem/line_buffer_window_3x3.sv \
    ../rtl/math/int8_mac_unit.sv \
    ../rtl/math/pe_array_3x3.sv \
    ../rtl/math/relu_activation.sv \
    ../rtl/math/maxpool_2x2.sv \
    ../rtl/core/conv_engine.sv \
    ../rtl/core/dense_classifier.sv \
    ../rtl/core/argmax_confidence.sv \
    ../rtl/control/agri_drone_csr.sv \
    ../rtl/control/agri_fsm_controller.sv \
    ../rtl/top/agri_drone_top.sv \
    -SystemVerilog -Golden -Root agri_drone_top

# 2. Setup Revised (Synthesized Gate-Level Netlist)
read design \
    ../reports/synthesis/agri_drone_top_netlist.v \
    -Verilog -Revised -Root agri_drone_top

# 3. Add Mapping Rules & Renaming
set system mode lec

# 4. Map Points
map key points

# 5. Run Formal Equivalence Comparison
compare

# 6. Generate Conformal Verification Reports
report mapped points > $REPORT_DIR/mapped_points.rpt
report unmapped points > $REPORT_DIR/unmapped_points.rpt
report compare points > $REPORT_DIR/compared_points.rpt
report statistics > $REPORT_DIR/lec_statistics.rpt
report verification > $REPORT_DIR/lec_verification.rpt

puts "=================================================================="
puts "  CONFORMAL LEC FORMAL EQUIVALENCE COMPLETED"
puts "  Check report: $REPORT_DIR/lec_verification.rpt"
puts "=================================================================="
