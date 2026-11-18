# Event contract (the same in every service)

Exchange `ecom.events` (topic, durable). Every message is JSON, persistent, with this envelope:

```json
{
  "id": "0b3f...uuid",                      // unique per event; consumers ignore ids they have seen
  "type": "catalog.variant.upserted",       // = the routing key
  "version": 1,
  "occurred_at": "2026-10-12T10:15:30.123456Z",
  "producer": "product-service",
  "data": { }
}
```

| Routing key | Published by | Consumed by (queue) | `data` |
|---|---|---|---|
| `catalog.variant.upserted` | ProductService | InventoryService (`inventory.catalog`) | variant_id, product_id, sku, product_name, variant_label, allow_preorder, initial_stock (new variants only) |
| `catalog.variant.deleted` | ProductService | InventoryService (`inventory.catalog`) | variant_id, sku |
| `order.placed` `order.confirmed` `order.shipped` `order.delivered` `order.delivery_failed` `order.cancelled` `order.preorder_ready` | OrderService | NotificationService (`notification.order`); `order.confirmed` / `order.cancelled` / `order.shipped` also InventoryService (`inventory.orders`) | order block: order_number, type, status, payment_method, payment_status, currency, totals, customer {id, name, email, phone, locale}, shipping, items[]; plus reason / carrier + tracking_number / pay_before |
| `payment.paid` `payment.failed` | OrderService | NotificationService (`notification.order`) | order block + reference / reason |
| `return.requested` | OrderService | NotificationService (`notification.order`) | order block + return_number, reason, items[] |
| `return.received` | OrderService | InventoryService (`inventory.orders`), NotificationService | order block + return_number, reason, items[] {variant_id, quantity, condition} |
| `refund.processed` | OrderService | NotificationService (`notification.order`) | order block + amount, method, reference |
| `inventory.reservation.expired` | InventoryService | OrderService (`order.inventory`) | reference (= order number), reservation_id |
| `inventory.preorder.allocated` | InventoryService | OrderService (`order.inventory`) | reference (= order number), variant_id, sku, quantity, reservation_id |
| `inventory.order.rejected` | InventoryService | OrderService (`order.inventory`) | order_number, event, reason |
| `inventory.stock.low` | InventoryService | NotificationService (`notification.inventory`) | variant_id, sku, warehouse, available, reorder_level |
| `inventory.stock.out` | InventoryService | NotificationService (`notification.inventory`) | variant_id, sku |

Every event is also copied to `events.audit` (7 days), so nothing is ever unroutable and there is a replay source.

Rules for changing it: add fields freely; never rename or remove one without bumping `version` and
supporting both for a while. Consumers must ignore event types and fields they do not know.

Every consumer queue `<queue>` -> on failure `ecom.retry` -> `<queue>.retry` (waits 30 s, then back)
-> after 5 failures `<queue>.dlq` (parked for a human: `php artisan rabbitmq:dlq`).
