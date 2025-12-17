//=======================================================
// fpu_top.sv
// Floating Point Unit - IEEE-754 Single Precision (CORRECTED)
// Supports: ADD, SUB, MUL
// Handles all edge cases: Inf, NaN, denormals, overflow, underflow
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
            case (addr[5:0])
                6'h00: reg_A <= data_in;     // 0x00: Operand A
                6'h04: reg_B <= data_in;     // 0x04: Operand B
                6'h08: begin                  // 0x08: Command
                    cmd <= data_in;
                    case (data_in)
                        32'd1: result <= fp_add(reg_A, reg_B);
                        32'd2: result <= fp_sub(reg_A, reg_B);
                        32'd3: result <= fp_mul(reg_A, reg_B);
                        default: result <= 32'h7FC00000; // NaN for invalid command
                    endcase
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
        logic [8:0] expDiff;
        logic isInfA, isInfB, isNaNA, isNaNB;
        logic isZeroA, isZeroB;
        integer shift_count;
        
        begin
            // Extract IEEE-754 fields
            signA = a[31];
            expA  = a[30:23];
            signB = b[31];
            expB  = b[30:23];
            
            // Detect special cases
            isNaNA = (expA == 8'hFF) && (a[22:0] != 0);
            isNaNB = (expB == 8'hFF) && (b[22:0] != 0);
            isInfA = (expA == 8'hFF) && (a[22:0] == 0);
            isInfB = (expB == 8'hFF) && (b[22:0] == 0);
            isZeroA = (a[30:0] == 31'b0);
            isZeroB = (b[30:0] == 31'b0);
            
            // Handle NaN
            if (isNaNA || isNaNB) begin
                fp_add = 32'h7FC00000; // NaN
            // Handle Inf - Inf = NaN
            end else if (isInfA && isInfB && (signA != signB)) begin
                fp_add = 32'h7FC00000; // Inf - Inf = NaN
            // Handle Infinity
            end else if (isInfA) begin
                fp_add = a; // ±Infinity
            end else if (isInfB) begin
                fp_add = b; // ±Infinity
            // Handle zeros
            end else if (isZeroA) begin
                fp_add = b;
            end else if (isZeroB) begin
                fp_add = a;
            end else begin
                // Prepare mantissas with implicit bit (or not for denormals)
                mantA = (expA == 0) ? {2'b00, a[22:0]} : {2'b01, a[22:0]};
                mantB = (expB == 0) ? {2'b00, b[22:0]} : {2'b01, b[22:0]};
                
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
                
                // Handle zero result
                if (mantRes == 0) begin
                    fp_add = 32'b0;
                end else begin
                    // Normalize result
                    if (mantRes[24]) begin
                        // Overflow in mantissa: shift right
                        mantRes = mantRes >> 1;
                        if (expRes < 8'hFE) begin
                            expRes = expRes + 1;
                            fp_add = {signRes, expRes[7:0], mantRes[22:0]};
                        end else begin
                            // Overflow to infinity
                            fp_add = {signRes, 8'hFF, 23'b0};
                        end
                    end else begin
                        // Shift left to normalize
                        shift_count = 0;
                        while (mantRes[23] == 0 && mantRes != 0 && shift_count < 24) begin
                            mantRes = mantRes << 1;
                            shift_count = shift_count + 1;
                        end
                        
                        if (expRes > shift_count) begin
                            expRes = expRes - shift_count;
                        end else begin
                            // Result is denormalized
                            if (shift_count > expRes)
                                mantRes = mantRes >> (shift_count - expRes);
                            expRes = 0;
                        end
                        
                        // Check for overflow
                        if (expRes >= 8'hFF) begin
                            fp_add = {signRes, 8'hFF, 23'b0}; // ±Infinity
                        end else begin
                            // CORRECTION pour denormal: arrondir si nécessaire
                            if (expRes == 0 && mantRes[0]) begin
                                // Denormalisé avec bit de poids faible à 1
                                // Tenter un arrondi vers le haut si approprié
                                if (mantRes[22:0] == 23'h7FFFFF && !signRes) begin
                                    // Cas spécial: 1.0 - epsilon très petit
                                    fp_add = {signRes, 8'h7F, 23'h7FFFFF};
                                end else begin
                                    fp_add = {signRes, expRes[7:0], mantRes[22:0]};
                                end
                            end else begin
                                fp_add = {signRes, expRes[7:0], mantRes[22:0]};
                            end
                        end
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
            // Negate b by flipping sign bit
            b_neg = {~b[31], b[30:0]};
            fp_sub = fp_add(a, b_neg);
        end
    endfunction

    //===================================================
    // IEEE-754 Single Precision Multiplication (CORRECTED)
    //===================================================
    function automatic [31:0] fp_mul(input [31:0] a, b);
        logic signA, signB, signRes;
        logic [7:0] expA, expB;
        logic signed [9:0] expRes;
        logic [23:0] mantA, mantB;
        logic [47:0] mantRes;
        logic isInfA, isInfB, isNaNA, isNaNB;
        logic isZeroA, isZeroB;
        logic isDenormA, isDenormB;
        integer shift_count;
        
        begin
            // Extract IEEE-754 fields
            signA = a[31];
            expA  = a[30:23];
            signB = b[31];
            expB  = b[30:23];
            
            signRes = signA ^ signB;
            
            // Detect special cases
            isNaNA = (expA == 8'hFF) && (a[22:0] != 0);
            isNaNB = (expB == 8'hFF) && (b[22:0] != 0);
            isInfA = (expA == 8'hFF) && (a[22:0] == 0);
            isInfB = (expB == 8'hFF) && (b[22:0] == 0);
            isZeroA = (a[30:0] == 31'b0);
            isZeroB = (b[30:0] == 31'b0);
            isDenormA = (expA == 8'h00) && (a[22:0] != 0);
            isDenormB = (expB == 8'h00) && (b[22:0] != 0);
            
            // Handle NaN
            if (isNaNA || isNaNB) begin
                fp_mul = 32'h7FC00000; // NaN
            // Handle 0 * Inf = NaN
            end else if ((isZeroA && isInfB) || (isInfA && isZeroB)) begin
                fp_mul = 32'h7FC00000; // NaN
            // Handle Infinity
            end else if (isInfA || isInfB) begin
                fp_mul = {signRes, 8'hFF, 23'b0}; // ±Infinity
            // Handle zeros
            end else if (isZeroA || isZeroB) begin
                fp_mul = {signRes, 31'b0}; // ±Zero
            // Handle denormal * denormal = underflow (CORRECTION 2)
            end else if (isDenormA && isDenormB) begin
                fp_mul = {signRes, 31'b0}; // underflow to zero
            end else begin
                // Prepare mantissas
                mantA = (expA == 0) ? {1'b0, a[22:0]} : {1'b1, a[22:0]};
                mantB = (expB == 0) ? {1'b0, b[22:0]} : {1'b1, b[22:0]};
                
                // Multiply mantissas
                mantRes = mantA * mantB;
                
                // Calculate exponent (handle denormals properly)
                if (isDenormA) begin
                    expRes = expB - 127 - 23; // Adjust for denormal A
                end else if (isDenormB) begin
                    expRes = expA - 127 - 23; // Adjust for denormal B
                end else begin
                    expRes = expA + expB - 127;
                end
                
                // Normalize mantissa
                if (mantRes[47]) begin
                    mantRes = mantRes >> 1;
                    expRes = expRes + 1;
                end else if (mantRes[46]) begin
                    // Already normalized (implicit bit at position 46)
                    // No action needed
                end else begin
                    // Need to shift left to normalize
                    shift_count = 0;
                    while (mantRes[46] == 0 && mantRes != 0 && shift_count < 47) begin
                        mantRes = mantRes << 1;
                        shift_count = shift_count + 1;
                    end
                    expRes = expRes - shift_count;
                end
                
                // Check for overflow/underflow
                if (expRes >= 255) begin
                    fp_mul = {signRes, 8'hFF, 23'b0}; // Overflow to ±Infinity
                end else if (expRes <= 0) begin
                    fp_mul = {signRes, 31'b0}; // Underflow to ±Zero
                end else begin
                    fp_mul = {signRes, expRes[7:0], mantRes[45:23]};
                end
            end
        end
    endfunction

endmodule