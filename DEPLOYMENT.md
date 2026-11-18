# Processes every service needs

The HTTP container alone is NOT enough: events only move when the outbox publisher and the consumers run,
and holds / unpaid orders only expire when the scheduler runs. Run each line below exactly once per service
(consumers and outbox publishers may run more than once; the scheduler must run ONCE).

| Service | HTTP | Outbox publisher | Consumers | Scheduler | Other |
|---|---|---|---|---|---|
| AuthService | `php-fpm` (+ `APIGateway/fpm-sidecar`) | - | - | - | - |
| ProductService | `php-fpm` (+ fpm-sidecar) | `php artisan outbox:publish` | - | `php artisan schedule:work` | - |
| InventoryService | image default (`api`) | included | included | included | - |
| OrderService | `php-fpm` (+ fpm-sidecar) | `php artisan outbox:publish` | `php artisan rabbitmq:consume order.inventory` | `php artisan schedule:work` | - |
| NotificationService | image default (`api`) | (none, consumes only) | included | included | e-mail worker included |

## Containers

- **ProductService / OrderService** images have no entrypoint, so the same image runs a worker when you give it
  the command, e.g. `docker run <order-image> php artisan outbox:publish`,
  `docker run <order-image> php artisan rabbitmq:consume order.inventory`, `docker run <order-image> php artisan schedule:work`.
  Without these, ProductService never tells Inventory about new variants and OrderService never tells Inventory /
  Notification anything (orders would never be confirmed, shipped or released in Inventory).
- **InventoryService / NotificationService** images start php-fpm, nginx AND every worker under Supervisor (`api` mode).
  When you run more than one replica, set `RUN_WORKERS=false` on the extra ones (API only), otherwise every replica
  also runs the scheduler. Workers can also be run as their own containers:
  Inventory `php artisan rabbitmq:consume inventory.catalog|inventory.orders`, `php artisan outbox:publish`,
  `php artisan schedule:work`; Notification `worker` / `queue` / `scheduler` (see its docker/entrypoint.sh).

## Before the first start / after every deploy

```bash
php artisan migrate --force          # every service (no image runs it on start)
php artisan rabbitmq:setup           # once per environment: exchanges + queues (safe to repeat)
php artisan db:seed --class=StaffRolePermissionSeeder   # AuthService: roles / permissions (safe to repeat)
```

## Redis

All services can share one Redis. Each service has its own `REDIS_PREFIX` / `CACHE_PREFIX` (queues, cache, locks
never collide); the staff authorization cache `authz:staff:{id}` uses the `authz` connection with the shared
prefix `REDIS_AUTHZ_PREFIX` (default `ecom-authz:`), which must be the same everywhere.
For bare-metal Supervisor configs see `rabbitmq-infra/*.conf` and `rabbitmq-infra/supervisor/*.conf`.
