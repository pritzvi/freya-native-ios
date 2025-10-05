# DeepScan Implementation Plan

## Overview
Implement facial analysis feature using ARKit for guided photo capture. User takes 4 photos (front, left side, right side, from below) after Question 7 in onboarding flow.

## Step-by-Step Incremental Plan

### **Phase 1: Basic Camera Integration**
**Goal:** Test basic camera functionality
**Deliverable:** Can user take photos?

1. **Create `DeepScanView.swift`** - Basic camera view
2. **Add camera permissions** - Info.plist camera usage description  
3. **Simple camera capture** - Take one photo using `UIImagePickerController`
4. **Test:** Can user take a photo and see it displayed?

### **Phase 2: Multi-Photo Flow** 
**Goal:** Guide user through 4-photo sequence
**Deliverable:** Complete photo capture flow

1. **Add photo sequence logic** - Track which photo (1/4, 2/4, etc.)
2. **Add instruction prompts** - "Take front photo", "Turn left", etc.
3. **Photo preview & retake** - Show captured photo, allow retake
4. **Test:** Can user complete all 4 photos with proper guidance?

### **Phase 3 & 4: ARKit Face Detection + Guided Capture (Combined)**
**Goal:** ARKit-guided photo capture with face positioning
**Deliverable:** Smart camera that validates face position
**Reference:** Check `README.md` for ARKit implementation details, sparsely distributed vertices syntax, and visual guidance patterns

1. **Add ARKit framework** - Basic ARFaceTrackingConfiguration
2. **Face detection overlay** - Show face mesh/vertices (sparse) as per README.md
3. **Face position validation** - Ensure face is centered, proper distance
4. **Combine ARKit with camera** - ARKit for guidance, camera for capture
5. **Position validation** - Only allow photo when face is properly positioned
6. **Angle detection** - Detect front vs side vs below angles
7. **Test:** Does the guided capture work for all 4 angles with proper face detection?

### **Phase 5: Firebase Storage**
**Goal:** Save captured photos to cloud storage
**Deliverable:** Photos persisted in Firebase

1. **Firebase Storage setup** - Configure storage rules
2. **Image upload logic** - Compress and upload 4 images
3. **Progress indicators** - Show upload progress
4. **Test:** Are all 4 photos saved to Firebase Storage correctly?

**Storage Structure:**
```
deepScanImages/{uid}/{sessionId}/
├── front.jpg
├── left.jpg  
├── right.jpg
└── below.jpg
```

### **Phase 6: Integration with Onboarding**
**Goal:** Seamless integration into existing onboarding flow
**Deliverable:** Complete onboarding with DeepScan

1. **Insert after Question 7** - Modify onboarding flow
2. **Navigation logic** - DeepScan → Continue to Question 8
3. **Data persistence** - Store image URLs in onboarding data
4. **Test:** Complete onboarding flow with DeepScan included

### **Phase 7: Polish & Error Handling**
**Goal:** Production-ready experience
**Deliverable:** Robust, user-friendly feature

1. **Error states** - Camera permission denied, upload failures
2. **Loading states** - Uploading indicators, processing states  
3. **Retry logic** - Retake photos, retry uploads
4. **Test:** Handle all error scenarios gracefully

## Technical Requirements

### **ARKit Requirements:**
- iOS 11+ (face tracking needs A12+ for best results)
- Front-facing TrueDepth camera for face mesh
- Privacy permissions for camera

### **Photo Capture Sequence:**
1. **Front face** - Straight on, centered
2. **Left side** - 90° left profile
3. **Right side** - 90° right profile  
4. **From below** - Slight upward angle

### **Integration Points:**
- Insert between Question 7 and 8 in onboarding flow
- Store image URLs in `OnboardingData` for later backend processing
- Maintain same navigation/progress patterns as other onboarding questions

## Testing Strategy
Each phase builds incrementally:
1. **Basic camera** → 2. **Multi-photo** → 3-4. **ARKit + Guided capture** → 5. **Storage** → 6. **Integration** → 7. **Polish**

## Future Backend Integration
- Later connect to backend API for DeepScan processing
- Images will be processed using OpenAI Vision API
- Results stored in `skinScores/{uid}` collection
- For now, just store images and continue onboarding flow

## Implementation Notes
- **Reference README.md** for ARKit face detection implementation details
- Use sparsely distributed vertices as specified in README.md
- Follow existing onboarding UI patterns for consistency
- Maintain same error handling and loading state patterns
