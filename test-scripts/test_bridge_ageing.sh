#!/bin/bash

# =================================================================
# Test Script for Bridge MAC Ageing Behavior
#
# This script checks if the first packet from a new MAC address
# is correctly processed by ingress QoS/firewall rules on a bridge.
#
# It uses an nftables counter on an ifb device to verify success.
# =================================================================

# --- Configuration ---
# Interface connected to the client VM
CLIENT_IF="enp0s8"
# A secondary interface for the bridge
OTHER_IF="enp0s9"
# MAC address of the client VM's interface.
# IMPORTANT: You must find and set this value manually.
# Run 'ip a' on the client VM to get its MAC address.
CLIENT_MAC="08:00:27:01:02:03" # <-- CHANGE THIS
# IP to ping (the bridge's own IP)
BRIDGE_IP="192.168.100.1"

# --- Helper Functions ---
function print_info() {
    echo "[INFO] $1"
}

function print_pass() {
    echo -e "\e[32m[PASS] $1\e[0m"
}

function print_fail() {
    echo -e "\e[31m[FAIL] $1\e[0m"
}

function setup_environment() {
    print_info "Setting up test environment..."
    modprobe ifb || { print_fail "Failed to load ifb module"; exit 1; }
    ip link set ifb0 up

    ip link add name br0 type bridge 2>/dev/null
    ip link set dev "$CLIENT_IF" master br0
    ip link set dev "$OTHER_IF" master br0
    ip link set dev br0 up
    ip link set dev "$CLIENT_IF" up
    ip link set dev "$OTHER_IF" up
    ip addr add "${BRIDGE_IP}/24" dev br0

    # Redirect ingress from client port to ifb0
    tc qdisc add dev "$CLIENT_IF" handle ffff: ingress
    tc filter add dev "$CLIENT_IF" parent ffff: protocol all u32 match u32 0 0 action mirred egress redirect dev ifb0

    # Setup nftables to count the packet on ifb0
    nft flush ruleset
    nft add table netdev my_ingress
    nft add chain netdev my_ingress from_ifb0 '{ type filter hook ingress device "ifb0" priority -500; }'
    nft add rule netdev my_ingress from_ifb0 ether saddr "$CLIENT_MAC" counter name first_packet_counter
    print_info "Setup complete."
}

function run_test() {
    print_info "--- Running Test ---"
    
    # 1. Reset state
    print_info "Flushing bridge FDB and resetting counter..."
    bridge fdb flush dev br0
    nft reset counter netdev my_ingress first_packet_counter

    # 2. Inform user to trigger the packet
    echo
    print_info "Please go to the CLIENT VM and run the following command now:"
    echo "ping -c 1 $BRIDGE_IP"
    echo
    read -p "Press [Enter] after the ping command has finished..."

    # 3. Check the result
    print_info "Checking counter..."
    local count=$(nft -j list chain netdev my_ingress from_ifb0 | grep -A2 first_packet_counter | grep packets | awk '{print $2}' | tr -d ',')

    if [[ "$count" -eq 1 ]]; then
        print_pass "Test successful. Counter is 1. The first packet was processed."
    else
        print_fail "Test failed. Counter is $count. The first packet was NOT processed."
        print_fail "This may indicate the old patch's functionality is still needed."
    fi
}

function cleanup() {
    print_info "Cleaning up test environment..."
    tc qdisc del dev "$CLIENT_IF" ingress &>/dev/null
    nft flush ruleset
    ip link set dev "$CLIENT_IF" nomaster &>/dev/null
    ip link set dev "$OTHER_IF" nomaster &>/dev/null
    ip link del dev br0 &>/dev/null
    ip link set dev ifb0 down
    print_info "Cleanup complete."
}

# --- Main Logic ---
# Ensure we run with root privileges
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

trap cleanup EXIT
setup_environment
run_test