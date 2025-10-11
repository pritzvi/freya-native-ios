# Phase 0 & 1 Implementation Summary

## Completed: Backend API Integration for Survey & DeepScan

### What Changed

#### 1. Created `ApiClient.swift` (NEW)
- Centralized HTTP client for all backend API calls
- Handles Firebase Auth token management
- Implements:
  - `submitDeepScan(uid:images:emphasis:)` → POST `/api/deepscan/score`
  - `saveSurvey(uid:surveyData:)` → POST `/api/survey/save`
- Uses async/await with URLSession
- Proper error handling with custom `APIError` enum
- Base URL: `http://127.0.0.1:5001/freya-7c812/us-central1/api` (TODO: update for production)

#### 2. Updated `OnboardingCoordinator.swift`
**Removed:**
- Firebase Firestore direct writes
- `import FirebaseFirestore`

**Added:**
- `submitDeepScan()` method - Fire-and-forget API call with placeholder image URL
- `deepScanSubmitted` published property for tracking status
- Updated `saveOnboardingData()` to call backend API instead of Firestore

**Flow:**
- DeepScan: Non-blocking, user continues immediately
- Survey save: Blocking with loading state, navigates on success

#### 3. Updated `DeepScanView.swift`
**Added:**
- `@EnvironmentObject var coordinator: OnboardingCoordinator`
- "Continue" button now calls `coordinator.submitDeepScan()` before `onNext()`
- User sees no delay - DeepScan processes in background

### API Endpoints Used

#### POST `/api/deepscan/score`
```json
Request: {
  "uid": "string",
  "images": ["url", "url", "url", "url"],
  "emphasis": "onboarding"
}

Response: {
  "scoreId": "string",
  "overall": 70,
  "subscores": {...},
  "confidence": 95
}
```

#### POST `/api/survey/save`
```json
Request: {
  "uid": "string",
  ...all survey fields
}

Response: {
  "ok": true,
  "message": "Survey saved successfully"
}
```

### Temporary Placeholder
- Using Unsplash image URL for all 4 DeepScan images: 
  `https://plus.unsplash.com/premium_photo-1683140815244-7441fd002195?q=80&w=774&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D`
- TODO: Replace with actual captured photos + Firebase Storage signed URLs

### User Experience Flow
1. User answers Q1-Q7
2. **DeepScan (Q11)**: Take 4 photos → Tap "Continue" → DeepScan submits in background → User immediately sees Q12
3. User answers Q12-Q21
4. **End of survey**: "Saving your profile..." → Backend API call → Navigate to welcome screen
5. By this time, DeepScan has likely completed and results are in Firestore

### Data Persistence
- **Survey data**: `skinProfiles/{uid}` (via backend)
- **DeepScan session**: `skinScanSessions/{uid}/items/{sessionId}` (via backend)
- **DeepScan score**: `skinScores/{uid}/items/{scoreId}` (via backend)

### Next Steps (Not Implemented Yet)
- Phase 2: Report generation (`POST /api/report/generate`)
- Phase 3: Product finding (`POST /api/report/find-products`)
- Phase 4: Replace placeholder images with actual Firebase Storage uploads + signed URLs
- Phase 5: Update `baseURL` for production deployment

### Testing
To test locally:
1. Ensure Firebase emulators are running
2. Backend functions running on port 5001
3. Run iOS app and complete onboarding
4. Check console logs for "DeepScan submitted successfully" and "Survey saved"
5. Verify Firestore collections in emulator UI

