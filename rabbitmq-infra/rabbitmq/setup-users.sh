#!/usr/bin/env bash
# Creates one RabbitMQ user per service (run once, after "docker compose up -d").
#   PRODUCT_PW=... INVENTORY_PW=... ./setup-users.sh
set -euo pipefail

: "${PRODUCT_PW:?set PRODUCT_PW}"
: "${INVENTORY_PW:?set INVENTORY_PW}"
C=ecom-rabbitmq
V=ecom

docker exec $C rabbitmqctl add_user productservice   "$PRODUCT_PW"   || docker exec $C rabbitmqctl change_password productservice   "$PRODUCT_PW"
docker exec $C rabbitmqctl add_user inventoryservice "$INVENTORY_PW" || docker exec $C rabbitmqctl change_password inventoryservice "$INVENTORY_PW"

# Development: each service may do anything inside the "ecom" vhost (configure, write, read).
# Production: tighten the regexes, e.g. for ProductService
#   configure '^(ecom\.events|ecom\.retry|debug\.catalog)$'  write '^(ecom\.events|debug\.catalog)$'  read '^debug\.catalog$'
docker exec $C rabbitmqctl set_permissions -p $V productservice   ".*" ".*" ".*"
docker exec $C rabbitmqctl set_permissions -p $V inventoryservice ".*" ".*" ".*"

echo "Users ready. Put them in each service's .env (RABBITMQ_USER / RABBITMQ_PASSWORD)."
