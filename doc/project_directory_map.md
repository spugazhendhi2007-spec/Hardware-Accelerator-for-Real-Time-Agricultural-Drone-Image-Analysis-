# Project Directory Map & Fast Access Guide
## Hardware Accelerator for Real-Time Agricultural Drone Image Analysis ($25 \times 25$)

This document provides a single-click navigation index to every design file, testbench, synthesis script, constraint file, and simulation command in the workspace.

---

## 1. Documentation & Architecture Plan
* [doc/architecture_plan.md](file:///c:/Users/VLSI%20LAB/.gemini/antigravity-ide/scratch/drone_acc/doc/architecture_plan.md) — Detailed architectural plan, datapath diagrams, register maps, and PPA strategies.
* [master_prompt.txt](file:///c:/Users/VLSI%20LAB/.gemini/antigravity-ide/scratch/drone_acc/master_prompt.txt) — Master ASIC front-end engineering prompt.
* [README.md](file:///c:/Users/VLSI%20LAB/.gemini/antigravity-ide/scratch/drone_acc/README.md) — High-level project summary and structure.

---

## 2. Synthesizable SystemVerilog RTL Source (`rtl/`)

### Definitions & Power
* [rtl/defs/agri_drone_pkg.sv](file:///c:/Users/VLSI%20LAB/.gemini/antigravity-ide/scratch/drone_acc/rtl/defs/agri_drone_pkg.sv) — Global types, 25x25 dimensions, FSM enums.
* [rtl/control/power_icg_cell.sv](file:///c:/Users/VLSI%20LAB/.gemini/antigravity-ide/scratch/drone_acc/rtl/control/power_icg_cell.sv) — Glitch-free clock gating cell.

### Storage & Buffers
* [rtl/mem/axis_input_fifo.sv](file:///c:/Users/VLSI%20LAB/.gemini/antigravity-ide/scratch/drone_acc/rtl/mem/axis_input_fifo.sv) — AXI4-Stream input elastic FIFO buffer.
* [rtl/mem/image_buffer_25x25.sv](file:///c:/Users/VLSI%20LAB/.gemini/antigravity-ide/scratch/drone_acc/rtl/mem/image_buffer_25x25.sv) — 625-byte dual-port SRAM / register buffer.
* [rtl/mem/line_buffer_window_3x3.sv](file:///c:/Users/VLSI%20LAB/.gemini/antigravity-ide/scratch/drone_acc/rtl/mem/line_buffer_window_3x3.sv) — 2D line buffer sliding 3x3 window generator.

### Arithmetic Units
* [rtl/math/int8_mac_unit.sv](file:///c:/Users/VLSI%20LAB/.gemini/antigravity-ide/scratch/drone_acc/rtl/math/int8_mac_unit.sv) — Pipelined INT8 MAC with operand isolation.
* [rtl/math/pe_array_3x3.sv](file:///c:/Users/VLSI%20LAB/.gemini/antigravity-ide/scratch/drone_acc/rtl/math/pe_array_3x3.sv) — 3x3 9-PE parallel convolution compute array.
* [rtl/math/relu_activation.sv](file:///c:/Users/VLSI%20LAB/.gemini/antigravity-ide/scratch/drone_acc/rtl/math/relu_activation.sv) — Clamped ReLU activation unit.
* [rtl/math/maxpool_2x2.sv](file:///c:/Users/VLSI%20LAB/.gemini/antigravity-ide/scratch/drone_acc/rtl/math/maxpool_2x2.sv) — Spatial 2x2 Max-Pooling downsampler.

### Core Processing Engines
* [rtl/core/conv_engine.sv](file:///c:/Users/VLSI%20LAB/.gemini/antigravity-ide/scratch/drone_acc/rtl/core/conv_engine.sv) — 2D Convolution orchestrator & feature extractor.
* [rtl/core/dense_classifier.sv](file:///c:/Users/VLSI%20LAB/.gemini/antigravity-ide/scratch/drone_acc/rtl/core/dense_classifier.sv) — Fully Connected 4-class score computer.
* [rtl/core/argmax_confidence.sv](file:///c:/Users/VLSI%20LAB/.gemini/antigravity-ide/scratch/drone_acc/rtl/core/argmax_confidence.sv) — ArgMax class detector and Q8.8 confidence unit.

### Control & Top Integration
* [rtl/control/agri_drone_csr.sv](file:///c:/Users/VLSI%20LAB/.gemini/antigravity-ide/scratch/drone_acc/rtl/control/agri_drone_csr.sv) — CSR register bank with programmable weights & biases.
* [rtl/control/agri_fsm_controller.sv](file:///c:/Users/VLSI%20LAB/.gemini/antigravity-ide/scratch/drone_acc/rtl/control/agri_fsm_controller.sv) — Master 6-state sequencing controller FSM.
* [rtl/top/agri_drone_top.sv](file:///c:/Users/VLSI%20LAB/.gemini/antigravity-ide/scratch/drone_acc/rtl/top/agri_drone_top.sv) — Top-level accelerator integration wrapper.

---

## 3. Self-Checking Verification Testbenches (`tb/`)

* [tb/tb_pkg.sv](file:///c:/Users/VLSI%20LAB/.gemini/antigravity-ide/scratch/drone_acc/tb/tb_pkg.sv) — Shared verification reporting utilities and assertion tasks.
* [tb/control/tb_power_icg_cell.sv](file:///c:/Users/VLSI%20LAB/.gemini/antigravity-ide/scratch/drone_acc/tb/control/tb_power_icg_cell.sv) — 8-test self-checking TB for ICG cell.
* [tb/mem/tb_axis_input_fifo.sv](file:///c:/Users/VLSI%20LAB/.gemini/antigravity-ide/scratch/drone_acc/tb/mem/tb_axis_input_fifo.sv) — 8-test self-checking TB for AXI FIFO.
* [tb/mem/tb_image_buffer_25x25.sv](file:///c:/Users/VLSI%20LAB/.gemini/antigravity-ide/scratch/drone_acc/tb/mem/tb_image_buffer_25x25.sv) — 8-test self-checking TB for 25x25 image buffer.
* [tb/mem/tb_line_buffer_window_3x3.sv](file:///c:/Users/VLSI%20LAB/.gemini/antigravity-ide/scratch/drone_acc/tb/mem/tb_line_buffer_window_3x3.sv) — 8-test self-checking TB for 3x3 line buffer.
* [tb/math/tb_int8_mac_unit.sv](file:///c:/Users/VLSI%20LAB/.gemini/antigravity-ide/scratch/drone_acc/tb/math/tb_int8_mac_unit.sv) — 8-test self-checking TB for INT8 MAC.
* [tb/math/tb_pe_array_3x3.sv](file:///c:/Users/VLSI%20LAB/.gemini/antigravity-ide/scratch/drone_acc/tb/math/tb_pe_array_3x3.sv) — 8-test self-checking TB for 3x3 PE array.
* [tb/math/tb_relu_activation.sv](file:///c:/Users/VLSI%20LAB/.gemini/antigravity-ide/scratch/drone_acc/tb/math/tb_relu_activation.sv) — 8-test self-checking TB for ReLU unit.
* [tb/math/tb_maxpool_2x2.sv](file:///c:/Users/VLSI%20LAB/.gemini/antigravity-ide/scratch/drone_acc/tb/math/tb_maxpool_2x2.sv) — 8-test self-checking TB for 2x2 MaxPool.
* [tb/core/tb_conv_engine.sv](file:///c:/Users/VLSI%20LAB/.gemini/antigravity-ide/scratch/drone_acc/tb/core/tb_conv_engine.sv) — 8-test self-checking TB for Conv2D engine.
* [tb/core/tb_dense_classifier.sv](file:///c:/Users/VLSI%20LAB/.gemini/antigravity-ide/scratch/drone_acc/tb/core/tb_dense_classifier.sv) — 8-test self-checking TB for Dense classifier.
* [tb/core/tb_argmax_confidence.sv](file:///c:/Users/VLSI%20LAB/.gemini/antigravity-ide/scratch/drone_acc/tb/core/tb_argmax_confidence.sv) — 8-test self-checking TB for ArgMax unit.
* [tb/control/tb_agri_drone_csr.sv](file:///c:/Users/VLSI%20LAB/.gemini/antigravity-ide/scratch/drone_acc/tb/control/tb_agri_drone_csr.sv) — 8-test self-checking TB for CSR bank.
* [tb/control/tb_agri_fsm_controller.sv](file:///c:/Users/VLSI%20LAB/.gemini/antigravity-ide/scratch/drone_acc/tb/control/tb_agri_fsm_controller.sv) — 8-test self-checking TB for FSM controller.
* [tb/top/tb_agri_drone_top.sv](file:///c:/Users/VLSI%20LAB/.gemini/antigravity-ide/scratch/drone_acc/tb/top/tb_agri_drone_top.sv) — **Master System Testbench** (End-to-end multi-frame validation).

---

## 4. Scripts, Constraints & Simulation Commands

* [scripts/irun_cmds.txt](file:///c:/Users/VLSI%20LAB/.gemini/antigravity-ide/scratch/drone_acc/scripts/irun_cmds.txt) — Master list of executable Cadence `irun` simulation and coverage commands.
* [scripts/genus.tcl](file:///c:/Users/VLSI%20LAB/.gemini/antigravity-ide/scratch/drone_acc/scripts/genus.tcl) — Cadence Genus synthesis script.
* [scripts/lec.tcl](file:///c:/Users/VLSI%20LAB/.gemini/antigravity-ide/scratch/drone_acc/scripts/lec.tcl) — Cadence Conformal LEC formal equivalence script.
* [scripts/git_sync.ps1](file:///c:/Users/VLSI%20LAB/.gemini/antigravity-ide/scratch/drone_acc/scripts/git_sync.ps1) — Git automatic staging, commit, and push script.
* [constraints/project.sdc](file:///c:/Users/VLSI%20LAB/.gemini/antigravity-ide/scratch/drone_acc/constraints/project.sdc) — SDC timing constraints ($100\text{ MHz}$ / $10.0\text{ ns}$).
