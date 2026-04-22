#!/usr/bin/env bash
set -euo pipefail

sudo sysctl -w kernel.nmi_watchdog=0
sudo sysctl -w kernel.perf_event_paranoid=0
sudo sysctl -w kernel.perf_event_mlock_kb=65536
sudo sysctl -w kernel.kptr_restrict=0
