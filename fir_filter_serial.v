`timescale 1ns/1ps

// Resource-reduced FIR: one signed sample/coefficient multiply per clock.
// sample_valid is accepted only when ready is high.
module fir_filter_serial #(
    parameter integer DATA_WIDTH = 16,
    parameter integer COEFF_WIDTH = 16,
    parameter integer NUM_TAPS = 64,
    parameter COEFF_FILE = "fir_coeff_q15.mem"
) (
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire                         sample_valid,
    input  wire signed [DATA_WIDTH-1:0] din,
    output reg                          ready,
    output reg                          output_valid,
    output reg  signed [DATA_WIDTH-1:0] dout
);

    localparam integer ACC_WIDTH = 64;

    reg signed [COEFF_WIDTH-1:0] coeff [0:NUM_TAPS-1];
    reg signed [DATA_WIDTH-1:0] delay_line [0:NUM_TAPS-1];
    reg signed [DATA_WIDTH-1:0] sample_reg;
    reg signed [ACC_WIDTH-1:0] accumulator;
    reg [6:0] tap_index;
    reg busy;
    reg signed [DATA_WIDTH+COEFF_WIDTH-1:0] product;
    reg signed [ACC_WIDTH-1:0] final_accumulator;
    integer i;

    initial $readmemh(COEFF_FILE, coeff);

    always @* begin
        if (tap_index == 0)
            product = sample_reg * coeff[0];
        else
            product = delay_line[tap_index - 1] * coeff[tap_index];
        final_accumulator = accumulator + product;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ready <= 1'b1;
            output_valid <= 1'b0;
            dout <= '0;
            sample_reg <= '0;
            accumulator <= '0;
            tap_index <= 7'd0;
            busy <= 1'b0;
            for (i = 0; i < NUM_TAPS; i = i + 1)
                delay_line[i] <= '0;
        end else begin
            output_valid <= 1'b0;

            if (!busy) begin
                ready <= 1'b1;
                if (sample_valid) begin
                    sample_reg <= din;
                    accumulator <= '0;
                    tap_index <= 7'd0;
                    busy <= 1'b1;
                    ready <= 1'b0;
                end
            end else if (tap_index == NUM_TAPS - 1) begin
                if ((final_accumulator >>> 15) > 32767)
                    dout <= 16'sh7fff;
                else if ((final_accumulator >>> 15) < -32768)
                    dout <= -16'sh8000;
                else
                    dout <= (final_accumulator >>> 15);
                output_valid <= 1'b1;
                for (i = NUM_TAPS-1; i > 0; i = i - 1)
                    delay_line[i] <= delay_line[i-1];
                delay_line[0] <= sample_reg;
                busy <= 1'b0;
                ready <= 1'b1;
            end else begin
                accumulator <= final_accumulator;
                tap_index <= tap_index + 1'b1;
            end
        end
    end

endmodule
