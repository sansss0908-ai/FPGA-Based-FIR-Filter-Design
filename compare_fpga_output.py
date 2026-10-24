import csv
import sys


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
        for row_number, row in enumerate(reader, start=2):
            try:
                values.append(int(row["Filtered_Accel_Z_FPGA"]))
            except (KeyError, TypeError, ValueError) as error:
                raise SystemExit(
                    f"FAIL: invalid Filtered_Accel_Z_FPGA at CSV row "
                    f"{row_number}: {error}"
                ) from error
        return values


def read_actual(path):
    with open(path, encoding="utf-8") as output_file:
        return [int(line.strip()) for line in output_file if line.strip()]


def main():
    expected_path = sys.argv[1] if len(sys.argv) > 1 else "sensor_fir_output.csv"
    actual_path = sys.argv[2] if len(sys.argv) > 2 else "fpga_output.txt"
    for path, description in (
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
    expected = read_expected(expected_path)
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
