# Container Demistifyed

## Linux Kernel Building Blocks Enabling Containers

## Namespaces - create isolated and independent instances of user space - 1 isolated instances = 1 containers

Provide isolation of system resources.
Each container gets its own instance of these kernel resources:

- PID — Process ID namespace (isolates process trees)
- NET — Network interfaces (e.g., each container gets its own eth0)
- MNT — Mount points/filesystem
- IPC — Interprocess communication
- UTS — Hostname/domain isolation
- USER — Maps container users to host users for security

Example:
Processes inside one PID namespace cannot see processes in another namespace.
Result: Each container has its own “virtualized” view of the system:

Own process list
Own network stack
Own mount points
Own interprocess communication (IPC) mechanisms

```sh
podman run -d --name alp1 alpine sleep 1000
podman run -d --name alp2 alpine sleep 1001

podman ps

podman exec -it alp1 ps aux arep sleep
podman exec -it alp2 ps aux arep sleep

ps aux | grep sleep

ls /proc/19559/ns/
```

## Control Groups (cgroups)

Provide resource control and accounting.
They define how much CPU, memory, I/O, etc. a container can use:
Prevents resource starvation (one container hogging all resources).

- Each container = one cgroup.
- Admins can set limits like:
```txt
CPU ≤ 50%
Memory ≤ 1 GB
```
Cgroups group processes and control resource usage:

- CPU
- Memory
- Disk I/O
- Network bandwidth

_If exceeded → container throttled, restarted, or killed._

```sh
podman run --name cgroupID -it -d --memory=1G --memory-swap=1G ubuntu /bin/bash

CONTAINER_ID=$(podman ps --format "{{.ID}}" --filter "name=cgroupID")
```

## Unified File System (UFS)

Used by Docker to manage container images.

- Filesystems are layered — multiple read-only layers (base OS, libraries, etc.) topped with a single writable layer.
- This structure gives the illusion of a unified filesystem.
- Base image (e.g., BusyBox) = minimal OS layer.
- User modifications occur in the top writable layer.
- Enables fast image builds and sharing.

_“UFS layers file systems on top of each other — presenting a unified block for the container.”_

Image vs Container

- Image: Static, immutable blueprint built via docker build.
- Container: A running instance of an image.

_Analogy: Image = binary program, Container = running process._

🧱 Layers

- Each image is made up of layers (from base → new additions).
- Commands like RUN, COPY, ADD create new layers.
- Layers stack like pancakes; each one depends on the one below.
- Layers are identified by hashes and sometimes tags (e.g., ubuntu:16.04).

⚙️ Intermediate Containers

- During docker build, Docker runs each step in a temporary container.
- That container’s result becomes a new image layer.
- These intermediate containers are deleted after build completion.

💾 Layer Reuse and Caching

- If you already have the base image (e.g., ubuntu), Docker reuses it.
- Only new or changed layers are downloaded or built.
- Works at file-level diffs, not line-level like git.
- Build cache: If earlier steps in Dockerfile haven’t changed, Docker reuses cached layers.
- Cache is invalidated once a step changes; all following steps rebuild.
- ADD/COPY always invalidate cache (since Docker doesn’t check file contents deeply).

🧍 Container’s Read-Write Layer

- Containers get a temporary top read-write layer above image layers.
- Changes (adds/modifies/deletes) occur only here — images remain unchanged.
- When a container stops, that layer disappears (unless committed to a new image).

🏗️ Best Practices

- Put static steps (e.g., package installs) at the top of the Dockerfile.
- Put frequently changed steps (e.g., source code COPY) at the bottom.
- This maximizes build cache efficiency and reduces rebuild time.

## Capabilities – Privilege Restriction

Linux capabilities divide the all-powerful “root” privileges into smaller permission sets.
Docker/Podman uses these to control what a containerized process can or cannot do. [Docker CAP]( https://docs.docker.com/engine/containers/run/#fruntime-privilege-and-linux-capabilities), [Podman CAP](https://docs.podman.io/en/latest/markdown/podman-build.1.html)

By default, Docker enables 14 standard capabilities (e.g., CHOWN, NET_BIND_SERVICE, etc.).

You can drop or add capabilities as needed.

- fine grain control over privileges a user or process gets
- --privileged = true 
- docker uses a white list

## Workshop

I'll provide a much more detailed version with comprehensive explanations for each command and concept.

## **Comprehensive Step-by-Step Podman Container Isolation Demo on RHEL 10**

---

### **Step 1: Setup and Prerequisites**

**Purpose:** Verify the environment and install necessary tools for inspecting container isolation mechanisms.

```bash
# Check Podman version
# This confirms Podman is installed and shows which version you're running
# RHEL 10 typically comes with Podman 4.x or newer
podman --version

# Expected output: podman version 4.x.x
```

```bash
# Verify cgroups version
# RHEL 10 uses cgroups v2 (unified hierarchy) by default
# cgroups v2 provides a simplified and more consistent interface
stat -fc %T /sys/fs/cgroup/

# Expected output: cgroup2fs
# If you see "tmpfs", you're on cgroups v1 (legacy)

# Additional verification - check the cgroup filesystem
mount | grep cgroup
# You should see a single cgroup2 mount point at /sys/fs/cgroup
```

```bash
# Check available namespace types on your kernel
# This shows what isolation mechanisms are available
ls -l /proc/self/ns/

# Expected output shows 7-8 namespace types:
# - cgroup: Cgroup root directory isolation
# - ipc: Inter-Process Communication isolation
# - mnt: Mount points isolation (filesystem)
# - net: Network stack isolation
# - pid: Process ID isolation
# - pid_for_children: PID namespace for child processes
# - user: User and group ID isolation
# - uts: Hostname and domain name isolation
```

---

### **Step 2: Start a Demo Container with Resource Constraints**

**Purpose:** Launch a container with specific resource limits and security restrictions to demonstrate how Podman configures kernel features.

```bash
# Start a container with multiple isolation and resource limit settings
podman run -d \
  --name demo-container \
  --memory=512m \
  --cpus=1.0 \
  --cap-drop=ALL \
  --cap-add=NET_BIND_SERVICE \
  registry.access.redhat.com/ubi9/ubi:latest \
  sleep 3600

# Parameter explanations:
# -d                    : Run in detached mode (background)
# --name demo-container : Give the container a friendly name
# --memory=512m         : Limit container to 512 MB of RAM (uses memory cgroup)
# --cpus=1.0            : Limit to 1 CPU core worth of time (uses cpu cgroup)
# --cap-drop=ALL        : Remove all Linux capabilities (maximum security)
# --cap-add=NET_BIND_SERVICE : Add back only the capability to bind to ports <1024
# registry.access.redhat.com/ubi9/ubi:latest : Use Red Hat Universal Base Image
# sleep 3600            : Keep container running for 1 hour

# This creates a container with:
# - Its own isolated namespaces (network, PID, mount, etc.)
# - Cgroup-enforced resource limits
# - Minimal capabilities for security
```

```bash
# Verify the container is running
podman ps

# Expected output shows:
# - CONTAINER ID: Unique identifier
# - IMAGE: The base image used
# - COMMAND: What's running inside (sleep 3600)
# - STATUS: How long it's been running
# - NAMES: Our friendly name (demo-container)
```

```bash
# Get detailed container information
podman inspect demo-container | less

# This JSON output includes:
# - State.Pid: The main process ID on the host
# - HostConfig: Resource limits and security settings
# - NetworkSettings: Network configuration
# - Mounts: Volume mounts
# Press 'q' to exit less
```

---

### **Step 3: Deep Dive into Namespaces**

**Purpose:** Understand how namespaces provide isolated views of system resources, making the container think it's on its own system.

```bash
# Get the container's main process ID (PID) on the host system
# This PID is crucial - it's the bridge between the host and container
CONTAINER_PID=$(podman inspect -f '{{.State.Pid}}' demo-container)
echo "Container PID: $CONTAINER_PID"

# Explanation: Every container has a main process that the host kernel tracks.
# From the host's perspective, it's just another process with a PID.
# From inside the container, this process appears as PID 1.
```

```bash
# View all namespace references for the container
echo "=== Container Namespaces ==="
sudo ls -l /proc/$CONTAINER_PID/ns/

# Expected output shows symbolic links like:
# cgroup -> 'cgroup:[4026532451]'  (the number is the namespace ID)
# ipc -> 'ipc:[4026532449]'
# mnt -> 'mnt:[4026532447]'
# net -> 'net:[4026532452]'
# pid -> 'pid:[4026532450]'
# ...

# Explanation: Each namespace type has a unique ID (the number in brackets).
# Processes in the same namespace share the same ID.
# Different IDs mean different isolated environments.
```

```bash
# Compare with host namespaces (systemd/init process)
echo -e "\n=== Host Namespaces (PID 1 for comparison) ==="
sudo ls -l /proc/1/ns/

# Key observation: The namespace IDs are DIFFERENT between host and container
# This proves the container is running in isolated namespaces
# Example:
#   Host net namespace:      net -> 'net:[4026531840]'
#   Container net namespace: net -> 'net:[4026532452]'
# Different IDs = different network stacks
```

```bash
# Use lsns (list namespaces) for a more detailed view
echo -e "\n=== Namespace Details with Process Counts ==="
sudo lsns -p $CONTAINER_PID

# Output columns explained:
# NS         : Namespace ID (inode number)
# TYPE       : Namespace type (cgroup, ipc, mnt, net, pid, user, uts)
# NPROCS     : Number of processes in this namespace
# PID        : Lowest PID in the namespace
# USER       : User who created the namespace
# COMMAND    : Command of the process

# This shows all namespaces the container process belongs to
```

```bash
# Show which processes share the same network namespace
echo -e "\n=== Processes in Same Network Namespace ==="
sudo lsns -t net | grep $CONTAINER_PID

# Explanation: If you run multiple processes in the same container,
# they'll all share the same network namespace (same network interfaces)
```

```bash
# Show mount namespace details
echo -e "\n=== Mount Namespace (Filesystem Isolation) ==="
sudo lsns -t mnt | grep $CONTAINER_PID

# The mount namespace gives the container its own filesystem view
# It can't see host mounts, and host can't see container's internal mounts
# (unless explicitly shared via volumes)
```

```bash
# Show PID namespace details
echo -e "\n=== PID Namespace (Process Isolation) ==="
sudo lsns -t pid | grep $CONTAINER_PID

# PID namespace means:
# - Container sees its own process tree (starting from PID 1)
# - Container can't see host processes
# - Host can see container processes (with host PIDs)
```

```bash
# Demonstrate PID namespace isolation
echo -e "\n=== Process View from HOST ==="
ps aux | grep sleep | grep 3600
# Shows the sleep process with a high PID number (e.g., 12345)

echo -e "\n=== Process View from INSIDE Container ==="
podman exec demo-container ps aux
# Shows the sleep process as PID 1!
# This is the magic of PID namespace - different views of the same process
```

---

### **Step 4: Deep Dive into Cgroups (Control Groups)**

**Purpose:** Understand how cgroups enforce resource limits (CPU, memory, I/O) on containers.

```bash
# View which cgroup the container belongs to
echo "=== Container Cgroup Membership ==="
cat /proc/$CONTAINER_PID/cgroup

# Expected output (cgroups v2 format):
# 0::/system.slice/libpod-abc123.scope
#
# Format explained:
# 0            : Hierarchy ID (always 0 in cgroups v2)
# ::           : Separator
# /system.slice/libpod-abc123.scope : Cgroup path in the hierarchy
#
# The path shows:
# - system.slice: System service slice
# - libpod-xxx.scope: Podman's cgroup for this container
```

```bash
# Extract the cgroup path for easier access
CGROUP_PATH=$(cat /proc/$CONTAINER_PID/cgroup | cut -d: -f3)
echo "Cgroup path: $CGROUP_PATH"
echo "Full filesystem path: /sys/fs/cgroup${CGROUP_PATH}"

# Explanation: Cgroups are represented as a filesystem hierarchy
# Each directory in /sys/fs/cgroup represents a cgroup
# Control files in these directories set limits and show statistics
```

```bash
# Examine memory limits and usage
echo -e "\n=== Memory Cgroup Controls ==="

# Maximum memory the container can use
echo -n "Memory Limit: "
sudo cat /sys/fs/cgroup${CGROUP_PATH}/memory.max
# Output: 536870912 (bytes) = 512 MB (what we set with --memory=512m)
# If output is "max", there's no limit

# Current memory usage
echo -n "Memory Current Usage: "
sudo cat /sys/fs/cgroup${CGROUP_PATH}/memory.current
# Shows actual bytes currently used by container
# Example: 4194304 (4 MB)

# Memory high watermark (soft limit)
echo -n "Memory High (soft limit): "
sudo cat /sys/fs/cgroup${CGROUP_PATH}/memory.high 2>/dev/null || echo "Not set"

# What happens when limit is reached:
# - memory.max exceeded: OOM killer terminates processes
# - memory.high exceeded: System throttles memory allocation
```

```bash
# Examine CPU limits
echo -e "\n=== CPU Cgroup Controls ==="

# CPU bandwidth limit
echo -n "CPU Max: "
sudo cat /sys/fs/cgroup${CGROUP_PATH}/cpu.max
# Output format: "quota period"
# Example: "100000 100000" means 100ms quota per 100ms period = 1 full CPU
# Our --cpus=1.0 sets this to allow 1 CPU core worth of time

# CPU weight (scheduling priority)
echo -n "CPU Weight: "
sudo cat /sys/fs/cgroup${CGROUP_PATH}/cpu.weight
# Range: 1-10000, default is 100
# Higher weight = more CPU time when there's contention

# CPU statistics
echo -e "\nCPU Statistics:"
sudo cat /sys/fs/cgroup${CGROUP_PATH}/cpu.stat
# Shows:
# - usage_usec: Total CPU time used (microseconds)
# - user_usec: User mode CPU time
# - system_usec: Kernel mode CPU time
# - nr_periods: Number of enforcement periods
# - nr_throttled: Times the cgroup was throttled
# - throttled_usec: Total time throttled
```

```bash
# View all available cgroup controllers
echo -e "\n=== Available Cgroup Controllers (Subsystems) ==="
cat /sys/fs/cgroup/cgroup.controllers

# Expected output: cpuset cpu io memory hugetlb pids rdma misc
# Each controller manages a different resource type:
# - cpuset: CPU and memory node assignment
# - cpu: CPU time distribution
# - io: Block I/O bandwidth
# - memory: Memory usage
# - hugetlb: Huge pages
# - pids: Number of processes
# - rdma: RDMA/IB resources
# - misc: Miscellaneous resources
```

```bash
# Check which controllers are enabled for this cgroup
echo -e "\n=== Enabled Controllers for Container ==="
sudo cat /sys/fs/cgroup${CGROUP_PATH}/cgroup.controllers 2>/dev/null || \
sudo cat /sys/fs/cgroup/system.slice/cgroup.controllers

# Explanation: Not all controllers may be enabled at every level
# of the hierarchy. They must be explicitly delegated.
```

```bash
# View detailed memory statistics
echo -e "\n=== Detailed Memory Statistics ==="
sudo cat /sys/fs/cgroup${CGROUP_PATH}/memory.stat

# Output includes many metrics:
# - anon: Anonymous memory (heap, stack) - not backed by files
# - file: Page cache memory - file-backed pages
# - kernel_stack: Memory used for kernel stacks
# - slab: Kernel slab memory
# - sock: Memory used by sockets
# - shmem: Shared memory
# - file_mapped: Memory-mapped files
# - pgfault: Page fault events
# - pgmajfault: Major page faults (requiring disk I/O)

# These stats help understand container memory behavior
```

```bash
# View I/O statistics (if IO controller is enabled)
echo -e "\n=== I/O Statistics ==="
sudo cat /sys/fs/cgroup${CGROUP_PATH}/io.stat 2>/dev/null || echo "IO controller not enabled"

# Shows read/write bytes and operations per block device
# Format: major:minor rbytes=X wbytes=Y rios=A wios=B
```

```bash
# Show all processes in this cgroup
echo -e "\n=== PIDs in This Cgroup ==="
sudo cat /sys/fs/cgroup${CGROUP_PATH}/cgroup.procs

# Lists all process IDs belonging to this container's cgroup
# You should see at least one PID (the sleep process)
# Multiple PIDs indicate multiple processes in the container
```

```bash
# Demonstrate cgroup enforcement with a memory stress test
echo -e "\n=== Testing Memory Limit Enforcement ==="
echo "Container memory limit: 512 MB"
echo "Attempting to allocate 1 GB inside container..."

# Try to exceed memory limit (this will be killed by OOM)
podman exec demo-container bash -c 'echo "Memory test starting"; sleep 2' || echo "Container still running"

# Real test (only run if you want to see OOM kill):
# podman exec demo-container bash -c 'dd if=/dev/zero of=/dev/null bs=1M count=1024'
# This would be killed when exceeding 512 MB limit
```

---

### **Step 5: Deep Dive into Capabilities**

**Purpose:** Understand how Linux capabilities provide fine-grained privilege control instead of all-or-nothing root access.

```bash
# View raw capability bitmasks
echo "=== Capabilities (Raw Hexadecimal Format) ==="
grep Cap /proc/$CONTAINER_PID/status

# Output shows 5 capability sets as hexadecimal bitmasks:
# CapInh (Inherited): Capabilities preserved across execve()
# CapPrm (Permitted): Capabilities the process can use
# CapEff (Effective): Capabilities currently active
# CapBnd (Bounding): Maximum capabilities a process can ever have
# CapAmb (Ambient): Capabilities preserved across execve() for non-privileged users

# Example output:
# CapInh: 0000000000000000  (No inherited capabilities)
# CapPrm: 0000000000000400  (Some permitted capabilities)
# CapEff: 0000000000000400  (Same as permitted - all are active)
# CapBnd: 0000000000000400  (Bounded to only these)
# CapAmb: 0000000000000000  (No ambient capabilities)
```

```bash
# Decode the effective capabilities to human-readable names
CAP_EFF=$(grep CapEff /proc/$CONTAINER_PID/status | awk '{print $2}')
echo -e "\n=== Effective Capabilities (Decoded) ==="
echo "Hex value: $CAP_EFF"
capsh --decode=$CAP_EFF

# Example output: 0x0000000000000400=cap_net_bind_service
# This means only CAP_NET_BIND_SERVICE is granted
#
# Capability explanation:
# CAP_NET_BIND_SERVICE: Allows binding to ports below 1024 (privileged ports)
# This is what we added with --cap-add=NET_BIND_SERVICE
```

```bash
# Use getpcaps for more readable output
echo -e "\n=== Capabilities via getpcaps (More Readable) ==="
getpcaps $CONTAINER_PID

# Output format: PID = cap_net_bind_service+eip
# The +eip means: effective, inheritable, permitted
# This is clearer than hex values
```

```bash
# Check capabilities from inside the container
echo -e "\n=== Capabilities from Container's Perspective ==="
podman exec demo-container capsh --print

# Shows:
# Current: Lists all current capabilities
# Bounding set: Maximum capabilities allowed
# Ambient set: Capabilities preserved for child processes
#
# With --cap-drop=ALL --cap-add=NET_BIND_SERVICE,
# you should only see cap_net_bind_service in the list
```

```bash
# List all possible Linux capabilities
echo -e "\n=== All Available Linux Capabilities ==="
capsh --print | grep "Bounding set" | tr ',' '\n'

# Common capabilities and their purposes:
# CAP_CHOWN           - Change file ownership
# CAP_DAC_OVERRIDE    - Bypass file permission checks
# CAP_FOWNER          - Bypass permission checks on operations requiring file owner UID
# CAP_KILL            - Bypass permission checks for sending signals
# CAP_SETGID          - Make arbitrary manipulations of process GIDs
# CAP_SETUID          - Make arbitrary manipulations of process UIDs
# CAP_NET_BIND_SERVICE- Bind socket to privileged ports (<1024)
# CAP_NET_RAW         - Use RAW and PACKET sockets
# CAP_SYS_CHROOT      - Use chroot()
# CAP_SYS_ADMIN       - Wide range of admin operations (very powerful!)
# CAP_SYS_PTRACE      - Trace arbitrary processes using ptrace()
```

```bash
# Demonstrate capability restriction
echo -e "\n=== Testing Capability Restrictions ==="

# This should SUCCEED (we have NET_BIND_SERVICE)
echo "Test 1: Binding to privileged port 80 (should work)"
podman exec demo-container bash -c 'nc -l 80 &' 2>&1 | head -5 || echo "Success - can bind to port 80"

# This should FAIL (we don't have NET_RAW)
echo -e "\nTest 2: Creating raw socket (should fail)"
podman exec demo-container bash -c 'ping -c 1 8.8.8.8' 2>&1 | head -5 || echo "Failed as expected - no CAP_NET_RAW"

# Install ping if needed for demo:
# podman exec demo-container dnf install -y iputils
```

---

### **Step 6: Compare Normal vs Privileged Container**

**Purpose:** Understand the dramatic security difference between normal and privileged containers.

```bash
# Start a privileged container for comparison
# WARNING: Privileged containers have almost no isolation!
podman run -d \
  --name privileged-container \
  --privileged \
  registry.access.redhat.com/ubi9/ubi:latest \
  sleep 3600

# The --privileged flag:
# - Grants ALL capabilities
# - Disables seccomp filtering
# - Disables AppArmor/SELinux confinement
# - Gives access to all devices
# - Essentially makes container nearly as powerful as host root
# USE WITH EXTREME CAUTION!

PRIV_PID=$(podman inspect -f '{{.State.Pid}}' privileged-container)
echo "Privileged container PID: $PRIV_PID"
```

```bash
# Compare capabilities side by side
echo "=== SECURITY COMPARISON ==="
echo ""
echo "Normal Container Capabilities:"
getpcaps $CONTAINER_PID 2>&1 | grep -v "warning"

echo ""
echo "Privileged Container Capabilities:"
getpcaps $PRIV_PID 2>&1 | grep -v "warning"

# Observation: Privileged container has MANY more capabilities
# This includes dangerous ones like:
# - CAP_SYS_ADMIN (administrative operations)
# - CAP_SYS_MODULE (load kernel modules)
# - CAP_SYS_RAWIO (perform I/O port operations)
```

```bash
# Compare full capability sets
echo -e "\n=== Detailed Capability Comparison ==="
echo "Normal container:"
podman exec demo-container capsh --print | grep "Current:"

echo ""
echo "Privileged container:"
podman exec privileged-container capsh --print | grep "Current:"

# Normal container: Very few capabilities
# Privileged container: Almost all capabilities (37+ capabilities)
```

```bash
# Compare namespace isolation
echo -e "\n=== Namespace Comparison ==="
echo "Normal container namespaces:"
sudo lsns -p $CONTAINER_PID -o TYPE,NS

echo ""
echo "Privileged container namespaces:"
sudo lsns -p $PRIV_PID -o TYPE,NS

# Note: Privileged containers still use namespaces
# But they have more access to host resources
```

```bash
# Demonstrate security difference with device access
echo -e "\n=== Device Access Test ==="
echo "Normal container devices:"
podman exec demo-container ls -l /dev | head -10
# Should see very limited devices: null, zero, random, urandom, etc.

echo ""
echo "Privileged container devices:"
podman exec privileged-container ls -l /dev | head -20
# Should see MANY more devices including block devices (sda, etc.)
# Privileged containers can access host hardware!
```

---

### **Step 7: Interactive Namespace Exploration**

**Purpose:** Enter and explore container namespaces from the host to understand isolation from both perspectives.

```bash
# nsenter allows us to enter one or more namespaces of a running process
# This is like "SSH into a namespace"

# Enter the network namespace only
echo "=== Exploring Network Namespace ==="
sudo nsenter -t $CONTAINER_PID -n ip addr show

# Explanation:
# -t $CONTAINER_PID : Target process (our container)
# -n                : Enter network namespace
# ip addr show      : Command to run inside that namespace
#
# Output shows container's network interfaces:
# - lo (loopback): Always present
# - eth0 or similar: Container's virtual ethernet interface
# 
# This is DIFFERENT from host network interfaces!
```

```bash
# Compare with host network interfaces
echo -e "\n=== Host Network Interfaces (for comparison) ==="
ip addr show

# You'll see different interfaces like:
# - Physical interfaces (eth0, ens5, etc.)
# - Docker/Podman bridge interfaces
# - Many more interfaces than the container sees
```

```bash
# Explore the mount namespace (filesystem view)
echo -e "\n=== Container's Mount Points ==="
sudo nsenter -t $CONTAINER_PID -m mount | wc -l
echo "Number of mounts in container: $(sudo nsenter -t $CONTAINER_PID -m mount | wc -l)"

echo ""
echo "Number of mounts on host: $(mount | wc -l)"

# Container has fewer mounts - only sees its own filesystem
# Host sees all system mounts
```

```bash
# Show specific mount differences
echo -e "\n=== Container Root Filesystem ==="
sudo nsenter -t $CONTAINER_PID -m df -h /

echo -e "\n=== Host Root Filesystem ==="
df -h /

# Different filesystems, different sizes, different usage
# Container's root is an overlay filesystem from the image
```

```bash
# Explore PID namespace
echo -e "\n=== Process View from Container's PID Namespace ==="
sudo nsenter -t $CONTAINER_PID -p -m ps aux

# Output shows only processes in the container
# PIDs start from 1 (the sleep command in our case)
# This is the container's isolated process tree
```

```bash
# Compare with host process tree
echo -e "\n=== Host Process Tree ==="
ps aux | head -20

# Shows ALL system processes
# Container processes appear with their HOST PIDs (much higher numbers)
```

```bash
# Enter multiple namespaces at once (network + PID + mount)
echo -e "\n=== Exploring Multiple Namespaces Simultaneously ==="
sudo nsenter -t $CONTAINER_PID -n -p -m bash -c '
  echo "=== Inside Container Namespaces ==="
  echo "Hostname: $(hostname)"
  echo "IP Address: $(hostname -I)"
  echo "Process count: $(ps aux | wc -l)"
  echo "Root filesystem: $(df -h / | tail -1)"
'

# This runs a bash command inside the container's environment
# without actually using "podman exec"
# It demonstrates that namespaces work at the kernel level
```

```bash
# Explore UTS namespace (hostname isolation)
echo -e "\n=== Hostname Isolation (UTS Namespace) ==="
echo "Host hostname: $(hostname)"
echo "Container hostname:"
podman exec demo-container hostname

# Different hostnames prove UTS namespace isolation
# Each container can have its own hostname
```

```bash
# Explore IPC namespace (Inter-Process Communication)
echo -e "\n=== IPC Namespace ==="
echo "Host IPC resources:"
ipcs -a | head -10

echo ""
echo "Container IPC resources:"
sudo nsenter -t $CONTAINER_PID -i ipcs -a

# Different IPC resources (message queues, semaphores, shared memory)
# Containers can't interfere with host IPC objects
```

---

### **Step 8: Real-World Resource Monitoring**

**Purpose:** Monitor container resource usage in real-time to see cgroups in action.

```bash
# Create a script to monitor container resources
cat > monitor_container.sh << 'EOF'
#!/bin/bash

# Get container PID
CONTAINER_NAME="demo-container"
PID=$(podman inspect -f '{{.State.Pid}}' $CONTAINER_NAME 2>/dev/null)

if [ -z "$PID" ]; then
    echo "Container not found or not running"
    exit 1
fi

# Get cgroup path
CGROUP_PATH=$(cat /proc/$PID/cgroup | cut -d: -f3)

echo "======================================"
echo "Real-Time Container Resource Monitor"
echo "======================================"
echo "Container: $CONTAINER_NAME"
echo "PID: $PID"
echo "Cgroup: $CGROUP_PATH"
echo ""

# Monitor loop
while true; do
    # Clear screen for clean output
    clear
    
    echo "=== Resource Usage (Updated every 2 seconds) ==="
    echo "Time: $(date '+%H:%M:%S')"
    echo ""
    
    # Memory usage
    MEM_CURRENT=$(sudo cat /sys/fs/cgroup${CGROUP_PATH}/memory.current 2>/dev/null)
    MEM_MAX=$(sudo cat /sys/fs/cgroup${CGROUP_PATH}/memory.max 2>/dev/null)
    
    if [ "$MEM_MAX" = "max" ]; then
        MEM_MAX_MB="unlimited"
        MEM_PERCENT="N/A"
    else
        MEM_MAX_MB=$((MEM_MAX / 1024 / 1024))
        MEM_PERCENT=$((MEM_CURRENT * 100 / MEM_MAX))
    fi
    
    MEM_CURRENT_MB=$((MEM_CURRENT / 1024 / 1024))
    
    echo "Memory:"
    echo "  Current: ${MEM_CURRENT_MB} MB"
    echo "  Limit:   ${MEM_MAX_MB} MB"
    [ "$MEM_PERCENT" != "N/A" ] && echo "  Usage:   ${MEM_PERCENT}%"
    echo ""
    
    # CPU usage
    CPU_STAT=$(sudo cat /sys/fs/cgroup${CGROUP_PATH}/cpu.stat 2>/dev/null)
    CPU_USAGE_USEC=$(echo "$CPU_STAT" | grep usage_usec | awk '{print $2}')
    CPU_THROTTLED=$(echo "$CPU_STAT" | grep throttled_usec | awk '{print $2}')
    
    CPU_USAGE_SEC=$((CPU_USAGE_USEC / 1000000))
    CPU_THROTTLED_SEC=$((CPU_THROTTLED / 1000000))
    
    echo "CPU:"
    echo "  Total time:      ${CPU_USAGE_SEC} seconds"
    echo "  Throttled time:  ${CPU_THROTTLED_SEC} seconds"
    echo ""
    
    # Process count
    PROC_COUNT=$(sudo cat /sys/fs/cgroup${CGROUP_PATH}/cgroup.procs 2>/dev/null | wc -l)
    echo "Processes: $PROC_COUNT"
    echo ""
    
    echo "Press Ctrl+C to stop monitoring"
    
    sleep 2
done
EOF

chmod +x monitor_container.sh

# Run the monitor
echo "Starting resource monitor..."
echo "This will update every 2 seconds. Press Ctrl+C to stop."
sleep 3
# sudo ./monitor_container.sh  # Uncomment to run
```

```bash
# Generate some load to see cgroup limits in action
echo -e "\n=== Creating CPU Load in Container ==="

# Start a CPU-intensive process in the container
podman exec -d demo-container bash -c 'while true; do echo "stress" > /dev/null; done'

# Monitor CPU throttling (run this in another terminal with the monitor script above)
echo "Watch the CPU throttling increase in the monitor output"
echo "The cgroup is limiting the container to 1.0 CPU core"
```

```bash
# Check CPU throttling statistics
CGROUP_PATH=$(cat /proc/$CONTAINER_PID/cgroup | cut -d: -f3)
echo -e "\n=== CPU Throttling Statistics ==="
sudo cat /sys/fs/cgroup${CGROUP_PATH}/cpu.stat

# Look for:
# - nr_throttled: Number of times the cgroup was throttled
# - throttled_usec: Total time spent throttled
# Higher values mean the container is hitting CPU limits
```

```bash
# Test memory allocation
echo -e "\n=== Testing Memory Usage ==="
podman exec demo-container bash -c '
    echo "Allocating memory..."
    # Allocate 100 MB
    python3 -c "
import time
data = [0] * (100 * 1024 * 1024 // 8)  # 100 MB
print(\"Allocated 100 MB\")
time.sleep(5)
print(\"Releasing memory\")
" 2>/dev/null || echo "Python not available, skipping memory test"
'

# Check memory usage during allocation
sleep 1
MEM_CURRENT=$(sudo cat /sys/fs/cgroup${CGROUP_PATH}/memory.current)
echo "Current memory usage: $((MEM_CURRENT / 1024 / 1024)) MB"
```

---

### **Step 9: Cleanup and Summary**

**Purpose:** Clean up resources and provide a summary of what was demonstrated.

```bash
# Stop all demo containers gracefully
echo "=== Stopping Containers ==="
podman stop demo-container privileged-container 2>/dev/null

# Container stop process:
# 1. Sends SIGTERM to main process (graceful shutdown)
# 2. Waits 10 seconds
# 3. Sends SIGKILL if still running (force kill)
```

```bash
# Remove containers
echo "=== Removing Containers ==="
podman rm demo-container privileged-container 2>/dev/null

# This removes the container metadata and storage
# The image remains cached for future use
```

```bash
# Verify cleanup
echo "=== Verifying Cleanup ==="
podman ps -a

# Should show no containers
# All cgroups and namespaces are automatically cleaned up
```

```bash
# Optional: Remove the image if you want complete cleanup
# podman rmi registry.access.redhat.com/ubi9/ubi:latest

# Optional: Clean up all unused resources
# podman system prune -a
```

# Display summary

================================================================
                    DEMONSTRATION SUMMARY
================================================================

What We Demonstrated:

1. NAMESPACES - Process Isolation
   ✓ PID namespace: Isolated process tree
   ✓ Network namespace: Isolated network stack
   ✓ Mount namespace: Isolated filesystem view
   ✓ UTS namespace: Isolated hostname
   ✓ IPC namespace: Isolated IPC resources
   ✓ User namespace: Isolated user IDs
   ✓ Cgroup namespace: Isolated cgroup hierarchy

2. CGROUPS - Resource Limits
   ✓ Memory limits and usage tracking
   ✓ CPU quota and weight
   ✓ I/O bandwidth control
   ✓ PID limits
   ✓ Real-time monitoring

3. CAPABILITIES - Security Controls
   ✓ Fine-grained privilege management
   ✓ Capability dropping for security
   ✓ Comparison with privileged mode
   ✓ Testing capability restrictions

Key Takeaways:

• Containers are NOT virtual machines - they share the kernel
• Isolation is achieved through kernel features, not hardware
• Namespaces provide WHAT processes can see
• Cgroups control HOW MUCH resources processes can use
• Capabilities control WHAT PRIVILEGES processes have
• Podman implements these features without a daemon
• Security requires careful capability and privilege management

Tools We Used:

• lsns - List namespaces
• nsenter - Enter namespaces
• cat /proc/*/cgroup - View cgroup membership
• cat /sys/fs/cgroup/* - View cgroup controls
• capsh - Decode capabilities
• getpcaps - View process capabilities
• podman inspect - View container configuration

================================================================

For presentations, focus on:
1. Show namespace IDs are different (isolation)
2. Demonstrate resource limits work (cgroup enforcement)
3. Compare normal vs privileged capabilities (security)
4. Use nsenter to show dual perspective (host vs container)

================================================================


_This comprehensive guide provides everything you need for undastanding on container isolation!_