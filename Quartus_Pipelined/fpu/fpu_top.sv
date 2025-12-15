//=======================================================
// fpu_top.sv
// Floating Point Unit - IEEE-754 Single Precision
// Supports: ADD, SUB, MUL
//=======================================================

module fpu_top(
    input  logic        clk,
    input  logic        reset,
    input  logic        chip_select,
    input  logic [12:0] addr,
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
            case(addr[5:0])
                6'h00: reg_A <= data_in;     // 0x0600: Operand A
                6'h04: reg_B <= data_in;     // 0x0604: Operand B
                6'h08: begin                  // 0x0608: Command
                    cmd <= data_in;
                    // Execute immediately
                    if (data_in == 32'd1)      result <= fp_add(reg_A, reg_B);
                    else if (data_in == 32'd2) result <= fp_sub(reg_A, reg_B);
                    else if (data_in == 32'd3) result <= fp_mul(reg_A, reg_B);
                    else                       result <= 32'h7FC00000; // NaN for invalid cmd
                end
                default: ;
            endcase
        end
    end
    
    // Output result (always available for reading)
    assign data_out = result;

    //===================================================
    // IEEE-754 Single Precision Addition
    //===================================================
    function automatic [31:0] fp_add(input [31:0] a, b);
        logic signA, signB, signRes;
        logic [7:0] expA, expB, expRes;
        logic [24:0] mantA, mantB, mantRes;
        logic [7:0] expDiff;
        integer shift_amt;
        
        begin
            // Extract IEEE-754 fields
            signA = a[31];
            expA  = a[30:23];
            mantA = (expA == 0) ? {2'b00, a[22:0]} : {2'b01, a[22:0]}; // implicit bit
            
            signB = b[31];
            expB  = b[30:23];
            mantB = (expB == 0) ? {2'b00, b[22:0]} : {2'b01, b[22:0]}; // implicit bit
            
            // Handle special cases
            if (expA == 8'hFF && a[22:0] != 0) begin
                fp_add = 32'h7FC00000; // NaN
            end else if (expB == 8'hFF && b[22:0] != 0) begin
                fp_add = 32'h7FC00000; // NaN
            end else if (expA == 8'hFF) begin
                fp_add = a; // ±Infinity
            end else if (expB == 8'hFF) begin
                fp_add = b; // ±Infinity
            end else if (a[30:0] == 0) begin
                fp_add = b; // A is zero
            end else if (b[30:0] == 0) begin
                fp_add = a; // B is zero
            end else begin
                // Align exponents
                if (expA > expB) begin
                    expDiff = expA - expB;
                    if (expDiff < 25)
                        mantB = mantB >> expDiff;
                    else
                        mantB = 0;
                    expRes = expA;
                end else begin
                    expDiff = expB - expA;
                    if (expDiff < 25)
                        mantA = mantA >> expDiff;
                    else
                        mantA = 0;
                    expRes = expB;
                end
                
                // Add or subtract mantissas
                if (signA == signB) begin
                    mantRes = mantA + mantB;
                    signRes = signA;
                end else begin
                    if (mantA >= mantB) begin
                        mantRes = mantA - mantB;
                        signRes = signA;
                    end else begin
                        mantRes = mantB - mantA;
                        signRes = signB;
                    end
                end
                
                // Normalize result
                if (mantRes == 0) begin
                    fp_add = 32'b0; // Result is zero
                end else begin
                    // Handle overflow in mantissa
                    if (mantRes[24]) begin
                        mantRes = mantRes >> 1;
                        expRes = expRes + 1;
                    end else begin
                        // Normalize by shifting left
                        while (mantRes[23] == 0 && expRes > 0 && mantRes != 0) begin
                            mantRes = mantRes << 1;
                            expRes = expRes - 1;
                        end
                    end
                    
                    // Check for overflow/underflow
                    if (expRes >= 8'hFF) begin
                        fp_add = {signRes, 8'hFF, 23'b0}; // ±Infinity
                    end else if (expRes == 0 || mantRes[23] == 0) begin
                        fp_add = {signRes, 8'b0, mantRes[22:0]}; // Denormalized
                    end else begin
                        fp_add = {signRes, expRes, mantRes[22:0]};
                    end
                end
            end
        end
    endfunction

    //===================================================
    // IEEE-754 Single Precision Subtraction
    //===================================================
    function automatic [31:0] fp_sub(input [31:0] a, b);
        logic [31:0] b_neg;
        begin
            b_neg = {~b[31], b[30:0]}; // Negate b by flipping sign bit
            fp_sub = fp_add(a, b_neg);
        end
    endfunction

    //===================================================
    // IEEE-754 Single Precision Multiplication
    //===================================================
    function automatic [31:0] fp_mul(input [31:0] a, b);
        logic signA, signB, signRes;
        logic [7:0] expA, expB;
        logic [9:0] expRes;
        logic [23:0] mantA, mantB;
        logic [47:0] mantRes;
        
        begin
            // Extract IEEE-754 fields
            signA = a[31];
            expA  = a[30:23];
            mantA = (expA == 0) ? {1'b0, a[22:0]} : {1'b1, a[22:0]};
            
            signB = b[31];
            expB  = b[30:23];
            mantB = (expB == 0) ? {1'b0, b[22:0]} : {1'b1, b[22:0]};
            
            signRes = signA ^ signB;
            
            // Handle special cases
            if (expA == 8'hFF && a[22:0] != 0) begin
                fp_mul = 32'h7FC00000; // NaN
            end else if (expB == 8'hFF && b[22:0] != 0) begin
                fp_mul = 32'h7FC00000; // NaN
            end else if (expA == 8'hFF || expB == 8'hFF) begin
                if (a[30:0] == 0 || b[30:0] == 0)
                    fp_mul = 32'h7FC00000; // NaN (0 * Inf)
                else
                    fp_mul = {signRes, 8'hFF, 23'b0}; // ±Infinity
            end else if (a[30:0] == 0 || b[30:0] == 0) begin
                fp_mul = {signRes, 31'b0}; // ±Zero
            end else begin
                // Multiply mantissas
                mantRes = mantA * mantB;
                
                // Calculate exponent (remove bias once: 127 + 127 = 254, but we want 127)
                expRes = expA + expB - 127;
                
                // Normalize (MSB should be at bit 47 or 46)
                if (mantRes[47]) begin
                    mantRes = mantRes >> 1;
                    expRes = expRes + 1;
                end else if (mantRes[46] == 0) begin
                    // Shouldn't happen with normalized inputs, but handle anyway
                    while (mantRes[46] == 0 && expRes > 0) begin
                        mantRes = mantRes << 1;
                        expRes = expRes - 1;
                    end
                end
                
                // Check for overflow/underflow
                if (expRes >= 255) begin
                    fp_mul = {signRes, 8'hFF, 23'b0}; // ±Infinity
                end else if (expRes <= 0) begin
                    fp_mul = {signRes, 31'b0}; // Underflow to ±Zero
                end else begin
                    fp_mul = {signRes, expRes[7:0], mantRes[45:23]};
                end
            end
        end
    endfunction

endmodule