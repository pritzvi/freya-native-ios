## Backend Routes and Firestore Data Model

This document captures each backend route, its purpose, Firestore paths it touches, request/response shapes, and expected document structures. Keep this in sync when routes or schemas change.

### Base
- All routes are mounted under the Firebase Functions Express app.
- Main API endpoints (from `freya-backend/functions/src/app.ts`).
- Functions URL: 
✔  Deploy complete!

Project Console: https://console.firebase.google.com/project/freya-7c812/overview

---

### POST `/api/deepscan/score`
**Purpose**: Run DeepScan (OpenAI Vision) on 1–4 image URLs, persist results, and return a `scoreId`.

Inputs (JSON):
```json
{
  "uid": "string",
  "images": ["https://..."],
  "emphasis": "optional string"
}
```

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

### POST `/api/survey/save`
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

### POST `/api/report/generate`
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

### POST `/api/report/find-products`
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

## Data Relationships Summary
- One user (`uid`) has:
  - 0..N `skinScanSessions/{uid}/items/{sessionId}`
  - 0..N `skinScores/{uid}/items/{scoreId}`
  - 0..N `skinReports/{uid}/items/{reportId}`
  - 0..1 `routines/{uid}`
  - 0..1 `skinProfiles/{uid}` (survey)

## Notes for Clients (iOS)
- Always include `uid` in POST bodies.
- For `/api/report/generate`, `scoreId` is optional; backend will select the most recent score.
- DeepScan can be fired-and-forgotten; the function persists results even if the client doesn’t wait.


Next Steps in Our Plan:
Immediate: Test the Deployment
Test health endpoint (from terminal):
Expected: {"ok":true,"now":1234567890} (Done!)

Next:
Test on your iPhone:
Build and run the iOS app on your physical device
Complete the onboarding flow
Check Xcode console for:
"DeepScan submitted successfully. ScoreId: ..."
"Survey saved: Survey saved successfully"
Verify in Firebase Console:
Check skinProfiles/{uid} for survey data
Check skinScores/{uid}/items/{scoreId} for DeepScan results
Check skinScanSessions/{uid}/items/{sessionId} for session tracking
Next Phase: Report Generation & Products (Not Yet Implemented)
Once Phase 1 testing passes:
Phase 2: Add report generation API call after survey save
Call POST /api/report/generate with { uid }
Handle retry logic if DeepScan not ready yet
Phase 3: Add product finding API call
Call POST /api/report/find-products with { uid, reportId }
Phase 4: Replace placeholder images with real photos + Firebase Storage signed URLs
Ready to test on your phone! 