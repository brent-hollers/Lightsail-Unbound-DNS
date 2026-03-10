# 🏫 School DNS Caching Infrastructure

A cost-effective, self-managed caching DNS resolver for K-12 school networks built on AWS Lightsail and Unbound. Designed to reduce DNS lookup latency, improve reliability during high-concurrency events (PSAT, standardized testing), and cache frequently visited domains — all for under $10/month.

---

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Infrastructure](#infrastructure)
- [Installation](#installation)
  - [Lightsail Instance Setup](#lightsail-instance-setup)
  - [Unbound Configuration](#unbound-configuration)
  - [UDM Pro DNS Configuration](#udm-pro-dns-configuration)
- [Monitoring](#monitoring)
  - [Option A: Datadog](#option-a-datadog)
  - [Option B: Netdata (Recommended)](#option-b-netdata-recommended)
- [Security](#security)
- [Cost Breakdown](#cost-breakdown)
- [GoGuardian Compatibility](#goguardian-compatibility)
- [Troubleshooting](#troubleshooting)

---

## Overview

### Problem

During high-concurrency events like PSAT testing, external DNS resolution becomes a hidden bottleneck. Without a local caching resolver, every client device sends individual DNS queries to external resolvers (Cloudflare, Google) — even when hundreds of devices are resolving the same hostnames within seconds of each other.

### Solution

A recursive, caching DNS resolver deployed on AWS Lightsail, reachable via an existing Site-to-Site VPN from a Unifi UDM Pro firewall. Unbound is used as the resolver for its prefetching capability, DNSSEC validation, and fine-grained cache TTL control.

### Goals

- ⚡ Sub-millisecond resolution for cached records (vs. 20–50ms to external resolvers)
- 🔁 Cache prefetching so popular records never go cold
- 🛡️ DNSSEC validation
- 💰 Predictable flat-rate cost (~$5–8/month)
- 🔒 Zero disruption to GoGuardian filtering on student VLANs

---

## Architecture

```
Staff / Faculty / Admin Devices
          │
          ▼
    UDM Pro (Unifi)
    ├── Student VLANs ──────────────────────► GoGuardian DNS (unchanged)
    │
    └── Staff/Admin VLANs
              │
              ▼
      Site-to-Site VPN
              │
              ▼
  AWS Lightsail (us-east-1)
  ┌─────────────────────────────────┐
  │  Ubuntu 22.04 LTS               │
  │  Unbound (Caching DNS Resolver) │
  │  Netdata or Datadog Agent       │
  └─────────────────────────────────┘
              │
              ▼
    Upstream: 1.1.1.1 / 8.8.8.8
```

> **Important:** Student VLAN DNS is intentionally left routing through GoGuardian. Do not change DNS settings for student devices without first confirming compatibility with GoGuardian support.

---

## Prerequisites

- Unifi UDM Pro with an active Site-to-Site VPN to AWS
- AWS account with Lightsail access
- Existing VLANs segmenting student and staff/admin devices
- Basic familiarity with Ubuntu CLI and Unifi Network console

---

## Infrastructure

### AWS Lightsail Instance

| Setting | Value |
|---|---|
| Plan | $5/month (2 vCPU, 1GB RAM) |
| OS | Ubuntu 22.04 LTS |
| Region | us-east-1 (or match your VPN region) |
| Static IP | Required — assign via Lightsail console |
| Firewall Rules | See [Security](#security) section |

---

## Installation

### Lightsail Instance Setup

1. Create a new Lightsail instance (Ubuntu 22.04 LTS, $5/month plan)
2. Assign a static private IP in the Lightsail console
3. SSH into the instance:

```bash
ssh -i your-key.pem ubuntu@<LIGHTSAIL_PUBLIC_IP>
```

4. Update the system:

```bash
sudo apt update && sudo apt upgrade -y
```

5. Install Unbound:

```bash
sudo apt install unbound -y
```

---

### Unbound Configuration

Create or edit the main Unbound config:

```bash
sudo nano /etc/unbound/unbound.conf
```

Paste the following configuration:

```conf
server:
    # Listen on all interfaces (restrict via firewall)
    interface: 0.0.0.0
    port: 53
    do-ip4: yes
    do-ip6: no
    do-tcp: yes
    do-udp: yes

    # Access control — replace with your VPN CIDR
    access-control: 127.0.0.0/8 allow
    access-control: 10.0.0.0/8 allow        # adjust to match your VPN tunnel CIDR
    access-control: 0.0.0.0/0 refuse

    # Caching
    cache-min-ttl: 300
    cache-max-ttl: 86400
    msg-cache-size: 64m
    rrset-cache-size: 128m

    # Prefetching — resolves popular records before TTL expires
    prefetch: yes
    prefetch-key: yes

    # Performance
    num-threads: 2
    so-rcvbuf: 1m

    # DNSSEC
    auto-trust-anchor-file: "/var/lib/unbound/root.key"

    # Privacy
    hide-identity: yes
    hide-version: yes

    # Logging (disable in production for performance)
    verbosity: 1
    log-queries: no

forward-zone:
    name: "."
    forward-addr: 1.1.1.1@853#cloudflare-dns.com
    forward-addr: 8.8.8.8@853#dns.google
    forward-tls-upstream: yes
```

Enable and start Unbound:

```bash
sudo systemctl enable unbound
sudo systemctl start unbound
sudo systemctl status unbound
```

Test local resolution:

```bash
dig @127.0.0.1 google.com
```

---

### UDM Pro DNS Configuration

1. Log into the Unifi Network console
2. Navigate to **Settings → Networks**
3. For each **staff/admin/faculty VLAN**:
   - Set **DNS Server 1** to the Lightsail instance's **private VPN IP**
   - Set **DNS Server 2** to `1.1.1.1` (fallback if VPN is down)
4. Leave all **student VLANs** pointing to GoGuardian DNS — do not modify

---

## Monitoring

### Option A: Datadog

> Recommended only if your organization already has a Datadog contract. Agent licensing adds ~$15–23/month per host.

Install the Datadog Agent:

```bash
DD_API_KEY=<YOUR_API_KEY> DD_SITE="datadoghq.com" bash -c "$(curl -L https://install.datadoghq.com/scripts/install_script_agent7.sh)"
```

Enable the Unbound integration by adding to `/etc/datadog-agent/conf.d/unbound.d/conf.yaml`:

```yaml
instances:
  - host: 127.0.0.1
    port: 8953
```

Restart the agent:

```bash
sudo systemctl restart datadog-agent
```

---

### Option B: Netdata (Recommended)

Zero-cost, real-time monitoring with a built-in Unbound plugin. Recommended for single-node deployments.

```bash
wget -O /tmp/netdata-kickstart.sh https://my-netdata.io/kickstart.sh
sh /tmp/netdata-kickstart.sh
```

Netdata auto-detects Unbound if `unbound-control` is enabled. Access the dashboard at:

```
http://<LIGHTSAIL_PRIVATE_IP>:19999
```

> ⚠️ Lock port 19999 to your VPN CIDR in Lightsail's firewall. Do not expose Netdata publicly.

**Key metrics to watch:**
- `unbound.queries` — queries/sec (watch for spikes during testing events)
- `unbound.cache` — cache hit/miss ratio (target >60% after 24hrs of warm-up)
- `unbound.cache_prefetch` — prefetch activity
- System CPU and memory utilization

---

## Security

### Lightsail Firewall Rules

| Port | Protocol | Source | Purpose |
|---|---|---|---|
| 53 | UDP/TCP | VPN CIDR only | DNS queries |
| 22 | TCP | Your IP only | SSH management |
| 19999 | TCP | VPN CIDR only | Netdata dashboard |
| 8953 | TCP | 127.0.0.1 only | unbound-control |

> Never expose port 53 to `0.0.0.0/0`. An open DNS resolver will be abused for amplification attacks within hours.

### Additional Hardening

```bash
# Disable root SSH login
sudo sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config

# Enable UFW as a secondary firewall layer
sudo ufw allow from <VPN_CIDR> to any port 53
sudo ufw allow from <YOUR_IP> to any port 22
sudo ufw enable
```

---

## Cost Breakdown

| Resource | Cost/Month |
|---|---|
| Lightsail Instance ($5 plan) | $5.00 |
| Lightsail Static IP | $0.00 (free when attached) |
| Data Transfer (est.) | ~$0–2.00 |
| Netdata Monitoring | $0.00 |
| **Total** | **~$5–7/month** |

> Route 53 Resolver endpoints were evaluated and rejected due to ~$90/month minimum cost for a redundant pair, without the caching control this use case requires.

---

## GoGuardian Compatibility

This resolver is intentionally scoped to **non-student VLANs only**. GoGuardian's DNS-based filtering components expect to route through GoGuardian's infrastructure. Inserting an upstream caching resolver into the student DNS chain may break content filtering.

If you wish to extend DNS caching to student devices, contact GoGuardian support to confirm whether an upstream caching forwarder is supported in your deployment configuration before making any changes.

---

## Troubleshooting

**Unbound won't start:**
```bash
sudo unbound-checkconf         # Validate config syntax
sudo journalctl -u unbound -n 50  # View recent logs
```

**Queries not resolving from client:**
```bash
# Test from the Lightsail instance
dig @127.0.0.1 google.com

# Test from a client over the VPN
dig @<LIGHTSAIL_PRIVATE_IP> google.com
```

**Check cache hit stats:**
```bash
sudo unbound-control stats | grep cache
```

**VPN tunnel down — DNS fallback:**
Ensure your UDM Pro VLAN config has `1.1.1.1` as the secondary DNS so client devices don't lose resolution if the VPN drops.

---

## License

MIT License. See [LICENSE](LICENSE) for details.

---

*Designed for K-12 school network environments. Tested on Ubuntu 22.04 LTS / AWS Lightsail.*