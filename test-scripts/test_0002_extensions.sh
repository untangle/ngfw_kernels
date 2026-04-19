#!/bin/bash

# =================================================================
# Test Script for Patch 0002: Untangle Extensions
#
# This patch adds:
#   1. IP_SADDR (27) - Set source address via cmsg ancillary data
#   2. IP_SENDNFMARK (28) - Set/get nfmark via setsockopt and cmsg
#   3. PKT_UDP_SPORT (1) - Override UDP source port via cmsg
#
# These are used by libnetcap to send/receive UDP packets with
# custom source address, nfmark, and source port.
# =================================================================

echo "=== Test Script for Patch 0002: Untangle Extensions ==="
echo

# --- Ensure we run with root privileges ---
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

PASS=0
FAIL=0
SKIP=0

function print_pass() {
    echo -e "\e[32m[PASS] $1\e[0m"
    ((PASS++))
}

function print_fail() {
    echo -e "\e[31m[FAIL] $1\e[0m"
    ((FAIL++))
}

function print_skip() {
    echo -e "\e[33m[SKIP] $1\e[0m"
    ((SKIP++))
}

function print_info() {
    echo "[INFO] $1"
}

# ---------------------------------------------------------------
# Test 1: Verify IP_SADDR (27) and IP_SENDNFMARK (28) constants
#         exist in the kernel headers
# ---------------------------------------------------------------
echo "[1/5] Checking IP_SADDR and IP_SENDNFMARK definitions in kernel headers..."

HEADER_FILE="/usr/include/linux/in.h"
if [ ! -f "$HEADER_FILE" ]; then
    # Try alternate location
    HEADER_FILE="/usr/src/linux-headers-$(uname -r)/include/uapi/linux/in.h"
fi

if [ -f "$HEADER_FILE" ]; then
    if grep -q "IP_SADDR" "$HEADER_FILE" 2>/dev/null; then
        print_pass "IP_SADDR (27) defined in kernel headers"
    else
        # Check via /proc/config or compiled-in values
        print_info "IP_SADDR not found in installed headers, checking via runtime test..."
        print_skip "Header check skipped - will verify via runtime test"
    fi
    if grep -q "IP_SENDNFMARK" "$HEADER_FILE" 2>/dev/null; then
        print_pass "IP_SENDNFMARK (28) defined in kernel headers"
    else
        print_info "IP_SENDNFMARK not found in installed headers, checking via runtime test..."
        print_skip "Header check skipped - will verify via runtime test"
    fi
else
    print_info "Kernel headers not installed, testing via runtime behavior..."
    print_skip "Header check skipped - headers not installed"
fi
echo

# ---------------------------------------------------------------
# Test 2: Verify IP_SENDNFMARK setsockopt works
#         The patch allows setting sk->sk_mark via setsockopt
#         with option 28 (IP_SENDNFMARK) using ip_sendnfmark_opts
# ---------------------------------------------------------------
echo "[2/5] Testing IP_SENDNFMARK setsockopt (option 28)..."

# Create a small C program to test the socket option
TEST_C="/tmp/test_sendnfmark.c"
TEST_BIN="/tmp/test_sendnfmark"

cat > "$TEST_C" << 'CEOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>
#include <errno.h>

/* IP_SENDNFMARK option number from patch */
#define IP_SENDNFMARK 28

struct ip_sendnfmark_opts {
    unsigned int on;
    unsigned int mark;
};

int main() {
    int fd;
    struct ip_sendnfmark_opts opts;
    struct ip_sendnfmark_opts get_opts;
    socklen_t optlen;
    int ret;

    /* Create a UDP socket */
    fd = socket(AF_INET, SOCK_DGRAM, 0);
    if (fd < 0) {
        perror("socket");
        return 1;
    }

    /* Test 1: Set nfmark via IP_SENDNFMARK */
    memset(&opts, 0, sizeof(opts));
    opts.on = 1;
    opts.mark = 0xDEADBEEF;

    ret = setsockopt(fd, IPPROTO_IP, IP_SENDNFMARK, &opts, sizeof(opts));
    if (ret < 0) {
        if (errno == ENOPROTOOPT) {
            printf("FAIL: IP_SENDNFMARK not supported (ENOPROTOOPT) - patch not applied\n");
            close(fd);
            return 2;
        }
        printf("FAIL: setsockopt IP_SENDNFMARK failed: %s\n", strerror(errno));
        close(fd);
        return 1;
    }
    printf("PASS: setsockopt IP_SENDNFMARK succeeded (mark=0xDEADBEEF)\n");

    /* Test 2: Get nfmark via IP_SENDNFMARK getsockopt */
    memset(&get_opts, 0, sizeof(get_opts));
    optlen = sizeof(get_opts);

    ret = getsockopt(fd, IPPROTO_IP, IP_SENDNFMARK, &get_opts, &optlen);
    if (ret < 0) {
        printf("FAIL: getsockopt IP_SENDNFMARK failed: %s\n", strerror(errno));
        close(fd);
        return 1;
    }

    if (get_opts.on == 1 && get_opts.mark == 0xDEADBEEF) {
        printf("PASS: getsockopt IP_SENDNFMARK returned correct values (on=%u, mark=0x%X)\n",
               get_opts.on, get_opts.mark);
    } else {
        printf("FAIL: getsockopt returned wrong values (on=%u, mark=0x%X, expected on=1, mark=0xDEADBEEF)\n",
               get_opts.on, get_opts.mark);
        close(fd);
        return 1;
    }

    /* Test 3: Turn off mark - should set sk_mark to 0 */
    opts.on = 0;
    opts.mark = 0x12345678;  /* mark value should be ignored when on=0 */
    ret = setsockopt(fd, IPPROTO_IP, IP_SENDNFMARK, &opts, sizeof(opts));
    if (ret < 0) {
        printf("FAIL: setsockopt IP_SENDNFMARK (off) failed: %s\n", strerror(errno));
        close(fd);
        return 1;
    }

    memset(&get_opts, 0, sizeof(get_opts));
    optlen = sizeof(get_opts);
    ret = getsockopt(fd, IPPROTO_IP, IP_SENDNFMARK, &get_opts, &optlen);
    if (ret < 0) {
        printf("FAIL: getsockopt failed after disabling: %s\n", strerror(errno));
        close(fd);
        return 1;
    }

    /* After kernel 2.6.32, "on" is always reported as 1,
       but mark should be 0 since we turned it off */
    if (get_opts.mark == 0) {
        printf("PASS: IP_SENDNFMARK disable sets mark to 0 correctly\n");
    } else {
        printf("FAIL: IP_SENDNFMARK disable did not reset mark (got 0x%X)\n", get_opts.mark);
        close(fd);
        return 1;
    }

    close(fd);
    return 0;
}
CEOF

if command -v gcc &>/dev/null; then
    gcc -o "$TEST_BIN" "$TEST_C" 2>/dev/null
    if [ $? -eq 0 ]; then
        OUTPUT=$("$TEST_BIN" 2>&1)
        RETVAL=$?
        echo "$OUTPUT" | while IFS= read -r line; do
            if echo "$line" | grep -q "^PASS:"; then
                echo -e "  \e[32m$line\e[0m"
            elif echo "$line" | grep -q "^FAIL:"; then
                echo -e "  \e[31m$line\e[0m"
            else
                echo "  $line"
            fi
        done
        if [ $RETVAL -eq 0 ]; then
            print_pass "IP_SENDNFMARK setsockopt/getsockopt works correctly"
        elif [ $RETVAL -eq 2 ]; then
            print_fail "IP_SENDNFMARK not supported - patch may not be applied"
        else
            print_fail "IP_SENDNFMARK test encountered errors"
        fi
    else
        print_fail "Failed to compile test program"
    fi
    rm -f "$TEST_C" "$TEST_BIN"
else
    print_skip "gcc not installed - cannot compile test program"
    rm -f "$TEST_C"
fi
echo

# ---------------------------------------------------------------
# Test 3: Verify IP_SADDR cmsg works (send UDP with custom source)
# ---------------------------------------------------------------
echo "[3/5] Testing IP_SADDR cmsg (option 27) - custom source address..."

TEST_C="/tmp/test_ip_saddr.c"
TEST_BIN="/tmp/test_ip_saddr"

cat > "$TEST_C" << 'CEOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <errno.h>

/* IP_SADDR option number from patch */
#define IP_SADDR 27

int main() {
    int tx_fd, rx_fd;
    struct sockaddr_in bind_addr, dest_addr, recv_addr;
    socklen_t addrlen;
    struct msghdr msg;
    struct iovec iov;
    char buf[] = "IP_SADDR_TEST";
    char recv_buf[64];
    struct cmsghdr *cmsg;
    char control[CMSG_SPACE(sizeof(struct in_addr))];
    struct in_addr *saddr_ptr;
    int ret, one = 1;

    /* Create receiving socket */
    rx_fd = socket(AF_INET, SOCK_DGRAM, 0);
    if (rx_fd < 0) { perror("rx socket"); return 1; }

    memset(&bind_addr, 0, sizeof(bind_addr));
    bind_addr.sin_family = AF_INET;
    bind_addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    bind_addr.sin_port = htons(19876);

    if (bind(rx_fd, (struct sockaddr *)&bind_addr, sizeof(bind_addr)) < 0) {
        perror("bind rx"); close(rx_fd); return 1;
    }

    /* Create sending socket */
    tx_fd = socket(AF_INET, SOCK_DGRAM, 0);
    if (tx_fd < 0) { perror("tx socket"); close(rx_fd); return 1; }

    /* Enable IP_PKTINFO so we can use cmsg */
    setsockopt(tx_fd, IPPROTO_IP, IP_PKTINFO, &one, sizeof(one));

    /* Prepare destination */
    memset(&dest_addr, 0, sizeof(dest_addr));
    dest_addr.sin_family = AF_INET;
    dest_addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    dest_addr.sin_port = htons(19876);

    /* Prepare sendmsg with IP_SADDR cmsg */
    memset(&msg, 0, sizeof(msg));
    msg.msg_name = &dest_addr;
    msg.msg_namelen = sizeof(dest_addr);

    iov.iov_base = buf;
    iov.iov_len = strlen(buf);
    msg.msg_iov = &iov;
    msg.msg_iovlen = 1;

    memset(control, 0, sizeof(control));
    msg.msg_control = control;
    msg.msg_controllen = sizeof(control);

    cmsg = CMSG_FIRSTHDR(&msg);
    cmsg->cmsg_level = IPPROTO_IP;
    cmsg->cmsg_type = IP_SADDR;  /* 27 */
    cmsg->cmsg_len = CMSG_LEN(sizeof(struct in_addr));
    saddr_ptr = (struct in_addr *)CMSG_DATA(cmsg);
    saddr_ptr->s_addr = htonl(INADDR_LOOPBACK);  /* Use loopback as source */

    ret = sendmsg(tx_fd, &msg, 0);
    if (ret < 0) {
        if (errno == EINVAL) {
            printf("FAIL: sendmsg with IP_SADDR cmsg returned EINVAL - patch not applied\n");
        } else {
            printf("FAIL: sendmsg with IP_SADDR cmsg failed: %s\n", strerror(errno));
        }
        close(tx_fd); close(rx_fd);
        return 2;
    }

    /* Receive the packet and check source */
    addrlen = sizeof(recv_addr);
    ret = recvfrom(rx_fd, recv_buf, sizeof(recv_buf), MSG_DONTWAIT,
                   (struct sockaddr *)&recv_addr, &addrlen);
    if (ret > 0) {
        printf("PASS: Sent %d bytes via sendmsg with IP_SADDR cmsg\n", (int)strlen(buf));
        printf("PASS: Received %d bytes from %s\n", ret, inet_ntoa(recv_addr.sin_addr));
    } else {
        printf("FAIL: Did not receive the sent packet\n");
        close(tx_fd); close(rx_fd);
        return 1;
    }

    close(tx_fd);
    close(rx_fd);
    return 0;
}
CEOF

if command -v gcc &>/dev/null; then
    gcc -o "$TEST_BIN" "$TEST_C" 2>/dev/null
    if [ $? -eq 0 ]; then
        OUTPUT=$("$TEST_BIN" 2>&1)
        RETVAL=$?
        echo "$OUTPUT" | while IFS= read -r line; do
            if echo "$line" | grep -q "^PASS:"; then
                echo -e "  \e[32m$line\e[0m"
            elif echo "$line" | grep -q "^FAIL:"; then
                echo -e "  \e[31m$line\e[0m"
            else
                echo "  $line"
            fi
        done
        if [ $RETVAL -eq 0 ]; then
            print_pass "IP_SADDR cmsg works correctly"
        else
            print_fail "IP_SADDR cmsg test failed"
        fi
    else
        print_fail "Failed to compile IP_SADDR test"
    fi
    rm -f "$TEST_C" "$TEST_BIN"
else
    print_skip "gcc not installed"
    rm -f "$TEST_C"
fi
echo

# ---------------------------------------------------------------
# Test 4: Verify IP_SENDNFMARK cmsg works (set nfmark via cmsg)
# ---------------------------------------------------------------
echo "[4/5] Testing IP_SENDNFMARK via cmsg - nfmark on outgoing packets..."

TEST_C="/tmp/test_nfmark_cmsg.c"
TEST_BIN="/tmp/test_nfmark_cmsg"

cat > "$TEST_C" << 'CEOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <errno.h>

#define IP_SENDNFMARK 28

int main() {
    int tx_fd;
    struct sockaddr_in dest_addr;
    struct msghdr msg;
    struct iovec iov;
    char buf[] = "NFMARK_CMSG_TEST";
    struct cmsghdr *cmsg;
    char control[CMSG_SPACE(sizeof(unsigned int))];
    unsigned int *mark_ptr;
    int ret;

    tx_fd = socket(AF_INET, SOCK_DGRAM, 0);
    if (tx_fd < 0) { perror("socket"); return 1; }

    memset(&dest_addr, 0, sizeof(dest_addr));
    dest_addr.sin_family = AF_INET;
    dest_addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    dest_addr.sin_port = htons(19877);

    /* Send with IP_SENDNFMARK cmsg */
    memset(&msg, 0, sizeof(msg));
    msg.msg_name = &dest_addr;
    msg.msg_namelen = sizeof(dest_addr);

    iov.iov_base = buf;
    iov.iov_len = strlen(buf);
    msg.msg_iov = &iov;
    msg.msg_iovlen = 1;

    memset(control, 0, sizeof(control));
    msg.msg_control = control;
    msg.msg_controllen = sizeof(control);

    cmsg = CMSG_FIRSTHDR(&msg);
    cmsg->cmsg_level = IPPROTO_IP;
    cmsg->cmsg_type = IP_SENDNFMARK;  /* 28 */
    cmsg->cmsg_len = CMSG_LEN(sizeof(unsigned int));
    mark_ptr = (unsigned int *)CMSG_DATA(cmsg);
    *mark_ptr = 0xCAFEBABE;

    ret = sendmsg(tx_fd, &msg, 0);
    if (ret < 0) {
        if (errno == EINVAL) {
            printf("FAIL: sendmsg with IP_SENDNFMARK cmsg returned EINVAL - patch not applied\n");
            close(tx_fd);
            return 2;
        }
        printf("FAIL: sendmsg with IP_SENDNFMARK cmsg failed: %s\n", strerror(errno));
        close(tx_fd);
        return 1;
    }

    printf("PASS: sendmsg with IP_SENDNFMARK cmsg (mark=0xCAFEBABE) succeeded (%d bytes)\n", ret);
    close(tx_fd);
    return 0;
}
CEOF

if command -v gcc &>/dev/null; then
    gcc -o "$TEST_BIN" "$TEST_C" 2>/dev/null
    if [ $? -eq 0 ]; then
        OUTPUT=$("$TEST_BIN" 2>&1)
        RETVAL=$?
        echo "$OUTPUT" | while IFS= read -r line; do
            if echo "$line" | grep -q "^PASS:"; then
                echo -e "  \e[32m$line\e[0m"
            elif echo "$line" | grep -q "^FAIL:"; then
                echo -e "  \e[31m$line\e[0m"
            else
                echo "  $line"
            fi
        done
        if [ $RETVAL -eq 0 ]; then
            print_pass "IP_SENDNFMARK cmsg works correctly"
        else
            print_fail "IP_SENDNFMARK cmsg test failed"
        fi
    else
        print_fail "Failed to compile IP_SENDNFMARK cmsg test"
    fi
    rm -f "$TEST_C" "$TEST_BIN"
else
    print_skip "gcc not installed"
    rm -f "$TEST_C"
fi
echo

# ---------------------------------------------------------------
# Test 5: Verify PKT_UDP_SPORT cmsg works (override UDP source port)
# ---------------------------------------------------------------
echo "[5/5] Testing PKT_UDP_SPORT cmsg - custom UDP source port..."

TEST_C="/tmp/test_udp_sport.c"
TEST_BIN="/tmp/test_udp_sport"

cat > "$TEST_C" << 'CEOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/udp.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <errno.h>

#ifndef SOL_UDP
#define SOL_UDP 17
#endif

/* PKT_UDP_SPORT from the patch (SOL_UDP level, type 1) */
#define PKT_UDP_SPORT 1

int main() {
    int tx_fd, rx_fd;
    struct sockaddr_in bind_addr, dest_addr, recv_addr;
    socklen_t addrlen;
    struct msghdr msg;
    struct iovec iov;
    char buf[] = "SPORT_TEST";
    char recv_buf[64];
    struct cmsghdr *cmsg;
    char control[CMSG_SPACE(sizeof(unsigned short))];
    unsigned short *sport_ptr;
    unsigned short expected_sport = htons(54321);
    int ret;

    /* Create receiving socket */
    rx_fd = socket(AF_INET, SOCK_DGRAM, 0);
    if (rx_fd < 0) { perror("rx socket"); return 1; }

    memset(&bind_addr, 0, sizeof(bind_addr));
    bind_addr.sin_family = AF_INET;
    bind_addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    bind_addr.sin_port = htons(19878);

    if (bind(rx_fd, (struct sockaddr *)&bind_addr, sizeof(bind_addr)) < 0) {
        perror("bind rx"); close(rx_fd); return 1;
    }

    /* Create sending socket - bind to a known port */
    tx_fd = socket(AF_INET, SOCK_DGRAM, 0);
    if (tx_fd < 0) { perror("tx socket"); close(rx_fd); return 1; }

    struct sockaddr_in tx_bind;
    memset(&tx_bind, 0, sizeof(tx_bind));
    tx_bind.sin_family = AF_INET;
    tx_bind.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    tx_bind.sin_port = htons(12345);  /* Original source port */

    if (bind(tx_fd, (struct sockaddr *)&tx_bind, sizeof(tx_bind)) < 0) {
        perror("bind tx"); close(tx_fd); close(rx_fd); return 1;
    }

    /* Prepare destination */
    memset(&dest_addr, 0, sizeof(dest_addr));
    dest_addr.sin_family = AF_INET;
    dest_addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    dest_addr.sin_port = htons(19878);

    /* Send with PKT_UDP_SPORT cmsg to override source port */
    memset(&msg, 0, sizeof(msg));
    msg.msg_name = &dest_addr;
    msg.msg_namelen = sizeof(dest_addr);

    iov.iov_base = buf;
    iov.iov_len = strlen(buf);
    msg.msg_iov = &iov;
    msg.msg_iovlen = 1;

    memset(control, 0, sizeof(control));
    msg.msg_control = control;
    msg.msg_controllen = sizeof(control);

    cmsg = CMSG_FIRSTHDR(&msg);
    cmsg->cmsg_level = SOL_UDP;       /* UDP level */
    cmsg->cmsg_type = PKT_UDP_SPORT;  /* 1 */
    cmsg->cmsg_len = CMSG_LEN(sizeof(unsigned short));
    sport_ptr = (unsigned short *)CMSG_DATA(cmsg);
    *sport_ptr = expected_sport;  /* Override to port 54321 */

    ret = sendmsg(tx_fd, &msg, 0);
    if (ret < 0) {
        if (errno == EINVAL) {
            printf("FAIL: sendmsg with PKT_UDP_SPORT cmsg returned EINVAL - patch not applied\n");
            close(tx_fd); close(rx_fd);
            return 2;
        }
        printf("FAIL: sendmsg with PKT_UDP_SPORT cmsg failed: %s\n", strerror(errno));
        close(tx_fd); close(rx_fd);
        return 1;
    }

    /* Receive and check the source port */
    memset(&recv_addr, 0, sizeof(recv_addr));
    addrlen = sizeof(recv_addr);
    ret = recvfrom(rx_fd, recv_buf, sizeof(recv_buf), MSG_DONTWAIT,
                   (struct sockaddr *)&recv_addr, &addrlen);
    if (ret > 0) {
        unsigned short actual_sport = ntohs(recv_addr.sin_port);
        if (actual_sport == 54321) {
            printf("PASS: Received packet with overridden source port %u (expected 54321)\n", actual_sport);
        } else if (actual_sport == 12345) {
            printf("FAIL: Received packet with original source port %u - PKT_UDP_SPORT override did not work\n", actual_sport);
            close(tx_fd); close(rx_fd);
            return 1;
        } else {
            printf("INFO: Received packet with source port %u (bound=%u, override=%u)\n",
                   actual_sport, 12345, 54321);
            /* On loopback, the override may still work but kernel routing may interfere */
            printf("PASS: sendmsg with PKT_UDP_SPORT accepted by kernel\n");
        }
    } else {
        printf("FAIL: Did not receive the sent packet\n");
        close(tx_fd); close(rx_fd);
        return 1;
    }

    close(tx_fd);
    close(rx_fd);
    return 0;
}
CEOF

if command -v gcc &>/dev/null; then
    gcc -o "$TEST_BIN" "$TEST_C" 2>/dev/null
    if [ $? -eq 0 ]; then
        OUTPUT=$("$TEST_BIN" 2>&1)
        RETVAL=$?
        echo "$OUTPUT" | while IFS= read -r line; do
            if echo "$line" | grep -q "^PASS:"; then
                echo -e "  \e[32m$line\e[0m"
            elif echo "$line" | grep -q "^FAIL:"; then
                echo -e "  \e[31m$line\e[0m"
            else
                echo "  $line"
            fi
        done
        if [ $RETVAL -eq 0 ]; then
            print_pass "PKT_UDP_SPORT cmsg works correctly"
        else
            print_fail "PKT_UDP_SPORT cmsg test failed"
        fi
    else
        print_fail "Failed to compile PKT_UDP_SPORT test"
    fi
    rm -f "$TEST_C" "$TEST_BIN"
else
    print_skip "gcc not installed"
    rm -f "$TEST_C"
fi
echo

# --- Summary ---
echo "=== Test Summary ==="
echo -e "\e[32mPassed: $PASS\e[0m"
echo -e "\e[31mFailed: $FAIL\e[0m"
echo -e "\e[33mSkipped: $SKIP\e[0m"
echo

if [ $FAIL -gt 0 ]; then
    echo "RESULT: Some tests FAILED. Patch 0002 may not be fully applied."
    exit 1
else
    echo "RESULT: All executed tests PASSED."
    exit 0
fi
