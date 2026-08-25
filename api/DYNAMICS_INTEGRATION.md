# Microsoft Dynamics 365 Integration Plan

This document describes the plan for integrating the DeHeus field sales application with
Microsoft Dynamics 365 via the Dataverse Web API (outbound sync) and inbound webhooks
(Azure Event Grid / Power Automate).

## Architecture

```
┌─────────────┐     ┌──────────────────┐     ┌────────────────────┐
│  Flutter    │────│  Supabase        │     │  Dynamics 365      │
│  App (lib/) │     │  (PostgreSQL)   │     │  Web API / Dataverse│
└─────────────┘     └──────────┬───────┘     └─────────┬──────────┘
                              │                         │
                       ┌──────┴──────┐                 │
                       │  Node.js    │                 │
                       │  Express API│                 │
                       │  (api/)     │◄── Webhook ────┘
                       └─────────────┘
```

Two integration flows:

1. **Outbound API (Push)** — The Node.js Express API reads records from the
   Supabase database and pushes them into Dynamics 365 via the Dataverse REST API.
2. **Inbound Webhooks (Pull/Push)** — Dynamics sends change notifications via
   Azure Event Grid / webhooks to an Express endpoint, which reconciles local
   Supabase data.

## Data Mapping (Supabase ↔ Dynamics)

| Supabase Table                       | Dynamics Entity                          | Notes                                                              |
|--------------------------------------|------------------------------------------|--------------------------------------------------------------------|
| `schools`                            | `account`                                | School → Account; `dealer_type`, `county` → address fields         |
| `users`                              | `systemuser` / `contact`                 | Agents/supervisors → systemuser                                    |
| `orders`                             | `salesorder`                             | `school_id` → `customerid`; `agent_id` → `parentsystemusername`  |
| `order_items`                        | `salesorderline`                         | Map `product_name`, `sku`, `quantity`, `unit_price` → line fields  |
| `catalog_items`                      | `product`                                | Books → Products; `sku` → `productnumber`; `unit_price` → `price`  |
| `school_sales`                       | `opportunity`                            | `sale_status` → `statecode`/`opportunitystatuscode` (pipeline)     |
| `school_visits`                      | `appointment`                            | Visit records → appointments linked to account                     |
| `school_sample_distributions`        | `salesorder` / `quote` (samples)         | Sample tracking                                                    |
| `tasks`                              | `task` / `activitypointer`               | Map `target_role`, `assigned_to`, `due_at`, `status`               |
| `regions`                            | `territory` (or custom `new_region`)     | Territory management                                              |
| `targets`                            | `goal`                                   | Performance targets → goals                                       |
| `messages`                           | `email`                                  | Messaging → email activities                                    |
| `debt_collections`                   | `payment` / `msdyn_bookings`             | Payments/receipts                                                 |

## 1. Outbound API Integration (Push to Dynamics)

The sync logic lives in the Express API. New modules:

- `api/lib/dynamics/auth.js` — Azure AD service-principal token acquisition with caching.
- `api/lib/dynamics/client.js` — Dataverse Web API HTTP wrapper (GET/POST/PATCH) with retry + backoff.
- `api/routes/dynamics.js` — REST endpoints that trigger sync for individual entities.

### Authentication

Dynamics 365 / Dataverse supports service-principal (app-only) auth via Azure AD OAuth 2.0
client-credentials flow. The Express API requests a bearer token from
`https://login.microsoftonline.com/{tenant}/oauth2/v2.0/token` and caches it for one hour.

### Dataverse REST API

| Operation              | Method | Endpoint                                          |
|------------------------|--------|---------------------------------------------------|
| Create Account         | POST   | `/api/data/v9.2/accounts`                         |
| Upsert Account         | PATCH  | `/api/data/v9.2/accounts(accountnumber='{id}')`   |
| Create System User     | POST   | `/api/data/v9.2/systemusers`                      |
| Create Sales Order     | POST   | `/api/data/v9.2/salesorders`                      |
| Create Order Line      | POST   | `/api/data/v9.2/salesorderdetails`                |
| Create Opportunity     | POST   | `/api/data/v9.2/opportunities`                    |
| Create Product         | POST   | `/api/data/v9.2/products`                         |
| Upsert Product         | PATCH  | `/api/data/v9.2/products(productnumber='{sku}')`  |
| Create Task            | POST   | `/api/data/v9.2/tasks`                            |

### Sync Endpoints (Express routes)

All `POST` endpoints return `{ success, dynamicsId?, message }` and are idempotent
(upsert by external ID prevents duplicates).

| Endpoint                              | Description                                  |
|---------------------------------------|----------------------------------------------|
| `POST /api/dynamics/sync/school/:id`    | Upsert school → Dynamics account             |
| `POST /api/dynamics/sync/order/:id`     | Upsert order + order_items → salesorder      |
| `POST /api/dynamics/sync/sale/:id`      | Upsert school_sales → opportunity            |
| `POST /api/dynamics/sync/catalog/:sku`  | Upsert catalog_item → product                |
| `POST /api/dynamics/sync/user/:id`      | Upsert user → systemuser                     |

### Conflict & Idempotency

- Use `externalid` fields in Dynamics (`accountnumber`, `productnumber`) for
  upsert-by-key.
- Add to Supabase tables: `dynamics_id` (Dynamics record GUID),
  `dynamics_sync_status` enum (`pending`, `synced`, `failed`, `conflict`).
- Use batch requests (`POST /api/data/v9.2/$batch`) for bulk operations.
- Retry with exponential backoff on 429 / 5xx responses.

## 2. Inbound Webhook Integration (Dynamics → App)

### Webhook Registration

- Register a webhook endpoint in **Dynamics 365** via **Azure Event Grid**
  or **Power Automate** → HTTP action.
- Subscribed events:
  - `salesorder` — `updated` (status changes)
  - `salesorderdetail` — `updated`
  - `account` — `updated` (credit hold, contact info)
  - `product` — `updated` (price, stock)
  - `opportunity` — `updated` (pipeline stage)
  - `task` — `created` / `updated`

### Webhook Receiver

Add this route to `api/index.js`:

```js
app.post('/webhook/dynamics', express.raw({ type: 'application/json' }), async (req, res) => {
  // 1. Verify HMAC-SHA256 signature
  // 2. Parse notification payload
  // 3. Map Dynamics entity → Supabase table
  // 4. Upsert into Supabase
  // 5. Respond 200 OK within 10s
  res.status(200).send('OK');
});
```

### Webhook Payload Handling

| Dynamics Entity     | Supabase Table          | Action                        |
|---------------------|-------------------------|-------------------------------|
| `salesorder` (status) | `orders`               | PATCH `status`, `approved_at` |
| `account`           | `schools`               | PATCH customer fields         |
| `product`           | `catalog_items`         | PATCH `unit_price`, `stock_qty`|
| `opportunity`       | `school_sales`          | PATCH `sale_status`           |
| `task`              | `tasks`                 | INSERT / UPDATE               |

Webhook updates can hit Supabase directly using the Supabase JS client
(`@supabase/supabase-js`) with a service_role key, or via direct MySQL/SQL updates
if the webhook handler connects to the `longhorn` MySQL database.

## 3. Implementation Phases

| Phase    | Task                                    | Files to Create / Modify                                          |
|----------|-----------------------------------------|-------------------------------------------------------------------|
| Phase 0  | Dynamics auth client                    | `api/lib/dynamics/auth.js`, `api/lib/dynamics/client.js`          |
| Phase 1  | Env config                            | `api/.env`, `api/.env.example`                                    |
| Phase 2  | Outbound sync endpoints                 | `api/routes/dynamics.js`                                          |
| Phase 3  | Schema migration                        | `supabase/schema_updates_dynamics.sql`                          |
| Phase 3  | Webhook receiver                      | `api/index.js` (extend)                                           |
| Phase 3  | Scheduling / triggers                 | `lib/features/background/`, `api/index.js`                        |
| Phase 3  | Flutter integration hooks             | `lib/services/dynamics_sync_service.dart`, `lib/features/dashboard/add_order_page.dart` |

### Environment Variables (`.env`)

```
# Existing
PORT=3000
DB_HOST=localhost
DB_USER=root
DB_PASSWORD=3577
DB_NAME=longhorn

# Dynamics 365 (new)
DYNAMICS_CLIENT_ID=your-app-client-id
DYNAMICS_CLIENT_SECRET=your-app-client-secret
DYNAMICS_TENANT_ID=your-azure-tenant-id
DYNAMICS_DATAVERSE_URL=https://yourorg.api.crm.dynamics.com
DYNAMICS_WEBHOOK_SECRET=your-shared-webhook-secret
DYNAMICS_ENVIRONMENT_ID=your-environment-id
```

## 4. Flutter App Integration

The Flutter app uses `package:http: ^1.1.0` (see `pubspec.yaml:43`). The new
Dynamics sync service calls the Express API, keeping all credentials server-side.

New service: `lib/services/dynamics_sync_service.dart` — triggered on order save,
catalog import, and school sale update.

Key hooks:
- `lib/features/dashboard/add_order_page.dart:431` — after `createOrder`, call
  `/api/dynamics/sync/order/{orderId}`.
- `lib/features/admin/catalog_import_page.dart` — after import, call
  `/api/dynamics/sync/catalog/{sku}` for each item.
- `lib/features/dashboard/school_sell_page.dart` — after saving a school sale,
  trigger `/api/dynamics/sync/sale/{saleId}`.

Sync status is surfaced in the UI via the `dynamics_sync_status` column on the
relevant model.

## 5. Security Considerations

1. **Secrets** — All Dynamics credentials in `api/.env` (gitignored). Never commit.
2. **Webhook verification** — HMAC-SHA256 with shared secret (`DYNAMICS_WEBHOOK_SECRET`).
   Reject unsigned requests.
3. **RLS compliance** — If writing to Supabase from the webhook handler, use a
   `service_role` key (server-side only) or restricted DB user.
4. **Idempotency** — Webhook replay protection via idempotent upsert-by-external-id.
5. **Rate limiting** — Dataverse enforces API limits. Use batch requests and
   exponential backoff for retries.
6. **Error isolation** — Webhook failures for one entity type must not block
   others. Return HTTP 200 quickly and queue processing asynchronously.

## Resources

- [Dataverse Web API overview — Microsoft Learn](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/webapi/about)
- [Authenticate to Dataverse using service principal](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/authentication-azure-ad)
- [Dataverse webhooks & Azure Event Grid](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/webhooks)
- [Dataverse batch requests](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/webapi/execute-batch-operations)
