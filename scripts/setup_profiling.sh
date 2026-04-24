#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 [--reset]"
    echo "  (no args)  enable profiling mode (relaxed perf sysctls + performance governor)"
    echo "  --reset    restore defaults (restrictive sysctls; leaves amd-pstate-epp at performance)"
    exit 1
}

mode="enable"
case "${1:-}" in
    "")        mode="enable" ;;
    --reset)   mode="reset" ;;
    -h|--help) usage ;;
    *)         usage ;;
esac

if [[ "$mode" == "enable" ]]; then
    sudo sysctl -w kernel.nmi_watchdog=0
    sudo sysctl -w kernel.perf_event_paranoid=0
    sudo sysctl -w kernel.perf_event_mlock_kb=65536
    sudo sysctl -w kernel.kptr_restrict=0
    sudo cpupower frequency-set -g performance
    echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference > /dev/null
else
    sudo sysctl -w kernel.nmi_watchdog=1
    sudo sysctl -w kernel.perf_event_paranoid=2
    sudo sysctl -w kernel.perf_event_mlock_kb=516
    sudo sysctl -w kernel.kptr_restrict=1
    sudo cpupower frequency-set -g performance
fi
