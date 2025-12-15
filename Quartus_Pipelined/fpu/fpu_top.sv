//=======================================================
// fpu_top.sv
// Floating Point Unit - Top module
// Supports add, sub, mul (single precision)
//=======================================================
module fpu_top(
    input  logic        clk,
    input  logic        reset,
    input  logic        chip_select,
    input  logic [12:0] addr,       // adresse de registre (bits [12:0])
    input  logic [31:0] data_in,
    output logic [31:0] data_out
);
    // Internal registers
    logic [31:0] reg_A, reg_B;
    logic [31:0] cmd;
    logic [31:0] result;
    
    // Write registers based on address
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            reg_A  <= 32'b0;
            reg_B  <= 32'b0;
            cmd    <= 32'b0;
            result <= 32'b0;
        end else if (chip_select) begin
            case(addr[5:0])  // Utiliser les 6 bits de poids faible
                6'h00: reg_A <= data_in;     // 0x0600: Operande A
                6'h04: reg_B <= data_in;     // 0x0604: Operande B
                6'h08: begin                  // 0x0608: Commande
                    cmd <= data_in;
                    // Execute immédiatement
                    if (data_in == 32'd1)      result <= fp_add(reg_A, reg_B);
                    else if (data_in == 32'd2) result <= fp_sub(reg_A, reg_B);
                    else if (data_in == 32'd3) result <= fp_mul(reg_A, reg_B);
                end
                default: ;
            endcase
        end
    end
    
    // Output result
    assign data_out = result;

    //===================================================
    // Floating Point Operations (simplified using integers for testing)
    //===================================================
    function automatic [31:0] fp_add(input [31:0] a, b);
        begin
            fp_add = a + b;  // Addition entière pour le test
        end
    endfunction

    function automatic [31:0] fp_sub(input [31:0] a, b);
        begin
            fp_sub = a - b;  // Soustraction entière
        end
    endfunction

    function automatic [31:0] fp_mul(input [31:0] a, b);
        begin
            fp_mul = a * b;  // Multiplication entière
        end
    endfunction

endmodule