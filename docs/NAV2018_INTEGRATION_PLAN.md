# Dynamics NAV 2018 Integration — Full Implementation Plan

## Goal

Import **existing data from Dynamics NAV 2018 into Supabase** so the Flutter app can read it.
Keep the Flutter app unchanged — it continues reading directly from Supabase.

## Architecture

```
┌─────────────┐     ┌──────────────────┐     ┌──────────────────────┐
│  Flutter    │────│  Supabase        │     │  Dynamics NAV 2018   │
│  App (lib/) │     │  (PostgreSQL)   │     │  OData Web Services  │
└─────────────┘     └──────────────────┘     └──────────┬───────────┘
                                                         │
                                                ┌────────┴────────┐
                                                │  Node.js API    │
                                                │  (api/)         │
                                                │  One-time sync  │
                                                │  + future hooks │
                                                └─────────────────┘
```

**Data flows one way:** NAV 2018 → Node.js API → Supabase → Flutter app.

No webhooks. No bidirectional sync. No Azure AD. No Dataverse.

## Prerequisites (NAV 2018 Admin Work)

Before writing code, these must be configured in NAV 2018:

### 1. Enable OData Web Services

- Open **Microsoft Dynamics NAV Administration Shell** (as Administrator)
- Set OData services enabled on the server instance:
  ```powershell
  Set-NAVServerConfiguration -ServerInstance NAV2018 -KeyName "ODataServicesEnabled" -KeyValue true
  Restart-NAVServerInstance -ServerInstance NAV2018
  ```
- Or enable via **Microsoft Dynamics NAV Server Administration** tool:
  - Edit instance → **OData Services** tab → check **Enabled**

### 2. Publish Standard API Pages

In NAV 2018 client, go to **Web Services** page and publish:

| Page | Entity Name | Purpose |
|------|-------------|---------|
| 5470 | `customers` | Schools/accounts |
| 5471 | `items` | Books/products |
| 5474 | `salesOrders` | Orders, quotations, and consignments |
| 5475 | `salesInvoiceLines` | Order lines |
| 5476 | `opportunities` | Pipeline/sales |
| 5477 | `resources` | Users/salespeople |
| 5478 | `contacts` | Contact persons |

### 2a. (If needed) Publish Custom Consignment API

If your NAV instance tracks consignments via a custom table or a separate API page:

1. In NAV, find the custom page/table used for consignments
2. Publish it as a web service (e.g., `consignments`)
3. Note the entity name and field structure

If consignments are just `salesOrders` with a specific status or custom flag, no extra page is needed — the existing `salesOrders` API covers it.

For each:
1. Search for **Web Services** page in NAV
2. Click **New**
3. Set **Object Type** = `Page`
4. Set **Object ID** = page number above
5. Set **Service Name** = entity name above (lowercase)
6. Check **Published** = Yes

### 3. Create NAV Web Service User

- Create a Windows user in NAV (or use existing service account)
- Set **Web Service Access Key** (generate a random strong password)
- Assign appropriate **Permission Sets** (e.g., `SUPER` for initial import, or granular sets per entity)
- Note the **Server Name**, **Instance Name**, **Port** (default 7048), **Company Name**, **Username**, and **Web Service Access Key**

### 4. Test from Postman / Browser

```bash
curl -u "NAV_USER:WEB_ACCESS_KEY" \
  "http://nav-server:7048/NAV2018/api/beta/companies?%24top=5"
```

If this returns JSON company data, NAV is ready.

## Data Mapping: NAV 2018 → Supabase

| NAV Entity | Supabase Table | NAV Fields → Supabase Columns |
|------------|---------------|-------------------------------|
| `customers` | `schools` | `number` → `id`, `name` → `name`, `address` → `address`, `city` → `city`, `county` → `county`, `contact` → `contact_person`, `phone` → `phone`, `email` → `email` |
| `items` | `catalog_items` | `number` → `sku`, `displayName` → `product_name`, `unitPrice` → `unit_price`, `description` → `description`, `itemCategory` → `category` |
| `salesOrders` | `orders` | `number` → `order_number`, `customerNumber` → `school_id`, `sellingPostalAddress` → `delivery_address`, `totalAmountIncludingTax` → `total_amount`, `orderDate` → `order_date`, `status` → `status` |
| `salesInvoiceLines` | `order_items` | `documentNumber` → `order_id`, `lineNumber` → `id`, `itemNumber` → `sku`, `description` → `product_name`, `quantity` → `quantity`, `unitPrice` → `unit_price` |
| `opportunities` | `school_sales` | `number` → `id`, `contactNumber` → `school_id`, `description` → `notes`, `probability` → `probability`, `status` → `sale_status`, `estimatedClosingDate` → `estimated_close_date` |
| `resources` | `users` | `number` → `employee_id`, `displayName` → `full_name`, `jobTitle` → `role`, `email` → `email`, `phone` → `phone` |
| `salesOrders` (documentType = Quote) | `school_sales` | `number` → `quotation_reference`, `customerNumber` → `school_id`, `sellingPostalAddress` → `delivery_address`, `totalAmountIncludingTax` → `expected_value`, `orderDate` → `stage_updated_at`, `status` → `sale_status = 'quotation_sent'` |
| `salesOrders` (consignment flag) | `orders` | `number` → `order_number`, `customerNumber` → `school_id`, `totalAmountIncludingTax` → `checkout_amount`, `orderDate` → `order_date`, `status` → `status` |

**Note on consignments:** NAV 2018 has no native "consignment" entity. Consignments are typically regular `salesOrders` marked by:
- A custom field/status in your NAV instance (e.g., `documentType` = "Consignment" or a custom flag)
- A specific `status` value (check your NAV customization)
- A separate custom API page if your NAV partner built one

Verify with your NAV admin which field/entity identifies consignments in your instance.

**Note on quotations:** NAV 2018 stores quotations as `salesOrders` with `documentType` = Quote. The Flutter app represents quotations as pipeline stages (`quotation_sent`) on `school_sales`, not as a separate table. The sync maps NAV quotes to `school_sales` records so they appear in the pipeline.

**Note:** NAV entity field names may differ based on your NAV 2018 customization. Always verify against your NAV instance's `$metadata` endpoint.

## Phase 0: Schema Migration (Supabase)

Create `supabase/schema_updates_nav2018.sql`:

```sql
-- Add Dynamics tracking columns to key tables

ALTER TABLE schools ADD COLUMN IF NOT EXISTS nav_id TEXT, ADD COLUMN IF NOT EXISTS nav_sync_status TEXT DEFAULT 'pending';
ALTER TABLE catalog_items ADD COLUMN IF NOT EXISTS nav_id TEXT, ADD COLUMN IF NOT EXISTS nav_sync_status TEXT DEFAULT 'pending';
ALTER TABLE users ADD COLUMN IF NOT EXISTS nav_id TEXT, ADD COLUMN IF NOT EXISTS nav_sync_status TEXT DEFAULT 'pending';
ALTER TABLE orders ADD COLUMN IF NOT EXISTS nav_id TEXT, ADD COLUMN IF NOT EXISTS nav_sync_status TEXT DEFAULT 'pending';
ALTER TABLE orders ADD COLUMN IF NOT EXISTS order_type TEXT DEFAULT 'order';
ALTER TABLE order_items ADD COLUMN IF NOT EXISTS nav_id TEXT, ADD COLUMN IF NOT EXISTS nav_sync_status TEXT DEFAULT 'pending';
ALTER TABLE school_sales ADD COLUMN IF NOT EXISTS nav_id TEXT, ADD COLUMN IF NOT EXISTS nav_sync_status TEXT DEFAULT 'pending';
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS nav_id TEXT, ADD COLUMN IF NOT EXISTS nav_sync_status TEXT DEFAULT 'pending';

-- Add indexes for fast upserts
CREATE INDEX IF NOT EXISTS idx_schools_nav_id ON schools(nav_id);
CREATE INDEX IF NOT EXISTS idx_catalog_items_nav_id ON catalog_items(nav_id);
CREATE INDEX IF NOT EXISTS idx_users_nav_id ON users(nav_id);
CREATE INDEX IF NOT EXISTS idx_orders_nav_id ON orders(nav_id);
CREATE INDEX IF NOT EXISTS idx_order_items_nav_id ON order_items(nav_id);
CREATE INDEX IF NOT EXISTS idx_school_sales_nav_id ON school_sales(nav_id);
CREATE INDEX IF NOT EXISTS idx_tasks_nav_id ON tasks(nav_id);
CREATE INDEX IF NOT EXISTS idx_orders_order_type ON orders(order_type);
```

Run it:
```bash
supabase db push   # or apply via Supabase SQL Editor
```

## Phase 1: API Dependencies

Update `api/package.json`:
```json
{
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "dotenv": "^16.3.1",
    "@supabase/supabase-js": "^2.49.1",
    "axios": "^1.6.0",
    "xml2js": "^0.6.2"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  }
}
```

Run: `cd api && npm install`

## Phase 2: Environment Configuration

Update `api/.env`:
```env
# Server
PORT=3000

# Supabase
SUPABASE_URL=https://nlikgeqoocimbbqyaegq.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key_here

# NAV 2018
NAV_SERVER_URL=http://your-nav-server:7048
NAV_INSTANCE=NAV2018
NAV_COMPANY_ID=guid-of-your-company
NAV_USERNAME=NAV_API_USER
NAV_WEB_ACCESS_KEY=your_web_access_key_here
```

Update `api/.env.example` with the same keys (no secrets).

## Phase 3: NAV Client Module

Create `api/lib/nav/client.js`:

```js
const axios = require('axios');
const { default: PQueue } = require('p-queue');

const {
  NAV_SERVER_URL,
  NAV_INSTANCE,
  NAV_COMPANY_ID,
  NAV_USERNAME,
  NAV_WEB_ACCESS_KEY
} = process.env;

const BASE_URL = `${NAV_SERVER_URL}/${NAV_INSTANCE}/api/beta/companies(${NAV_COMPANY_ID})`;
const AUTH = Buffer.from(`${NAV_USERNAME}:${NAV_WEB_ACCESS_KEY}`).toString('base64');

const queue = new PQueue({ concurrency: 2, interval: 500, intervalCap: 2 });

async function navGet(entity, params = {}) {
  const qs = new URLSearchParams({ '$top': 500, ...params });
  const { data } = await queue.add(() =>
    axios.get(`${BASE_URL}/${entity}?${qs}`, {
      headers: { Authorization: `Basic ${AUTH}` },
      timeout: 30000
    })
  );
  return data.value || [];
}

async function navGetAll(entity) {
  const results = [];
  let skip = 0;
  const top = 500;
  while (true) {
    const batch = await navGet(entity, { '$top': top, '$skip': skip, '$skiptoken': undefined });
    results.push(...batch);
    if (batch.length < top) break;
    skip += top;
  }
  return results;
}

module.exports = { navGet, navGetAll };
```

Install queue dependency:
```bash
npm install p-queue
```

## Phase 4: Supabase Client Module

Create `api/lib/supabase/client.js`:

```js
const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

async function upsertByNavId(table, navRecords, mapping) {
  for (const navRec of navRecords) {
    const supabaseRow = mapping(navRec);
    if (!supabaseRow.nav_id) continue;

    const { error } = await supabase
      .from(table)
      .upsert(supabaseRow, { onConflict: 'nav_id' });

    if (error) {
      console.error(`Failed to upsert ${table} nav_id=${supabaseRow.nav_id}:`, error.message);
    }
  }
}

module.exports = { supabase, upsertByNavId };
```

## Phase 5: Mapping Functions

Create `api/lib/nav/mappings.js`:

```js
function mapCustomerToSchool(c) {
  return {
    nav_id: c.id || c.number,
    nav_sync_status: 'synced',
    name: c.name,
    address: c.address,
    city: c.city,
    county: c.county,
    contact_person: c.contact,
    phone: c.phone,
    email: c.email,
    updated_at: new Date().toISOString()
  };
}

function mapItemToCatalog(i) {
  return {
    nav_id: i.id || i.number,
    nav_sync_status: 'synced',
    sku: i.number,
    product_name: i.displayName,
    unit_price: i.unitPrice,
    description: i.description,
    category: i.itemCategory,
    updated_at: new Date().toISOString()
  };
}

function mapSalesOrderToOrder(o) {
  return {
    nav_id: o.id || o.number,
    nav_sync_status: 'synced',
    order_number: o.number,
    school_id: o.customerNumber,
    delivery_address: o.sellingPostalAddress,
    total_amount: o.totalAmountIncludingTax,
    order_date: o.orderDate,
    status: o.status,
    order_type: o.documentType === 'Quote' ? 'quotation' : (o.orderType === 'Consignment' ? 'consignment' : 'order'),
    updated_at: new Date().toISOString()
  };
}

function mapQuoteToSchoolSale(q) {
  return {
    nav_id: q.id || q.number,
    nav_sync_status: 'synced',
    school_id: q.customerNumber,
    sale_status: 'quotation_sent',
    quotation_reference: q.number,
    expected_value: q.totalAmountIncludingTax,
    notes: q.description,
    stage_updated_at: q.orderDate,
    updated_at: new Date().toISOString()
  };
}

function mapConsignmentToOrder(c) {
  return {
    nav_id: c.id || c.number,
    nav_sync_status: 'synced',
    order_number: c.number,
    school_id: c.customerNumber,
    delivery_address: c.sellingPostalAddress,
    checkout_amount: c.totalAmountIncludingTax,
    order_date: c.orderDate,
    status: c.status,
    order_type: 'consignment',
    updated_at: new Date().toISOString()
  };
}

function mapSalesInvoiceLineToOrderItem(li) {
  return {
    nav_id: li.id || `${li.documentNumber}-${li.lineNumber}`,
    nav_sync_status: 'synced',
    order_id: li.documentNumber,
    sku: li.itemNumber,
    product_name: li.description,
    quantity: li.quantity,
    unit_price: li.unitPrice,
    updated_at: new Date().toISOString()
  };
}

function mapOpportunityToSale(op) {
  return {
    nav_id: op.id || op.number,
    nav_sync_status: 'synced',
    sale_status: op.status,
    notes: op.description,
    probability: op.probability,
    estimated_close_date: op.estimatedClosingDate,
    updated_at: new Date().toISOString()
  };
}

function mapResourceToUser(r) {
  return {
    nav_id: r.id || r.number,
    nav_sync_status: 'synced',
    employee_id: r.number,
    full_name: r.displayName,
    role: r.jobTitle,
    email: r.email,
    phone: r.phone,
    updated_at: new Date().toISOString()
  };
}

module.exports = {
  mapCustomerToSchool,
  mapItemToCatalog,
  mapSalesOrderToOrder,
  mapSalesInvoiceLineToOrderItem,
  mapOpportunityToSale,
  mapResourceToUser,
  mapQuoteToSchoolSale,
  mapConsignmentToOrder
};
```

## Phase 6: One-Time Sync Script

Create `api/scripts/sync-from-nav2018.js`:

```js
require('dotenv').config();
const { navGetAll } = require('../lib/nav/client');
const { upsertByNavId } = require('../lib/supabase/client');
const {
  mapCustomerToSchool,
  mapItemToCatalog,
  mapSalesOrderToOrder,
  mapSalesInvoiceLineToOrderItem,
  mapOpportunityToSale,
  mapResourceToUser,
  mapQuoteToSchoolSale,
  mapConsignmentToOrder
} = require('../lib/nav/mappings');

async function syncAll() {
  console.log('Starting NAV 2018 → Supabase sync...');

  console.log('Syncing customers → schools...');
  const customers = await navGetAll('customers');
  await upsertByNavId('schools', customers, mapCustomerToSchool);
  console.log(`Imported ${customers.length} schools`);

  console.log('Syncing items → catalog_items...');
  const items = await navGetAll('items');
  await upsertByNavId('catalog_items', items, mapItemToCatalog);
  console.log(`Imported ${items.length} catalog items`);

  console.log('Syncing salesOrders → orders...');
  const orders = await navGetAll('salesOrders');
  await upsertByNavId('orders', orders, mapSalesOrderToOrder);
  console.log(`Imported ${orders.length} orders`);

  console.log('Syncing salesInvoiceLines → order_items...');
  const lines = await navGetAll('salesInvoiceLines');
  await upsertByNavId('order_items', lines, mapSalesInvoiceLineToOrderItem);
  console.log(`Imported ${lines.length} order items`);

  console.log('Syncing quotations (NAV quotes) → school_sales...');
  const quotes = await navGetAll('salesOrders', { '$filter': "documentType eq 'Quote'" });
  await upsertByNavId('school_sales', quotes, mapQuoteToSchoolSale);
  console.log(`Imported ${quotes.length} quotations`);

  console.log('Syncing consignments → orders...');
  const consignments = await navGetAll('salesOrders', { '$filter': "orderType eq 'Consignment'" });
  await upsertByNavId('orders', consignments, mapConsignmentToOrder);
  console.log(`Imported ${consignments.length} consignments`);

  console.log('Syncing opportunities → school_sales...');
  const opportunities = await navGetAll('opportunities');
  await upsertByNavId('school_sales', opportunities, mapOpportunityToSale);
  console.log(`Imported ${opportunities.length} school sales`);

  console.log('Syncing resources → users...');
  const resources = await navGetAll('resources');
  await upsertByNavId('users', resources, mapResourceToUser);
  console.log(`Imported ${resources.length} users`);

  console.log('Sync complete.');
}

syncAll().catch(err => {
  console.error('Sync failed:', err);
  process.exit(1);
});
```

## Phase 7: Extend Express API (Optional Future-Proofing)

Update `api/index.js` to connect to Supabase instead of MySQL:

```js
const express = require('express');
const cors = require('cors');
require('dotenv').config();
const { supabase } = require('./lib/supabase/client');

const app = express();
const port = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', database: 'supabase', timestamp: new Date().toISOString() });
});

// Root path
app.get('/', (req, res) => {
  res.json({
    message: 'DeHeus NAV 2018 Integration API',
    endpoints: ['/health', '/api/sync/nav2018']
  });
});

// Manual sync trigger (admin use)
app.post('/api/sync/nav2018', async (req, res) => {
  try {
    const { syncAll } = require('./scripts/sync-from-nav2018');
    await syncAll();
    res.json({ success: true, message: 'Sync completed' });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Generic Supabase CRUD proxy (for tables that need API access)
const createSupabaseRouter = (tableName) => {
  const router = express.Router();

  router.get('/', async (req, res) => {
    const { data, error } = await supabase.from(tableName).select('*');
    if (error) return res.status(500).json({ error: error.message });
    res.json(data);
  });

  router.get('/:id', async (req, res) => {
    const { data, error } = await supabase.from(tableName).select('*').eq('id', req.params.id).maybeSingle();
    if (error) return res.status(500).json({ error: error.message });
    if (!data) return res.status(404).json({ error: 'Not found' });
    res.json(data);
  });

  router.post('/', async (req, res) => {
    const { data, error } = await supabase.from(tableName).insert(req.body).select().single();
    if (error) return res.status(500).json({ error: error.message });
    res.status(201).json(data);
  });

  router.put('/:id', async (req, res) => {
    const { data, error } = await supabase.from(tableName).update(req.body).eq('id', req.params.id).select().single();
    if (error) return res.status(500).json({ error: error.message });
    res.json(data);
  });

  router.delete('/:id', async (req, res) => {
    const { error } = await supabase.from(tableName).delete().eq('id', req.params.id);
    if (error) return res.status(500).json({ error: error.message });
    res.json({ message: 'Deleted' });
  });

  return router;
};

// Register CRUD routes for tables that need them
const tables = ['schools', 'catalog_items', 'orders', 'order_items', 'school_sales', 'users'];
tables.forEach(table => {
  app.use(`/api/${table}`, createSupabaseRouter(table));
});

// NAV-specific sync endpoints
app.post('/api/sync/nav2018/quotations', async (req, res) => {
  try {
    const quotes = await navGetAll('salesOrders', { '$filter': "documentType eq 'Quote'" });
    await upsertByNavId('school_sales', quotes, mapQuoteToSchoolSale);
    res.json({ success: true, count: quotes.length });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.post('/api/sync/nav2018/consignments', async (req, res) => {
  try {
    const consignments = await navGetAll('salesOrders', { '$filter': "orderType eq 'Consignment'" });
    await upsertByNavId('orders', consignments, mapConsignmentToOrder);
    res.json({ success: true, count: consignments.length });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});
```

## Phase 8: Run the Initial Sync

```bash
cd api
npm install
node scripts/sync-from-nav2018.js
```

Verify in Supabase that records have `nav_id` populated and `nav_sync_status = 'synced'`.

## Phase 9: Scheduling Ongoing Syncs

The initial sync imports everything. For ongoing updates, choose one approach:

### Option A: Cron (Simple)
```bash
# Add to crontab
0 2 * * * cd /path/to/api && node scripts/sync-from-nav2018.js >> logs/nav-sync.log 2>&1
```

### Option B: Node-cron (In-process)
```bash
npm install node-cron
```

In `api/index.js`:
```js
const cron = require('node-cron');
const { syncAll } = require('./scripts/sync-from-nav2018');

cron.schedule('0 2 * * *', async () => {
  console.log('Running scheduled NAV sync...');
  try {
    await syncAll();
    console.log('Scheduled sync complete');
  } catch (err) {
    console.error('Scheduled sync failed:', err);
  }
});
```

## Phase 10: Flutter Integration (Optional Trigger)

Only needed if you want the Flutter app to **trigger syncs** after local changes.
Currently **not required** — the Flutter app reads Supabase directly and sees NAV data after the sync script runs.

If needed later, create `lib/services/nav_sync_service.dart`:

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

class NavSyncService {
  static const _baseUrl = 'http://your-server:3000';

  Future<void> syncSchool(String schoolId) async {
    await _post('/api/sync/nav2018/school/$schoolId');
  }

  Future<void> syncOrder(String orderId) async {
    await _post('/api/sync/nav2018/order/$orderId');
  }

  Future<void> syncCatalogItem(String sku) async {
    await _post('/api/sync/nav2018/catalog/$sku');
  }

  Future<void> _post(String endpoint) async {
    final response = await http.post(Uri.parse('$_baseUrl$endpoint'));
    if (response.statusCode != 200) {
      throw Exception('Sync failed: ${response.body}');
    }
  }
}
```

## File Summary

| File | Action |
|------|--------|
| `supabase/schema_updates_nav2018.sql` | Create — add `nav_id` + `nav_sync_status` columns + `order_type` |
| `api/package.json` | Modify — add `@supabase/supabase-js`, `axios`, `p-queue` |
| `api/.env` | Modify — add `SUPABASE_SERVICE_ROLE_KEY` + NAV creds |
| `api/.env.example` | Modify — add NAV env template |
| `api/lib/nav/client.js` | Create — OData client with queue/backoff |
| `api/lib/nav/mappings.js` | Create — NAV → Supabase field mappings (includes quotations + consignments) |
| `api/lib/supabase/client.js` | Create — Supabase service-role client |
| `api/scripts/sync-from-nav2018.js` | Create — one-time + scheduled sync (includes quotations + consignments) |
| `api/index.js` | Modify — swap MySQL for Supabase + add sync endpoints |

## Flutter App Changes

**None.** The Flutter app continues reading from Supabase directly.
Imported NAV data appears in existing Supabase tables automatically.

## Security Notes

1. **`NAV_WEB_ACCESS_KEY`** — Store in `api/.env` (gitignored). Rotate if exposed.
2. **`SUPABASE_SERVICE_ROLE_KEY`** — Server-side only. Never expose to Flutter.
3. **Network** — If NAV 2018 is on-premises, the Node.js API must run inside the corporate network or VPN.
4. **Rate limiting** — NAV 2018 OData can be slow. The `p-queue` with `concurrency: 2` prevents overwhelming the server.
5. **Timeouts** — Large NAV datasets may need the initial sync run in chunks or during off-hours.

## Testing Checklist

- [ ] NAV OData endpoint returns JSON when hit from Postman
- [ ] `supabase/schema_updates_nav2018.sql` applied — columns exist
- [ ] `node scripts/sync-from-nav2018.js` completes without errors
- [ ] Supabase tables contain NAV data with `nav_id` populated
- [ ] Flutter app displays imported schools, catalog items, and orders
- [ ] Quotations from NAV appear in `school_sales` with `sale_status = 'quotation_sent'`
- [ ] Consignments from NAV appear in `orders` with `order_type = 'consignment'`
- [ ] Re-running sync does not create duplicates (upsert by `nav_id`)
- [ ] Scheduled cron runs and logs successfully
