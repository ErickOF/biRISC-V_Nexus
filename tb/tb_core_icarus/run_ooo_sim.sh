#!/usr/bin/env bash
set -euo pipefail

echo "Cleaning previous builds, just to avoid unexpected issues if previous build was pointing to testbench in branch mode"
make clean

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"
ASM_FILE="${SCRIPT_DIR}/stress_test_ooo.S"
ELF_FILE="${BUILD_DIR}/stress_test_ooo.elf"
HEX_FILE="${BUILD_DIR}/stress_test_ooo.hex"
LOG_DIR="${BUILD_DIR}/logs"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="${LOG_DIR}/run_ooo_sim_${TIMESTAMP}.log"

RISCV_GCC="${RISCV_GCC:-riscv32-unknown-elf-gcc}"
RISCV_OBJCOPY="${RISCV_OBJCOPY:-riscv32-unknown-elf-objcopy}"

mkdir -p "${BUILD_DIR}" "${LOG_DIR}"

# Save all output (stdout/stderr) to both console and log file.
exec > >(tee -a "${LOG_FILE}") 2>&1

# Also record executed commands. Disable with TRACE_CMDS=0.
if [[ "${TRACE_CMDS:-1}" == "1" ]]; then
    export PS4='+ [${BASH_SOURCE##*/}:${LINENO}] '
    set -x
fi

echo "==== Start run_ooo_sim.sh: $(date '+%F %T') ===="
echo "Log: ${LOG_FILE}"

on_exit() {
    local ec="$?"
    echo "==== End run_ooo_sim.sh: $(date '+%F %T') | exit=${ec} ===="
    echo "Log saved at: ${LOG_FILE}"
}
trap on_exit EXIT

if ! command -v "${RISCV_GCC}" >/dev/null 2>&1; then
    echo "ERROR: ${RISCV_GCC} not found in PATH"
    exit 1
fi

if ! command -v "${RISCV_OBJCOPY}" >/dev/null 2>&1; then
    echo "ERROR: ${RISCV_OBJCOPY} not found in PATH"
    exit 1
fi

if [[ ! -f "${ASM_FILE}" ]]; then
    echo "ERROR: File does not exist: ${ASM_FILE}"
    exit 1
fi

echo "[1/4] Compiling ${ASM_FILE} -> ${ELF_FILE}"
"${RISCV_GCC}" \
    -march=rv32im \
    -mabi=ilp32 \
    -nostdlib \
    -nostartfiles \
    -Wl,-Ttext=0x80000000 \
    -Wl,--no-relax \
    -o "${ELF_FILE}" \
    "${ASM_FILE}"

echo "[2/4] Extracting machine code to HEX -> ${HEX_FILE}"
"${RISCV_OBJCOPY}" -O ihex "${ELF_FILE}" "${HEX_FILE}"

echo "[3/4] Running simulation with make"
pushd "${SCRIPT_DIR}" >/dev/null
make ELF_FILE="${ELF_FILE}" OBJCOPY="${RISCV_OBJCOPY}" VDEFINES="-DTEST_MODE_OOO"
popd >/dev/null

echo "[4/4] Simulation finished"

WAVE_VCD="${SCRIPT_DIR}/waveform.vcd"
WAVE_FST="${SCRIPT_DIR}/waveform.fst"

if command -v gtkwave >/dev/null 2>&1; then
    if [[ -f "${WAVE_VCD}" ]]; then
        echo "Opening GTKWave with ${WAVE_VCD}"
        gtkwave "${WAVE_VCD}" "${SCRIPT_DIR}/gtksettings.sav" >/dev/null 2>&1 &
    elif [[ -f "${WAVE_FST}" ]]; then
        echo "Opening GTKWave with ${WAVE_FST}"
        gtkwave "${WAVE_FST}" "${SCRIPT_DIR}/gtksettings.sav" >/dev/null 2>&1 &
    else
        echo "Warning: waveform.vcd and waveform.fst were not found"
    fi
else
    echo "Warning: gtkwave is not installed."
fi

echo "OoO flow completed successfully."
