#!/usr/bin/env bash
#==============================================================================
# File: run_sim.sh
# Description: Automated Simulation Launcher for Agricultural Drone Accelerator
# Usage:
#   ./scripts/run_sim.sh              (runs master tb_agri_drone_top)
#   ./scripts/run_sim.sh <tb_name>    (e.g., ./scripts/run_sim.sh tb_power_icg_cell)
#   ./scripts/run_sim.sh all          (runs all 14 testbenches sequentially)
#==============================================================================

# Determine project root directory dynamically
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORK_DIR="$PROJ_ROOT/work"

mkdir -p "$WORK_DIR"
cd "$WORK_DIR" || exit 1

TB_TARGET="${1:-tb_agri_drone_top}"

echo "=================================================================="
echo " Project Root : $PROJ_ROOT"
echo " Work Dir     : $WORK_DIR"
echo " Target Test  : $TB_TARGET"
echo "=================================================================="

run_tb() {
    local name="$1"
    local cmd="$2"
    echo ""
    echo ">>> Running Testbench: $name ..."
    eval "$cmd"
    local status=$?
    if [ $status -ne 0 ]; then
        echo "[ERROR] Simulation failed for $name (Exit Code: $status)"
    else
        echo "[SUCCESS] Simulation finished for $name"
    fi
    return $status
}

case "$TB_TARGET" in
    compile_check|check)
        run_tb "RTL_Compilation_Check" \
        "irun -sv -compile -messages -nocopyright \
            $PROJ_ROOT/rtl/defs/agri_drone_pkg.sv \
            $PROJ_ROOT/rtl/control/power_icg_cell.sv \
            $PROJ_ROOT/rtl/mem/axis_input_fifo.sv \
            $PROJ_ROOT/rtl/mem/image_buffer_25x25.sv \
            $PROJ_ROOT/rtl/mem/line_buffer_window_3x3.sv \
            $PROJ_ROOT/rtl/math/int8_mac_unit.sv \
            $PROJ_ROOT/rtl/math/pe_array_3x3.sv \
            $PROJ_ROOT/rtl/math/relu_activation.sv \
            $PROJ_ROOT/rtl/math/maxpool_2x2.sv \
            $PROJ_ROOT/rtl/core/conv_engine.sv \
            $PROJ_ROOT/rtl/core/dense_classifier.sv \
            $PROJ_ROOT/rtl/core/argmax_confidence.sv \
            $PROJ_ROOT/rtl/control/agri_drone_csr.sv \
            $PROJ_ROOT/rtl/control/agri_fsm_controller.sv \
            $PROJ_ROOT/rtl/top/agri_drone_top.sv"
        ;;

    tb_power_icg_cell|power_icg|icg)
        run_tb "tb_power_icg_cell" \
        "irun -sv -access +rwc $PROJ_ROOT/tb/tb_pkg.sv $PROJ_ROOT/rtl/control/power_icg_cell.sv $PROJ_ROOT/tb/control/tb_power_icg_cell.sv"
        ;;

    tb_axis_input_fifo|axis_fifo|fifo)
        run_tb "tb_axis_input_fifo" \
        "irun -sv -access +rwc $PROJ_ROOT/tb/tb_pkg.sv $PROJ_ROOT/rtl/mem/axis_input_fifo.sv $PROJ_ROOT/tb/mem/tb_axis_input_fifo.sv"
        ;;

    tb_image_buffer_25x25|image_buffer|img_buf)
        run_tb "tb_image_buffer_25x25" \
        "irun -sv -access +rwc $PROJ_ROOT/tb/tb_pkg.sv $PROJ_ROOT/rtl/mem/image_buffer_25x25.sv $PROJ_ROOT/tb/mem/tb_image_buffer_25x25.sv"
        ;;

    tb_line_buffer_window_3x3|line_buffer|lb)
        run_tb "tb_line_buffer_window_3x3" \
        "irun -sv -access +rwc $PROJ_ROOT/tb/tb_pkg.sv $PROJ_ROOT/rtl/mem/line_buffer_window_3x3.sv $PROJ_ROOT/tb/mem/tb_line_buffer_window_3x3.sv"
        ;;

    tb_int8_mac_unit|int8_mac|mac)
        run_tb "tb_int8_mac_unit" \
        "irun -sv -access +rwc $PROJ_ROOT/tb/tb_pkg.sv $PROJ_ROOT/rtl/math/int8_mac_unit.sv $PROJ_ROOT/tb/math/tb_int8_mac_unit.sv"
        ;;

    tb_pe_array_3x3|pe_array|pe)
        run_tb "tb_pe_array_3x3" \
        "irun -sv -access +rwc $PROJ_ROOT/tb/tb_pkg.sv $PROJ_ROOT/rtl/math/pe_array_3x3.sv $PROJ_ROOT/tb/math/tb_pe_array_3x3.sv"
        ;;

    tb_relu_activation|relu)
        run_tb "tb_relu_activation" \
        "irun -sv -access +rwc $PROJ_ROOT/tb/tb_pkg.sv $PROJ_ROOT/rtl/math/relu_activation.sv $PROJ_ROOT/tb/math/tb_relu_activation.sv"
        ;;

    tb_maxpool_2x2|maxpool|pool)
        run_tb "tb_maxpool_2x2" \
        "irun -sv -access +rwc $PROJ_ROOT/tb/tb_pkg.sv $PROJ_ROOT/rtl/math/maxpool_2x2.sv $PROJ_ROOT/tb/math/tb_maxpool_2x2.sv"
        ;;

    tb_conv_engine|conv_engine|conv)
        run_tb "tb_conv_engine" \
        "irun -sv -access +rwc $PROJ_ROOT/tb/tb_pkg.sv $PROJ_ROOT/rtl/defs/agri_drone_pkg.sv $PROJ_ROOT/rtl/math/pe_array_3x3.sv $PROJ_ROOT/rtl/core/conv_engine.sv $PROJ_ROOT/tb/core/tb_conv_engine.sv"
        ;;

    tb_dense_classifier|dense_classifier|dense|cls)
        run_tb "tb_dense_classifier" \
        "irun -sv -access +rwc $PROJ_ROOT/tb/tb_pkg.sv $PROJ_ROOT/rtl/core/dense_classifier.sv $PROJ_ROOT/tb/core/tb_dense_classifier.sv"
        ;;

    tb_argmax_confidence|argmax_confidence|argmax)
        run_tb "tb_argmax_confidence" \
        "irun -sv -access +rwc $PROJ_ROOT/tb/tb_pkg.sv $PROJ_ROOT/rtl/defs/agri_drone_pkg.sv $PROJ_ROOT/rtl/core/argmax_confidence.sv $PROJ_ROOT/tb/core/tb_argmax_confidence.sv"
        ;;

    tb_agri_drone_csr|csr)
        run_tb "tb_agri_drone_csr" \
        "irun -sv -access +rwc $PROJ_ROOT/tb/tb_pkg.sv $PROJ_ROOT/rtl/control/agri_drone_csr.sv $PROJ_ROOT/tb/control/tb_agri_drone_csr.sv"
        ;;

    tb_agri_fsm_controller|fsm)
        run_tb "tb_agri_fsm_controller" \
        "irun -sv -access +rwc $PROJ_ROOT/tb/tb_pkg.sv $PROJ_ROOT/rtl/defs/agri_drone_pkg.sv $PROJ_ROOT/rtl/control/agri_fsm_controller.sv $PROJ_ROOT/tb/control/tb_agri_fsm_controller.sv"
        ;;

    tb_agri_drone_top|top|system)
        run_tb "tb_agri_drone_top" \
        "irun -sv -access +rwc \
            $PROJ_ROOT/tb/tb_pkg.sv \
            $PROJ_ROOT/rtl/defs/agri_drone_pkg.sv \
            $PROJ_ROOT/rtl/control/power_icg_cell.sv \
            $PROJ_ROOT/rtl/mem/axis_input_fifo.sv \
            $PROJ_ROOT/rtl/mem/image_buffer_25x25.sv \
            $PROJ_ROOT/rtl/mem/line_buffer_window_3x3.sv \
            $PROJ_ROOT/rtl/math/int8_mac_unit.sv \
            $PROJ_ROOT/rtl/math/pe_array_3x3.sv \
            $PROJ_ROOT/rtl/math/relu_activation.sv \
            $PROJ_ROOT/rtl/math/maxpool_2x2.sv \
            $PROJ_ROOT/rtl/core/conv_engine.sv \
            $PROJ_ROOT/rtl/core/dense_classifier.sv \
            $PROJ_ROOT/rtl/core/argmax_confidence.sv \
            $PROJ_ROOT/rtl/control/agri_drone_csr.sv \
            $PROJ_ROOT/rtl/control/agri_fsm_controller.sv \
            $PROJ_ROOT/rtl/top/agri_drone_top.sv \
            $PROJ_ROOT/tb/top/tb_agri_drone_top.sv"
        ;;

    all)
        echo ">>> Executing Complete Testbench Suite (14 Tests)..."
        $0 tb_power_icg_cell
        $0 tb_axis_input_fifo
        $0 tb_image_buffer_25x25
        $0 tb_line_buffer_window_3x3
        $0 tb_int8_mac_unit
        $0 tb_pe_array_3x3
        $0 tb_relu_activation
        $0 tb_maxpool_2x2
        $0 tb_conv_engine
        $0 tb_dense_classifier
        $0 tb_argmax_confidence
        $0 tb_agri_drone_csr
        $0 tb_agri_fsm_controller
        $0 tb_agri_drone_top
        ;;

    *)
        echo "Unknown target: $TB_TARGET"
        echo "Available options: compile_check, tb_power_icg_cell, tb_axis_input_fifo, tb_image_buffer_25x25, tb_line_buffer_window_3x3, tb_int8_mac_unit, tb_pe_array_3x3, tb_relu_activation, tb_maxpool_2x2, tb_conv_engine, tb_dense_classifier, tb_argmax_confidence, tb_agri_drone_csr, tb_agri_fsm_controller, tb_agri_drone_top, all"
        exit 1
        ;;
esac
