`timescale 1ns/1ps

module fir_filter_top #(
    parameter integer SERIAL_CORE = 1,
    parameter integer NUM_TAPS = 64,
    parameter COEFF_FILE = "fir_coeff_q15.mem"
) (
    input  wire              clk,
    input  wire              rst_n,
    input  wire              spi_sck,
    input  wire              spi_cs_n,
    input  wire              spi_mosi,
    output wire              ready,
    output wire              output_valid,
    output wire signed [15:0] dout
);

    wire signed [15:0] sample;
    wire async_sample_valid;
    wire sample_valid;

    spi_slave_sample spi_receiver (
        .rst_n(rst_n),
        .sck(spi_sck),
        .cs_n(spi_cs_n),
        .mosi(spi_mosi),
        .sample(sample),
        .sample_valid(async_sample_valid)
    );

    sample_valid_sync valid_synchronizer (
        .clk(clk),
        .rst_n(rst_n),
        .async_valid(async_sample_valid),
        .valid_pulse(sample_valid)
    );

    generate
        if (SERIAL_CORE != 0) begin : serial_implementation
            fir_filter_serial #(
                .NUM_TAPS(NUM_TAPS),
                .COEFF_FILE(COEFF_FILE)
            ) filter (
                .clk(clk),
                .rst_n(rst_n),
                .sample_valid(sample_valid),
                .din(sample),
                .ready(ready),
                .output_valid(output_valid),
                .dout(dout)
            );
        end else begin : parallel_implementation
            reg parallel_output_valid;

            assign ready = 1'b1;
            assign output_valid = parallel_output_valid;

            fir_filter #(
                .NUM_TAPS(NUM_TAPS),
                .COEFF_FILE(COEFF_FILE)
            ) filter (
                .clk(clk),
                .rst_n(rst_n),
                .sample_valid(sample_valid),
                .din(sample),
                .dout(dout)
            );

            always @(posedge clk or negedge rst_n) begin
                if (!rst_n)
                    parallel_output_valid <= 1'b0;
                else
                    parallel_output_valid <= sample_valid;
            end
        end
    endgenerate

endmodule
