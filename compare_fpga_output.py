import csv
import re
import sys


def read_sensor_inputs(csv_path, mem_path):
    with open(csv_path, newline="", encoding="utf-8") as csv_file:
        reader = csv.DictReader(csv_file)
        if reader.fieldnames != ["Sample_Index", "Raw_Accel_Z"]:
            raise SystemExit(
                f"FAIL: expected sensor CSV columns "
                f"['Sample_Index', 'Raw_Accel_Z'], found {reader.fieldnames}"
            )
        raw_values = []
        for index, row in enumerate(reader):
            try:
                row_index = int(row["Sample_Index"])
                value = int(row["Raw_Accel_Z"])
            except (KeyError, TypeError, ValueError) as error:
                raise SystemExit(
                    f"FAIL: invalid sensor CSV row {index + 2}: {error}"
                ) from error
            if row_index != index:
                raise SystemExit(
                    f"FAIL: sensor CSV index at row {index + 2} is "
                    f"{row_index}; expected {index}"
                )
            if not -32768 <= value <= 32767:
                raise SystemExit(
                    f"FAIL: sensor value at sample {index} is outside int16: {value}"
                )
            raw_values.append(value)

    with open(mem_path, encoding="ascii") as mem_file:
        mem_lines = [line.rstrip("\r\n") for line in mem_file]
    for index, word in enumerate(mem_lines):
        if re.fullmatch(r"[0-9A-Fa-f]{4}", word) is None:
            raise SystemExit(
                f"FAIL: sensor_data.mem line {index + 1} is not 4-digit hex: {word!r}"
            )
    if len(mem_lines) != len(raw_values):
        raise SystemExit(
            f"FAIL: sensor input length mismatch: CSV={len(raw_values)}, "
            f"MEM={len(mem_lines)}"
        )
    clipped_high = sum(value == 32767 for value in raw_values)
    clipped_low = sum(value == -32768 for value in raw_values)
    if clipped_high or clipped_low:
        print(
            f"WARNING: sensor capture touches int16 rails: "
            f"+32767={clipped_high}, -32768={clipped_low}."
        )

    mem_values = [(int(word, 16) ^ 0x8000) - 0x8000 for word in mem_lines]
    for index, (csv_value, mem_value) in enumerate(zip(raw_values, mem_values)):
        if csv_value != mem_value:
            raise SystemExit(
                f"FAIL: sensor input mismatch at sample {index}: "
                f"CSV={csv_value}, MEM={mem_value}"
            )
    print(
        f"PASS: {len(raw_values)} sensor samples match between CSV and "
        "4-digit-hex MEM."
    )
    return raw_values


def validate_coefficients(path):
    with open(path, encoding="ascii") as coeff_file:
        lines = [line.rstrip("\r\n") for line in coeff_file]
    if len(lines) != 64:
        raise SystemExit(
            f"FAIL: expected 64 Q15 coefficient words, found {len(lines)}"
        )
    for index, word in enumerate(lines):
        if re.fullmatch(r"[0-9A-Fa-f]{4}", word) is None:
            raise SystemExit(
                f"FAIL: coefficient line {index + 1} is not 4-digit hex: {word!r}"
            )


def read_expected(path):
    with open(path, newline="", encoding="utf-8") as csv_file:
        reader = csv.DictReader(csv_file)
        expected_columns = [
            "Sample_Index",
            "Raw_Accel_Z",
            "Filtered_Accel_Z_Floating",
            "Filtered_Accel_Z_FPGA",
        ]
        if reader.fieldnames != expected_columns:
            raise SystemExit(
                f"FAIL: expected CSV columns {expected_columns}, "
                f"found {reader.fieldnames}"
            )

        values = []
        raw_values = []
        for row_number, row in enumerate(reader, start=2):
            try:
                sample_index = int(row["Sample_Index"])
                raw_values.append(int(row["Raw_Accel_Z"]))
                values.append(int(row["Filtered_Accel_Z_FPGA"]))
            except (KeyError, TypeError, ValueError) as error:
                raise SystemExit(
                    f"FAIL: invalid FPGA reference at CSV row "
                    f"{row_number}: {error}"
                ) from error
            if sample_index != row_number - 2:
                raise SystemExit(
                    f"FAIL: reference CSV index at row {row_number} is "
                    f"{sample_index}; expected {row_number - 2}"
                )
        return raw_values, values


def read_actual(path):
    try:
        with open(path, encoding="utf-8") as output_file:
            return [int(line.strip()) for line in output_file if line.strip()]
    except ValueError as error:
        raise SystemExit(f"FAIL: invalid non-integer FPGA output: {error}") from error


def main():
    expected_path = sys.argv[1] if len(sys.argv) > 1 else "sensor_fir_output.csv"
    actual_path = sys.argv[2] if len(sys.argv) > 2 else "fpga_output.txt"
    for path, description in (
        ("sensor_vibration_dataset.csv", "sensor CSV"),
        ("sensor_data.mem", "sensor memory input"),
        ("fir_coeff_q15.mem", "FIR coefficient input"),
        (expected_path, "MATLAB reference CSV"),
        (actual_path, "HDL output file"),
    ):
        try:
            with open(path):
                pass
        except OSError as error:
            raise SystemExit(
                f"FAIL: cannot read {description} '{path}': {error}. "
                "Run the required generation step first."
            ) from error

    sensor_values = read_sensor_inputs(
        "sensor_vibration_dataset.csv", "sensor_data.mem"
    )
    validate_coefficients("fir_coeff_q15.mem")
    reference_inputs, expected = read_expected(expected_path)
    if reference_inputs != sensor_values:
        raise SystemExit(
            "FAIL: reference CSV Raw_Accel_Z samples do not match "
            "sensor_vibration_dataset.csv"
        )
    actual = read_actual(actual_path)

    if len(expected) != len(actual):
        raise SystemExit(
            f"FAIL: output length mismatch: MATLAB={len(expected)}, FPGA={len(actual)}"
        )

    mismatches = [
        (index, expected_value, actual_value)
        for index, (expected_value, actual_value) in enumerate(zip(expected, actual))
        if expected_value != actual_value
    ]
    if mismatches:
        index, expected_value, actual_value = mismatches[0]
        raise SystemExit(
            f"FAIL: {len(mismatches)} mismatches; first at sample {index}: "
            f"MATLAB={expected_value}, FPGA={actual_value}"
        )
    print(f"PASS: {len(actual)} FPGA outputs match Filtered_Accel_Z_FPGA.")


if __name__ == "__main__":
    main()
