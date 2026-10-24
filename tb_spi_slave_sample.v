`timescale 1ns/1ps

module tb_spi_slave_sample;

    reg rst_n = 1'b1;
    reg sck = 1'b0;
    reg cs_n = 1'b1;
    reg mosi = 1'b0;
    wire signed [15:0] sample;
    wire sample_valid;
    integer i;
    reg [15:0] expected = 16'hA55A;

    spi_slave_sample uut (
        .rst_n(rst_n),
        .sck(sck),
        .cs_n(cs_n),
        .mosi(mosi),
        .sample(sample),
        .sample_valid(sample_valid)
    );

    task send_bit;
        input bit_value;
        begin
            mosi = bit_value;
            #5 sck = 1'b1;
            #1 sck = 1'b0;
        end
    endtask

    initial begin
        #1 rst_n = 1'b0;
        #1 rst_n = 1'b1;
        #2 cs_n = 1'b0;
        for (i = 15; i >= 0; i = i - 1)
            send_bit(expected[i]);
        #1;
        if (!sample_valid || sample !== expected)
            $display("FAIL: SPI sample expected %h, got %h valid=%b",
                     expected, sample, sample_valid);
        else
            $display("PASS: SPI assembled %h from two MSB-first bytes.", sample);
        cs_n = 1'b1;
        #1 $finish;
    end

endmodule
