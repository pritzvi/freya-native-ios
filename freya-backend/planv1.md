# freya-backend plan v1

Purpose: Stand up a minimal Firebase Functions (v2) API that can:
- Create/fetch product snapshots in Firestore
- Maintain a `product_index` collection with 768-dim vectors
- Provide a simple endpoint to resolve a product by query text
- Keep surface area tiny so we can iterate quickly

No implementation changes in this document; this is the execution plan for the code you outlined.

## 0) Runtime, packages, and configuration

- Runtime: Node 20
- Functions: Firebase Functions v2 (`onRequest`) on `us-central1`
- Admin: `firebase-admin` 12.x
- HTTP: `express` 4.x (simple router only)
- Auth: none for now (no middleware) — curl with a dummy `Authorization` header
- External SDKs:
  - `openai` 4.x (ESM-only)
  - `google-auth-library` 9.x (for Vertex token)
  - `node-fetch` 3.x (works with ESM; optional because Node 20 has global `fetch`)
  - `zod` for basic validation later (already listed)
  - Add: `@google-cloud/firestore` 7.x (required for `DistanceMeasure` and `findNearest` types)

Required config so the above deps work together without code changes:
- Use ESM so `openai` and `node-fetch` import cleanly
  - package.json: add "type": "module"
  - tsconfig.json: set "module": "NodeNext", "moduleResolution": "NodeNext" (target stays ES2020)
- Vertex API project id: resolve with `(process.env.GOOGLE_CLOUD_PROJECT || process.env.GCLOUD_PROJECT)`
- ADC present on dev machine (confirmed): `gcloud auth application-default login`

## 1) Project layout (under `freya-backend/functions`)

Keep exactly what you proposed:
- package.json (Node 20; Functions v2 compatible)
- tsconfig.json
- .gitignore: `lib/`, `node_modules/`, `.env*`
- src/
  - index.ts → export `api` with v2 `onRequest`
  - app.ts → `express()` app, routes mounted, `admin.initializeApp()` guarded
  - authMiddleware.ts → SKIP for now (we will add later)
  - lib/
    - vertex.ts → Vertex text-embedding-005 (768 dims, us-central1)
    - normalize.ts → `slugify`, `canon`, `parsePrice`
    - firecrawl.ts → search
    - urlPicker.ts → OpenAI hosted prompt call to choose URL
    - fcScrape.ts → scrape product details via Firecrawl
  - routes/
    - devEmbed.ts → GET /dev/embed
    - devIndexProduct.ts → POST /dev/indexProduct
    - devKnn.ts → POST /dev/knn
    - productResolve.ts → POST /product/resolve

Functions export:
- `setGlobalOptions({ region: "us-central1" })`
- `export const api = onRequest(app)`

## 2) Firestore setup

- Collections used:
  - `products/{productId}` — snapshot document
  - `product_index/{productId}` — vector row `{ snapshotId, name, brand, embedding }`
- Vector index (already created):
  - 768 dims, flat, COSINE distance
  - Confirmed via your pasted gcloud command

Minimal dev rules (keep locked down in prod):
- You can keep your auth-based rules; emulator ignores rules if needed for quick tests

## 3) Required Google Cloud APIs (project `freya-7c812`)

- Vertex AI API: ENABLED
- Firestore API: ENABLED
- (Optional now) Cloud Functions API (for deploy later)

## 4) Local run

Terminal A:
```
cd freya-backend/functions
npm install
npm run build
cd ..
firebase emulators:start --project freya-7c812
```

Terminal B (tests — use any string for Authorization header for now):

- Embedding smoke test
```
curl -s http://localhost:5001/freya-7c812/us-central1/api/dev/embed \
  -H "Authorization: Bearer test" | jq
# Expect: { "dim": 768, "preview": [...] }
```

- Index a sample product
```
curl -s http://localhost:5001/freya-7c812/us-central1/api/dev/indexProduct \
  -H "Authorization: Bearer test" -H "Content-Type: application/json" \
  -d '{"name":"Renewing SA Cleanser", "brand":"CeraVe"}' | jq
# Check Emulator UI -> products/* and product_index/* created
```

- Nearest neighbor
```
curl -s http://localhost:5001/freya-7c812/us-central1/api/dev/knn \
  -H "Authorization: Bearer test" -H "Content-Type: application/json" \
  -d '{"query":"cerave sa clnsr"}' | jq
# Expect found:true with the productId from previous step
```

- End-to-end resolve
```
curl -s http://localhost:5001/freya-7c812/us-central1/api/product/resolve \
  -H "Authorization: Bearer test" -H "Content-Type: application/json" \
  -d '{"query":"CeraVe Renewing SA Cleanser"}' | jq
# First time: { "status":"created","productId":"..." }
# Later:      { "status":"found","productId":"..." }
```

## 5) Secrets and env

Local (emulator):
- Export env vars in your shell before starting emulators:
  - `OPENAI_API_KEY`, `FIRECRAWL_API_KEY`
- ADC provides Vertex IAM (no key file needed)

Prod (later):
- `firebase functions:secrets:set OPENAI_API_KEY`
- `firebase functions:secrets:set FIRECRAWL_API_KEY`

## 6) Deployment (later)

- Ensure Firestore vector index exists in prod
- Deploy:
```
firebase deploy --only functions:api --project freya-7c812
```

## 7) Future steps (post-MVP)

- Add `requireAuth` middleware to verify Firebase ID tokens (or a static key for server-to-server)
- Normalize and validate route inputs with `zod`
- Add CORS allowlist if the mobile app will call the HTTPS function directly
- Add retries/backoff around Vertex and Firecrawl calls

## 8) Open points (confirmations)

- Hosted prompt id/version for URL picker is final (you confirmed)
- COSINE distance is acceptable for non-unit-normalized vectors (you confirmed)
- Keep ESM config to match `openai` and `node-fetch` without code changes
- Add dependency: `@google-cloud/firestore` 7.x for `DistanceMeasure`

Once you confirm, we proceed to implement exactly as specified here without extra scaffolding.
