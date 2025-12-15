//=======================================================
//  MyDE0_Nano
//=======================================================

module MyDE0_Nano(

//////////// CLOCK //////////
input logic                 CLOCK_50,

//////////// LED //////////
output logic     [7:0]      LED,

//////////// KEY //////////
input logic      [1:0]      KEY,

//////////// SW //////////
input logic      [3:0]      SW,

//////////// SDRAM //////////
output logic    [12:0]      DRAM_ADDR,
output logic     [1:0]      DRAM_BA,
output logic                DRAM_CAS_N,
output logic                DRAM_CKE,
output logic                DRAM_CLK,
output logic                DRAM_CS_N,
inout logic     [15:0]      DRAM_DQ,
output logic     [1:0]      DRAM_DQM,
output logic                DRAM_RAS_N,
output logic                DRAM_WE_N,

//////////// EPCS //////////
output logic                EPCS_ASDO,
input logic                 EPCS_DATA0,
output logic                EPCS_DCLK,
output logic                EPCS_NCSO,

//////////// Accelerometer and EEPROM //////////
output logic                G_SENSOR_CS_N,
input logic                 G_SENSOR_INT,
output logic                I2C_SCLK,
inout logic                 I2C_SDAT,

//////////// ADC //////////
output logic                ADC_CS_N,
output logic                ADC_SADDR,
output logic                ADC_SCLK,
input logic                 ADC_SDAT,

//////////// 2x13 GPIO Header //////////
inout logic     [12:0]      GPIO_2,
input logic      [2:0]      GPIO_2_IN,

//////////// GPIO_0 //////////
inout logic     [33:0]      GPIO_0_PI,
input logic      [1:0]      GPIO_0_PI_IN,

//////////// GPIO_1 //////////
inout logic     [33:0]      GPIO_1,
input logic      [1:0]      GPIO_1_IN
);

    //=======================================================
    // MODE SELECTION
    //=======================================================
    parameter TESTBENCH_MODE = 0;
    
    //=======================================================
    // Internal signals
    //=======================================================
    logic        clk, reset;
    logic [31:0] WriteDataM, DataAdrM;
    logic        MemWriteM;
    logic [31:0] PCF, InstrF, ReadDataM, ReadData_dmem, ReadData_spi;
    
    logic        cs_dmem, cs_led, cs_spi, cs_fpu;
    logic [7:0]  led_reg;
    logic [31:0] spi_data;
    logic [31:0] fpu_data_out;
    
    logic [31:0] ARM_DataAdrM, ARM_WriteDataM;
    logic        ARM_MemWriteM;
    
    //=======================================================
    // Clock and reset - MODE DEPENDENT
    //=======================================================
    assign clk = CLOCK_50;
    
    generate
        if (TESTBENCH_MODE) begin : tb_reset
            // En mode testbench, reset est toujours 0 (pas de reset externe)
            assign reset = 1'b0;
        end else begin : arm_reset
            // En mode ARM, utiliser le GPIO
            assign reset = GPIO_0_PI[0];
        end
    endgenerate
  
    //=======================================================
    // Instantiate ARM processor and memories
    //=======================================================
    arm arm(
        .clk       (clk),
        .reset     (reset),
        .PCF       (PCF),
        .InstrF    (InstrF),
        .MemWriteM (ARM_MemWriteM),
        .ALUOutM   (ARM_DataAdrM),
        .WriteDataM(ARM_WriteDataM),
        .ReadDataM (ReadDataM)
    );
    
    imem imem(.a(PCF), .rd(InstrF));
    dmem dmem(.clk(clk), .we(MemWriteM), .cs(cs_dmem), .a(DataAdrM), .wd(WriteDataM), .rd(ReadData_dmem));
    
    //=======================================================
    // Instantiate FPU
    //=======================================================
    fpu_top fpu(
        .clk        (clk),
        .reset      (reset),
        .chip_select(cs_fpu & MemWriteM),
        .addr       (DataAdrM[12:0]),
        .data_in    (WriteDataM),
        .data_out   (fpu_data_out)
    );
    
    //=======================================================
    // MODE MUX
    //=======================================================
    generate
        if (TESTBENCH_MODE) begin : tb_mode
            assign MemWriteM  = GPIO_1[33];
            assign WriteDataM = GPIO_1[31:0];
            assign DataAdrM   = {19'b0, GPIO_2[12:0]};
        end else begin : arm_mode
            assign MemWriteM  = ARM_MemWriteM;
            assign WriteDataM = ARM_WriteDataM;
            assign DataAdrM   = ARM_DataAdrM;
        end
    endgenerate
    
    //=======================================================
    // Chip Select logic
    //=======================================================
    assign cs_dmem = ~DataAdrM[11] & ~DataAdrM[10];
    assign cs_spi  = ~DataAdrM[11] &  DataAdrM[10] & ~DataAdrM[9] & ~DataAdrM[8];
    assign cs_led  = ~DataAdrM[11] &  DataAdrM[10] & ~DataAdrM[9] &  DataAdrM[8];
    assign cs_fpu  = ~DataAdrM[11] &  DataAdrM[10] &  DataAdrM[9] & ~DataAdrM[8];
    
    //=======================================================
    // Read Data Mux
    //=======================================================
    always_comb begin
        if (cs_dmem)      ReadDataM = ReadData_dmem;
        else if (cs_spi)  ReadDataM = spi_data;
        else if (cs_led)  ReadDataM = {24'h000000, led_reg};
        else if (cs_fpu)  ReadDataM = fpu_data_out;
        else              ReadDataM = 32'b0;
    end
    
    //=======================================================
    // LED Logic
    //=======================================================
    assign LED = led_reg;
    always_ff @(posedge clk)
        if (MemWriteM & cs_led)
            led_reg <= WriteDataM[7:0];
    
    //=======================================================
    // GPIO Testbench Interface - SORTIE UNIQUEMENT
    //=======================================================
    generate
        if (TESTBENCH_MODE) begin
            assign GPIO_0_PI[32:1] = ReadDataM;
            assign GPIO_0_PI[33]   = 1'b0;
        end else begin
            assign GPIO_0_PI[32:1] = 32'bz;
            assign GPIO_0_PI[33]   = 1'bz;
        end
    endgenerate

    // GPIO_0_PI[0] non pilot� en mode testbench
    
    //=======================================================
    // SPI (�viter conflit avec testbench)
    //=======================================================
    generate
        if (!TESTBENCH_MODE) begin : spi_enabled
            logic spi_clk, spi_cs, spi_mosi, spi_miso;

            spi_slave spi_slave_instance(
                .SPI_CLK    (spi_clk),
                .SPI_CS     (spi_cs),
                .SPI_MOSI   (spi_mosi),
                .SPI_MISO   (spi_miso),
                .Data_WE    (MemWriteM & cs_spi),
                .Data_Addr  (DataAdrM),
                .Data_Write (WriteDataM),
                .Data_Read  (spi_data),
                .Clk        (clk)
            );

            assign spi_clk  = GPIO_0_PI[11];
            assign spi_cs   = GPIO_0_PI[9];
            assign spi_mosi = GPIO_0_PI[15];
            assign GPIO_0_PI[13] = spi_cs ? 1'bz : spi_miso;
        end else begin : spi_disabled
            // En mode testbench, pas de SPI
            assign spi_data = 32'b0;
        end
    endgenerate

endmodule

//=======================================================
// Memories
//=======================================================
module dmem(input logic clk, we, cs,
            input logic [31:0] a, wd,
            output logic [31:0] rd);
    logic [31:0] RAM[255:0];
    assign rd = RAM[a[31:2]];
    always_ff @(posedge clk)
        if (cs & we) RAM[a[31:2]] <= wd;
endmodule

module imem(input logic [31:0] a,
            output logic [31:0] rd);
    logic [31:0] RAM[255:0];
    initial begin
        // Initialiser avec des NOPs si le fichier n'existe pas
        for (int i = 0; i < 256; i++) RAM[i] = 32'hE320F000;  // NOP
        $readmemh("MyProgram_Pipelined.hex", RAM);
    end
    assign rd = RAM[a[31:2]];
endmodule