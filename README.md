# Freya — Handoff Brief (read this first)

## What it is (one line)

Freya is a mobile skincare app that onboards a user, performs an AI “DeepScan” of their face, generates/updates a personalized routine, tracks daily adherence and progress, and lets users look up products (by name or photo) without a prebuilt catalog—using OpenAI to fetch details, then caching them.

## Who it’s for

People who want a **simple, guided skincare journey**—from beginners to enthusiasts—who need: (a) quick product checks (is this safe for me?), (b) a routine that adapts, and (c) visible progress over weeks.

---

# Features (start → finish)

### 1) Onboarding

* Multi-step survey captures: age band, gender (optional), Fitzpatrick type, skin type, concerns, allergies, pregnancy/breastfeeding, preferences (vegan, non-comedogenic, etc.).
* Immediately after sign-up, user captures **3–4 face photos** (front/left/right/chin).
* We create an **onboarding DeepScan session** and upload the images.

### 2) DeepScan (AI skin scoring)

* We call an OpenAI vision prompt (you already have it) → returns a **Skin Score** and **5 sub-scores**:

  * Barrier & Hydration; Complexion (scars/pigmentation); Acne & Texture; Fine lines & Wrinkles; Eye bags & Dark circles.
* We store score + confidence and link it to the captured photos.
* Optional: user can take **daily pictures** to track change; you can score as often as you want.

### 3) Routine generation

* Using survey + latest score + your “report” prompt, Freya generates a **report** and turns it into a **Routine**.
* Routine is a **template with slots** (e.g., cleanser, moisturizer, sunscreen, retinoid); each slot has AM/PM, frequency (daily / X times per week / alternate), optional notes, and a `preference` (like/dislike/neutral).
* The routine can change weekly (we keep current routine; history optional).

### 4) Home (daily checklist)

* Materialize today’s **tasks** from the routine (product steps + wellness tasks).
* Each task can be `unchecked`, `completed`, or `skipped`. We show streaks.

### 5) Explore (no product DB up front)

* User types a name or snaps a product → we call an **OpenAI product fetcher** (prompt you have) to get **structured details** from the web.
* We **cache** that result as a “Product Snapshot”, **embed** the name/brand, and store the vector to support fuzzy search.
* Future searches use **vector KNN** to retrieve similar products by name even with typos/partial names.
* Product detail screen shows the cached snapshot (name, actives, INCI, pregnancy/allergen flags, price, how-to, images, links, similar products). User can mark as **owned** and like/dislike.

### 6) Progress

* Graph of scores over time; gallery of images; quick comparison.

### 7) Profile / Settings

* Profile picture, survey responses, subscription status flag, owned products, auth (email/password to start; add Apple/Google later).

### 8) Chat (v1 simple)

* A chat screen with your prompt (still to design) for skincare Q\&A using OpenAI.

---

# Tech stack (optimized for **speed**, with a path to scale & secure data)

**Mobile app**

* **Expo / React Native** with **Expo Router** (file-based navigation keeps screens simple).
* **TypeScript**.
* **TanStack Query** for **server state** (all Firestore/API reads/writes live in hooks; cache/invalidate done for you).
* **Zod** for **runtime validation** at every boundary (we parse OpenAI responses & Firestore docs before using them).
* **expo-image-picker** for MVP camera/photos (swap to VisionCamera later if you need frame processors).
* OTA updates via **EAS Update** (optional on day 1; helpful to hotfix JS without re-submitting binaries).

**Backend**

* **Firebase**:

  * **Auth** (email/password initially).
  * **Cloud Firestore** (documents/collections; includes **vector search/KNN** for fuzzy product search).
  * **Storage** (user images).
  * (Optional) **Cloud Functions** for small server helpers: product filtering, KNN wrapper if needed, nightly jobs.
* **OpenAI**:

  * Product fetcher (structured output JSON).
  * Embeddings for product name/brand & user queries.
  * DeepScan (vision prompt) → skin scores.
  * Report generator → routine template (slots + pacing).

> Priorities: 1) **ship fast**, 2) keep user data guarded (Auth-scoped reads/writes; later add App Check & rules), 3) leave room to grow (collections are stable; you can layer features without rewriting).

---

# Source tree (so the next dev knows where everything lives)

```
app/                          # Expo Router screens (routes only)
  (tabs)/index.tsx            # Home
  (tabs)/explore.tsx
  (tabs)/progress.tsx
  (tabs)/routine.tsx
  (tabs)/chat.tsx
  auth/                       # sign-in, onboarding steps incl. deepscan
  settings/
  _layout.tsx                 # providers/shell

src/
  services/                   # external integrations (no UI)
    firebase/                 # single init for Auth/Firestore/Storage
    api/                      # OpenAI & HTTP clients (product fetch, embeddings, deepscan, report)
    storage/                  # image upload helpers
  data/                       # server-state only
    schemas/                  # Zod schemas (our de-facto schema)
    queries/                  # TanStack Query hooks (Firestore/API)
    queryClient.ts
  features/                   # app logic modules (products, routine-gen, reports, deepscan)
  ui/                         # reusable dumb components (Button/Card/etc.)
  utils/                      # pure helpers (format/label/map)
```

* **Screens never talk to SDKs directly**. They call hooks from `src/data/queries/*` or helpers in `src/features/*`.
* **All network/AI** lives in `src/services/api/*`.
* **All Firestore/Storage** access goes through hooks in `src/data/queries/*`.
* **All shapes** are defined once in `src/data/schemas/*` and enforced with `zod.parse`.

---

# Database design (Firestore)

## Collections & example documents

### Users & profile

* **`users/{uid}`** — auth basics + subscription flag.
* **`skinProfiles/{uid}`** — onboarding answers (normalized), e.g.:

  ```json
  {
    "ageBand":"18-24","gender":"male","fitzpatrick":"IV","skinType":"oily",
    "concerns":["acne","hyperpigmentation"],"allergies":["fragrance"],
    "pregnancy":false,"preferences":{"vegan":true,"nonComedogenic":true},
    "updatedAt": 0
  }
  ```

### DeepScan sessions, images, and scores (time series)

* **`skinScanSessions/{uid}/items/{sessionId}`** — groups onboarding images + status.
* **`userImages/{uid}/items/{imageId}`** — metadata for uploaded photos (Storage path, URL, angle, createdAt).
* **`skinScores/{uid}/items/{scoreId}`** — one row per DeepScan:

  ```json
  {
    "overall":64,"barrierHydration":58,"complexion":60,
    "acneTexture":45,"fineLines":72,"eyes":55,
    "imageId":"img_ulid","confidence":0.82,"createdAt":0
  }
  ```

### Routine (current) and history

* **`routines/{uid}`** — the current routine (AM/PM arrays of slots):

  ```json
  {
    "routineScore":78,"templateVersion":3,
    "AM":[
      {"slotId":"am-cleanser","step":1,"slotType":"cleanser",
       "frequency":{"pattern":"daily"},
       "productRef":{"productId":"cerave_sa_cleanser","name":"CeraVe Renewing SA Cleanser"},
       "preference":"neutral","note":null}
    ],
    "PM":[
      {"slotId":"pm-retinoid","step":2,"slotType":"retinoid",
       "frequency":{"pattern":"weekly","timesPerWeek":2,"nonConsecutive":true},
       "productRef":{"productId":"pm_retinoid_low","name":"PM Retinoid (low)"},
       "preference":"neutral","note":"Apply to dry skin; wait 10–20 min"}
    ],
    "updatedAt":0
  }
  ```
* **`routineHistory/{uid}/{versionId}`** — (optional) weekly snapshots when the routine changes.

### Daily tasks (checklist)

* **`tasks/{uid}/items/{taskId}`** — generated from routine:

  ```json
  {
    "date":"2025-09-23","slotId":"am-spf","period":"AM",
    "title":"Apply AM Sunscreen SPF 30+ tinted",
    "status":"unchecked","completedAt":null,"createdAt":0
  }
  ```

### Product cache & vector index

* **`products/{productId}`** — **Product Snapshot** (cached from OpenAI):

  ```json
  {
    "name":"CeraVe Renewing SA Cleanser","brand":"CeraVe","category":"cleanser",
    "highlights":["2% SA","non-drying"], "ingredients":["Aqua","Salicylic Acid","Niacinamide","Ceramides"],
    "allergens":["fragrance"], "pregnancySafe":true,
    "price":{"amount":13.99,"currency":"USD"},"howToUse":"Massage onto wet skin...",
    "images":["https://..."], "websiteUrls":["https://brand.com/...","https://store.com/..."],
    "barcode":"3337875597380",
    "similar":[{"title":"Paula’s Choice 2% BHA","image":"https://...","price":{"amount":34,"currency":"USD"},"productId":"pc_2bha"}],
    "source":{"type":"openai","fetchedAt":0,"sourceUrl":"https://..."},
    "updatedAt":0
  }
  ```
* **`product_index/{id}`** — **vector row** for fuzzy search:

  ```json
  { "snapshotId":"cerave_sa_cleanser","name":"CeraVe Renewing SA Cleanser",
    "brand":"CeraVe","category":"cleanser","embedding":[ /* float32[] */ ] }
  ```

  Create a **KNN vector index** on `embedding`. Query = embed user text → nearest neighbors → hydrate `products`.

### Per-user product relationships

* **`userProducts/{uid}/{productId}`** — owned & preference:

  ```json
  { "owned":true,"preference":"like","addedAt":0,"lastUsedAt":0,"notes":"Travel size" }
  ```

> Pattern: **global** product data is cached once in `products/…`; **user-specific** things live under that user (ownership, likes). App reads are fast and cheap.

---

# Data we collect (explicit)

* **Profile/survey**: age band, gender (optional), Fitzpatrick, skin type, concerns, allergies, pregnancy/breastfeeding, preferences.
* **Images**: 3–4 onboarding images (front/left/right/chin); optional dailies.
* **Scores**: overall + 5 sub-scores + confidence + timestamps.
* **Routine**: AM/PM arrays of slots (slotId, slotType, step, frequency pattern, productRef {productId, name}, preference, note) + optional routineScore.
* **Tasks**: date, slotId, period, title, status, completedAt.
* **Products** (cached from web): name, brand, category, actives/highlights, full INCI, allergens, pregnancySafe, price, howToUse, images, URLs, barcode (if known), similar products, source {type, fetchedAt, sourceUrl}, updatedAt.
* **Vector index**: product name/brand embedding.
* **User–product**: owned, preference (like/dislike/neutral), notes.

---

# How the key flows work

## A) Product fetch → cache → vector index → search

1. User types a query or snaps a product.
2. `services/api/openai.ts` calls your prompt with **structured output** → JSON.
3. Validate with **Zod** and **cache** to `products/{productId}`.
4. Generate an **embedding** for “name + brand”; **store** as `product_index/{id}.embedding`.
5. On future searches: embed query → **KNN vector search** on `product_index` → hydrate product snapshots.
6. Product detail screen reads cached snapshot; user can mark as owned or like/dislike.

## B) DeepScan (onboarding & repeat)

1. Capture 3–4 images → upload to Storage; create a **scan session**.
2. Call OpenAI vision prompt; validate JSON.
3. Write `skinScores/{uid}/items/{scoreId}` (and optionally update session to `succeeded`).
4. Progress shows the new score; routine/report can react to trends.

## C) Report → routine → tasks

1. Call OpenAI “report” prompt with latest score/profile; validate.
2. `features/routine/materialize.ts` converts report → **Routine** doc.
3. Each day, generate **tasks** from the routine (client on first open or a small cron).
4. Home toggles task status; Progress can compute streaks from tasks.

---

# Where to put code (so the screens stay thin)

* **OpenAI & HTTP clients** → `src/services/api/*`
* **Firestore & Storage reads/writes** → `src/data/queries/*` (TanStack Query hooks)
* **Schemas** → `src/data/schemas/*` (Zod)
* **Feature logic** → `src/features/*` (deepscan, products, routine-gen, reports)
* **Screens** → `app/*` (routes only; compose hooks + present UI)

---

# Minimal guardrails (secure data, without slowing dev)

* Scope per-user reads/writes to their own `uid` paths (that’s your baseline rule).
* Avoid sensitive info in document IDs/field names.
* Keep secrets out of the client; server calls (if any) behind Functions.
* Parse every external payload with **Zod** before writing/using.
* Add App Check + tight Rules later when you’re past the first internal build.

---

# Minimal indexes (MVP)

* `skinScores/{uid}/items`: index `createdAt desc` (for charts).
* `tasks/{uid}/items`: index on `date` (optionally + `period`).
* `product_index`: **vector KNN** index on `embedding`.
* (Optional) `products`: index on `brand` for simple filters.

---

# Setup & dev order (fastest path)

1. Bootstrap Expo + Router; add Firebase init; wrap with TanStack Query.
2. Implement **Product fetch→cache→index→search** (it proves OpenAI/Firestore/vector).
3. Implement **DeepScan → score** (images + scoring).
4. Implement **Report → routine → daily tasks**.
5. Wire Profile/Settings + owned/likes + subscription flag.
6. Polish Explore detail + Home/Progress UIs.
7. Add Chat last (prompt TBD).
8. Optional: EAS Update, Analytics/Crashlytics.

---

Awesome—here’s your **updated, end-to-end plan** that bakes in the full **survey (Algorithm Inputs)**, **DeepScan**, **Skin Report**, and the rest of the app. It’s backend-first, minimal, and maps cleanly to your code layout and Firestore design. I’ll show what to build, in what order, where files live, what gets stored, and the simplest way to keep it secure and scalable **without** over-engineering.

---

# File layout we’re sticking to

```
app/                                # screens/routes only (Expo Router)
  (tabs)/index.tsx                  # Home (daily checklist)
  (tabs)/explore.tsx                # Product search
  (tabs)/progress.tsx               # Scores & photos
  (tabs)/routine.tsx                # View/edit routine
  (tabs)/chat.tsx                   # Chat
  auth/
    sign-in.tsx
    onboarding/                     # multi-step survey + DeepScan
      start.tsx
      goals.tsx
      concerns.tsx
      skinfeel.tsx
      acne-scar-branch.tsx
      reactivity.tsx
      deep-scan.tsx                 # 3–4 pics
      ethnicity.tsx
      pregnancy.tsx
      freeform.tsx
      routine-intake.tsx            # shelf photo / manual / none
      ingredient-sensitivities.tsx
      lifestyle.tsx
      budget-time.tsx
      makeup.tsx
      prefs.tsx
      location.tsx
      notifications.tsx
      review-submit.tsx
  settings/

src/
  services/
    firebase/                       # init
    api/                            # openai, embeddings, (optional) cloud funcs
    storage/                        # image upload
  data/
    queryClient.ts
    schemas/                        # Zod
      skinProfile.ts
      skinScore.ts
      product.ts
      routine.ts
      task.ts
      notificationPrefs.ts
    queries/                        # TanStack Query hooks
      skinProfile.ts
      scanSession.ts
      skinScores.ts
      products.ts
      productSearch.ts
      routine.ts
      tasks.ts
      prefs.ts
  features/
    deepscan/                       # image capture orchestration
    products/                       # fetch&cache, allow/deny label
    routine-gen/                    # report -> routine materializer
    reports/                        # present JSON report
  ui/                               # presentational components
  utils/                            # pure helpers (formatting, mapping)
```

---

# Firestore data model (recap, now with survey fields)

## Per-user current docs

* `users/{uid}`: email, displayName, photoURL, subscribed, createdAt, updatedAt
* `skinProfiles/{uid}` *(final merged survey answers)*:

  * `name`, `ageBand`, `gender?`
  * `goals[]` (multi-select “how do you want to use Freya”)
  * `mainConcern` (single) + `extraConcerns[]`
  * `skinFeel` (VeryDry|Dry|Combo|Oily|Neutral)
  * `acneFlags[]` (painful, inflamed, cycle-variant, active-worse, none)
  * `scarFlags[]` (raised, darkenWithSun, family, easyScarring, newActiveAlongScars, none)
  * `reactivity` (BreakoutProne|Sensitive|Balanced|Resistant)
  * `ethnicity` (enum list you provided)
  * `pregnancy` (boolean)
  * `freeformNotes` (string)
  * `routineIntake` (shelfPhoto|manual|none)
  * `ingredientSensitivities[]` (expanded list if “Yes”)
  * `lifestyle[]` (sunscreen, water, sleep, lowStress, sugar, dairy, exercise, none)
  * `budget` (Simple|Splurge|Premium)
  * `dailyTime` (<5, 5-15, 15-30, >30)
  * `wearsMakeupDaily` (boolean)
  * `prefs[]` (FattyAlcoholFree, FungalAcneSafe, NonComedogenic, OilFree, ParabenFree, SiliconeFree, SulfateFree, Vegan, AlcoholFree, CrueltyFree, EUAllergenFree, OpenToAnything)
  * `locationPrefs?` (if you capture region for store links)
  * `notificationPrefs` (routineReminders: boolean, paymentReminders: boolean, schedule?: {hour, tz})
  * `updatedAt`

> All survey steps write to a local form; on final submit, consolidate into **one** `skinProfiles/{uid}` document. Keep it **flat** and normalized—easy to query and update.

## Time-series & session collections

* `skinScanSessions/{uid}/items/{sessionId}`: { phase: 'onboarding'|'repeat', angles\[], images\[], status, createdAt, scoreId? }
* `userImages/{uid}/items/{imageId}`: { storagePath, url, angle?, createdAt }
* `skinScores/{uid}/items/{scoreId}`: { overall, barrierHydration, complexion, acneTexture, fineLines, eyes, imageId?, confidence?, createdAt }

## Routine & tasks

* `routines/{uid}`: **current** routine with AM/PM slot arrays (slotId, slotType, step, frequency, productRef{productId,name}, preference, note), optional `routineScore`, `templateVersion`, `updatedAt`
* `routineHistory/{uid}/{versionId}`: (optional) snapshots when routine changes
* `tasks/{uid}/items/{taskId}`: { date: 'YYYY-MM-DD', slotId, period: AM|PM|Any, title, status: unchecked|completed|skipped, completedAt?, createdAt }

## Product cache & vector index

* `products/{productId}`: Product Snapshot (OpenAI-extracted): { name, brand, category, highlights\[], ingredients\[], allergens\[], pregnancySafe?, price, howToUse, images\[], websiteUrls\[], barcode?, similar\[], source{type,fetchedAt,sourceUrl}, updatedAt }
* `product_index/{id}`: { snapshotId, name, brand, category, embedding: float\[] }  ← **KNN vector index** on `embedding`
* `userProducts/{uid}/{productId}`: { owned, preference: like|dislike|neutral|null, notes?, addedAt, lastUsedAt? }

---

# Minimal Zod schemas you’ll want (names only here)

* `SkinProfile`, `SkinScore`, `Routine`, `Task`, `ProductSnapshot`, `ProductIndexEntry`, `NotificationPrefs`.
* Each step of onboarding maps to fields in `SkinProfile`. You **parse** any external JSON (OpenAI) and any Firestore reads.

---
Here's the onboarding survey by the way:
1. What is your name?
2. Age?
3. Gender?
4. **How do you want to use** *Freya***?**
    
    *This will help Freya shape your experience. Select all that apply.*
    
    - I want to improve my skin & confidence
    - I don’t have a routine and would like you to help me create one.
    - I want to improve my current routine
    - I want to save money on products
    - Scan products to find reviews and information
    - I just want to have fun!
5. **What is your main skincare concern?**
    - Acne
    - Aging
    - Scarring
    - Oiliness
    - Dryness
    - Dark circles
    - Eye bags
    - Fine lines & wrinkles
    - Enlarged pores / Blackheads
    - Redness / Rosacea
    - Hyperpigmentation / Dark Spots
    - None
6. Do you have more skincare concerns?
    
    Select as many as you want : ) 
    
    - Acne
    - Scarring
    - Oiliness
    - Dryness
    - Dark circles
    - Eye bags
    - Fine lines & wrinkles
    - Enlarged pores
    - Redness
    - Hyperpigmentation
    - None
7. **How does your skin feel on a typical day?**
- Very Dry — Flaky, rough patches, can’t moisturize enough.
- Dry — Tight or rough or white dry areas in some spots.
- Combination — Some areas dry, others shiny.
- Oily — Shiny or greasy most of the time.
- Neutral — None of the above.
1. **Select all that apply to you.**
    - My skin feels swollen or painful to the touch
    - My skin feels inflamed or I have hard bumps
    - My skin varies with my cycle
    - I am experiencing a worse than usual breakout
    - None of the above
2. **Select all that apply to you.**
    - I notice raised scars after skin damage heals
    - My scars get darker with sun exposure
    - Others in my family (e.g., parents, siblings) experience scars similar to mine
    - I get scars even after minor breakouts
    - I have new active acne along with my existing scarring
    - None of the above

10. **How does your skin react to new products?**

- Breakout Prone — My skin usually breaks out with new products.
- Sensitive — My skin reacts with irritation or itchiness.
- Balanced — Sometimes my skin reacts with new products, but it’s very manageable.
- Resistant — My skin rarely reacts to new products.
1. **Ok, let’s do this!**
- In order to best help with your skin, Freya needs to take a few photos to perform a facial analysis.
- [Button] Let’s get started
1. DeepScan (4 pictures) - while we’re calculating your facial scores, we need to ask you just a  few more questions for the best results
    1. Also get the skin tone / ethnicity in the background
2. **What is your ethnicity and background?**

*This helps Freya understand how your skin might react to certain products, treatments, and ingredients like strong acids.*

- White / Caucasian
- East Asian
- South Asian
- Hispanic / Latino
- Middle Eastern / North African
- Black / African American
- Indigenous / Native
1. **Are you pregnant or breastfeeding?**

*Certain ingredients have not been tested on those who are pregnant or breastfeeding, so we will exclude those from your recommendations.*

- Yes
- No
1. **Please share any details about your concerns or specific questions you want answered.**

*The more detail, the better*

- [Textbox Example] I started getting acne 2 months ago
- [Textbox Example] "I started breaking out a few weeks ago"
1. **Ok, we’re almost done.**

*We need to know about your current routine and products before we show you your Skin Report*

- Take a photo of my bathroom shelf 📸
    
    *This is easier, and more fun!*
    
- I’ll type them in 😊
    
    *Slower, but works if you aren’t near your products.*
    
- I use no products at all
    
    *We’ll create your routine from scratch!*
    
1. **Do you breakout or have sensitivities to any particular skincare ingredients?**
- Yes
- No
1. Branching question - which ones
2. **Select all that apply to you.**

*Lifestyle factors can be a key contributor to some skincare concerns.*

- I wear sunscreen every day
- I drink at least 8 glasses of water every day
- I get 7-8 hours of sleep on most nights
- My stress levels are under control
- I consume processed sugar several times per week
- I consume dairy several times per week
- I exercise / sweat everyday
- None of the above
1. **How much do you prefer to invest in skincare?**
- I prefer the simplest products that work
- I am willing to splurge on effective products
- I prefer to always get premium products
1. How much time do you want to invest daily?
- < 5mins
- 5 - 15 mins
- 15 - 30 mins
- > 30 mins
1. Do you wear makeup or heavy SPF sunscreen daily?
- Yes
- No
1. **Please select your skincare preferences.**
- Fatty Alcohol Free
- Fungal Acne Safe
- Non-comedogenic
- Oil Free
- Paraben Free
- Silicone Free
- Sulfate Free
- Vegan
- Alcohol Free
- Cruelty Free
- EU Allergen Free
- Fatty Alcohol Free
- Fungal Acne Safe
- Non-comedogenic
- Oil Free
- Paraben Free
- Open to anything!

Location Prefs

**Skin Report: [generated by making the user take some face pics] **

- Skin Score
    - Barrier and Hydration
    - Complexion [scars, uneven pigmentation, hyper pig]
    - Acne and Texture
    - Fine lines and wrinkles
    - Eye bags and dark circles


Swift Module for Face Mesh, implementation, and how we got a sparse mesh unlike iOS default implementation, full code and logic below: 

# ARKit Face Mesh Implementation: From Dense to Sparse

This document explains how we created a sparse, customizable face mesh overlay using Apple's ARKit framework. If you're new to iOS development or ARKit, this guide will walk you through everything from the basics to our final implementation.

## Table of Contents
1. [What is ARKit?](#what-is-arkit)
2. [Understanding Face Tracking](#understanding-face-tracking)
3. [The Problem: Dense Face Mesh](#the-problem-dense-face-mesh)
4. [Our Journey: Multiple Approaches](#our-journey-multiple-approaches)
5. [Final Solution: Region-Weighted K-Means](#final-solution-region-weighted-k-means)
6. [Code Breakdown](#code-breakdown)
7. [Key Learnings](#key-learnings)

## What is ARKit?

ARKit is Apple's augmented reality framework that uses the device's camera, motion sensors, and machine learning to track the real world and overlay digital content. For face tracking, ARKit uses the front-facing camera and specialized hardware (TrueDepth camera on newer devices) to create a detailed 3D model of the user's face in real-time.

### Key ARKit Components:

- **ARSession**: Manages the AR experience and coordinates between different components
- **ARFaceTrackingConfiguration**: Tells ARKit to track faces instead of world tracking
- **ARFaceAnchor**: Contains the 3D face data (geometry, transform, expressions)
- **ARFaceGeometry**: The actual mesh data with ~1,220 vertices and ~2,000 triangles

## Understanding Face Tracking

When ARKit tracks your face, it provides:

```swift
let faceAnchor = anchor as? ARFaceAnchor
let geometry = faceAnchor.geometry

// Raw data ARKit gives us:
let vertices = geometry.vertices      // ~1,220 3D points (SIMD3<Float>)
let uvs = geometry.textureCoordinates // UV mapping (SIMD2<Float>)
let triangles = geometry.triangleIndices // How vertices connect (Int16)
```

**The Problem**: ARKit's default mesh is extremely dense - designed for realistic face reconstruction, not sparse overlay graphics.

## The Problem: Dense Face Mesh

Our goal was to create a sparse wireframe overlay (like sci-fi face scanning effects), but ARKit gives us this:

- **1,220+ vertices**: Far too many points
- **2,000+ triangles**: Creates a dense, overwhelming mesh
- **Uneven distribution**: More detail around eyes/mouth, but still too dense everywhere

We needed maybe 200-300 well-distributed points instead.

## Our Journey: Multiple Approaches

### Approach 1: Simple Vertex Subsampling
```swift
// Take every 8th vertex
let keepIdx = Array(stride(from: 0, to: vertices.count, by: 8))
```
**Problem**: Created "star patterns" - vertices clustered in some areas, gaps in others.

### Approach 2: Poisson Disk Sampling
```swift
// Ensure minimum distance between selected points
func poissonSample(points: [SIMD2<Float>], radius: Float) -> [Int]
```
**Problem**: Still created uneven distribution, some clustering remained.

### Approach 3: Uniform K-Means
```swift
// Use clustering to find representative points
func kmeansSubsample(uvs: [SIMD2<Float>], k: Int) -> [Int]
```
**Better**: More uniform distribution, but forehead appeared too dense visually.

### Approach 4: Region-Weighted K-Means (Final Solution)
Separate the face into regions and apply different densities:
- **Forehead**: 50% fewer points than proportional
- **Rest of face**: Normal density
- **Triangulate**: Use Delaunay triangulation to connect points

## Final Solution: Region-Weighted K-Means

Our final approach solves the density problem by treating different face regions separately:

```swift
// 1. Split face into regions based on UV coordinates
func foreheadMask(_ uv: SIMD2<Float>) -> Float {
    let t = smoothstep(0.78, 0.82, uv.y)  // Forehead is upper face
    return clamp(t, 0, 1)
}

// 2. Allocate fewer points to forehead
let kF = max(4, Int(round(0.5 * kF_prop)))  // 50% reduction

// 3. Run separate K-means on each region
let keepF = kmeansSubsampleSubset(uvs: uvs, subset: idxForehead, k: kF_final)
let keepR = kmeansSubsampleSubset(uvs: uvs, subset: idxRest, k: kR_final)

// 4. Merge and triangulate
self.keepIdx = keepF + keepR
let triangles = delaunay(points: keptUV)
```

## Code Breakdown

Let's examine the key parts of our implementation:

### 1. SwiftUI Integration
```swift
struct ARFaceViewContainer: UIViewRepresentable {
    func makeUIView(context: Context) -> ARSCNView {
        let v = ARSCNView(frame: .zero)
        v.delegate = context.coordinator
        // Configure AR session for face tracking
        let cfg = ARFaceTrackingConfiguration()
        v.session.run(cfg)
        return v
    }
}
```
**Why**: SwiftUI can't directly use ARKit, so we wrap ARSCNView in `UIViewRepresentable`.

### 2. Face Tracking Delegate
```swift
func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
    guard let fa = anchor as? ARFaceAnchor else { return }

    // First time: create sparse mesh
    if remesh == nil {
        remesh = Remesher(faceGeo: fa.geometry, targetSampleCount: 260)
        node.geometry = remesh!.makeGeometry(from: fa.geometry)
    }

    // Every frame: update vertex positions
    if let g = remesh?.updateGeometryVertices(geometry: node.geometry, with: fa.geometry) {
        node.geometry = g
    }
}
```
**Why**: ARKit calls this 60 times per second with updated face data. We create the sparse pattern once, then just update vertex positions.

### 3. Region Detection
```swift
func foreheadMask(_ uv: SIMD2<Float>) -> Float {
    // ARKit UV coordinates: (0,0) = bottom-left, (1,1) = top-right
    // Forehead is roughly v ∈ [0.78, 1.0]
    let t = smoothstep(0.78, 0.82, uv.y)
    return clamp(t, 0, 1)
}
```
**Why**: UV coordinates let us identify face regions. `smoothstep` creates soft boundaries instead of hard edges.

### 4. K-Means Clustering
```swift
func kmeansSubsampleSubset(uvs: [SIMD2<Float>], subset: [Int], k: Int) -> [Int] {
    // 1. Seed centroids in a grid pattern for coverage
    let grid = Int(ceil(sqrt(Double(k))))

    // 2. Lloyd iterations: assign points to nearest centroid, update centroids
    for _ in 0..<maxIters {
        // assign step
        for i in 0..<m {
            let p = pts[i]
            for (j, c) in centroids.enumerated() {
                let d = simd_length_squared(p - c)
                if d < bd { bd = d; best = j }
            }
        }
        // update step
        centroids[j] = sum[j] / Float(cnt[j])
    }

    // 3. Snap each centroid to nearest actual vertex
    return out.append(subset[bestIdxLocal])
}
```
**Why**: K-means finds the most representative points in each region. Grid seeding ensures coverage, Lloyd iterations optimize placement.

### 5. Delaunay Triangulation
```swift
func delaunay(points: [SIMD2<Float>]) -> [(Int,Int,Int)] {
    // Bowyer-Watson algorithm
    // 1. Create super-triangle containing all points
    // 2. For each point: find triangles whose circumcircle contains the point
    // 3. Remove bad triangles, add new triangles from point to polygon boundary
    return triangles.map { ($0.a,$0.b,$0.c) }
}
```
**Why**: Delaunay triangulation creates the most "natural" connections between points, avoiding long skinny triangles.

### 6. Visual Enhancement: Vertex Dots
```swift
func makeVertexDotNode() -> SCNNode? {
    let parent = SCNNode()
    for _ in keepIdx {
        let plane = SCNPlane(width: dotSize, height: dotSize)
        plane.cornerRadius = dotSize * 0.5  // Makes it circular
        let n = SCNNode(geometry: plane)
        n.constraints = [SCNBillboardConstraint()]  // Always faces camera
        parent.addChildNode(n)
    }
    return parent
}
```
**Why**: Adds bright dots at vertices for a "sci-fi scanner" effect. Billboard constraint makes dots always face the camera.

## Key Technical Details

### UV Coordinate System
- ARKit uses UV coordinates (0,0) to (1,1) to map 2D texture space to 3D face
- **(0,0)** = bottom-left of face, **(1,1)** = top-right
- **Forehead** ≈ v ∈ [0.78, 1.0] (upper 22% of face)
- **Cheeks** ≈ u ∈ [0.6, 0.96] (sides of face)

### Performance Considerations
- **Sparse sampling**: 260 points vs 1,220 (78% reduction)
- **Cached geometry**: Only recompute sparse pattern once, update positions each frame
- **Efficient triangulation**: Delaunay is O(n log n), acceptable for ~260 points

### Material Properties
```swift
let m = SCNMaterial()
m.lightingModel = .constant          // No 3D lighting
m.emission.contents = UIColor.white  // Self-illuminated
m.transparency = 0.88                // Semi-transparent
m.writesToDepthBuffer = false        // Don't block objects behind
```
**Why**: Creates a glowing overlay effect that doesn't interfere with other 3D objects.

## Swift Language Gotchas We Hit

### 1. Ternary Operator Mutability
```swift
// ❌ This fails - ternary result is immutable
(condition ? array1 : array2).append(item)

// ✅ This works - explicit branching
if condition {
    array1.append(item)
} else {
    array2.append(item)
}
```

### 2. Array Prefix Method Ambiguity
```swift
// ❌ Ambiguous - could be prefix(while:) or prefix(_:)
let kept = arr.prefix(keepCount)

// ✅ Explicit type conversion
let kept = Array(arr.prefix(keepCount))
```

## Tuning Parameters

You can adjust these values to change the mesh appearance:

```swift
// Density control
targetSampleCount: 260        // Total points (lower = sparser)

// Region weighting
let kF = Int(round(0.5 * kF_prop))  // 0.5 = 50% forehead reduction

// Forehead detection
smoothstep(0.78, 0.82, uv.y)  // Adjust bounds to change forehead area

// Visual effects
addVertexDots: true           // Toggle bright vertex dots
dotSize: 0.0022              // Size of vertex dots
transparency: 0.88           // Mesh opacity
```

## Results

Our final implementation achieves:
- ✅ **Sparse mesh**: ~260 points instead of 1,220+
- ✅ **Uniform distribution**: No clustering or gaps
- ✅ **Reduced forehead density**: 50% fewer points in forehead area
- ✅ **Real-time performance**: 60 FPS face tracking
- ✅ **Visual enhancement**: Optional bright vertex dots
- ✅ **Customizable**: Easy parameter tuning

The mesh isn't perfect - true uniform distribution would require more complex algorithms - but it achieves the goal of a clean, sparse overlay suitable for AR effects.

## Future Improvements

1. **Adaptive density**: Adjust point count based on face size/distance
2. **Expression awareness**: Modify point distribution based on facial expressions
3. **Temporal stability**: Reduce jitter by tracking points across frames
4. **Multiple face support**: Handle multiple faces simultaneously
5. **Custom region masks**: Allow user-defined density regions

This implementation demonstrates how to take ARKit's dense face data and create customized sparse visualizations suitable for AR applications.
