#!/bin/bash

# =================================================================
# Pre-flight Check Script for Bridge Ageing Test
#
# This script verifies that the necessary tools and kernel
# modules are available on your Debian Bookworm VM.
# =================================================================

echo "--- Running Pre-flight Checks ---"
echo

# 1. Check Kernel Version
echo "[1/4] Checking Kernel Version..."
KERNEL_VERSION=$(uname -r)
if [[ $KERNEL_VERSION == 6.* ]]; then
    echo "  - OK: Found Kernel $KERNEL_VERSION"
else
    echo "  - WARNING: Kernel version is $KERNEL_VERSION. Expected a 6.x kernel for Bookworm."
fi
echo

# 2. Check for Required Commands
echo "[2/4] Checking for required commands..."
COMMANDS=("ip" "tc" "bridge" "nft")
all_found=true
for cmd in "${COMMANDS[@]}"; do
    if command -v $cmd &> /dev/null; then
        echo "  - OK: '$cmd' command found."
    else
        echo "  - FAIL: '$cmd' command NOT found."
        all_found=false
    fi
done
if ! $all_found; then
    echo "  - ACTION: Please install the missing packages. 'ip', 'tc', 'bridge' are in 'iproute2'. 'nft' is in 'nftables'."
    echo "    sudo apt update && sudo apt install -y iproute2 nftables"
fi
echo

# 3. Check for Kernel Module: ifb
echo "[3/4] Checking for 'ifb' kernel module..."
if modinfo ifb &> /dev/null; then
    echo "  - OK: 'ifb' module is available."
else
    echo "  - FAIL: 'ifb' module is NOT available. The test cannot run."
    echo "  - ACTION: Ensure you are running a standard Debian kernel. This module should be included."
fi
echo

# 4. Check for Kernel Module: br_netfilter
echo "[4/4] Checking for 'br_netfilter' kernel module..."
if modinfo br_netfilter &> /dev/null; then
    echo "  - OK: 'br_netfilter' module is available (needed for bridge firewalling)."
else
    echo "  - WARNING: 'br_netfilter' module is NOT available. While not strictly required for this specific test, it's essential for any advanced bridge firewalling."
fi
echo

echo "--- Checks Complete ---"