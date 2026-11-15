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
fprintf('Raw min = %d, max = %d (int16 limits: -32768, 32767)\n', min(x), max(x));
fprintf('Samples at the limits: %d\n', sum(x <= -32768 | x >= 32767));
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
coeffQ15 = coeffQ15(:);

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

% MATLAB bitshift on signed integers must match Verilog's arithmetic >>>.
negativeAccumulator = int64(-1);
if bitshift(negativeAccumulator, -15) ~= negativeAccumulator
    error('Signed right-shift behavior does not match Verilog arithmetic shift.');
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
title(sprintf('64-tap Q15 FPGA reference (pass 0-%g Hz, stop %g Hz)', Fpass, Fstop));

figure('Name', 'FIR response');
freqz(h, 1, 2048, Fs);
title('Designed FIR frequency response');

[Hf, f] = freqz(h, 1, 2048, Fs);
[Hq, ~] = freqz(double(coeffQ15)/32768, 1, 2048, Fs);
figure('Name', 'Float vs Q15 response');
plot(f, 20*log10(abs(Hf)), f, 20*log10(abs(Hq)));
grid on;
legend('Floating', 'Q15');
xlabel('Frequency (Hz)');
ylabel('Magnitude (dB)');

%% Elliptic IIR comparison (same pass/stop band as the FIR)
% Used only for the paper's FIR-vs-IIR comparison. Not part of the FPGA design.
pbIdx = f <= Fpass;                         % f and Hf come from the freqz call above
sbIdx = f >= Fstop;
Rp = max(abs(20*log10(abs(Hf(pbIdx)))));    % measured FIR pass-band ripple (dB)
Rs = -max(20*log10(abs(Hf(sbIdx))));        % measured FIR stop-band attenuation (dB)
Rp = max(Rp, 0.01);                         % guard against a zero ripple value
fprintf('FIR: pass-band ripple %.3f dB, stop-band attenuation %.1f dB\n', Rp, Rs);

[nIIR, Wn] = ellipord(Fpass/(Fs/2), Fstop/(Fs/2), Rp, Rs);
[bI, aI]   = ellip(nIIR, Rp, Rs, Wn);
[gdI, fI]  = grpdelay(bI, aI, 2048, Fs);
gdMs       = gdI(fI <= Fpass) / Fs * 1000;  % IIR group delay in ms over the pass band
fprintf('Elliptic IIR order %d; stable = %d; group delay %.1f to %.1f ms over 0-%g Hz\n', ...
        nIIR, isstable(bI, aI), min(gdMs), max(gdMs), Fpass);

yIIR = filter(bI, aI, double(xInt16));      % IIR output on the same data

tIdx = (0:numel(x)-1)' / Fs;
figure('Name', 'FIR vs IIR');
plot(tIdx, double(yFpga) - mean(double(yFpga(64:end))), ...
     tIdx, yIIR - mean(yIIR));
grid on;
legend('FIR (Q15)', 'IIR (elliptic)');
xlabel('Time (s)');
ylabel('Counts (mean removed)');
title('FIR versus IIR output on the same data');

fprintf('Designed %d-tap FIR for Fs = %g Hz.\n', numel(h), Fs);
fprintf('Passband: 0-%g Hz; stopband starts at %g Hz.\n', Fpass, Fstop);
fprintf('Generated fir_coeff_q15.txt, fir_coeff_q15.mem, and sensor_fir_output.csv.\n');
fprintf('CSV includes floating-point and bit-accurate FPGA reference outputs.\n');