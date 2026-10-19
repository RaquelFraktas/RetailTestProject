# Solution Notes

How to run the solution, followed by the key decisions for each objective.

## Running it

Requires Ruby 3.2.2 and PostgreSQL 13+.

```bash
bundle install                        # added pagy for pagination
bin/rails db:create db:migrate
bin/rails db:seed                     # run against a fresh database
bin/rails tracking_events:import      # imports the 1M-row CSV and detects alerts (~3 min)
bin/rails server                      # http://localhost:3000
```

Other commands:

```bash
bin/rails test           # model, alert detector and CSV importer tests
bin/rails alerts:detect  # rebuild every alert from existing events (safe to re-run)
```

The CSV has no price column, so a way to see price tracking in the UI, create an event in `bin/rails console`:

```ruby
TrackingEvent.create!(store: Store.first, product: Product.first, event_time: Time.current, price: 4.99)
```

Then open `/products/<Product.first.id>`. The new row shows the price, with "—" for inventory.

## 1. Price tracking

- **Schema:** added a nullable `price` column (`decimal(10, 2)`) to `tracking_events`. `inventory_present` was already nullable. A `nil` in either column means that check wasn't performed, so an event can hold an inventory check, a price check, or both.
- **Why not separate tables:** both checks share the same store, product and time, so one row per observation keeps queries and the UI simple.
- **Validation:** an event must include at least one check, and price must be ≥ 0.
- **Helpers:** `inventory_checks` / `price_checks` scopes and `inventory_checked?` / `price_checked?` predicates.
- **Importer:** reads an optional `Price` column, tolerates values like `$4.99`, and skips rows with neither check.

## 2. Out-of-stock alerts

An alert is raised for the brand when a store records two consecutive "no inventory" events for the same product, ordered by `event_time`.

- **Data model:** `alerts` references the triggering event and the event before it, plus `brand`, `store` and `product`. Storing those three directly lets the index page filter by brand without joins.
- **Detection:** `Alerts::OutOfStockDetector` replays a store/product's inventory history in `event_time` order. It then makes the `alerts` table match that history: it upserts the alerts that should exist and deletes the ones that no longer should.
  - **Out-of-order events:** CSV rows don't arrive in time order. A late "in stock" event can land between two "no inventory" events, so the detector recomputes the whole history rather than comparing against the most recent event.
  - **Idempotent:** a unique index on `tracking_event_id` makes re-running safe, which is why `alerts:detect` can be run at any time.
  - **Price-only events** neither break nor extend a streak.
  - **One alert per streak:** the alert is raised on the streak's second event, and a restock is needed before the next alert.
- **When detection runs:**
  - **Single saves:** an `after_commit` callback on `TrackingEvent` re-checks just that store/product pair.
  - **Bulk import:** the import skips callbacks and runs one full detection pass at the end.
- **UI:** an index page (filterable by brand, linked from each brand page) and a show page listing the two triggering events.
- **Index:** added `(store_id, product_id, event_time)` so each history is a single indexed range scan.

## 3. Performance

- **CSV importer:** the original made 2 lookup queries, 1 insert and a full alert re-check for every row. Now:
  - stores and products are loaded once into lookup hashes;
  - rows are inserted in batches of 1,000 with `insert_all`;
  - alert detection runs once at the end, instead of once per row.

  A 10,000-row sample went from tens of thousands of queries to 16. Because `insert_all` skips model validations, the importer checks the same rules itself before inserting.
- **Pagination:** every index page and every list on the show pages is paginated with Pagy, 30 per page. Tracking events are listed newest first. Stores, products and brands are listed alphabetically, so pages stay stable.
- **N+1 queries:** association lookups (brand, store, product) are eager-loaded with `includes`. The per-row event counts remain (see next steps).

## Trade-offs and next steps

- **Indexes:** the store and product pages sort a store's or product's whole event history to show 30 rows (~10k events for the largest store). Adding `(store_id, event_time)` and `(product_id, event_time)` would let Postgres read the newest 30 directly. Those would also make the existing single-column `store_id` / `product_id` indexes redundant.
- **Data integrity:** the importer matches stores by address and products by name, so I'd add unique indexes on both.
- **Event counts:** the per-row counts on the index pages run one `COUNT` per row (30 per page). A counter cache would remove those queries, at the cost of extra writes on every import.
- **Scale:**
  - With millions of stores or products, load the lookups per batch rather than all up front.
  - The full detection pass holds all inventory events in memory. A SQL `LAG()` window function, or re-checking only the store/product pairs the import touched, would scale further.
- **Background jobs and concurrency:**
  - Detection is fast enough to run inline today (about 1 ms per history). Once alerts send emails or call other services, detection belongs in a background job (e.g. Sidekiq) that can retry.
  - If writes become concurrent (web forms, parallel workers), wrap detection in a per-pair `pg_advisory_xact_lock` to prevent races. The current importer is single-process, so this can't happen today.
- **Import atomicity:** each batch commits on its own. A failure partway through leaves the earlier batches saved, and re-running would duplicate them. A unique key on events, or one wrapping transaction, would fix that.
