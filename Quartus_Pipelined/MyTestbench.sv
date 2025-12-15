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

  // GPIO wires
  wire [33:0] GPIO_0_PI;
  wire [33:0] GPIO_1;
  wire [12:0] GPIO_2;

  integer f;

  // Instantiate device under test
  MyDE0_Nano dut(
    .CLOCK_50(clk), 
    .GPIO_0_PI(GPIO_0_PI),
    .GPIO_1(GPIO_1),  
    .GPIO_2(GPIO_2)
  );

  // ============ CONNEXIONS CORRIGÉES ============
  // Reset sur bit isolé
  assign GPIO_0_PI[0] = reset;
  
  // SORTIES du testbench ? ENTRÉES du DUT
  assign GPIO_1[33]    = tb_MemWrite;
  assign GPIO_1[31:0]  = tb_WriteData;
  assign GPIO_2        = tb_DataAdr;

  // ENTRÉE du testbench ? SORTIE du DUT (bits [33:2] pour données 32-bit)
  assign tb_ReadData = {GPIO_0_PI[33:2]};
  // =============================================

  // Initialize test
  initial begin
    f = $fopen("student_simul.txt", "w");
    
    // Initialiser
    tb_MemWrite  = 0;
    tb_DataAdr   = 0;
    tb_WriteData = 0;
    
    // Reset
    reset = 1; 
    #20; 
    reset = 0; 
    #20;
    
    $display("=== Starting FPU Test ===");

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

    // Écrire CMD = 1
    @(negedge clk);
    tb_DataAdr   = 13'h0608;
    tb_WriteData = 32'd1;
    tb_MemWrite  = 1;
    $display("Time %0t: Writing CMD=1 to 0x608", $time);

    // Arrêter écriture et attendre calcul
    @(negedge clk);
    tb_MemWrite  = 0;
    
    @(negedge clk);

    // Lire résultat
    tb_DataAdr   = 13'h060C;
    @(negedge clk);
    
    // Attendre propagation combinatoire
    #2;
    
    $display("Time %0t: FPU result = %d (expected 30)", $time, tb_ReadData);
    $fwrite(f, "FPU result: %d\n", tb_ReadData);
    
    // Vérification
    if (tb_ReadData == 32'd30) begin
        $display("??? TEST PASSED ???");
    end else begin
        $display("??? TEST FAILED ??? - Expected 30, got %d", tb_ReadData);
    end

    #100;
    $display("=== Test Complete ===");
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
    if (reset == 0) begin
      $fwrite(f, "Time=%0t Addr=%h WData=%d RData=%d WE=%b\n", 
              $time, tb_DataAdr, tb_WriteData, tb_ReadData, tb_MemWrite);
    end
  end

endmodule