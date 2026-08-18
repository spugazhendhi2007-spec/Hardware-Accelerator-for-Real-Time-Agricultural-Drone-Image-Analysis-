#==============================================================================
# File: project.sdc
# Description: Synopsys Design Constraints (SDC) for Cadence Genus Synthesis
#              Target: 100 MHz System Clock (10.0 ns period)
# Project: Hardware Accelerator for Real-Time Agricultural Drone Image Analysis
#==============================================================================

# Set design context
current_design agri_drone_top

# 1. Primary Clock Definition (100 MHz -> 10.0 ns)
create_clock -name clk -period 10.0 [get_ports clk]

# 2. Clock Uncertainty and Jitter (0.2 ns)
set_clock_uncertainty 0.200 [get_clocks clk]
set_clock_transition 0.150 [get_clocks clk]

# 3. Input Delays (Assume 2.0 ns external setup margin)
set_input_delay -clock clk -max 2.000 [get_ports s_axis_tdata*]
set_input_delay -clock clk -min 0.500 [get_ports s_axis_tdata*]
set_input_delay -clock clk -max 2.000 [get_ports s_axis_tvalid]
set_input_delay -clock clk -min 0.500 [get_ports s_axis_tvalid]
set_input_delay -clock clk -max 2.000 [get_ports s_axis_tlast]
set_input_delay -clock clk -min 0.500 [get_ports s_axis_tlast]
set_input_delay -clock clk -max 2.000 [get_ports start]
set_input_delay -clock clk -min 0.500 [get_ports start]
set_input_delay -clock clk -max 2.000 [get_ports csr_wr_en]
set_input_delay -clock clk -max 2.000 [get_ports csr_rd_en]
set_input_delay -clock clk -max 2.000 [get_ports csr_addr*]
set_input_delay -clock clk -max 2.000 [get_ports csr_wdata*]

# 4. Output Delays (Assume 2.0 ns external setup margin)
set_output_delay -clock clk -max 2.000 [get_ports s_axis_tready]
set_output_delay -clock clk -min 0.500 [get_ports s_axis_tready]
set_output_delay -clock clk -max 2.000 [get_ports busy]
set_output_delay -clock clk -max 2.000 [get_ports done]
set_output_delay -clock clk -max 2.000 [get_ports disease_class*]
set_output_delay -clock clk -max 2.000 [get_ports disease_detected]
set_output_delay -clock clk -max 2.000 [get_ports confidence*]
set_output_delay -clock clk -max 2.000 [get_ports csr_rdata*]

# 5. Output Capacitance Loading (50 fF)
set_load 0.050 [all_outputs]

# 6. False Paths (Asynchronous Reset and Scan Test Bypass)
set_false_path -from [get_ports rst_n]
set_false_path -from [get_ports test_en]
