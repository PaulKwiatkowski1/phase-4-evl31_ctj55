#!/usr/bin/env python3
import difflib
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CASES = ROOT / "test" / "cases"
EXP = ROOT / "test" / "exp"
MCC = ROOT / "obj" / "mcc"

def main() -> int:
    if not MCC.exists():
        print("error: ./obj/mcc not found; run make first")
        return 1

    failures = 0
    for case_path in sorted(CASES.glob("*.mC")):
        base = case_path.stem
        exp_path = EXP / f"{base}.exp"

        proc = subprocess.run([str(MCC), str(case_path)], cwd=ROOT, capture_output=True, text=True)
        actual = proc.stdout
        expected = exp_path.read_text()

        if actual == expected:
            print(f"PASS {base}")
            continue

        failures += 1
        print(f"FAIL {base}")
        diff = difflib.unified_diff(
            expected.splitlines(keepends=True),
            actual.splitlines(keepends=True),
            fromfile=str(exp_path.relative_to(ROOT)),
            tofile="actual",
        )
        sys.stdout.writelines(diff)

    return 1 if failures else 0

if __name__ == "__main__":
    raise SystemExit(main())
