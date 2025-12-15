`timescale 1 ps / 1 ps

module MyTestbench();

  // Clock & reset
  logic clk;
  logic reset;

  // Signaux de contrôle du testbench
  logic [31:0] tb_WriteData;
  logic [12:0] tb_DataAdr;
  logic        tb_MemWrite;
  logic [31:0] tb_ReadData;

  // GPIO wires - TOUS en wire pour les ports inout
  wire [33:0] GPIO_0_PI;
  wire [33:0] GPIO_1;
  wire [12:0] GPIO_2;

  integer f;
  logic test_running;

  // Instantiate device under test
  MyDE0_Nano dut(
    .CLOCK_50(clk), 
    .GPIO_0_PI(GPIO_0_PI),
    .GPIO_1(GPIO_1),  
    .GPIO_2(GPIO_2)
  );

  // ============ CONNEXIONS ============
  // Entrées au DUT via GPIO_1 et GPIO_2
  assign GPIO_1[33]   = tb_MemWrite;
  assign GPIO_1[31:0] = tb_WriteData;
  assign GPIO_1[32]   = 1'b0;
  
  assign GPIO_2 = tb_DataAdr;

  // Sortie du DUT via GPIO_0_PI
  assign tb_ReadData = GPIO_0_PI[32:1];
  
  // Reset (non utilisé en mode testbench, mais assigné à 0)
  assign GPIO_0_PI[0] = 1'b0;
  // ====================================

  // Initialize test
  initial begin
    test_running = 1;
    f = $fopen("student_simul.txt", "w");
    
    // Initialiser
    tb_MemWrite  = 0;
    tb_DataAdr   = 0;
    tb_WriteData = 0;
    
    // Reset interne (pas utilisé car le DUT ignore le reset en mode testbench)
    reset = 1; 
    #20; 
    reset = 0; 
    #20;
    
    $display("=== Starting FPU Test ===");
    $fwrite(f, "=== Starting FPU Test ===\n");

    // Écrire A = 10
    @(negedge clk);
    tb_DataAdr   = 13'h0600;
    tb_WriteData = 32'd10;
    tb_MemWrite  = 1;
    $display("Time %0t: Writing A=10 to 0x600", $time);

    // Écrire B = 20
    @(negedge clk);
    tb_DataAdr   = 13'h0604;
    tb_WriteData = 32'd20;
    tb_MemWrite  = 1;
    $display("Time %0t: Writing B=20 to 0x604", $time);

    // Écrire CMD = 1 (addition)
    @(negedge clk);
    tb_DataAdr   = 13'h0608;
    tb_WriteData = 32'd1;
    tb_MemWrite  = 1;
    $display("Time %0t: Writing CMD=1 (ADD) to 0x608", $time);

    // Arrêter écriture
    @(negedge clk);
    tb_MemWrite  = 0;
    
    // Attendre que le calcul se fasse
    repeat(3) @(negedge clk);

    // Lire résultat
    tb_DataAdr = 13'h060C;
    @(negedge clk);
    #1;  // Délai pour propagation combinatoire
    
    $display("Time %0t: tb_ReadData = %d (expected 30)", $time, tb_ReadData);
    $fwrite(f, "\nFPU result: %d\n", tb_ReadData);
    
    // Vérification
    if (tb_ReadData === 32'd30) begin
        $display("========================================");
        $display("*** TEST PASSED ***");
        $display("========================================");
        $fwrite(f, "*** TEST PASSED ***\n");
    end else if (tb_ReadData === 32'bx || tb_ReadData === 32'bz) begin
        $display("*** TEST FAILED - ReadData is undefined ***");
        $fwrite(f, "*** TEST FAILED - ReadData is X/Z ***\n");
    end else begin
        $display("*** TEST FAILED - Expected 30, got %d ***", tb_ReadData);
        $fwrite(f, "*** TEST FAILED - Expected 30, got %d ***\n", tb_ReadData);
    end

    #100;
    $display("=== Test Complete ===");
    
    test_running = 0;
    $fclose(f);
    $stop;
  end

  // Generate clock
  always begin
    clk = 1; #5; 
    clk = 0; #5;
  end

  // Log
  always @(negedge clk) begin
    if (test_running && reset == 0) begin
      $fwrite(f, "Time=%0t Addr=%h WData=%d RData=%d WE=%b\n", 
              $time, tb_DataAdr, tb_WriteData, tb_ReadData, tb_MemWrite);
    end
  end

endmodule