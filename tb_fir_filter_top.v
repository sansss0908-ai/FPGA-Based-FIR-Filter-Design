`timescale 1ns/1ps

module tb_fir_filter_top;

`ifdef TEST_PARALLEL
    localparam integer SERIAL_CORE = 0;
`else
    localparam integer SERIAL_CORE = 1;
`endif

    reg clk = 1'b0;
    reg rst_n = 1'b1;
    reg spi_sck = 1'b0;
    reg spi_cs_n = 1'b1;
    reg spi_mosi = 1'b0;
    wire ready;
    wire output_valid;
    wire signed [15:0] dout;
    integer output_count = 0;
    integer output_failures = 0;
    integer bit_index;
    reg [15:0] captured_output [0:1];

    fir_filter_top #(
        .SERIAL_CORE(SERIAL_CORE)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .spi_sck(spi_sck),
        .spi_cs_n(spi_cs_n),
        .spi_mosi(spi_mosi),
        .ready(ready),
        .output_valid(output_valid),
        .dout(dout)
    );

    always #18.518 clk = ~clk;

    always @(posedge clk) begin
        if (output_valid) begin
            if (output_count < 2)
                captured_output[output_count] = dout;
            output_count = output_count + 1;
        end
    end

    initial begin
        #50000;
        $fatal(1, "FAIL: top-level test timed out; outputs=%0d sample=%0d valid=%b ready=%b async_valid=%b",
               output_count, $signed(uut.sample), output_valid, ready,
               uut.async_sample_valid);
    end

    task send_spi_sample;
        input [15:0] value;
        begin
            @(negedge clk);
            spi_cs_n = 1'b0;
            for (bit_index = 15; bit_index >= 0; bit_index = bit_index - 1) begin
                spi_mosi = value[bit_index];
                #190 spi_sck = 1'b1;
                #191 spi_sck = 1'b0;
            end
            spi_cs_n = 1'b1;
        end
    endtask

    initial begin
        #1 rst_n = 1'b0;
        repeat (3) @(negedge clk);
        rst_n = 1'b1;

        send_spi_sample(16'd13888);
        wait (output_count >= 1);
        send_spi_sample(16'd13628);
        wait (output_count >= 2);
        repeat (5) @(negedge clk);

        if (output_count != 2)
            output_failures = output_failures + 1;
        if (captured_output[0] !== 16'd5)
            output_failures = output_failures + 1;
        if (captured_output[1] !== 16'd10)
            output_failures = output_failures + 1;

        if (output_failures == 0)
            $display("PASS: SPI-to-FIR top produced two correctly aligned outputs (serial=%0d).",
                     SERIAL_CORE);
        else
            $fatal(1, "FAIL: top outputs count=%0d values=%0d,%0d (serial=%0d)",
                   output_count, $signed(captured_output[0]),
                   $signed(captured_output[1]), SERIAL_CORE);
        $finish;
    end

endmodule
