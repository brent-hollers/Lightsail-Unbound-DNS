#!/bin/bash
apt-get update -y
apt-get upgrade -y

systemctl stop systemd-resolved
echo "nameserver 1.1.1.1" > /etc/resolv.conf
PRIVATE_IP=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)
echo "$${PRIVATE_IP} $${HOSTNAME}" >> /etc/hosts

apt-get install -y unbound

cat > /etc/unbound/unbound.conf <<UNBOUND
server:
    interface: 0.0.0.0
    port: 53
    do-ip4: yes
    do-ip6: no
    do-tcp: yes
    do-udp: yes

    access-control: 127.0.0.0/8 allow
    access-control: 10.21.0.0/16 allow
    access-control: 10.21.0.0/16 allow
    access-control: 0.0.0.0/0 refuse

    cache-min-ttl: 300
    cache-max-ttl: 86400
    msg-cache-size: 64m
    rrset-cache-size: 128m

    prefetch: yes
    prefetch-key: yes

    num-threads: 2
    so-rcvbuf: 1m

    auto-trust-anchor-file: "/var/lib/unbound/root.key"

    hide-identity: yes
    hide-version: yes

    verbosity: 1
    log-queries: no
    tls-cert-bundle: "/etc/ssl/certs/ca-certificates.crt"

forward-zone:
    name: "."
    forward-addr: 1.1.1.1@853#cloudflare-dns.com
    forward-addr: 8.8.8.8@853#dns.google
    forward-tls-upstream: yes
UNBOUND

systemctl enable unbound
systemctl restart unbound

DD_API_KEY=${datadog_api_key} \
DD_SITE="us5.datadoghq.com" \
bash -c "$(curl -L https://install.datadoghq.com/scripts/install_script_agent7.sh)"

