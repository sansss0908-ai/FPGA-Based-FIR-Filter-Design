import serial
import time
import csv

# --- CONFIGURATION ---
PORT = "COM4"       # Change to your USB-UART COM port.
BAUD_RATE = 115200  # Must match huart2 baud rate.
CAPTURE_SECONDS = 60
PROGRESS_INTERVAL = 500

CSV_FILE = "sensor_vibration_dataset.csv"
MEM_FILE = "sensor_data.mem"
RATE_FILE = "sample_rate_hz.txt"

def main():
    print(f"Opening serial port {PORT} at {BAUD_RATE} baud...")
    
    try:
        ser = serial.Serial(PORT, BAUD_RATE, timeout=1)
        time.sleep(2)  # Wait for serial connection to stabilize
        ser.reset_input_buffer()
        print("Connected! Logging data...\n")
    except Exception as e:
        print(f"Error opening serial port: {e}")
        return

    samples = []
    first_sample_time = None
    last_sample_time = None
    wait_started = time.perf_counter()

    while (
        first_sample_time is None
        or last_sample_time - first_sample_time < CAPTURE_SECONDS
    ):
        try:
            line = ser.readline().decode('utf-8', errors='ignore').strip()
            if line:
                val = int(line)  # Read integer raw_z value sent by STM32
                sample_time = time.perf_counter()
                if first_sample_time is None:
                    first_sample_time = sample_time
                samples.append(val)
                last_sample_time = sample_time
                if len(samples) % PROGRESS_INTERVAL == 0:
                    print(f"Captured {len(samples)} samples...")
            elif first_sample_time is None and time.perf_counter() - wait_started > 10:
                print("No numeric sensor samples received within 10 seconds.")
                ser.close()
                return
        except ValueError:
            continue  # Skip incomplete lines
        except KeyboardInterrupt:
            print("\nLogging interrupted by user.")
            break

    ser.close()

    if not samples:
        print("No samples logged.")
        return

    measured_seconds = last_sample_time - first_sample_time
    measured_rate = (len(samples) - 1) / measured_seconds if measured_seconds > 0 else 0
    clipped_high = sum(val == 32767 for val in samples)
    clipped_low = sum(val == -32768 for val in samples)
    print(
        f"\nCaptured {len(samples)} samples in {measured_seconds:.3f} s "
        f"({measured_rate:.2f} samples/s)."
    )
    if clipped_high or clipped_low:
        print(
            f"WARNING: int16 rail values detected: +32767={clipped_high}, "
            f"-32768={clipped_low}. These may indicate accelerometer clipping."
        )

    with open(RATE_FILE, mode='w') as rate_f:
        rate_f.write(f"{measured_rate:.9f}\n")
    print(f"Saved measured sample rate to: {RATE_FILE}")

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