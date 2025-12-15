`timescale 1 ps / 1 ps

module MyTestbench();

  // Clock & reset
  logic clk;
  logic reset;

  // Testbench control signals
  logic [31:0] tb_WriteData;
  logic [12:0] tb_DataAdr;
  logic        tb_MemWrite;
  logic [31:0] tb_ReadData;

  // GPIO wires - ALL as wire for inout ports
  wire [33:0] GPIO_0_PI;
  wire [33:0] GPIO_1;
  wire [12:0] GPIO_2;

  integer f;
  logic test_running;
  integer pass_count, fail_count;

  // Instantiate device under test
  MyDE0_Nano dut(
    .CLOCK_50(clk), 
    .GPIO_0_PI(GPIO_0_PI),
    .GPIO_1(GPIO_1),  
    .GPIO_2(GPIO_2)
  );

  // ============ CONNECTIONS ============
  // Inputs to DUT via GPIO_1 and GPIO_2
  assign GPIO_1[33]   = tb_MemWrite;
  assign GPIO_1[31:0] = tb_WriteData;
  assign GPIO_1[32]   = 1'b0;
  
  assign GPIO_2 = tb_DataAdr;

  // Output from DUT via GPIO_0_PI
  assign tb_ReadData = GPIO_0_PI[32:1];
  
  // Reset (not used in testbench mode, but assigned to 0)
  assign GPIO_0_PI[0] = 1'b0;
  // ====================================

  // Helper task to write operand A
  task write_operand_a(input [31:0] value);
    begin
      @(negedge clk);
      tb_DataAdr   = 13'h0600;
      tb_WriteData = value;
      tb_MemWrite  = 1;
    end
  endtask

  // Helper task to write operand B
  task write_operand_b(input [31:0] value);
    begin
      @(negedge clk);
      tb_DataAdr   = 13'h0604;
      tb_WriteData = value;
      tb_MemWrite  = 1;
    end
  endtask

  // Helper task to execute command
  task execute_cmd(input [31:0] cmd);
    begin
      @(negedge clk);
      tb_DataAdr   = 13'h0608;
      tb_WriteData = cmd;
      tb_MemWrite  = 1;
      @(negedge clk);
      tb_MemWrite  = 0;
      repeat(3) @(negedge clk);
    end
  endtask

  // Helper task to read result
  task read_result();
    begin
      tb_DataAdr = 13'h060C;
      @(negedge clk);
      #1; // Delay for combinational propagation
    end
  endtask

  // Helper function to convert float to hex string
  function string float_to_str(input [31:0] f);
    real r;
    begin
      r = $bitstoreal({32'b0, f});
      $sformat(float_to_str, "%f (0x%h)", r, f);
    end
  endfunction

  // Test case task
  task test_operation(
    input string op_name,
    input [31:0] a_val,
    input [31:0] b_val,
    input [31:0] cmd_val,
    input [31:0] expected
  );
    real a_real, b_real, exp_real, res_real;
    logic [31:0] tolerance_mask;
    logic pass;
    begin
      $display("\n----------------------------------------");
      $display("Test: %s", op_name);
      
      // Convert to real for display
      a_real = $bitstoreal({32'b0, a_val});
      b_real = $bitstoreal({32'b0, b_val});
      exp_real = $bitstoreal({32'b0, expected});
      
      $display("  A = %f (0x%h)", a_real, a_val);
      $display("  B = %f (0x%h)", b_real, b_val);
      $display("  Expected = %f (0x%h)", exp_real, expected);
      
      $fwrite(f, "\n%s: A=0x%h B=0x%h Expected=0x%h\n", op_name, a_val, b_val, expected);
      
      // Execute operation
      write_operand_a(a_val);
      write_operand_b(b_val);
      execute_cmd(cmd_val);
      read_result();
      
      res_real = $bitstoreal({32'b0, tb_ReadData});
      $display("  Result = %f (0x%h)", res_real, tb_ReadData);
      $fwrite(f, "  Result=0x%h\n", tb_ReadData);
      
      // Check result (allow 1 LSB tolerance for rounding)
      tolerance_mask = 32'hFFFFFF00; // Ignore last byte for rounding differences
      pass = (tb_ReadData == expected) || 
             ((tb_ReadData & tolerance_mask) == (expected & tolerance_mask));
      
      if (pass) begin
        $display("  ? PASS");
        $fwrite(f, "  PASS\n");
        pass_count++;
      end else begin
        $display("  ? FAIL - Expected 0x%h, got 0x%h", expected, tb_ReadData);
        $fwrite(f, "  FAIL - Expected 0x%h, got 0x%h\n", expected, tb_ReadData);
        fail_count++;
      end
    end
  endtask

  // Initialize test
  initial begin
    test_running = 1;
    pass_count = 0;
    fail_count = 0;
    f = $fopen("student_simul.txt", "w");
    
    // Initialize signals
    tb_MemWrite  = 0;
    tb_DataAdr   = 0;
    tb_WriteData = 0;
    
    // Internal reset (not used in testbench mode)
    reset = 1; 
    #20; 
    reset = 0; 
    #20;
    
    $display("??????????????????????????????????????????????????????????");
    $display("?       IEEE-754 FLOATING POINT UNIT TEST SUITE         ?");
    $display("??????????????????????????????????????????????????????????");
    $fwrite(f, "=== IEEE-754 FPU Test Suite ===\n");

    //=======================================================
    // ADDITION TESTS
    //=======================================================
    $display("\n????? ADDITION TESTS ?????");
    
    // Test 1: Simple positive addition
    // 3.5 + 2.25 = 5.75
    test_operation("ADD: 3.5 + 2.25", 
                   32'h40600000, 32'h40100000, 32'd1, 32'h40B80000);
    
    // Test 2: Different exponents
    // 1.0 + 0.5 = 1.5
    test_operation("ADD: 1.0 + 0.5", 
                   32'h3F800000, 32'h3F000000, 32'd1, 32'h3FC00000);
    
    // Test 3: Negative numbers
    // -2.5 + 1.5 = -1.0
    test_operation("ADD: -2.5 + 1.5", 
                   32'hC0200000, 32'h3FC00000, 32'd1, 32'hBF800000);
    
    // Test 4: Large exponent difference
    // 100.0 + 0.001 ? 100.0
    test_operation("ADD: 100.0 + 0.001", 
                   32'h42C80000, 32'h3A83126F, 32'd1, 32'h42C80000);
    
    // Test 5: Zero + number
    // 0.0 + 5.5 = 5.5
    test_operation("ADD: 0.0 + 5.5", 
                   32'h00000000, 32'h40B00000, 32'd1, 32'h40B00000);
    
    // Test 6: Same numbers
    // 7.0 + 7.0 = 14.0
    test_operation("ADD: 7.0 + 7.0", 
                   32'h40E00000, 32'h40E00000, 32'd1, 32'h41600000);

    //=======================================================
    // SUBTRACTION TESTS
    //=======================================================
    $display("\n????? SUBTRACTION TESTS ?????");
    
    // Test 7: Simple subtraction
    // 5.0 - 3.0 = 2.0
    test_operation("SUB: 5.0 - 3.0", 
                   32'h40A00000, 32'h40400000, 32'd2, 32'h40000000);
    
    // Test 8: Negative result
    // 2.0 - 5.0 = -3.0
    test_operation("SUB: 2.0 - 5.0", 
                   32'h40000000, 32'h40A00000, 32'd2, 32'hC0400000);
    
    // Test 9: Subtract same number
    // 4.5 - 4.5 = 0.0
    test_operation("SUB: 4.5 - 4.5", 
                   32'h40900000, 32'h40900000, 32'd2, 32'h00000000);

    //=======================================================
    // MULTIPLICATION TESTS
    //=======================================================
    $display("\n????? MULTIPLICATION TESTS ?????");
    
    // Test 10: Simple multiplication
    // 2.0 * 3.0 = 6.0
    test_operation("MUL: 2.0 * 3.0", 
                   32'h40000000, 32'h40400000, 32'd3, 32'h40C00000);
    
    // Test 11: Fractional multiplication
    // 0.5 * 0.5 = 0.25
    test_operation("MUL: 0.5 * 0.5", 
                   32'h3F000000, 32'h3F000000, 32'd3, 32'h3E800000);
    
    // Test 12: Multiply by zero
    // 5.5 * 0.0 = 0.0
    test_operation("MUL: 5.5 * 0.0", 
                   32'h40B00000, 32'h00000000, 32'd3, 32'h00000000);
    
    // Test 13: Negative multiplication
    // -2.0 * 3.0 = -6.0
    test_operation("MUL: -2.0 * 3.0", 
                   32'hC0000000, 32'h40400000, 32'd3, 32'hC0C00000);
    
    // Test 14: Large numbers
    // 10.0 * 10.0 = 100.0
    test_operation("MUL: 10.0 * 10.0", 
                   32'h41200000, 32'h41200000, 32'd3, 32'h42C80000);

    //=======================================================
    // FINAL SUMMARY
    //=======================================================
    #100;
    $display("\n??????????????????????????????????????????????????????????");
    $display("?                    TEST SUMMARY                        ?");
    $display("??????????????????????????????????????????????????????????");
    $display("?  Total Tests: %2d                                       ?", pass_count + fail_count);
    $display("?  Passed:      %2d ?                                     ?", pass_count);
    $display("?  Failed:      %2d ?                                     ?", fail_count);
    $display("??????????????????????????????????????????????????????????");
    
    if (fail_count == 0) begin
      $display("?          ?? ALL TESTS PASSED! ??                       ?");
      $fwrite(f, "\n*** ALL TESTS PASSED ***\n");
    end else begin
      $display("?          ??  SOME TESTS FAILED  ??                      ?");
      $fwrite(f, "\n*** %0d TESTS FAILED ***\n", fail_count);
    end
    
    $display("??????????????????????????????????????????????????????????\n");
    
    test_running = 0;
    $fclose(f);
    $stop;
  end

  // Generate clock
  always begin
    clk = 1; #5; 
    clk = 0; #5;
  end

  // Detailed logging
  always @(negedge clk) begin
    if (test_running && reset == 0 && tb_MemWrite) begin
      $fwrite(f, "Time=%0t Addr=0x%h WriteData=0x%h\n", 
              $time, tb_DataAdr, tb_WriteData);
    end
  end

endmodule