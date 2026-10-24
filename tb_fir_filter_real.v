`timescale 1ns/1ps

module tb_fir_filter_real;

    localparam integer NUM_SAMPLES = 1000;
    localparam integer NUM_TAPS = 64;
    localparam SENSOR_MEM_FILE = "sensor_data.mem";
    localparam OUTPUT_FILE = "fpga_output.txt";
    localparam VCD_FILE = "fir_real_wave.vcd";

    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg sample_valid = 1'b0;
    reg signed [15:0] din = 16'sd0;
    wire signed [15:0] dout;
    reg signed [15:0] samples [0:NUM_SAMPLES-1];
    integer output_file;
    integer i;
    integer output_count;

    fir_filter uut (
        .clk(clk),
        .rst_n(rst_n),
        .sample_valid(sample_valid),
        .din(din),
        .dout(dout)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile(VCD_FILE);
        $dumpvars(0, tb_fir_filter_real);

        $readmemh(SENSOR_MEM_FILE, samples);
        output_file = $fopen(OUTPUT_FILE, "w");
        if (output_file == 0) begin
            $display("ERROR: could not open %s", OUTPUT_FILE);
            $finish;
        end

        output_count = 0;
        repeat (3) @(posedge clk);
        rst_n = 1'b1;

        for (i = 0; i < NUM_SAMPLES; i = i + 1) begin
            @(negedge clk);
            din = samples[i];
            sample_valid = 1'b1;
            @(posedge clk);
            #1 $fwrite(output_file, "%0d\n", dout);
            output_count = output_count + 1;
            sample_valid = 1'b0;
        end

        $fclose(output_file);
        $dumpoff;
        if (output_count != NUM_SAMPLES) begin
            $display("FAIL: wrote %0d outputs; expected %0d.",
                     output_count, NUM_SAMPLES);
            $finish;
        end
        $display("PASS: replayed %0d samples from %s and wrote dout to %s.",
                 NUM_SAMPLES, SENSOR_MEM_FILE, OUTPUT_FILE);
        $finish;
    end

endmodule
