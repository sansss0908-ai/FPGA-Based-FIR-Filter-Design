%% Design and validate the FPGA FIR filter from captured sensor data
% Intended interface: 500 Hz sample rate, 16-bit signed samples, Q15
% coefficients, 64 taps (FIR order 63).

clear; clc; close all;

csvName = 'sensor_vibration_dataset.csv';
Fs = 500;
Fpass = 20;
Fstop = 50;
filterOrder = 63;

if exist(csvName, 'file') ~= 2
    error('Cannot find %s. Run this script from the project folder.', csvName);
end

data = readtable(csvName);
if ismember('Raw_Accel_Z', data.Properties.VariableNames)
    x = double(data.Raw_Accel_Z);
else
    x = double(data{:, 1});
end
x = x(:);
if isempty(x) || any(~isfinite(x))
    error('The input CSV contains no valid finite samples.');
end
if any(x < -32768 | x > 32767 | x ~= fix(x))
    error('The input samples must be integer values in the signed 16-bit range.');
end
xInt16 = int16(x);

% Remove the static gravity/DC component only for the analysis plot.
xCentered = x - mean(x);

% Equiripple low-pass: passband 0-20 Hz, stopband starts at 50 Hz.
h = firpm(filterOrder, [0 Fpass Fstop Fs/2] / (Fs/2), [1 1 0 0]);
yFloating = filter(h, 1, double(xInt16));

% Convert coefficients to signed Q15 for the FPGA.
coeffQ15 = round(h * 32768);
coeffQ15 = min(max(coeffQ15, -32768), 32767);

% Bit-accurate reference for the FPGA datapath:
% signed 16-bit samples * signed Q15 coefficients, 64-bit accumulation,
% arithmetic right shift by 15, then signed 16-bit saturation.
acc = zeros(size(xInt16), 'int64');
yFpga = zeros(size(xInt16), 'int16');
for n = 1:numel(xInt16)
    firstTap = max(1, n - filterOrder);
    sampleIndices = n:-1:firstTap;
    coeffIndices = 1:numel(sampleIndices);
    acc(n) = sum(int64(xInt16(sampleIndices)) .* int64(coeffQ15(coeffIndices)));
    scaled = bitshift(acc(n), -15);
    yFpga(n) = int16(min(max(scaled, int64(-32768)), int64(32767)));
end

% Write decimal coefficients and one 16-bit two's-complement hex word per line.
writematrix(coeffQ15(:), 'fir_coeff_q15.txt', 'Delimiter', 'tab');
fid = fopen('fir_coeff_q15.mem', 'w');
if fid == -1
    error('Could not create fir_coeff_q15.mem.');
end
cleanup = onCleanup(@() fclose(fid));
for k = 1:numel(coeffQ15)
    fprintf(fid, '%04X\n', mod(coeffQ15(k), 65536));
end
clear cleanup;

result = table((0:numel(x)-1)', xInt16, yFloating, yFpga, ...
    'VariableNames', {'Sample_Index', 'Raw_Accel_Z', ...
    'Filtered_Accel_Z_Floating', 'Filtered_Accel_Z_FPGA'});
writetable(result, 'sensor_fir_output.csv');

figure('Name', 'Sensor FIR validation');
subplot(2, 1, 1);
plot((0:numel(x)-1)' / Fs, xCentered);
grid on;
xlabel('Time (s)');
ylabel('Centered raw counts');
title('Input sensor signal');

subplot(2, 1, 2);
plot((0:numel(yFpga)-1)' / Fs, yFpga);
grid on;
xlabel('Time (s)');
ylabel('Filtered raw counts');
title(sprintf('64-tap Q15 FPGA reference (%g-%g Hz)', Fpass, Fstop));

figure('Name', 'FIR response');
freqz(h, 1, 2048, Fs);
title('Designed FIR frequency response');

fprintf('Designed %d-tap FIR for Fs = %g Hz.\n', numel(h), Fs);
fprintf('Passband: 0-%g Hz; stopband starts at %g Hz.\n', Fpass, Fstop);
fprintf('Generated fir_coeff_q15.txt, fir_coeff_q15.mem, and sensor_fir_output.csv.\n');
fprintf('CSV includes floating-point and bit-accurate FPGA reference outputs.\n');
