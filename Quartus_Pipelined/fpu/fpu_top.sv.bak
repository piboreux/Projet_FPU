module fpu_top(
    input  logic        clk,
    input  logic        reset,
    input  logic        chip_select,  // Actif seulement pendant write
    input  logic [12:0] addr,
    input  logic [31:0] data_in,
    output logic [31:0] data_out
);
    logic [31:0] reg_A, reg_B;
    logic [31:0] cmd;
    logic [31:0] result;
    
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            reg_A  <= 32'b0;
            reg_B  <= 32'b0;
            cmd    <= 32'b0;
            result <= 32'b0;
        end else if (chip_select) begin  // Écriture seulement si chip_select
            case(addr[5:0])
                6'h00: reg_A <= data_in;
                6'h04: reg_B <= data_in;
                6'h08: begin
                    cmd <= data_in;
                    if (data_in == 32'd1)      result <= fp_add(reg_A, reg_B);
                    else if (data_in == 32'd2) result <= fp_sub(reg_A, reg_B);
                    else if (data_in == 32'd3) result <= fp_mul(reg_A, reg_B);
                end
                default: ;
            endcase
        end
    end
    
    // Lecture TOUJOURS disponible
    assign data_out = result;

    function automatic [31:0] fp_add(input [31:0] a, b);
        begin
            fp_add = a + b;
        end
    endfunction

    function automatic [31:32] fp_sub(input [31:0] a, b);
        begin
            fp_sub = a - b;
        end
    endfunction

    function automatic [31:0] fp_mul(input [31:0] a, b);
        begin
            fp_mul = a * b;
        end
    endfunction

endmodule