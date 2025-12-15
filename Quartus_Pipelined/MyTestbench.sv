`timescale 1 ps / 1 ps

module MyTestbench();

  // Clock & reset
  logic clk;
  logic reset;

  // Signaux de contrôle du testbench (LOCAL)
  logic [31:0] tb_WriteData;
  logic [12:0] tb_DataAdr;
  logic        tb_MemWrite;      // ← Signal LOCAL pour piloter MemWrite
  logic [31:0] tb_ReadData;

  // GPIO wires connectant le testbench au DUT
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

  // Connect testbench signals to DUT
  assign GPIO_0_PI[1]  = reset;
  assign GPIO_1[33]    = tb_MemWrite;      // ← Piloter MemWrite
  assign GPIO_1[31:0]  = tb_WriteData;     // Écrire 32 bits
  assign GPIO_2        = tb_DataAdr;
  assign tb_ReadData   = GPIO_1[31:0];     // Lire 32 bits

  // Initialize test
  initial begin
    f = $fopen("student_simul.txt", "w");
    
    // Initialiser tous les signaux
    tb_MemWrite  = 0;
    tb_DataAdr   = 0;
    tb_WriteData = 0;
    
    // Reset DUT
    reset = 1; 
    #20; 
    reset = 0; 
    #20;
    
    $display("=== Starting FPU Test ===");

    // ---------- TEST FPU ----------
    
    // Écrire opérande A = 10
    @(negedge clk);
    tb_DataAdr   = 13'h0600;
    tb_WriteData = 32'd10;
    tb_MemWrite  = 1;
    $display("Time %0t: Writing A=10 to address 0x600", $time);

    // Écrire opérande B = 20
    @(negedge clk);
    tb_DataAdr   = 13'h0604;
    tb_WriteData = 32'd20;
    tb_MemWrite  = 1;
    $display("Time %0t: Writing B=20 to address 0x604", $time);

    // Déclencher le calcul (addition)
    @(negedge clk);
    tb_DataAdr   = 13'h0608;
    tb_WriteData = 32'd1;
    tb_MemWrite  = 1;
    $display("Time %0t: Writing CMD=1 (ADD) to address 0x608", $time);

    // Arrêter l'écriture et attendre le calcul
    @(negedge clk);
    tb_MemWrite  = 0;
    
    @(negedge clk);

    // Lire le résultat
    tb_DataAdr   = 13'h060C;
    tb_MemWrite  = 0;
    @(negedge clk);
    
    $display("Time %0t: FPU result = %d (expected 30)", $time, tb_ReadData);
    $fwrite(f, "FPU result: %d\n", tb_ReadData);

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

  // Log all bus activity
  always @(negedge clk) begin
    if (reset == 0) begin
      $fwrite(f, "Time=%0t Addr=%h WData=%h RData=%h WE=%b\n", 
              $time, tb_DataAdr, tb_WriteData, tb_ReadData, tb_MemWrite);
    end
  end

endmodule