<!-- 94f4076b-9ac2-477e-a625-fc108e273a84 ac322387-3da3-48f7-be02-c0cc80f34689 -->
# Navbar + Home Screen Only (SwiftUI) in Separate Worktree

## Git Worktree (no conflicts)

```bash
# from repo root (/Users/bprithvi/Desktop/freya/freya)
git fetch origin
mkdir -p /Users/bprithvi/Desktop/freya/worktrees
git worktree add -b feature/navbar-home \
  /Users/bprithvi/Desktop/freya/worktrees/navbar-home origin/main
```

## Chronological Implementation Order

1. Create worktree and branch.
2. Seed minimal Firestore data for a test user (prereq):

   - `users/{uid}/routineTemplate` with 3–5 steps (Cleanser, Serum, Sunscreen...).
   - `users/{uid}/reports/latest` with `{ score, subScores, date }`.
   - Options:
     - a) Console: add docs manually (fastest for first run).
     - b) Script (recommended): one-off Admin script to write the docs.
     - c) Emulator + curl: seed to localhost if testing offline.

3. Scaffold `TabView` with five tabs; set Home as initial.
4. Build `HomeView` layout: placeholder score card + empty routine list.
5. Implement `RoutineStep` model and `RoutineViewModel`:

   - Read `routineTemplate` once.
   - Listen to `routineDaily/{yyyy-MM-dd}`; create doc on first write.
   - Toggle uses `arrayUnion/arrayRemove` for `stepsCompleted`.

6. Hook `RoutineView` UI to ViewModel; show images, names, and a circular check.
7. Implement `ScoreHeaderView` pulling `reports/latest` (or a tiny mock if missing).
8. Wire entry point: after sign-in, present `MainTabView`.
9. Manual QA: verify live updates across two devices/simulators; confirm day rollover.

## Authoritative schema from codebase

Code references for documents we need:

```166:175:/Users/bprithvi/Desktop/freya/freya/freya-backend/functions/src/routes/report.ts
// Write current routine (materialized from report)
await db.collection("routines").doc(uid).set({
  ...routine,
  templateVersion: 1,
  updatedAt: FieldValue.serverTimestamp()
}, { merge: true });
```



```75:82:/Users/bprithvi/Desktop/freya/freya/freya-backend/functions/src/routes/deepScan.ts
// Stored skin score document shape
await db.collection("skinScores").doc(uid).collection("items").doc(scoreId).set({
  skin_score_total_0_100: scoreResult.skin_score_total_0_100,
  subscores: scoreResult.subscores,
  confidence_0_100: scoreResult.confidence_0_100,
  full_analysis: scoreResult.full_analysis,
  createdAt: FieldValue.serverTimestamp()
});
```

From design docs (routines richer variant permitted):

```159:176:README.md
// routines/{uid}
{
  "routineScore":78,
  "templateVersion":3,
  "AM":[{"slotId":"am-cleanser","step":1,"slotType":"cleanser","frequency":{"pattern":"daily"},"productRef":{"productId":"cerave_sa_cleanser","name":"CeraVe Renewing SA Cleanser"},"preference":"neutral","note":null}],
  "PM":[{"slotId":"pm-retinoid","step":2,"slotType":"retinoid","frequency":{"pattern":"weekly","timesPerWeek":2,"nonConsecutive":true},"productRef":{"productId":"pm_retinoid_low","name":"PM Retinoid (low)"},"preference":"neutral","note":"Apply to dry skin; wait 10–20 min"}],
  "updatedAt":0
}
```

Minimum viable routine the backend already handles today:

- `routines/{uid}` with fields:
  - `AM: [ { step: number, product: string, note? } ]`
  - `PM: [ { step: number, product: string, note? } ]`
  - optional `templateVersion`

Skin score for Home header:

- `skinScores/{uid}/items/{scoreId}` with fields shown above.

We do not currently have a daily checklist collection in repo; if we need live completion, add:

- `routineDaily/{uid}/{yyyy-MM-dd}` with `{ stepsCompleted: [slotId|string] }` (new, client-owned).

- Template:
  - `users/{uid}/routineTemplate`:
    - `steps: [ { slotId, slotOrder, stepName, productId, productName, brand, imageUrl } ]`
- Daily:
  - `users/{uid}/routineDaily/{yyyy-MM-dd}`:
    - `stepsCompleted: [slotId]`, optional `completedAt`.
- Score:
  - `users/{uid}/reports/latest`:
    - `score: Int`, `subScores: { hydration, complexion, acneTexture, wrinkles, darkCircles }`, `date`.

## One-off Seeder Options

- Admin Script (recommended for cloud/dev project):
```bash
# pseudo-commands (do not run yet)
cd freya-backend/functions
# create seedRoutine.ts using Firebase Admin to write the three docs
# run with GOOGLE_APPLICATION_CREDENTIALS and ts-node
```

- Emulator curl example (adapt to your projectId and uid):
```bash
# Example for routineDaily doc creation
curl -X PATCH "http://localhost:8080/v1/projects/PROJECT_ID/databases/(default)/documents/users/TEST_UID/routineDaily/2025-10-11" \
  -H 'Content-Type: application/json' \
  -d '{"fields":{"stepsCompleted":{"arrayValue":{"values":[{"stringValue":"cleanser"}]}}}}'
```


## UX Notes

- SF Symbols: Home `house.fill`, Products `bag.fill`, Chat `ellipsis.bubble.fill`, Progress `chart.bar.fill`, Profile `person.fill`.
- Routine row: 56×56 image (rounded 12), step name + product title; right-aligned circular check.
- Tiny progress text above list like "2/4 done today".

## Acceptance Criteria

- Tab bar visible; Home functional.
- Score card shows latest score (real doc or mock).
- Routine list renders from `routineTemplate` with product images.
- Tapping a step persists immediately to `routineDaily/{today}` and reflects in UI; state survives app restart.
- All work isolated to feature worktree; `main` remains untouched until PR.

### To-dos

- [ ] Create Git worktree and feature branch for mobile nav + home
- [ ] Add TabView with five tabs and stub views
- [ ] Implement Skin Score header using existing ApiClient or mock
- [ ] Define RoutineStep model and template source
- [ ] Implement RoutineViewModel with Firestore live sync
- [ ] Build Routine list UI with images and checkbox
- [ ] Show MainTabView after sign-in; keep onboarding path intact
- [ ] Create Progress tab stub reading daily completion count
- [ ] Run with Firebase Emulator or dev project and test live updates
- [ ] Open PR from feature branch; no direct changes to main



