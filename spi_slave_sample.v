`timescale 1ns/1ps

// SPI mode 0 receiver: sample MOSI on rising SCK, MSB first.
// The two received bytes are presented as one signed sample after bit 16.
module spi_slave_sample (
    input  wire       rst_n,
    input  wire       sck,
    input  wire       cs_n,
    input  wire       mosi,
    output reg signed [15:0] sample,
    output reg       sample_valid
);

    reg [15:0] shift_reg;
    reg [4:0] bit_count;

    always @(posedge sck or negedge rst_n or posedge cs_n) begin
        if (!rst_n) begin
            shift_reg <= 16'd0;
            bit_count <= 5'd0;
            sample <= 16'sd0;
            sample_valid <= 1'b0;
        end else begin
            sample_valid <= 1'b0;

            if (cs_n) begin
                shift_reg <= 16'd0;
                bit_count <= 5'd0;
            end else if (bit_count == 5'd15) begin
                sample <= {shift_reg[14:0], mosi};
                sample_valid <= 1'b1;
                shift_reg <= 16'd0;
                bit_count <= 5'd0;
            end else begin
                shift_reg <= {shift_reg[14:0], mosi};
                bit_count <= bit_count + 1'b1;
            end
        end
    end

endmodule
