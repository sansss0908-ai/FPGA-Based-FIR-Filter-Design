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

The current repository contains the STM32 firmware and a compiled `fir_sim`
artifact, but not the FPGA HDL source or a reproducible HDL comparison
testbench. Those are still required for an end-to-end FPGA result.
