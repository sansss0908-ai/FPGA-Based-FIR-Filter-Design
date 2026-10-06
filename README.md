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
- `sensor_fir_output.csv`: MATLAB reference output

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
