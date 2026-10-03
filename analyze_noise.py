import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from scipy.signal import welch

# 1. Load Live Sensor Dataset
df = pd.read_csv('sensor_vibration_dataset.csv')

# Handle both raw CSV formats (with headers or single column)
if 'Raw_Accel_Z' in df.columns:
    raw_z = df['Raw_Accel_Z'].values
else:
    raw_z = df.iloc[:, 0].values

Fs = 500  # 500 Hz sampling rate
N = len(raw_z)
time = np.arange(N) / Fs

# 2. FFT Analysis
fft_vals = np.abs(np.fft.rfft(raw_z))
freqs = np.fft.rfftfreq(N, 1/Fs)

# 3. Power Spectral Density (PSD)
psd_freqs, psd_vals = welch(raw_z, fs=Fs, nperseg=min(256, N))

# 4. Plotting Results
plt.figure(figsize=(10, 8))

plt.subplot(3, 1, 1)
plt.plot(time, raw_z, color='b')
plt.title('Time-Domain Live Acceleration Signal')
plt.xlabel('Time (s)')
plt.ylabel('Raw Z Value')
plt.grid(True)

plt.subplot(3, 1, 2)
plt.plot(freqs, fft_vals, color='r')
plt.title('Magnitude Spectrum (FFT)')
plt.xlabel('Frequency (Hz)')
plt.ylabel('Magnitude')
plt.grid(True)

plt.subplot(3, 1, 3)
plt.semilogy(psd_freqs, psd_vals, color='g')
plt.title('Power Spectral Density (Welch PSD)')
plt.xlabel('Frequency (Hz)')
plt.ylabel('PSD')
plt.grid(True)

plt.tight_layout()
plt.savefig('live_noise_analysis.png')
print("Analysis complete! Saved plot to live_noise_analysis.png")
plt.show()