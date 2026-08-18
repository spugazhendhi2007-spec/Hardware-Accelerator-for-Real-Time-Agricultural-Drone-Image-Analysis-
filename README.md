# Hardware Accelerator for Real-Time Agricultural Drone Image Analysis

SystemVerilog-based ASIC Front-End RTL Design, Verification Suite, and Synthesis-Ready Implementation for Real-Time Agricultural Drone Image Processing ($25 \times 25$ Pixels).

---

## 📚 Quick Navigation Index

* 📋 **Architecture Specification:** [doc/architecture_plan.md](doc/architecture_plan.md)
* 🗺️ **Full Project Directory Map:** [doc/project_directory_map.md](doc/project_directory_map.md)
* ⚙️ **Simulation Commands:** [scripts/irun_cmds.txt](scripts/irun_cmds.txt)
* 🔨 **Synthesis Script:** [scripts/genus.tcl](scripts/genus.tcl)
* ⚖️ **Formal LEC Script:** [scripts/lec.tcl](scripts/lec.tcl)
* ⏱️ **Timing Constraints:** [constraints/project.sdc](constraints/project.sdc)
* 📜 **Master Prompt:** [master_prompt.txt](master_prompt.txt)

---

## 📁 Directory Structure

```text
├── doc/           # Architecture plan and project directory navigation maps
├── rtl/           # Synthesizable SystemVerilog (IEEE 1800) RTL source files
│   ├── defs/      # Global parameters, 25x25 dimensions, types, enums
│   ├── control/   # ICG clock gating, CSR registers, master sequencing FSM
│   ├── mem/       # AXI Stream FIFO, 25x25 image buffer, 3x3 line buffer
│   ├── math/      # INT8 MAC, 3x3 PE array, ReLU activation, 2x2 MaxPool
│   ├── core/      # 2D Conv engine, Dense classifier, ArgMax / Confidence unit
│   └── top/       # Top-level accelerator integration wrapper
├── tb/            # SystemVerilog self-checking testbenches (5 Corner + 2 Normal + 1 Stress)
│   ├── defs/      # Package testbenches
│   ├── control/   # Control subsystem testbenches
│   ├── mem/       # Storage subsystem testbenches
│   ├── math/      # Math unit testbenches
│   ├── core/      # Core processing engine testbenches
│   └── top/       # Master top-level system testbench
├── scripts/       # Cadence irun commands, Genus TCL, LEC TCL, and git sync script
├── constraints/   # SDC timing constraints (100 MHz / 10.0 ns)
├── work/          # Cadence simulation execution directory
├── reports/       # Simulation, synthesis, and formal reports
└── logs/          # EDA tool execution logs
```

---

## ⚡ Execution Commands

### 1. Compile & Run Master System Testbench
```bash
cd work && irun -sv -access +rwc \
    ../tb/tb_pkg.sv \
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
    ../tb/top/tb_agri_drone_top.sv
```

### 2. Run Cadence Genus Synthesis
```bash
cd work && genus -f ../scripts/genus.tcl
```
