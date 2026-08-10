#!/bin/bash


CONNECT_URL="http://localhost:8083"
CONNECTOR_NAME="postgres-fines-connector"

echo "Waiting for Kafka Connect to be ready..."
until curl -sf "$CONNECT_URL/connectors" > /dev/null 2>&1; do
  echo "  Connect not ready yet, retrying in 5s..."
  sleep 5
done
echo "Kafka Connect is ready!"

echo "Registering connector: $CONNECTOR_NAME"
curl -s -X PUT \
  "$CONNECT_URL/connectors/$CONNECTOR_NAME/config" \
  -H "Content-Type: application/json" \
  -d @"$(dirname "$0")/connector.json" \
  | python3 -m json.tool 2>/dev/null || cat

echo ""
echo "Checking connector status..."
sleep 3
curl -s "$CONNECT_URL/connectors/$CONNECTOR_NAME/status" \
  | python3 -m json.tool 2>/dev/null || cat