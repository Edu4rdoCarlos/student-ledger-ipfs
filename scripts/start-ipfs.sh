#!/bin/sh
set -e

# Create TLS certificates from environment variables
if [ -n "$IPFS_TLS_CA_CERT" ] && [ -n "$IPFS_TLS_SERVER_CERT" ] && [ -n "$IPFS_TLS_SERVER_KEY" ]; then
  echo "Creating TLS certificates..."
  mkdir -p /tmp/certs
  echo "$IPFS_TLS_CA_CERT" > /tmp/certs/ca-cert.pem
  echo "$IPFS_TLS_SERVER_CERT" > /tmp/certs/server-cert.pem
  echo "$IPFS_TLS_SERVER_KEY" > /tmp/certs/server-key.pem
  chmod 600 /tmp/certs/server-key.pem
  chmod 644 /tmp/certs/*.pem
else
  echo "WARNING: TLS variables not set, mTLS disabled"
fi

# Initialize IPFS on first run
if [ ! -f /data/ipfs/config ]; then
  echo "Initializing IPFS..."
  ipfs init --profile=server
  ipfs config Addresses.API /ip4/127.0.0.1/tcp/5001
  ipfs config --json Addresses.Gateway "null"
  ipfs config --json Gateway.NoFetch true
  ipfs config --json Addresses.Swarm '["/ip4/0.0.0.0/tcp/4001"]'
  ipfs config --json Discovery.MDNS.Enabled false
  ipfs config --json Swarm.DisableNatPortMap true
  ipfs config --json Swarm.RelayClient.Enabled false
  ipfs config --json Swarm.RelayService.Enabled false
  ipfs config --json AutoConf.Enabled false
  ipfs config --json Routing.Type '"none"'
  ipfs bootstrap rm --all
fi

# Check swarm.key for private network
if [ ! -f /data/ipfs/swarm.key ]; then
  echo "ERROR: swarm.key not found"
  exit 1
fi

# Start IPFS daemon
ipfs daemon --migrate=true --enable-gc &
IPFS_PID=$!
sleep 5

# Start mTLS proxy if certificates exist
if [ -f /tmp/certs/server-cert.pem ]; then
  echo "mTLS enabled on port 5443"
  socat OPENSSL-LISTEN:5443,cert=/tmp/certs/server-cert.pem,key=/tmp/certs/server-key.pem,cafile=/tmp/certs/ca-cert.pem,verify=1,fork,reuseaddr TCP:127.0.0.1:5001 &
  SOCAT_PID=$!
  wait $IPFS_PID $SOCAT_PID
else
  echo "mTLS disabled"
  wait $IPFS_PID
fi
