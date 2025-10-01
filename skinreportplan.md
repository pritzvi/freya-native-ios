# Skin Report Generator Implementation Plan

## Overview
Build complete skin analysis pipeline: Survey → DeepScan → Report Generation → Routine Creation

**High-Level Flow:**
1. **Survey capture** → `skinProfiles/{uid}`
2. **DeepScan score** → `skinScanSessions/{uid}` + `userImages/{uid}` + `skinScores/{uid}`
3. **Skin Report** → `skinReports/{uid}/{reportId}` + write/update `routines/{uid}`

## API Endpoints to Implement

### A) Save Survey
- **Route**: `POST /api/survey/save`
- **Purpose**: Store user onboarding survey responses
- **Input**: Survey data + uid in request body
- **Output**: Confirmation of save

### B) DeepScan Score  
- **Route**: `POST /api/deepscan/score`
- **Purpose**: Analyze face images with OpenAI Vision API
- **Input**: Image URLs + emphasis + uid
- **Output**: Skin scores (overall + 5 subscores + confidence)

### C) Generate Report
- **Route**: `POST /api/report/generate` 
- **Purpose**: Create personalized skin report and routine
- **Input**: uid + optional scoreId
- **Output**: Generated report + routine preview

### D) Get Latest Report
- **Route**: `GET /api/report/get-latest`
- **Purpose**: Retrieve most recent skin report
- **Input**: uid in request body
- **Output**: Latest report data

## Implementation Steps

### Step 1: Add Secrets Configuration
**File**: `src/index.ts`
- Add `SKINSCORE_PROMPT_OAI` to secrets array
- Add `SKINCAREROUTINE_REPORT_GENERATOR_PROMPT_OAI` to secrets array
- Bind both secrets to the `api` function

### Step 2: Create Core Library Functions
**File**: `src/lib/deepScan.ts`
- `deepScanScore(imageUrls: string[], emphasis: any): Promise<SkinScoreResult>`
- OpenAI Vision API integration using Responses API
- Parse JSON response (same pattern as productFit.ts)
- Return overall + barrierHydration + complexion + acneTexture + fineLines + eyes + confidence

**File**: `src/lib/reportGenerator.ts`
- `generateSkinReport(profile: any, score: any): Promise<ReportResult>`
- OpenAI text generation with combined profile + score data
- Parse structured response for thinking + initial_routine + final_routine
- Same OpenAI syntax pattern as existing functions

### Step 3: Create API Route Handlers
**File**: `src/routes/survey.ts`
- `saveSurvey(req: Request, res: Response)` 
- Validate minimal survey fields
- Upsert to `skinProfiles/{uid}` with updatedAt timestamp

**File**: `src/routes/deepScan.ts`
- `deepScanScore(req: Request, res: Response)`
- Create `skinScanSessions/{uid}/items/{sessionId}` with status "processing"
- Call `deepScanScore()` library function
- Store result in `skinScores/{uid}/items/{scoreId}`
- Update session with scoreId and status "succeeded"
- Return trimmed score payload

**File**: `src/routes/report.ts`
- `generateReport(req: Request, res: Response)`
  - Fetch latest `skinProfiles/{uid}` 
  - Fetch latest `skinScores/{uid}/items` (by createdAt desc)
  - Call `generateSkinReport()` library function
  - Write full result to `skinReports/{uid}/items/{reportId}`
  - Materialize initial_routine to `routines/{uid}` as current routine
  - Return reportId + routine preview
- `getLatestReport(req: Request, res: Response)`
  - Query `skinReports/{uid}/items` ordered by createdAt desc, limit 1
  - Return full report document

### Step 4: Mount Routes in Express App
**File**: `src/app.ts`
- Import all new route handlers
- Mount endpoints:
  ```typescript
  app.post("/api/survey/save", saveSurvey);
  app.post("/api/deepscan/score", deepScanScore);
  app.post("/api/report/generate", generateReport);
  app.get("/api/report/get-latest", getLatestReport);
  ```

## Firestore Collections Schema

### skinProfiles/{uid}
```json
{
  "name": "Alex",
  "ageBand": "24-30",
  "skinType": "combo", 
  "reactivity": "balanced",
  "primaryConcern": "acne",
  "secondaryConcerns": ["hyperpigmentation"],
  "beginner": true,
  "timeCommitment": "5-15",
  "pregnancy": false,
  "allergens": ["fragrance"],
  "prefs": ["NonComedogenic"],
  "wearsMakeupDaily": true,
  "updatedAt": "timestamp"
}
```

### skinScanSessions/{uid}/items/{sessionId}
```json
{
  "phase": "onboarding",
  "images": ["url1", "url2", "url3"],
  "status": "succeeded",
  "scoreId": "scoreId",
  "createdAt": "timestamp"
}
```

### skinScores/{uid}/items/{scoreId}
```json
{
  "overall": 64,
  "barrierHydration": 58,
  "complexion": 60,
  "acneTexture": 45,
  "fineLines": 72,
  "eyes": 55,
  "confidence": 0.82,
  "createdAt": "timestamp"
}
```

### skinReports/{uid}/items/{reportId}
```json
{
  "profileVersion": 1,
  "scoreId": "scoreId",
  "payload": {
    "thinking": "Analysis text...",
    "initial_routine": {
      "AM": [{"step": 1, "product": "AM Gel Cleanser"}],
      "PM": [{"step": 1, "product": "PM Gel Cleanser"}]
    },
    "final_routine": {
      "AM": [{"step": 1, "product": "Advanced AM Cleanser"}],
      "PM": [{"step": 1, "product": "Advanced PM Cleanser"}]
    }
  },
  "createdAt": "timestamp"
}
```

### routines/{uid}
```json
{
  "AM": [{"step": 1, "product": "AM Gel Cleanser"}],
  "PM": [{"step": 1, "product": "PM Gel Cleanser"}],
  "templateVersion": 1,
  "updatedAt": "timestamp"
}
```

## Testing Plan

### 1. Survey Save Test
```bash
curl -s http://localhost:5001/freya-7c812/us-central1/api/survey/save \
  -H "Authorization: Bearer test" -H "Content-Type: application/json" \
  -d '{
    "uid": "demoUser1",
    "name": "Alex",
    "ageBand": "24-30",
    "skinType": "combo",
    "reactivity": "balanced",
    "primaryConcern": "acne",
    "secondaryConcerns": ["hyperpigmentation"],
    "beginner": true,
    "timeCommitment": "5-15",
    "pregnancy": false,
    "allergens": ["fragrance"],
    "prefs": ["NonComedogenic"],
    "wearsMakeupDaily": true
  }' | jq
```
**Expected**: `{ "ok": true }` and `skinProfiles/demoUser1` document created

### 2. DeepScan Score Test
```bash
curl -s http://localhost:5001/freya-7c812/us-central1/api/deepscan/score \
  -H "Authorization: Bearer test" -H "Content-Type: application/json" \
  -d '{
    "uid": "demoUser1",
    "images": [
      "https://picsum.photos/seed/facefront/800/800",
      "https://picsum.photos/seed/faceleft/800/800", 
      "https://picsum.photos/seed/faceright/800/800"
    ],
    "emphasis": {
      "primary_concern": "acne",
      "secondary_concerns": ["hyperpigmentation"]
    }
  }' | jq
```
**Expected**: 
```json
{
  "scoreId": "ulid",
  "overall": 64,
  "subscores": {
    "barrierHydration": 58,
    "complexion": 60,
    "acneTexture": 45,
    "fineLines": 72,
    "eyes": 55
  },
  "confidence": 0.82
}
```

### 3. Report Generation Test
```bash
curl -s http://localhost:5001/freya-7c812/us-central1/api/report/generate \
  -H "Authorization: Bearer test" -H "Content-Type: application/json" \
  -d '{
    "uid": "demoUser1",
    "force": true
  }' | jq
```
**Expected**:
```json
{
  "reportId": "ulid",
  "routine": {
    "AM": [{"step": 1, "product": "AM Gel Cleanser"}],
    "PM": [{"step": 1, "product": "PM Gel Cleanser"}]
  }
}
```

### 4. Get Latest Report Test
```bash
curl -s http://localhost:5001/freya-7c812/us-central1/api/report/get-latest \
  -H "Authorization: Bearer test" -H "Content-Type: application/json" \
  -d '{"uid": "demoUser1"}' | jq
```
**Expected**: Most recent `skinReports/{uid}/items/*` document

## Technical Notes

### OpenAI Integration
- Use same pattern as existing functions (`productFit.ts`, `urlPicker.ts`)
- Version "4" with tools array for consistency
- Parse `output_text` field with JSON.parse() and fallback handling
- No structured outputs needed - use existing proven approach

### UID Handling
- Pass `uid` in request body for all endpoints
- No special headers needed (simpler than X-Debug-UID approach)
- Validate uid exists in request body for all operations

### Image Handling
- Use public HTTPS URLs for testing (emulator limitation)
- Later can integrate with Firebase Storage for production
- Stock portrait URLs work fine for development/testing

### Error Handling
- Graceful fallbacks for OpenAI API failures
- Validate required fields in request bodies
- Return appropriate HTTP status codes
- Log errors for debugging

### Success Criteria
1. ✅ Survey data saves to `skinProfiles/{uid}`
2. ✅ DeepScan produces realistic skin scores
3. ✅ Report generation creates both report and routine documents  
4. ✅ End-to-end flow: Survey → Scan → Report → Retrieve works
5. ✅ All endpoints testable via curl commands

## Future Enhancements
- Image upload to Firebase Storage
- User authentication integration
- Real-time progress updates
- Report history and versioning
- Routine customization and updates
