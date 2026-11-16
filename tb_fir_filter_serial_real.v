`timescale 1ns/1ps

module tb_fir_filter_serial_real;

    localparam integer MAX_SAMPLES = 100000;
    localparam integer NUM_TAPS = 64;
    localparam integer MAX_LATENCY = NUM_TAPS + 2;
    localparam SENSOR_MEM_FILE = "sensor_data.mem";
    localparam OUTPUT_FILE = "fpga_serial_output.txt";
    localparam VCD_FILE = "fir_serial_real_wave.vcd";

    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg sample_valid = 1'b0;
    reg signed [15:0] din = 16'sd0;
    wire ready;
    wire output_valid;
    wire signed [15:0] dout;
    reg signed [15:0] samples [0:MAX_SAMPLES-1];
    integer output_file;
    integer input_file;
    integer i;
    integer output_count;
    integer sample_count;
    integer scan_status;
    integer line_length;
    integer cycles_waited;
    reg [8*32-1:0] input_line;
    reg [15:0] sample_word;

    fir_filter_serial uut (
        .clk(clk),
        .rst_n(rst_n),
        .sample_valid(sample_valid),
        .din(din),
        .ready(ready),
        .output_valid(output_valid),
        .dout(dout)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile(VCD_FILE);
        $dumpvars(0, tb_fir_filter_serial_real);

        input_file = $fopen(SENSOR_MEM_FILE, "r");
        if (input_file == 0)
            $fatal(1, "FAIL: could not open %s", SENSOR_MEM_FILE);

        sample_count = 0;
        line_length = $fgets(input_line, input_file);
        while (line_length != 0) begin
            scan_status = $sscanf(input_line, "%h", sample_word);
            if (scan_status != 1)
                $fatal(1, "FAIL: invalid hex data in %s", SENSOR_MEM_FILE);
            if (sample_count >= MAX_SAMPLES)
                $fatal(1, "FAIL: %s exceeds capacity of %0d samples",
                       SENSOR_MEM_FILE, MAX_SAMPLES);
            samples[sample_count] = $signed(sample_word);
            sample_count = sample_count + 1;
            line_length = $fgets(input_line, input_file);
        end
        $fclose(input_file);
        if (sample_count == 0)
            $fatal(1, "FAIL: %s contains no samples", SENSOR_MEM_FILE);

        output_file = $fopen(OUTPUT_FILE, "w");
        if (output_file == 0)
            $fatal(1, "FAIL: could not open %s", OUTPUT_FILE);

        output_count = 0;
        repeat (3) @(negedge clk);
        rst_n = 1'b1;

        for (i = 0; i < sample_count; i = i + 1) begin
            while (ready !== 1'b1)
                @(negedge clk);
            @(negedge clk);
            din = samples[i];
            sample_valid = 1'b1;
            @(negedge clk);
            sample_valid = 1'b0;

            cycles_waited = 0;
            while (output_valid !== 1'b1 &&
                   cycles_waited < MAX_LATENCY) begin
                @(posedge clk);
                #1;
                cycles_waited = cycles_waited + 1;
            end
            if (output_valid !== 1'b1)
                $fatal(1, "FAIL: timed out waiting for sample %0d output", i);

            $fwrite(output_file, "%0d\n", dout);
            output_count = output_count + 1;
        end

        $fclose(output_file);
        $dumpflush;
        if (output_count != sample_count)
            $fatal(1, "FAIL: wrote %0d outputs; expected %0d.",
                   output_count, sample_count);
        $display("SIMULATION COMPLETE: replayed %0d samples from %s; wrote %0d outputs to %s.",
                 sample_count, SENSOR_MEM_FILE, output_count, OUTPUT_FILE);
        $display("Run compare_fpga_output.py to validate the serial FIR values.");
        $finish;
    end

endmodule
