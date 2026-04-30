#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 [--reset]"
    echo "  (no args)  enable profiling mode (relaxed perf sysctls + performance governor + BCC NOPASSWD drop-in)"
    echo "  --reset    restore defaults (restrictive sysctls; leaves amd-pstate-epp at performance; removes drop-in)"
    exit 1
}

mode="enable"
case "${1:-}" in
    "")        mode="enable" ;;
    --reset)   mode="reset" ;;
    -h|--help) usage ;;
    *)         usage ;;
esac

# BCC tools to allow NOPASSWD during a profiling session. Keep this list tight:
# only fixed-probe read-only observers, nothing that accepts user-supplied
# eBPF scripts or -c <cmd>. Review before adding anything.
BCC_TOOLS=(offcputime)
SUDOERS_DROPIN="/etc/sudoers.d/99-profiling-bcc"

if [[ "$mode" == "enable" ]]; then
    sudo sysctl -w kernel.nmi_watchdog=0
    sudo sysctl -w kernel.perf_event_paranoid=0            # unprivileged perf on kernel (samply/perf/flamegraph)
    sudo sysctl -w kernel.perf_event_mlock_kb=1048576
    sudo sysctl -w kernel.kptr_restrict=0                  # needed for kernel stack symbolication
    sudo sysctl -w kernel.randomize_va_space=0             # ASLR off: stable VA layout for sub-us dispatch benches
    sudo sysctl -w kernel.numa_balancing=0 || true         # stop kthread page migration onto bench cores
    sudo cpupower frequency-set -g performance
    echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference > /dev/null

    # AMD CPU boost off: boost throttles the producer when 16 cores spin and is the
    # main source of bimodal medians on Zen 5 desktop SKUs.
    if [[ -e /sys/devices/system/cpu/cpufreq/boost ]]; then
        echo 0 | sudo tee /sys/devices/system/cpu/cpufreq/boost > /dev/null
    fi

    # Transparent Huge Pages off: removes defrag kthread spikes that show as
    # occasional 100x tails on short benches.
    if [[ -e /sys/kernel/mm/transparent_hugepage/enabled ]]; then
        echo never | sudo tee /sys/kernel/mm/transparent_hugepage/enabled > /dev/null
    fi
    if [[ -e /sys/kernel/mm/transparent_hugepage/defrag ]]; then
        echo never | sudo tee /sys/kernel/mm/transparent_hugepage/defrag > /dev/null
    fi

    # KSM off: page merging scans burn shared L3 lines under bench load.
    if [[ -e /sys/kernel/mm/ksm/run ]]; then
        echo 0 | sudo tee /sys/kernel/mm/ksm/run > /dev/null
    fi

    # irqbalance off: keeps NIC / NVMe IRQs from drifting onto bench cores. The
    # static IRQ distribution that remains is good enough with `taskset -c 0-15`.
    sudo systemctl stop irqbalance.service 2>/dev/null || true

    # Pin scaling_max_freq to the base clock. With boost off, cpuinfo_max_freq is
    # already the non-turbo max under amd-pstate, so pinning to it hardens against
    # thermal-driven down-scaling without lowering the ceiling.
    base_khz=$(cat /sys/devices/system/cpu/cpu0/cpufreq/bios_limit 2>/dev/null \
               || cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq)
    sudo cpupower frequency-set --min "${base_khz}" --max "${base_khz}" > /dev/null

    # Disable deep CPU idle states (anything beyond C1). When a benchmark cell
    # uses only some cores for several seconds, idle cores fall into C2/C3 on
    # Zen 5; wake from C3 is on the order of 350 us per core (see the cpuidle
    # latency file). The next cell that touches those cores then pays that
    # wake cost on every dispatch, making sub-us workloads measure 100 us+.
    # Keeping cores in POLL/C1 only costs a few watts of idle power but keeps
    # cross-cell timings comparable. Direct sysfs writes work without an
    # interactive sudo prompt the way `cpupower idle-set` requires.
    for f in /sys/devices/system/cpu/cpu*/cpuidle/state[!01]/disable; do
        [[ -e "$f" ]] || continue
        echo 1 | sudo tee "$f" > /dev/null
    done

    # NOPASSWD drop-in for BCC tools. List every link in the symlink chain so
    # sudo's command matching works regardless of which hop it resolves to.
    user=$(id -un)
    rules=""
    for tool in "${BCC_TOOLS[@]}"; do
        src=$(command -v "$tool" 2>/dev/null) || { echo "warning: $tool not in PATH" >&2; continue; }
        # Walk the symlink chain: start with the PATH hit, follow until non-symlink.
        paths=("$src")
        cur=$src
        while [[ -L "$cur" ]]; do
            target=$(readlink "$cur")
            [[ "$target" != /* ]] && target=$(cd "$(dirname "$cur")" && realpath -m "$target")
            paths+=("$target")
            cur=$target
        done
        # De-dup into comma-separated list.
        joined=$(printf '%s\n' "${paths[@]}" | awk '!seen[$0]++' | paste -sd,)
        rules+="$user ALL=(root) NOPASSWD: $joined"$'\n'
    done
    if [[ -n "$rules" ]]; then
        # Precondition: sudoers must include /etc/sudoers.d. See nixos/security.nix.
        if ! sudo grep -qE '^[@#]includedir[[:space:]]+/etc/sudoers\.d' /etc/sudoers; then
            echo "ERROR: /etc/sudoers has no @includedir for /etc/sudoers.d." >&2
            echo "  Run 'sudo nixos-rebuild switch' to apply security.sudo.extraConfig." >&2
            exit 1
        fi
        sudo mkdir -p /etc/sudoers.d
        sudo chown root:root /etc/sudoers.d
        sudo chmod 0750 /etc/sudoers.d
        printf '%s' "$rules" | sudo tee "$SUDOERS_DROPIN" >/dev/null
        sudo chown root:root "$SUDOERS_DROPIN"
        sudo chmod 0440 "$SUDOERS_DROPIN"
        sudo visudo -c -f "$SUDOERS_DROPIN" >/dev/null
        echo "installed $SUDOERS_DROPIN for: ${BCC_TOOLS[*]}"
    fi

    # Clear stale BCC header cache from mixed-ownership runs so sudo/non-sudo both work.
    sudo rm -rf /tmp/kheaders-* 2>/dev/null || true

    # Verify each whitelisted tool is reachable passwordless. -n fails if a password would be needed.
    for tool in "${BCC_TOOLS[@]}"; do
        path=$(command -v "$tool" 2>/dev/null) || continue
        path=$(readlink -f "$path")
        if sudo -n -l "$path" >/dev/null 2>&1; then
            echo "ok: sudo $tool runs without password"
        else
            echo "FAIL: sudo $tool still needs password (drop-in not matching $path)" >&2
        fi
    done
else
    sudo sysctl -w kernel.nmi_watchdog=1
    sudo sysctl -w kernel.perf_event_paranoid=2
    sudo sysctl -w kernel.perf_event_mlock_kb=516
    sudo sysctl -w kernel.kptr_restrict=1
    sudo sysctl -w kernel.randomize_va_space=2
    sudo sysctl -w kernel.numa_balancing=1 || true
    sudo cpupower frequency-set -g performance

    if [[ -e /sys/devices/system/cpu/cpufreq/boost ]]; then
        echo 1 | sudo tee /sys/devices/system/cpu/cpufreq/boost > /dev/null
    fi
    if [[ -e /sys/kernel/mm/transparent_hugepage/enabled ]]; then
        echo madvise | sudo tee /sys/kernel/mm/transparent_hugepage/enabled > /dev/null
    fi
    if [[ -e /sys/kernel/mm/transparent_hugepage/defrag ]]; then
        echo madvise | sudo tee /sys/kernel/mm/transparent_hugepage/defrag > /dev/null
    fi
    if [[ -e /sys/kernel/mm/ksm/run ]]; then
        echo 1 | sudo tee /sys/kernel/mm/ksm/run > /dev/null
    fi
    sudo systemctl start irqbalance.service 2>/dev/null || true
    sudo cpupower frequency-set --min 0 --max 0 > /dev/null 2>&1 || true
    for f in /sys/devices/system/cpu/cpu*/cpuidle/state*/disable; do
        [[ -e "$f" ]] || continue
        echo 0 | sudo tee "$f" > /dev/null
    done

    sudo rm -f "$SUDOERS_DROPIN"
    echo "removed $SUDOERS_DROPIN (if present)"
fi
