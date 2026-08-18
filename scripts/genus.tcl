#==============================================================================
# File: genus.tcl
# Description: Cadence Genus Synthesis Script for Agricultural Drone Accelerator
# Target Technology: 90nm Digital Standard Cell Foundry Library (slow.lib)
# Execute from work/ directory: genus -f ../scripts/genus.tcl
#==============================================================================

# 1. Read 90nm Standard Cell Technology Library
read_libs /home/ece-server/cadance_install/FOUNDRY/digital/90nm/dig/lib/slow.lib

# 2. Read SystemVerilog RTL Source Files in Prerequisite Dependency Order
read_hdl -language sv {
    ../rtl/defs/agri_drone_pkg.sv
    ../rtl/control/power_icg_cell.sv
    ../rtl/mem/axis_input_fifo.sv
    ../rtl/mem/image_buffer_25x25.sv
    ../rtl/mem/line_buffer_window_3x3.sv
    ../rtl/math/int8_mac_unit.sv
    ../rtl/math/pe_array_3x3.sv
    ../rtl/math/relu_activation.sv
    ../rtl/math/maxpool_2x2.sv
    ../rtl/core/conv_engine.sv
    ../rtl/core/dense_classifier.sv
    ../rtl/core/argmax_confidence.sv
    ../rtl/control/agri_drone_csr.sv
    ../rtl/control/agri_fsm_controller.sv
    ../rtl/top/agri_drone_top.sv
}

# 3. Elaboration of Top-Level Module Hierarchy
elaborate agri_drone_top

# 4. Apply Timing Constraints
read_sdc ../constraints/project.sdc

# 5. Generic Synthesis & Optimization
syn_generic

# 6. Technology Mapping to 90nm Standard Cells
syn_map

# 7. Incremental Timing & Area Optimization
syn_opt

# 8. Export Gate-Level Netlist & Output Constraints
write_hdl > agri_drone_top_netlist.v
write_sdc > agri_drone_top_out_constraints.sdc

# 9. Generate Quality of Results (QoR) Reports
report_area > agri_drone_top_area.txt
report_power > agri_drone_top_power.txt
report_timing > agri_drone_top_timing.txt
report_qor > agri_drone_top_qor.txt

puts "=================================================================="
puts "  GENUS 90nm SYNTHESIS COMPLETED SUCCESSFULLY"
puts "  Generated: agri_drone_top_netlist.v"
puts "  Generated: agri_drone_top_area.txt"
puts "  Generated: agri_drone_top_power.txt"
puts "  Generated: agri_drone_top_timing.txt"
puts "  Generated: agri_drone_top_qor.txt"
puts "=================================================================="

# 10. Launch Cadence Genus Graphical User Interface (GUI)
gui_show
