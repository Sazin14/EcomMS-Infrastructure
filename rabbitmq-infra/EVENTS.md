# Event contract (the same in both services)

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
| `catalog.variant.upserted` | ProductService | InventoryService (`inventory.catalog`) | variant_id, product_id, sku, product_name, variant_label, allow_preorder |
| `catalog.variant.deleted` | ProductService | InventoryService (`inventory.catalog`) | variant_id, sku |
| `inventory.stock.out` | InventoryService | nobody yet | variant_id, sku |
| `inventory.stock.low` | InventoryService | nobody yet | variant_id, sku, warehouse, available, reorder_level |
| `inventory.preorder.allocated` | InventoryService | nobody yet (Order service later) | reference, variant_id, sku, quantity, reservation_id |

Rules for changing it: add fields freely; never rename or remove one without bumping `version` and
supporting both for a while. Consumers must ignore event types and fields they do not know.

Queues of InventoryService: `inventory.catalog` (main) -> on failure `ecom.retry` -> `inventory.catalog.retry`
(waits 30 s, then back) -> after 5 failures `inventory.catalog.dlq` (parked for a human).
