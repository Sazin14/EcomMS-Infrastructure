#!/usr/bin/env bash
# Creates one RabbitMQ user per service (run once, after "docker compose up -d"; safe to run again).
#   PRODUCT_PW=... INVENTORY_PW=... ORDER_PW=... NOTIFICATION_PW=... ./setup-users.sh
set -euo pipefail

: "${PRODUCT_PW:?set PRODUCT_PW}"
: "${INVENTORY_PW:?set INVENTORY_PW}"
: "${ORDER_PW:?set ORDER_PW}"
: "${NOTIFICATION_PW:?set NOTIFICATION_PW}"
C=ecom-rabbitmq
V=ecom

add_user() {   # name password
  docker exec $C rabbitmqctl add_user "$1" "$2" || docker exec $C rabbitmqctl change_password "$1" "$2"
}

add_user productservice      "$PRODUCT_PW"
add_user inventoryservice    "$INVENTORY_PW"
add_user orderservice        "$ORDER_PW"
add_user notificationservice "$NOTIFICATION_PW"

# Development: each service may do anything inside the "ecom" vhost (configure, write, read).
# Production: tighten the regexes per service, e.g. NotificationService only needs
#   configure '^(ecom\.events|ecom\.retry|notification\..*)$'  write '^(ecom\.retry|notification\..*)$'  read '^notification\..*$'
for u in productservice inventoryservice orderservice notificationservice; do
  docker exec $C rabbitmqctl set_permissions -p $V "$u" ".*" ".*" ".*"
done

echo "Users ready. Put them in each service's .env (RABBITMQ_USER / RABBITMQ_PASSWORD)."