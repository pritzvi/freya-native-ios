## Backend Routes and Firestore Data Model

This document captures each backend route, its purpose, Firestore paths it touches, request/response shapes, and expected document structures. Keep this in sync when routes or schemas change.

### Base
- All routes are mounted under the Firebase Functions Express app.
- Main API endpoints (from `freya-backend/functions/src/app.ts`).
- Cloud Function URL: `https://us-central1-freya-7c812.cloudfunctions.net/api`
- **Note:** The Cloud Function URL path `/api` is stripped before reaching Express, so Express routes should NOT have `/api` prefix.

---

### POST `/deepscan/score`
**Purpose**: Run DeepScan (OpenAI Vision) on 1–4 images (either direct URLs or GCS paths), persist results, and return a `scoreId`.

Inputs (JSON) - **Two modes supported:**

**Mode 1: Direct URLs (legacy/placeholder)**
```json
{
  "uid": "string",
  "images": ["https://..."],
  "emphasis": "optional string (will be overridden by survey data)"
}
```

**Mode 2: GCS Paths (new, for private Storage)**
```json
{
  "uid": "string",
  "gcsPaths": ["userImages/uid123/items/photo-front.jpg", ...],
  "emphasis": "optional string (will be overridden by survey data)"
}
```

**Backend behavior:**
- If `images` provided: uses URLs directly
- If `gcsPaths` provided: generates short-lived signed URLs (10 min TTL) using `signedReadUrl()` from `lib/storage.ts`
- Fetches survey data from `skinProfiles/{uid}` to build emphasis text:
  - `emphasisText = "Primary concern: {mainConcern}. Secondary concerns: {additionalConcerns}."`
  - Fallback if no survey: `"Primary concern: general skin health. Secondary concerns: none."`

Response (JSON):
```json
{
  "scoreId": "string",
  "overall": 0,
  "subscores": {},
  "confidence": 0
}
```

Firestore Writes:
- `skinScanSessions/{uid}/items/{sessionId}`
  - Example:
  ```json
  {
    "phase": "onboarding",
    "images": ["https://..."],
    "status": "processing|succeeded",
    "scoreId": "string (added when complete)",
    "createdAt": <serverTimestamp>
  }
  ```
- `skinScores/{uid}/items/{scoreId}`
  - Example:
  ```json
  {
    "skin_score_total_0_100": 70,
    "subscores": { "barrier_hydration_0_100": 90, "...": 0 },
    "confidence_0_100": 95,
    "full_analysis": { /* model JSON */ },
    "createdAt": <serverTimestamp>
  }
  ```

Notes:
- Route accepts 1–4 images.
- Images should be publicly accessible or signed URLs so the function can fetch them.

---

### POST `/survey/save`
**Purpose**: Save/merge user survey (onboarding) data to `skinProfiles`.

Inputs (JSON):
```json
{
  "uid": "string",
  "...": "all survey fields (flattened)"
}
```

Response (JSON):
```json
{ "ok": true, "message": "Survey saved successfully" }
```

Firestore Writes:
- `skinProfiles/{uid}` (merge=true)
  - Example (keys vary by onboarding implementation):
  ```json
  {
    "name": "string",
    "age": "string",
    "gender": "string",
    "freyaUsage": ["string"],
    "mainConcern": "string",
    "additionalConcerns": ["string"],
    "skinFeel": "string",
    "skinConditions": ["string"],
    "scarringConditions": ["string"],
    "skinReaction": "string",
    "ethnicity": "string",
    "isPregnantOrBreastfeeding": "string",
    "additionalDetails": "string",
    "currentRoutineOption": "string",
    "hasIngredientSensitivities": "string",
    "specificIngredients": "string",
    "lifestyleFactors": ["string"],
    "investmentLevel": "string",
    "timeInvestment": "string",
    "wearsMakeup": "string",
    "skincarePreferences": ["string"],
    "updatedAt": <serverTimestamp>
  }
  ```

---

### POST `/report/generate`
**Purpose**: Generate a skin report using survey + skin score, store it, and materialize a routine.

Inputs (JSON):
```json
{
  "uid": "string",
  "scoreId": "optional string (if omitted, latest score is used)"
}
```

Response (JSON):
```json
{
  "reportId": "string",
  "status": "generated",
  "reportData": { /* LLM output */ }
}
```

Firestore Reads:
- `skinProfiles/{uid}` (survey)
- `skinScores/{uid}/items/{scoreId}` or latest by `createdAt desc`

Firestore Writes:
- `skinReports/{uid}/items/{reportId}`
  - Example:
  ```json
  {
    "surveyRef": "uid",
    "scoreId": "string",
    "reportData": { /* LLM output, may include initial_routine */ },
    "createdAt": <serverTimestamp>
  }
  ```
- `routines/{uid}` (materialized if `reportData.initial_routine` exists)
  - Example:
  ```json
  {
    "AM": [ { "product": "string", "step": 1, "note": "optional" } ],
    "PM": [ { "product": "string", "step": 1, "note": "optional" } ],
    "templateVersion": 1,
    "updatedAt": <serverTimestamp>
  }
  ```

Notes:
- Returns 404 if no survey or no skin score available.

---

### POST `/report/find-products`
**Purpose**: For a generated report, run product finding per routine step in parallel and store results.

Inputs (JSON):
```json
{
  "uid": "string",
  "reportId": "string"
}
```

Response (JSON):
```json
{
  "success": true,
  "totalSteps": 0,
  "successfulProducts": 0,
  "failedProducts": 0,
  "status": "products_complete|products_partial|products_failed",
  "productRecommendations": { "AM_step_1": { /* step result */ } },
  "failedSteps": [ { "stepId": "PM_step_3", "error": "..." } ]
}
```

Firestore Reads:
- `skinReports/{uid}/items/{reportId}`
- `skinProfiles/{uid}` (survey)
- `skinScores/{uid}/items/{scoreId}` (from report)

Firestore Writes (update):
- `skinReports/{uid}/items/{reportId}`
  - Example fields added/updated:
  ```json
  {
    "productRecommendations": { "AM_step_1": { /* products */ } },
    "productFindingStatus": {
      "totalSteps": 5,
      "successfulSteps": 4,
      "failedSteps": [ { "stepId": "PM_step_3", "error": "..." } ],
      "completedAt": <serverTimestamp>
    },
    "status": "products_complete|products_partial|products_failed",
    "updatedAt": <serverTimestamp>
  }
  ```

---

### POST `/report/enrich-products`
**Purpose**: Enrich existing product recommendations with `productId` and `imageUrl` by calling `/product/resolve` for each product.

**Timing**: ~50-60s (parallel productResolve calls for all products in report)

**When to call**: After `/report/find-products` completes. Can be called in background (fire-and-forget) from iOS.

Inputs (JSON):
```json
{
  "uid": "string",
  "reportId": "string"
}
```

Response (JSON):
```json
{
  "success": true,
  "enrichedProducts": {
    "AM_step_1": {
      "stepInfo": { "routine_step": "AM Gel Cleanser", "time_of_day": "AM", "step_number": 1 },
      "products": [
        {
          "product_name": "Hada Labo Tokyo Skin Plumping Gel Cleanser",
          "note_on_recommendation": "...",
          "key_ingredients": ["Hyaluronic Acid", "Glycerin"],
          "reddit_source": "...",
          "productId": "hada-labo-tokyo-hada-labo-tokyo-skin-plumping-gel-cleanser",
          "imageUrl": "https://us-central1-freya-7c812.cloudfunctions.net/api/products/hada-labo-tokyo-hada-labo-tokyo-skin-plumping-gel-cleanser/images/0"
        }
      ]
    }
  },
  "totalProducts": 15,
  "successfulResolves": 15,
  "failedResolves": 0,
  "status": "complete|partial"
}
```

Firestore Reads:
- `skinReports/{uid}/items/{reportId}` (gets existing productRecommendations)

Firestore Writes (update):
- `skinReports/{uid}/items/{reportId}`
  - Adds `productId` and `imageUrl` to each product in `productRecommendations`
  - Adds `enrichmentStatus: "complete"|"partial"`
  - Adds `enrichmentCompletedAt: <serverTimestamp>`
  - Updates `updatedAt: <serverTimestamp>`

**Note**: This endpoint is idempotent - if products are already enriched, it will re-resolve them (but productResolve will hit cache for most).

---

### Dev/Utility Routes (for completeness)
- POST `/dev/indexProduct` → Index a product prototype (testing)
- POST `/dev/knn` → KNN similarity utilities (testing)
- GET `/dev/embed` → Embedding demos
- POST `/dev/search` → Web search helper
- POST `/dev/pickUrl` → Pick best URL from search results
- POST `/dev/scrape` → Scrape product URL
- POST `/product/resolve` → Product parsing/resolve
- POST `/match/score` → Matching utilities

---

## Firebase Storage Structure

### User Images Collection
- **Path pattern**: `userImages/{uid}/items/{fileName}`
- **Example**: `userImages/abc123/items/deepscan-1739472000-front.jpg`
- **Usage**: Private user photos for DeepScan
- **Security**: Read/write restricted to authenticated user (see `storage.rules`)
- **File naming convention**: `deepscan-{timestamp}-{angle}.jpg`
  - Angles: `front`, `left`, `right`, `below`
- **Access**: 
  - iOS uploads: `Storage.storage().reference(withPath: path).putDataAsync()`
  - Backend reads: `signedReadUrl(path, ttlMinutes)` from `lib/storage.ts`
  - **Never use `getDownloadURL()`** - it creates long-lived public URLs

### Signed URL Generation (`lib/storage.ts`)
```typescript
async function signedReadUrl(gsPath: string, ttlMinutes: number): Promise<string>
```
- Generates v4 signed URL with short TTL (typically 10 minutes)
- Used by backend to give OpenAI temporary access to private images
- URL expires after TTL - cannot be reused
- Example: `https://storage.googleapis.com/freya-7c812.appspot.com/userImages/...?X-Goog-Algorithm=...`

---

## Data Relationships Summary
- One user (`uid`) has:
  - 0..N `skinScanSessions/{uid}/items/{sessionId}`
  - 0..N `skinScores/{uid}/items/{scoreId}`
  - 0..N `skinReports/{uid}/items/{reportId}`
  - 0..1 `routines/{uid}`
  - 0..1 `skinProfiles/{uid}` (survey)
  - 0..N images in Storage: `userImages/{uid}/items/{fileName}`

## Notes for Clients (iOS)
- Always include `uid` in POST bodies.
- For `/report/generate`, `scoreId` is optional; backend will select the most recent score.
- DeepScan workflow:
  1. Capture 4 photos with ARKit overlay
  2. Upload to Storage → get `gcsPaths` array
  3. Call `/deepscan/score` with `gcsPaths` (fire-and-forget, non-blocking)
  4. Continue survey immediately
  5. Backend generates signed URLs → calls OpenAI → stores results
  6. Poll for `skinScoreResult` before showing ScoreSummaryView
- **Never store or persist signed URLs** - they expire after TTL


