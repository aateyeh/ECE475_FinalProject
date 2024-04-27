module MatrixMultiplier(
    input wire clk,
    input wire start,
    input wire [63:0] matrix_A [0:63][0:63], // 64x64 matrix A
    input wire [63:0] matrix_B [0:63][0:63], // 64x64 matrix B
    output reg [63:0] result [0:63][0:63],    // 64x64 result matrix
    output reg done // Signal indicating computation completion
);

reg [63:0] partial_sum [0:63][0:63]; // Partial sum matrix
integer i, j, k;

// Reset done signal and result matrix
always @(posedge clk) begin
    if (start) begin
        done <= 0;
        for (i = 0; i < 64; i = i + 1) begin
            for (j = 0; j < 64; j = j + 1) begin
                result[i][j] <= 0;
            end
        end
    end
end

// Multiply matrices A and B
always @(*) begin
    for (i = 0; i < 64; i = i + 1) begin
        for (j = 0; j < 64; j = j + 1) begin
            partial_sum[i][j] = 0;
            for (k = 0; k < 64; k = k + 1) begin
                partial_sum[i][j] = partial_sum[i][j] + matrix_A[i][k] * matrix_B[k][j];
            end
        end
    end
end

// Output the result and set done signal
always @(posedge clk) begin
    if (start) begin
        for (i = 0; i < 64; i = i + 1) begin
            for (j = 0; j < 64; j = j + 1) begin
                result[i][j] <= partial_sum[i][j];
            end
        end
        done <= 1;
    end
end

endmodule
