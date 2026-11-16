`timescale 1ns/1ps

module sample_valid_sync (
    input  wire clk,
    input  wire rst_n,
    input  wire async_valid,
    output reg  valid_pulse
);

    reg valid_meta;
    reg valid_sync;
    reg valid_sync_d;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_meta <= 1'b0;
            valid_sync <= 1'b0;
            valid_sync_d <= 1'b0;
            valid_pulse <= 1'b0;
        end else begin
            valid_meta <= async_valid;
            valid_sync <= valid_meta;
            valid_sync_d <= valid_sync;
            valid_pulse <= valid_sync & ~valid_sync_d;
        end
    end

endmodule
