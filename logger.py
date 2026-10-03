import serial
import time
import csv

# --- CONFIGURATION ---
PORT = "COM4"          # Change to your USB-UART COM port (e.g., "COM3", "COM4", or "/dev/ttyUSB0")
BAUD_RATE = 115200     # Must match huart2 baud rate (115200)
SAMPLES_TO_LOG = 1000  # Number of samples to capture (1000 samples = 2 seconds at 500 Hz)

CSV_FILE = "sensor_vibration_dataset.csv"
MEM_FILE = "sensor_data.mem"

def main():
    print(f"Opening serial port {PORT} at {BAUD_RATE} baud...")
    
    try:
        ser = serial.Serial(PORT, BAUD_RATE, timeout=2)
        time.sleep(2)  # Wait for serial connection to stabilize
        ser.reset_input_buffer()
        print("Connected! Logging data...\n")
    except Exception as e:
        print(f"Error opening serial port: {e}")
        return

    samples = []
    
    while len(samples) < SAMPLES_TO_LOG:
        try:
            line = ser.readline().decode('utf-8', errors='ignore').strip()
            if line:
                val = int(line)  # Read integer raw_z value sent by STM32
                samples.append(val)
                print(f"Sample {len(samples)}/{SAMPLES_TO_LOG}: {val}")
        except ValueError:
            continue  # Skip incomplete lines
        except KeyboardInterrupt:
            print("\nLogging interrupted by user.")
            break

    ser.close()

    if not samples:
        print("No samples logged.")
        return

    # 1. Save as CSV
    with open(CSV_FILE, mode='w', newline='') as csv_f:
        writer = csv.writer(csv_f)
        writer.writerow(["Sample_Index", "Raw_Accel_Z"])
        for idx, val in enumerate(samples):
            writer.writerow([idx, val])
    print(f"\nSaved CSV dataset to: {CSV_FILE}")

    # 2. Save as 16-bit Hex .mem for Verilog Testbench ($readmemh)
    with open(MEM_FILE, mode='w') as mem_f:
        for val in samples:
            # Convert signed 16-bit integer to 4-character hex string
            hex_val = f"{val & 0xFFFF:04X}"
            mem_f.write(f"{hex_val}\n")
    print(f"Saved Verilog memory file to: {MEM_FILE}")

if __name__ == "__main__":
    main()