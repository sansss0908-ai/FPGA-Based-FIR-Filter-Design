`timescale 1ns/1ps

module tb_fir_filter;

    localparam integer NUM_TAPS = 64;
    localparam integer NUM_SAMPLES = 160;

    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg sample_valid = 1'b0;
    reg signed [15:0] din = 16'sd0;
    wire signed [15:0] dout;

    reg signed [15:0] reference_delay [0:NUM_TAPS-1];
    reg signed [15:0] reference_coeff [0:NUM_TAPS-1];
    reg signed [15:0] reference_sample;
    reg signed [31:0] reference_product;
    reg signed [63:0] reference_accumulator;
    reg signed [63:0] reference_scaled;
    reg signed [15:0] expected_output;
    integer i;
    integer sample_number;
    integer failures;

    fir_filter uut (
        .clk(clk),
        .rst_n(rst_n),
        .sample_valid(sample_valid),
        .din(din),
        .dout(dout)
    );

    always #5 clk = ~clk;

    task send_sample;
        input integer sample_value;
        integer j;
        begin
            reference_sample = sample_value;
            reference_accumulator = 64'sd0;
            for (j = 0; j < NUM_TAPS; j = j + 1) begin
                if (j == 0)
                    reference_product = reference_sample * reference_coeff[j];
                else
                    reference_product = reference_delay[j-1] * reference_coeff[j];
                reference_accumulator = reference_accumulator + reference_product;
            end

            reference_scaled = reference_accumulator >>> 15;
            if (reference_scaled > 32767)
                expected_output = 16'sh7fff;
            else if (reference_scaled < -32768)
                expected_output = -16'sh8000;
            else
                expected_output = reference_scaled[15:0];

            @(negedge clk);
            din = reference_sample;
            sample_valid = 1'b1;
            @(posedge clk);
            #1;
            if (dout !== expected_output) begin
                $display("FAIL sample=%0d input=%0d expected=%0d got=%0d",
                         sample_number, sample_value, expected_output, dout);
                failures = failures + 1;
            end
            sample_number = sample_number + 1;
            sample_valid = 1'b0;

            for (j = NUM_TAPS-1; j > 0; j = j - 1)
                reference_delay[j] = reference_delay[j-1];
            reference_delay[0] = reference_sample;
        end
    endtask

    initial begin
        $readmemh("fir_coeff_q15.mem", reference_coeff);
        failures = 0;
        sample_number = 0;
        for (i = 0; i < NUM_TAPS; i = i + 1)
            reference_delay[i] = 16'sd0;

        repeat (3) @(posedge clk);
        rst_n = 1'b1;

        // Exercise startup, positive/negative values, and saturation.
        send_sample(32767);
        send_sample(-32768);
        send_sample(16000);
        send_sample(-16000);
        send_sample(32767);
        send_sample(-32768);
        for (i = 0; i < NUM_SAMPLES-6; i = i + 1)
            send_sample(((i * 7919) % 65536) - 32768);

        if (failures == 0)
            $display("PASS: %0d samples matched the bit-accurate Q15 reference.",
                     sample_number);
        else
            $display("FAIL: %0d mismatches out of %0d samples.",
                     failures, sample_number);
        $finish;
    end

endmodule
