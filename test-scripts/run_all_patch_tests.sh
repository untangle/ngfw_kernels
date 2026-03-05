#!/bin/bash

# =================================================================
# Master Test Runner for Untangle Kernel Patches
#
# Runs all patch test scripts in sequence and summarizes results.
# Patches tested:
#   0001 - Bridge MAC ageing fix
#   0002 - UDP extensions (IP_SADDR, IP_SENDNFMARK, PKT_UDP_SPORT)
#   0003 - IPsec policy bypass (mark 0x10000000)
#   0004 - xt_socket mark restoration (upper 16-bit OR)
#   0005 - xt_mac byte-level matching (srcaddr[0]=0xFF)
#   0006 - Whitespace fix (no functional test needed)
# =================================================================

echo "============================================================"
echo "  Untangle Kernel Patch Test Suite"
echo "  Kernel: $(uname -r)"
echo "  Date:   $(date)"
echo "============================================================"
echo

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOTAL_PASS=0
TOTAL_FAIL=0
RESULTS=()

function run_test() {
    local name="$1"
    local script="$2"

    echo "============================================================"
    echo "  Running: $name"
    echo "============================================================"

    if [ ! -f "$script" ]; then
        echo -e "\e[31m[ERROR] Script not found: $script\e[0m"
        RESULTS+=("$name: MISSING")
        ((TOTAL_FAIL++))
        return
    fi

    chmod +x "$script"
    bash "$script"
    local ret=$?

    if [ $ret -eq 0 ]; then
        RESULTS+=("$name: PASSED")
        ((TOTAL_PASS++))
    else
        RESULTS+=("$name: FAILED")
        ((TOTAL_FAIL++))
    fi
    echo
}

# Install gcc if not available (needed for C test programs)
if ! command -v gcc &>/dev/null; then
    echo "[SETUP] Installing gcc for test compilation..."
    apt-get update -qq && apt-get install -y -qq gcc >/dev/null 2>&1
    if command -v gcc &>/dev/null; then
        echo "[SETUP] gcc installed successfully"
    else
        echo "[SETUP] WARNING: gcc installation failed - some tests will be skipped"
    fi
fi

# Install iptables if not available (needed for xt_socket and xt_mac tests)
if ! command -v iptables &>/dev/null; then
    echo "[SETUP] Installing iptables for kernel module tests..."
    apt-get install -y -qq iptables >/dev/null 2>&1
fi

# Install nftables if not available
if ! command -v nft &>/dev/null; then
    echo "[SETUP] Installing nftables..."
    apt-get install -y -qq nftables >/dev/null 2>&1
fi

# Install iproute2 if not available
if ! command -v ip &>/dev/null; then
    echo "[SETUP] Installing iproute2..."
    apt-get install -y -qq iproute2 >/dev/null 2>&1
fi

# Install netcat if not available
if ! command -v nc &>/dev/null; then
    echo "[SETUP] Installing netcat..."
    apt-get install -y -qq netcat-openbsd >/dev/null 2>&1
fi

echo
echo "============================================================"
echo "  Pre-flight Checks"
echo "============================================================"
if [ -f "$SCRIPT_DIR/check_test_env.sh" ]; then
    bash "$SCRIPT_DIR/check_test_env.sh"
else
    echo "[INFO] Pre-flight check script not found, continuing..."
fi
echo

# Run each patch test
# Note: test_bridge_ageing.sh (0001) requires a 2-VM setup, skip in automated run
echo "[INFO] Skipping Patch 0001 (bridge MAC ageing) - requires 2-VM setup"
echo "[INFO] To test manually, run: $SCRIPT_DIR/test_bridge_ageing.sh"
RESULTS+=("Patch 0001 (Bridge MAC ageing): SKIPPED (requires 2-VM setup)")
echo

run_test "Patch 0002 (UDP Extensions)" "$SCRIPT_DIR/test_0002_extensions.sh"
run_test "Patch 0003 (IPsec Bypass)" "$SCRIPT_DIR/test_0003_ipsec_bypass.sh"
run_test "Patch 0004 (xt_socket Mark)" "$SCRIPT_DIR/test_0004_xt_socket.sh"
run_test "Patch 0005 (xt_mac Byte Match)" "$SCRIPT_DIR/test_0005_xt_mac.sh"

echo "[INFO] Patch 0006 (Whitespace fix) - no functional test needed"
RESULTS+=("Patch 0006 (Whitespace fix): N/A (cosmetic only)")

# Summary
echo
echo "============================================================"
echo "  OVERALL TEST RESULTS"
echo "============================================================"
for result in "${RESULTS[@]}"; do
    if echo "$result" | grep -q "PASSED"; then
        echo -e "  \e[32m$result\e[0m"
    elif echo "$result" | grep -q "FAILED"; then
        echo -e "  \e[31m$result\e[0m"
    elif echo "$result" | grep -q "SKIPPED"; then
        echo -e "  \e[33m$result\e[0m"
    else
        echo "  $result"
    fi
done
echo
echo "  Passed: $TOTAL_PASS"
echo "  Failed: $TOTAL_FAIL"
echo "============================================================"

if [ $TOTAL_FAIL -gt 0 ]; then
    exit 1
else
    exit 0
fi
