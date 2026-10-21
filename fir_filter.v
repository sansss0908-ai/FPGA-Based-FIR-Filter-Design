`timescale 1ns/1ps

module fir_filter #(
    parameter integer DATA_WIDTH = 16,
    parameter integer COEFF_WIDTH = 16,
    parameter integer NUM_TAPS = 64,
    parameter COEFF_FILE = "fir_coeff_q15.mem"
) (
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire                         sample_valid,
    input  wire signed [DATA_WIDTH-1:0] din,
    output reg  signed [DATA_WIDTH-1:0] dout
);

    localparam integer ACC_WIDTH = 64;

    reg signed [COEFF_WIDTH-1:0] coeff [0:NUM_TAPS-1];
    reg signed [DATA_WIDTH-1:0]  delay_line [0:NUM_TAPS-1];

    reg signed [ACC_WIDTH-1:0] accumulator;
    reg signed [ACC_WIDTH-1:0] scaled_result;
    reg signed [DATA_WIDTH+COEFF_WIDTH-1:0] product;
    integer i;

    initial begin
        $readmemh(COEFF_FILE, coeff);
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dout <= '0;
            for (i = 0; i < NUM_TAPS; i = i + 1)
                delay_line[i] <= '0;
        end else if (sample_valid) begin
            accumulator = '0;

            for (i = 0; i < NUM_TAPS; i = i + 1) begin
                if (i == 0)
                    product = din * coeff[i];
                else
                    product = delay_line[i-1] * coeff[i];
                accumulator = accumulator + product;
            end

            scaled_result = accumulator >>> 15;
            if (scaled_result > 32767)
                dout <= 16'sh7fff;
            else if (scaled_result < -32768)
                dout <= -16'sh8000;
            else
                dout <= scaled_result[DATA_WIDTH-1:0];

            for (i = NUM_TAPS-1; i > 0; i = i - 1)
                delay_line[i] <= delay_line[i-1];
            delay_line[0] <= din;
        end
    end

endmodule
