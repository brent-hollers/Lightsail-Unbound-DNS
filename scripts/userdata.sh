user_data = <<-EOF
  #!/bin/bash
  apt-get update -y
  apt-get upgrade -y
  apt-get install -y unbound

  cat > /etc/unbound/unbound.conf <<-UNBOUND
  server:
      interface: 0.0.0.0
      port: 53
      do-ip4: yes
      do-ip6: no
      do-tcp: yes
      do-udp: yes

      access-control: 127.0.0.0/8 allow
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

  forward-zone:
      name: "."
      forward-addr: 1.1.1.1@853#cloudflare-dns.com
      forward-addr: 8.8.8.8@853#dns.google
      forward-tls-upstream: yes
  UNBOUND

  systemctl enable unbound
  systemctl restart unbound
  
    DD_API_KEY= ${datadog_api_key}\
    DD_SITE="us5.datadoghq.com" \
    DD_APM_INSTRUMENTATION_ENABLED=host \
    DD_ENV=prod \
    DD_APM_INSTRUMENTATION_LIBRARIES=java:1,python:4,js:5,php:1,dotnet:3,ruby:2 \
    DD_RUM_ENABLED=true \
    DD_RUM_APPLICATION_ID=15c3ba00-1da3-4832-81ea-a2216d1f2561 \
    DD_RUM_CLIENT_TOKEN=pub628f90b6045fe9ca912612173efac0ec \
    DD_RUM_REMOTE_CONFIGURATION_ID=cacd3b22-913c-4cca-8894-e2c69fb2f25d \
    DD_RUM_SITE=us5.datadoghq.com \
    bash -c "$(curl -L https://install.datadoghq.com/scripts/install_script_agent7.sh)"

EOF