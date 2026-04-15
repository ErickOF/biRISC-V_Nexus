#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BENCH_DIR="${ROOT_DIR}/tb/riscv-benchmarks"

if [[ -d "${BENCH_DIR}/.git" ]]; then
    echo "Updating riscv-benchmarks in ${BENCH_DIR}"
    git -C "${BENCH_DIR}" fetch --all --tags
    git -C "${BENCH_DIR}" checkout master
    git -C "${BENCH_DIR}" pull --ff-only origin master
else
    echo "Cloning riscv-benchmarks into ${BENCH_DIR}"
    git clone --recurse-submodules --jobs 4 https://github.com/ucb-bar/riscv-benchmarks.git "${BENCH_DIR}"
fi

cd "${BENCH_DIR}"

# Ensure submodules are configured and cloned using HTTPS where possible.
git submodule set-url riscv-pk https://github.com/riscv/riscv-pk.git || true
git submodule set-url riscv-test-env https://github.com/riscv/riscv-test-env.git || true
git submodule set-url libamf https://github.com/ericlove/libamf.git || true

git submodule sync --recursive

git submodule deinit --all -f || true

git submodule update --init --recursive

echo "riscv-benchmarks is ready at ${BENCH_DIR}"
