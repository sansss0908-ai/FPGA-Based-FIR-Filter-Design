`timescale 1ns/1ps

module tb_sample_valid_sync;

    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg async_valid = 1'b0;
    wire valid_pulse;
    integer pulse_count = 0;
    integer high_cycle_count = 0;

    sample_valid_sync uut (
        .clk(clk),
        .rst_n(rst_n),
        .async_valid(async_valid),
        .valid_pulse(valid_pulse)
    );

    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (valid_pulse) begin
            pulse_count = pulse_count + 1;
            high_cycle_count = high_cycle_count + 1;
        end
    end

    initial begin
        repeat (3) @(negedge clk);
        rst_n = 1'b1;

        #2 async_valid = 1'b1;
        repeat (6) @(negedge clk);
        async_valid = 1'b0;
        repeat (5) @(negedge clk);

        #2 async_valid = 1'b1;
        repeat (3) @(negedge clk);
        async_valid = 1'b0;
        repeat (5) @(negedge clk);

        if (pulse_count != 2 || high_cycle_count != 2)
            $fatal(1, "FAIL: expected two one-cycle pulses; got %0d pulses across %0d cycles",
                   pulse_count, high_cycle_count);

        $display("PASS: each asynchronous valid level produced one synchronized pulse.");
        $finish;
    end

endmodule
