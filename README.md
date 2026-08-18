# Hardware Accelerator for Real-Time Agricultural Drone Image Analysis

SystemVerilog-based ASIC Front-End RTL Design, Verification, and Synthesis-Ready Implementation for Real-Time Agricultural Drone Image Processing.

## Project Structure

```text
├── rtl/           # Synthesizable SystemVerilog (IEEE 1800) RTL design source files
├── tb/            # SystemVerilog self-checking testbenches (5 Corner + 2 Normal + 1 Ultimate Stress test)
├── scripts/       # Cadence simulation run commands (irun_cmds.txt) & Genus synthesis scripts (genus.tcl)
├── constraints/   # SDC timing constraints (project.sdc)
├── work/          # Cadence simulation execution directory
├── reports/       # Simulation and synthesis reports
└── logs/          # EDA tool execution logs
```

## Verification Standard
Every module features a dedicated self-checking testbench adhering to the standard 8-test suite (5 Corner Cases, 2 Normal Operating Scenarios, 1 Randomized Ultimate Stress Test) with automated summary counters and assertions.
