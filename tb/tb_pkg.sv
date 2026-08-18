//=============================================================================
// File: tb_pkg.sv
// Description: Master Verification Package for Agricultural Drone Accelerator
//              Contains test counters, assertion helpers, and summary formatters.
// Standard: SystemVerilog IEEE 1800
//=============================================================================

`timescale 1ns/1ps

package tb_pkg;

    // Test execution counters
    int corner_pass_count = 0;
    int corner_fail_count = 0;
    int normal_pass_count = 0;
    int normal_fail_count = 0;
    int stress_pass_count = 0;
    int stress_fail_count = 0;

    int total_pass_count  = 0;
    int total_fail_count  = 0;
    int total_test_count  = 0;

    // Reset counters before each testbench run
    function void reset_counters();
        corner_pass_count = 0;
        corner_fail_count = 0;
        normal_pass_count = 0;
        normal_fail_count = 0;
        stress_pass_count = 0;
        stress_fail_count = 0;
        total_pass_count  = 0;
        total_fail_count  = 0;
        total_test_count  = 0;
    endfunction

    // Record individual test results
    function void record_result(input string test_type, input bit passed, input string test_name = "");
        total_test_count++;
        if (passed) begin
            total_pass_count++;
            case (test_type)
                "CORNER": corner_pass_count++;
                "NORMAL": normal_pass_count++;
                "STRESS": stress_pass_count++;
                default:  normal_pass_count++;
            endcase
            $display("[TB_PKG] [PASS] [%-6s] %s", test_type, test_name);
        end else begin
            total_fail_count++;
            case (test_type)
                "CORNER": corner_fail_count++;
                "NORMAL": normal_fail_count++;
                "STRESS": stress_fail_count++;
                default:  normal_fail_count++;
            endcase
            $display("[TB_PKG] [FAIL] [%-6s] %s (MISMATCH/ERROR)", test_type, test_name);
        end
    endfunction

    // Standardized Summary Reporting Task
    task print_summary(input string module_name);
        $display("\n================================================================");
        $display("TEST SUMMARY : %s", module_name);
        $display("================================================================");
        $display("Corner Tests Passed : %0d / 5", corner_pass_count);
        $display("Normal Tests Passed : %0d / 2", normal_pass_count);
        $display("Stress Tests Passed : %0d / 1", stress_pass_count);
        $display("----------------------------------------------------------------");
        $display("Total Tests Run     : %0d", total_test_count);
        $display("Passed Checks       : %0d", total_pass_count);
        $display("Failed Checks       : %0d", total_fail_count);
        $display("================================================================");
        if (total_fail_count == 0 && total_pass_count >= 8) begin
            $display("FINAL STATUS        : [ TEST STATUS : PASS ]");
            $display("================================================================\n");
        end else begin
            $display("FINAL STATUS        : [ TEST STATUS : FAIL ]");
            $display("================================================================\n");
        end
    endtask

endpackage: tb_pkg
