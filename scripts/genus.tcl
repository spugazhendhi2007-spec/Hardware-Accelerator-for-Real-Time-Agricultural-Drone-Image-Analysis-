#==============================================================================
# File: genus.tcl
# Description: Cadence Genus Synthesis Script for Agricultural Drone Accelerator
# Execute from work/ directory: genus -f ../scripts/genus.tcl
#==============================================================================

# 1. Global Setup and Multi-threading
set_db / .max_cpus_per_server 4
set_db / .information_level 7

# 2. Output and Report Directory Creation
set REPORT_DIR "../reports/synthesis"
file mkdir $REPORT_DIR

# 3. Target Technology Library Setup (.lib / .db)
# If you have a specific standard cell .lib file, specify its path below:
set TARGET_LIBS ""

# Search common lab paths if TARGET_LIBS is empty
if {$TARGET_LIBS eq ""} {
    # Check for standard library locations
    set search_paths [list \
        "../libs" \
        "/mnt/rl-home/PUGAZH/libs" \
        "/cad/lib" \
        "/tools/cadence/lib" \
        "[get_db / .install_path]/lib" \
        "[get_db / .install_path]/share/samples" \
        "/usr/local/lib" \
        "." \
    ]
    
    foreach sp $search_paths {
        if {[file exists $sp]} {
            set found_libs [glob -nocomplain -directory $sp -types f *.lib]
            if {[llength $found_libs] > 0} {
                set TARGET_LIBS [lindex $found_libs 0]
                puts "INFO: Auto-detected standard cell library: $TARGET_LIBS"
                break
            }
        }
    }
}

if {$TARGET_LIBS ne ""} {
    read_libs $TARGET_LIBS
} else {
    puts "=================================================================="
    puts "WARNING: No target .lib file auto-detected."
    puts "Please set your technology library path in scripts/genus.tcl"
    puts "Example: read_libs /path/to/slow.lib or NangateOpenCellLibrary.lib"
    puts "=================================================================="
    # Try loading default generic library if available
    catch {read_libs [glob -nocomplain [get_db / .install_path]/share/samples/*.lib]}
}

# 4. Read RTL Source Files in Prerequisite Dependency Order
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

# 5. Elaboration and Hierarchy Resolution
elaborate agri_drone_top
check_design -unresolved > $REPORT_DIR/unresolved_modules.rpt

# 6. Apply SDC Timing Constraints
read_sdc ../constraints/project.sdc

# 7. Generic Synthesis
syn_generic

# 8. Technology Mapping
syn_map

# 9. Incremental Optimization
syn_opt

# 10. Generate Synthesis Quality of Results (QoR) Reports
report_area > $REPORT_DIR/area.rpt
report_timing -max_paths 20 > $REPORT_DIR/timing.rpt
report_power > $REPORT_DIR/power.rpt
report_qor > $REPORT_DIR/qor.rpt
report_gates > $REPORT_DIR/gates.rpt
report_clock_gating > $REPORT_DIR/clock_gating.rpt

# 11. Export Mapped Gate-Level Netlist & Constraints
write_hdl > $REPORT_DIR/agri_drone_top_netlist.v
write_sdc > $REPORT_DIR/agri_drone_top_synth.sdc
write_design -basename $REPORT_DIR/agri_drone_top_mapped

puts "=================================================================="
puts "  GENUS SYNTHESIS COMPLETED SUCCESSFULLY"
puts "  All reports saved to $REPORT_DIR"
puts "=================================================================="
