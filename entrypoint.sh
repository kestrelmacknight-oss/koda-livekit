#!/bin/sh
# Entrypoint for LiveKit on Railway (TCP-only mode).
# Substitutes API key/secret from environment variables into the config,
# then configures iptables to forward TCP traffic for WebRTC ICE transport.

set -e

# Validate required environment variables
if [ -z "$LIVEKIT_API_KEY" ]; then
  echo "ERROR: LIVEKIT_API_KEY is not set"
  exit 1
fi

if [ -z "$LIVEKIT_API_SECRET" ]; then
  echo "ERROR: LIVEKIT_API_SECRET is not set"
  exit 1
fi

# Substitute credentials into config template
sed \
  -e "s/__API_KEY__/${LIVEKIT_API_KEY}/g" \
  -e "s/__API_SECRET__/${LIVEKIT_API_SECRET}/g" \
  /etc/livekit.yaml.template > /etc/livekit.yaml

echo "LiveKit config written"
echo "API Key: $LIVEKIT_API_KEY"

# Configure iptables for TCP port forwarding (Railway TCP proxy workaround)
# Railway exposes TCP on the PORT env var and forwards to our internal port
if command -v iptables > /dev/null 2>&1; then
  echo "Configuring iptables TCP forwarding..."
  iptables -t nat -A PREROUTING -p tcp --dport 7882 -j REDIRECT --to-port 7882 2>/dev/null || true
  echo "iptables configured"
else
  echo "iptables not available, using haproxy fallback if needed"
fi

# Get public IP for LiveKit (using wget which is available in the base image)
PUBLIC_IP=$(wget -qO- https://api.ipify.org 2>/dev/null || echo "")
if [ -n "$PUBLIC_IP" ]; then
  echo "Public IP detected: $PUBLIC_IP"
  # Append node_ip to config
  echo "node_ip: $PUBLIC_IP" >> /etc/livekit.yaml
fi

echo "Starting LiveKit server..."
exec /livekit-server --config /etc/livekit.yaml
