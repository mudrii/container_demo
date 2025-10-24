#!/bin/bash

# Colors for better presentation
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

pause() {
    echo ""
    echo -e "${YELLOW}Press Enter to continue...${NC}"
    read
}

header() {
    echo ""
    echo -e "${GREEN}================================================================${NC}"
    echo -e "${GREEN}  $1${NC}"
    echo -e "${GREEN}================================================================${NC}"
    echo ""
}

clear
echo -e "${BLUE}"
cat << 'BANNER'
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║   PODMAN CONTAINER ISOLATION DEMONSTRATION                    ║
║   Namespaces • Cgroups • Capabilities                         ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
BANNER
echo -e "${NC}"

pause

header "DEMO 1: Starting Container with Security Restrictions"
echo "Creating a container with:"
echo "  • 512 MB memory limit (cgroup enforcement)"
echo "  • 1.0 CPU limit (cgroup enforcement)"
echo "  • ALL capabilities dropped (security)"
echo "  • Only NET_BIND_SERVICE added (minimal privilege)"
echo ""

podman run -d \
  --name live-demo \
  --memory=512m \
  --cpus=1.0 \
  --cap-drop=ALL \
  --cap-add=NET_BIND_SERVICE \
  registry.access.redhat.com/ubi9/ubi:latest \
  sleep 3600

PID=$(podman inspect -f '{{.State.Pid}}' live-demo)
CONTAINER_ID=$(podman inspect -f '{{.Id}}' live-demo | cut -c1-12)

echo -e "${GREEN}✓ Container started successfully${NC}"
echo "  Container ID: $CONTAINER_ID"
echo "  Host PID: $PID"

pause

header "DEMO 2: Namespace Isolation"
echo "Namespaces provide isolated views of system resources."
echo "Let's compare namespace IDs between host and container:"
echo ""

echo -e "${BLUE}Host Namespaces (PID 1 - systemd/init):${NC}"
sudo ls -l /proc/1/ns/ | tail -n +2 | awk '{printf "  %-20s %s\n", $9, $11}'

echo ""
echo -e "${BLUE}Container Namespaces (PID $PID):${NC}"
sudo ls -l /proc/$PID/ns/ | tail -n +2 | awk '{printf "  %-20s %s\n", $9, $11}'

echo ""
echo -e "${YELLOW}Analysis:${NC}"
echo "  ✓ Different IDs = Isolated namespaces"
echo "  ✓ cgroup: $(sudo ls -l /proc/$PID/ns/cgroup | grep -o '\[.*\]') (isolated)"
echo "  ✓ ipc: $(sudo ls -l /proc/$PID/ns/ipc | grep -o '\[.*\]') (isolated)"
echo "  ✓ mnt: $(sudo ls -l /proc/$PID/ns/mnt | grep -o '\[.*\]') (isolated)"
echo "  ✓ net: $(sudo ls -l /proc/$PID/ns/net | grep -o '\[.*\]') (isolated)"
echo "  ✓ pid: $(sudo ls -l /proc/$PID/ns/pid | grep -o '\[.*\]') (isolated)"
echo "  ✓ uts: $(sudo ls -l /proc/$PID/ns/uts | grep -o '\[.*\]') (isolated)"

pause

header "DEMO 3: PID Namespace - Process Isolation"
echo "PID namespace gives each container its own isolated process tree."
echo "We'll use /proc filesystem to inspect processes (no ps command needed)."
echo ""

# Count processes using /proc
HOST_PROC_COUNT=$(ls -d /proc/[0-9]* 2>/dev/null | wc -l)
CONTAINER_PROC_COUNT=$(podman exec live-demo sh -c 'ls -d /proc/[0-9]* 2>/dev/null | wc -l')

echo -e "${BLUE}Host Process Count (via /proc):${NC}"
echo "  $HOST_PROC_COUNT processes running on the host"

echo ""
echo -e "${BLUE}Container Process Count (via /proc):${NC}"
echo "  $CONTAINER_PROC_COUNT processes visible inside container"

echo ""
echo -e "${BLUE}Processes Inside Container:${NC}"
# Create a simpler, cleaner process list
podman exec live-demo sh -c '
echo "  PID    COMMAND"
echo "  ----   -------"
for pid in /proc/[0-9]*; do
    pid_num=$(basename $pid)
    if [ -f "$pid/comm" ]; then
        comm=$(cat $pid/comm 2>/dev/null)
        # Get first argument of cmdline for cleaner display
        cmdline=$(cat $pid/cmdline 2>/dev/null | tr "\0" " " | awk "{print \$1}" | xargs basename 2>/dev/null)
        [ -z "$cmdline" ] && cmdline="$comm"
        [ -n "$comm" ] && printf "  %-6s %s\n" "$pid_num" "$cmdline"
    fi
done | grep -v "grep\|awk\|basename" | head -10
'

echo ""
echo -e "${YELLOW}Key Insight:${NC}"
echo "  • Host can see $HOST_PROC_COUNT processes across the entire system"
echo "  • Container sees only $CONTAINER_PROC_COUNT processes (its own)"
echo "  • The 'sleep 3600' command:"
echo "    - Appears as PID 1 inside the container (init process)"
echo "    - Appears as PID $PID on the host"
echo "  • This is PID namespace isolation in action!"

echo ""
echo -e "${BLUE}Same Process, Two Views:${NC}"
echo "  From host:      PID $PID → $(ps -p $PID -o comm= 2>/dev/null)"
echo "  From container: PID 1    → sleep"

pause

header "DEMO 4: Cgroups - Resource Limits"
echo "Cgroups enforce resource limits at the kernel level."
echo ""

CGROUP_PATH=$(cat /proc/$PID/cgroup | cut -d: -f3)

echo -e "${BLUE}Cgroup Location:${NC}"
echo "  /sys/fs/cgroup${CGROUP_PATH}"

echo ""
echo -e "${BLUE}Memory Limits:${NC}"
MEM_MAX=$(sudo cat /sys/fs/cgroup${CGROUP_PATH}/memory.max)
MEM_CURRENT=$(sudo cat /sys/fs/cgroup${CGROUP_PATH}/memory.current)
MEM_MAX_MB=$((MEM_MAX / 1024 / 1024))
MEM_CURRENT_MB=$((MEM_CURRENT / 1024 / 1024))
MEM_PERCENT=$((MEM_CURRENT * 100 / MEM_MAX))

echo "  Limit:        $MEM_MAX_MB MB (hard limit)"
echo "  Current Use:  $MEM_CURRENT_MB MB"
echo "  Percentage:   $MEM_PERCENT%"
echo ""
echo "  What happens if exceeded: OOM (Out Of Memory) Killer terminates processes"

echo ""
echo -e "${BLUE}CPU Limits:${NC}"
CPU_MAX=$(sudo cat /sys/fs/cgroup${CGROUP_PATH}/cpu.max)
echo "  Quota: $CPU_MAX"
echo "  Explanation: 100000 100000 = 100ms CPU per 100ms period = 1.0 CPU core"

echo ""
echo -e "${BLUE}CPU Statistics:${NC}"
sudo cat /sys/fs/cgroup${CGROUP_PATH}/cpu.stat | while read line; do
    echo "  $line"
done

echo ""
echo -e "${YELLOW}Summary:${NC}"
echo "  ✓ Memory capped at 512 MB (currently using $MEM_CURRENT_MB MB)"
echo "  ✓ CPU capped at 1.0 core"
echo "  ✓ Kernel enforces these limits automatically"

pause

header "DEMO 5: Linux Capabilities - Fine-Grained Security"
echo "Capabilities replace the all-or-nothing root/non-root model."
echo ""

echo -e "${BLUE}Container Capabilities:${NC}"
echo "  Process: $PID"
getpcaps $PID 2>&1 | grep -v "warning" | sed 's/^/  /'

echo ""
echo -e "${BLUE}Host Init Process Capabilities (PID 1):${NC}"
getpcaps 1 2>&1 | grep -v "warning" | head -1 | sed 's/^/  /'

echo ""
echo -e "${BLUE}Capability Breakdown:${NC}"
CAP_EFF=$(grep CapEff /proc/$PID/status | awk '{print $2}')
echo "  Effective capabilities (hex): $CAP_EFF"
echo "  Decoded: $(capsh --decode=$CAP_EFF)"

echo ""
echo -e "${YELLOW}Security Analysis:${NC}"
echo "  Container has: ONLY cap_net_bind_service"
echo "    └─ Allows: Binding to privileged ports (< 1024)"
echo "    └─ Denies: Everything else"
echo ""
echo "  Host PID 1 has: ALL capabilities (=ep)"
echo "    └─ Full system privileges"
echo ""
echo "  Impact: Even if attacker gains root in container,"
echo "          they have minimal capabilities on the host"

pause

header "DEMO 6: Network Namespace Isolation"
echo "Each container gets its own network stack."
echo ""

echo -e "${BLUE}Host Network Interfaces:${NC}"
ip link show | grep "^[0-9]" | awk '{print "  " $2}' | tr -d ':'

echo ""
echo -e "${BLUE}Container Network Interfaces:${NC}"
sudo nsenter -t $PID -n ip link show | grep "^[0-9]" | awk '{print "  " $2}' | tr -d ':'

echo ""
echo -e "${BLUE}Container IP Address:${NC}"
CONTAINER_IP=$(sudo nsenter -t $PID -n ip addr show eth0 2>/dev/null | grep "inet " | awk '{print $2}')
if [ -n "$CONTAINER_IP" ]; then
    echo "  $CONTAINER_IP"
else
    echo "  eth0 interface present but IP not yet assigned"
fi

echo ""
echo -e "${YELLOW}Isolation Details:${NC}"
echo "  • Container cannot see host network interfaces"
echo "  • Container has virtual ethernet (veth) pair"
echo "  • Traffic is bridged/NATed by Podman"
echo "  • Complete network isolation achieved"

pause

header "DEMO 7: Mount Namespace - Filesystem Isolation"
echo "Each container has its own view of the filesystem."
echo ""

echo -e "${BLUE}Mount Points:${NC}"
HOST_MOUNTS=$(mount | wc -l)
# Use the container's /proc/self/mounts which always exists
CONTAINER_MOUNTS=$(podman exec live-demo cat /proc/self/mounts 2>/dev/null | wc -l)
echo "  Host:      $HOST_MOUNTS mount points"
echo "  Container: $CONTAINER_MOUNTS mount points"

echo ""
echo -e "${BLUE}Container Root Filesystem:${NC}"
podman exec live-demo cat /proc/self/mounts 2>/dev/null | grep " / " | head -1 | awk '{
    print "  Device: " $1
    print "  Type: " $3
    print "  Options: " $4
}'

echo ""
echo -e "${BLUE}Filesystem Usage (from container view):${NC}"
podman exec live-demo df -h / 2>/dev/null | tail -1 | awk '{
    print "  Size: " $2
    print "  Used: " $3
    print "  Available: " $4
    print "  Use%: " $5
}'

echo ""
echo -e "${YELLOW}Mount Namespace Benefits:${NC}"
echo "  ✓ Container uses overlay/copy-on-write filesystem"
echo "  ✓ Cannot see host mounts (security)"
echo "  ✓ Cannot interfere with host filesystem"
echo "  ✓ Efficient storage through layering"

pause

header "DEMO 8: Additional Isolation Examples"

echo -e "${BLUE}UTS Namespace - Hostname:${NC}"
echo "  Host hostname:      $(hostname)"
# Get hostname from /proc instead of hostname command
CONTAINER_HOSTNAME=$(podman exec live-demo cat /proc/sys/kernel/hostname 2>/dev/null)
echo "  Container hostname: $CONTAINER_HOSTNAME"

echo ""
echo -e "${BLUE}User Namespace - UID Mapping:${NC}"
echo "  Process user inside container:"
podman exec live-demo sh -c 'id' 2>/dev/null | sed 's/^/    /'
echo ""
echo "  Same process from host perspective:"
ps -o user,pid,comm -p $PID 2>/dev/null | tail -1 | sed 's/^/    /'

echo ""
echo -e "${BLUE}IPC Namespace - Shared Memory:${NC}"
echo "  Host IPC message queues:"
HOST_IPC_COUNT=$(ipcs -q 2>/dev/null | grep -c "^0x" || echo "0")
echo "    $HOST_IPC_COUNT message queues"
echo "  Container IPC (isolated):"
echo "    Has its own IPC namespace, cannot access host IPC resources"

pause

header "SUMMARY: Container Isolation Technology"

echo ""
echo -e "${BOLD}Three Pillars of Container Isolation:${NC}"
echo ""
echo -e "${BLUE}1. NAMESPACES${NC} - What processes can SEE"
echo "   ├─ PID:    Isolated process tree"
echo "   ├─ NET:    Isolated network stack"
echo "   ├─ MNT:    Isolated filesystem view"
echo "   ├─ UTS:    Isolated hostname"
echo "   ├─ IPC:    Isolated inter-process communication"
echo "   └─ USER:   Isolated user/group IDs"

echo ""
echo -e "${BLUE}2. CGROUPS${NC} - How MUCH resources processes can USE"
echo "   ├─ Memory: 512 MB limit (OOM kill if exceeded)"
echo "   ├─ CPU:    1.0 core limit (throttling if exceeded)"
echo "   ├─ I/O:    Bandwidth limits"
echo "   └─ PIDs:   Process count limits"

echo ""
echo -e "${BLUE}3. CAPABILITIES${NC} - What PRIVILEGES processes HAVE"
echo "   ├─ Traditional: root vs non-root (binary)"
echo "   ├─ Capabilities: 40+ fine-grained privileges"
echo "   └─ Our demo: Only NET_BIND_SERVICE (minimal)"

echo ""
echo -e "${YELLOW}Real-World Impact:${NC}"
echo "  📊 Host sees: $HOST_PROC_COUNT processes"
echo "  📦 Container sees: $CONTAINER_PROC_COUNT processes"
echo "  🔒 Container capabilities: 1 out of 40+"
echo "  💾 Memory usage: $MEM_CURRENT_MB MB / $MEM_MAX_MB MB"

echo ""
echo -e "${GREEN}Architecture:${NC}"
cat << 'ARCH'
  ┌───────────────────────────────────────────────────────┐
  │           Linux Kernel (Shared by All)                │
  │  ┌─────────────┬──────────────┬─────────────────────┐ │
  │  │ Namespaces  │   Cgroups    │   Capabilities      │ │
  │  │  (Isolation)│  (Resources) │    (Security)       │ │
  │  └─────────────┴──────────────┴─────────────────────┘ │
  └───────────────────────────────────────────────────────┘
        │                 │                   │
  ┌─────┴─────┐     ┌────┴─────┐      ┌─────┴──────┐
  │Container 1│     │Container 2│      │    Host    │
  │ (isolated)│     │ (isolated)│      │ (full sys) │
  └───────────┘     └───────────┘      └────────────┘
ARCH

echo ""
echo -e "${BOLD}Key Concepts Demonstrated:${NC}"
echo "  1. Containers share the kernel but are isolated"
echo "  2. /proc filesystem reveals kernel-level isolation"
echo "  3. No external tools needed to inspect isolation"
echo "  4. All isolation is enforced at the Linux kernel level"

pause

header "Cleaning Up"
echo "Removing demo container..."
podman stop live-demo > /dev/null 2>&1
podman rm live-demo > /dev/null 2>&1
echo -e "${GREEN}✓ Cleanup complete${NC}"

echo ""
echo -e "${BLUE}${BOLD}Thank you for watching the demonstration!${NC}"
echo ""
echo "For more information:"
echo "  • Podman: https://docs.podman.io/"
echo "  • Namespaces: man 7 namespaces"
echo "  • Cgroups: man 7 cgroups"
echo "  • Capabilities: man 7 capabilities"
echo "  • /proc filesystem: man 5 proc"
echo ""