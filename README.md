# Design-of-FPGA-Based-FIR-Filter

This project captures MPU6050 Z-axis acceleration on an STM32F446RE, sends each
16-bit signed sample to an FPGA over SPI, and provides a MATLAB reference model
for the FPGA FIR filter.

## MATLAB reference workflow

Open the repository folder in MATLAB or VS Code and run:

```matlab
design_fir_from_sensor
```

The input file must be `sensor_vibration_dataset.csv` in the current folder.
The script designs the documented 64-tap, 500 Hz, 20/50 Hz low-pass filter and
generates:

- `fir_coeff_q15.txt`: decimal Q15 coefficients
- `fir_coeff_q15.mem`: hexadecimal coefficients for Verilog `$readmemh`
- `sensor_fir_output.csv`: floating-point and bit-accurate FPGA reference
  outputs (`Filtered_Accel_Z_Floating` and `Filtered_Accel_Z_FPGA`)

The FPGA reference treats each input as a signed 16-bit integer, multiplies it
by each signed Q15 coefficient, accumulates in 64 bits, performs an arithmetic
right shift by 15, and saturates the result to signed 16 bits. The HDL must
implement the same rules for sample-by-sample comparison with the CSV.

In VS Code, install the **MATLAB** extension, open this folder, configure the
extension to use the installed MATLAB executable, and run the script from the
MATLAB Command Window or with the MATLAB Run command. VS Code still requires a
local MATLAB installation; the extension does not provide MATLAB itself.

## Data capture

Use `logger.py` after setting the correct serial `PORT`. It creates the CSV
input and `sensor_data.mem` sample file from the STM32 UART stream.

The STM32 timer is configured for 500 Hz with the current 84 MHz timer clock.
Verify the actual sample period on hardware before changing `Fs` in the
MATLAB script.

## FPGA integration checklist

The FPGA project must provide HDL source and a testbench that:

1. Loads all 64 lines of `fir_coeff_q15.mem` in tap order.
2. Accepts the two SPI bytes as one signed 16-bit sample.
3. Produces one signed 16-bit output for each accepted sample.
4. Applies the Q15 scaling and saturation rules described above.
5. Writes captured FPGA outputs to a file that can be compared with
   `Filtered_Accel_Z_FPGA` in `sensor_fir_output.csv`.

The repository contains the STM32 firmware, a compiled `fir_sim` artifact,
and the FPGA HDL source and reproducible comparison testbenches described below.

## Verilog FIR implementation

The repository includes:

- `fir_filter.v`: a synthesizable 64-tap streaming FIR. Assert `sample_valid`
  for one clock cycle when `din` contains a new signed 16-bit sample; the
  corresponding signed 16-bit result is available on `dout` after that clock.
- `fir_coeff_q15.mem`: the 64 signed Q15 coefficients in tap order for
  `$readmemh`.
- `tb_fir_filter.v`: a self-checking simulation testbench covering startup,
  signed inputs, and output saturation.
- `tb_fir_filter_real.v`: loads all 1000 samples from `sensor_data.mem`,
  writes each HDL `dout` value to `fpga_output.txt`, and preserves startup
  samples. The bench checks that one output is written for every input sample
  and creates `fir_real_wave.vcd` for GTKWave analysis.
- `compare_fpga_output.py`: compares `fpga_output.txt` against the
  `Filtered_Accel_Z_FPGA` column in `sensor_fir_output.csv` and verifies the
  CSV has exactly the four generated columns.
- `spi_slave_sample.v`: mode-0 SPI slave that assembles two MSB-first bytes
  and pulses `sample_valid` on each complete sample.
- `tb_spi_slave_sample.v`: checks two-byte MSB-first sample assembly.
- `fir_filter_serial.v`: one-tap-per-clock FIR alternative. It exposes
  `ready` and takes 64 clocks per accepted sample instead of using 64
  multipliers concurrently.

Run with Icarus Verilog from this directory:

```text
iverilog -g2012 -o fir_tb.vvp fir_filter.v tb_fir_filter.v
vvp fir_tb.vvp
```

The SPI receiver check is:

```text
iverilog -g2012 -o spi_tb.vvp spi_slave_sample.v tb_spi_slave_sample.v
vvp spi_tb.vvp
```

For the real captured dataset, first run `design_fir_from_sensor` in MATLAB,
then run:

```text
iverilog -g2012 -o fir_real_tb.vvp fir_filter.v tb_fir_filter_real.v
vvp fir_real_tb.vvp
python compare_fpga_output.py
```

The real-data testbench also writes a waveform dump. Open it with GTKWave:

```text
gtkwave fir_real_wave.vcd
```

Useful signals to add in GTKWave are `clk`, `rst_n`, `sample_valid`, `din`,
`dout`, and the FIR internals under `uut`, such as `accumulator`,
`scaled_result`, `product`, and `delay_line`.

The Python step is the CSV diff: it requires exactly 1000 output lines and
reports the first mismatch, including its sample index and both values.

The HDL uses the same zero-initialized delay line, 64-bit accumulation,
arithmetic right shift by 15, and signed 16-bit saturation as the MATLAB
`yFpga` reference.

`fir_coeff_q15.txt` and `sensor_fir_output.csv` are generated MATLAB
artifacts and are intentionally not source-controlled. `fir_coeff_q15.mem`
and `sensor_data.mem` are checked-in simulation inputs, so the HDL testbench
can run reproducibly after the MATLAB reference CSV has been generated.
