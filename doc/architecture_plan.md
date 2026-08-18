# ARCHITECTURAL DESIGN & PPA SPECIFICATION
## Hardware Accelerator for Real-Time Agricultural Drone Image Analysis ($25 \times 25$)

---

## 1. System Overview & Key Metrics

* **Target Application:** Real-time aerial drone edge-computing for agricultural foliage analysis, weed classification, and crop disease diagnosis (Leaf Blight, Leaf Rust, Nutrient Deficiency).
* **Input Resolution:** $25 \times 25$ pixels ($625$ bytes per frame, $U8 \in [0, 255]$).
* **Clock Frequency:** $100\text{ MHz} - 200\text{ MHz}$ ($10.0\text{ ns}$ target period).
* **Throughput:** $> 120\text{ Frames/sec}$ (full inference $< 1200\text{ clock cycles}$).
* **Dynamic Power Optimization:** Dynamic operand isolation, Integrated Clock Gating (ICG), INT8 datapath quantization, ReLU zero-skipping.
* **Area Footprint:** $< 25\text{k}$ NAND2 gate equivalent.

---

## 2. Complete Module Hierarchy & Interconnect Map

```text
agri_drone_top (Top-Level SoC/Accelerator Integration Wrapper)
│
├── [DEFS]
│   └── agri_drone_pkg.sv (Global dimensions, arithmetic types, FSM enums, clamp functions)
│
├── [POWER]
│   ├── u_icg_load (power_icg_cell.sv)  -> Gated clock for input buffer loading
│   ├── u_icg_conv (power_icg_cell.sv)  -> Gated clock for 2D convolution engine
│   └── u_icg_cls  (power_icg_cell.sv)  -> Gated clock for dense classification layer
│
├── [STORAGE & STREAMING]
│   ├── u_input_fifo   (axis_input_fifo.sv)        -> 32-entry elastic AXI4-Stream slave FIFO
│   ├── u_image_buffer (image_buffer_25x25.sv)     -> 625-byte dual-port SRAM / register buffer
│   └── u_line_buffer  (line_buffer_window_3x3.sv) -> 2D line buffer sliding 3x3 window generator
│
├── [COMPUTATION & CORE ENGINES]
│   ├── u_conv_engine (conv_engine.sv)
│   │   ├── u_pe_array (pe_array_3x3.sv) -> 9-PE parallel convolution compute array
│   │   │   └── 9x (int8_mac_unit.sv)     -> Pipelined S8xS8 MAC with operand isolation
│   │   ├── (relu_activation.sv)         -> Non-linear clamp: clamp(max(0, x), 0, 32767)
│   │   └── (maxpool_2x2.sv)             -> 2x2 spatial downsampler: max(max(a,b), max(c,d))
│   │
│   ├── u_dense_classifier (dense_classifier.sv) -> Fully connected layer computing 4 class scores
│   └── u_argmax           (argmax_confidence.sv) -> Multi-class ArgMax detector & Q8.8 confidence
│
└── [CONTROL & HOST MANAGEMENT]
    ├── u_csr (agri_drone_csr.sv)      -> CSR register bank (weights, biases, mode control)
    └── u_fsm (agri_fsm_controller.sv) -> Master 6-state sequencing controller
```

---

## 3. Subsystem Layer Specifications

### Layer 0: Common Definitions & Power Primitives
* **`agri_drone_pkg.sv`**: Defines $25 \times 25$ dimensions, kernel size $3 \times 3$, pooled feature count $121$, disease class enums (`CLASS_HEALTHY=00`, `CLASS_LEAF_BLIGHT=01`, `CLASS_LEAF_RUST=10`, `CLASS_NUTRIENT_DEFICIENT=11`).
* **`power_icg_cell.sv`**: Glitch-free negative-latch integrated clock gating cell with scan test bypass.

### Layer 1: Memory & Buffering
* **`axis_input_fifo.sv`**: Ingests streaming pixels over AXI-Stream slave interface (`s_axis_tdata`, `s_axis_tvalid`, `s_axis_tready`, `s_axis_tlast`).
* **`image_buffer_25x25.sv`**: 625-byte dual-port storage for $25 \times 25$ image frame.
* **`line_buffer_window_3x3.sv`**: Contains two 25-pixel line buffers + 3-tap shift registers, generating $3 \times 3$ sliding windows ($p_0 \dots p_8$) on the fly (producing exactly $23 \times 23 = 529$ valid windows per frame).

### Layer 2: Arithmetic Units
* **`int8_mac_unit.sv`**: Multiplies signed 8-bit centered pixel $S8$ with signed 8-bit weight $S8$, producing $S16$ intermediate product, accumulated into $S24$ accumulator. Includes operand isolation.
* **`pe_array_3x3.sv`**: Computes $\sum_{i=0}^8 p_i \times w_i + \text{bias}$ via parallel multipliers and tree-adder reduction.
* **`relu_activation.sv`**: Saturating non-linear activation unit ($S24 \rightarrow S16$).
* **`maxpool_2x2.sv`**: Spatial $2 \times 2$ downsampler ($S16$).

### Layer 3: Core Processing Engines
* **`conv_engine.sv`**: Orchestrates 2D convolution and $2 \times 2$ Max-Pooling over the 529 windows, outputting 121 pooled features.
* **`dense_classifier.sv`**: Multiplies 121 pooled features with $4 \times 121$ classification weights to produce 4 class scores ($S_0 \dots S_3$).
* **`argmax_confidence.sv`**: Identifies highest scoring class and computes normalized Q8.8 fixed-point confidence ($[128, 256] \rightarrow [0.5, 1.0]$).

### Layer 4: Control & Top Integration
* **`agri_drone_csr.sv`**: Memory-mapped host interface for programmable convolution kernels, biases, control strobes, and reading detection outputs.
* **`agri_fsm_controller.sv`**: Sequences states: `IDLE` $\rightarrow$ `LOAD_STREAM` $\rightarrow$ `CONV_POOL` $\rightarrow$ `CLASSIFY` $\rightarrow$ `ARGMAX_CONF` $\rightarrow$ `DONE`.
* **`agri_drone_top.sv`**: Top-level accelerator integration wrapper.

---

## 4. Register Memory Map (`agri_drone_csr.sv`)

| Offset | Register Name | R/W | Description |
| :--- | :--- | :---: | :--- |
| `0x00` | `CTRL_REG` | R/W | `bit[0]`: start pulse (auto-clearing), `bit[1]`: soft_rst, `bit[3]`: clk_gate_en |
| `0x04` | `STATUS_REG` | RO | `bit[0]`: busy, `bit[1]`: done, `bit[2]`: disease_detected |
| `0x08` | `RESULT_REG` | RO | `bits[1:0]`: disease_class (`00`=Healthy, `01`=Blight, `10`=Rust, `11`=Deficiency), `bits[31:16]`: confidence (Q8.8) |
| `0x0C` | `CONV_BIAS_REG`| R/W | `bits[23:0]`: signed 24-bit convolution bias |
| `0x10` | `CONV_W0123` | R/W | Packed weights $w_0, w_1, w_2, w_3$ ($4 \times S8$) |
| `0x14` | `CONV_W4567` | R/W | Packed weights $w_4, w_5, w_6, w_7$ ($4 \times S8$) |
| `0x18` | `CONV_W8` | R/W | Packed weight $w_8$ ($S8$) |
| `0x1C` | `DENSE_BIAS0` | R/W | Class 0 (Healthy) dense bias ($S24$) |
| `0x20` | `DENSE_BIAS1` | R/W | Class 1 (Leaf Blight) dense bias ($S24$) |
| `0x24` | `DENSE_BIAS2` | R/W | Class 2 (Leaf Rust) dense bias ($S24$) |
| `0x28` | `DENSE_BIAS3` | R/W | Class 3 (Nutrient Deficiency) dense bias ($S24$) |
