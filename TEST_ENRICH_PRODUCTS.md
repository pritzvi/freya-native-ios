# Test `/report/enrich-products` Endpoint

## Prerequisites

1. You need an existing report with `productRecommendations` populated
2. Get `uid` and `reportId` from Firestore or from previous API calls

## Step 1: Verify you have a report with products

Check Firestore:
```
skinReports/{uid}/items/{reportId}
```

Should have:
- `productRecommendations.AM_step_1.products` (array of products with names)
- Each product has: `product_name`, `note_on_recommendation`, `key_ingredients`
- Products do NOT have `productId` or `imageUrl` yet

## Step 2: Call enrich-products

```bash
curl -X POST https://us-central1-freya-7c812.cloudfunctions.net/api/report/enrich-products \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  -d '{
    "uid": "demoUser1",
    "reportId": "YOUR_REPORT_ID_HERE"
  }'
```

**Expected wait time**: 50-60 seconds

## Step 3: Verify response

Expected response structure:
```json
{
  "success": true,
  "enrichedProducts": {
    "AM_step_1": {
      "stepInfo": {...},
      "products": [
        {
          "product_name": "Hada Labo Tokyo Skin Plumping Gel Cleanser",
          "note_on_recommendation": "...",
          "key_ingredients": [...],
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
  "status": "complete"
}
```

## Step 4: Verify Firestore update

Check Firestore again:
```
skinReports/{uid}/items/{reportId}
```

Should now have:
- `productRecommendations.AM_step_1.products[0].productId` ✅
- `productRecommendations.AM_step_1.products[0].imageUrl` ✅
- `enrichmentStatus: "complete"` ✅
- `enrichmentCompletedAt: <timestamp>` ✅

## Step 5: Test image URL

Copy one `imageUrl` from the response and test in browser or curl:

```bash
curl "https://us-central1-freya-7c812.cloudfunctions.net/api/products/hada-labo-tokyo-hada-labo-tokyo-skin-plumping-gel-cleanser/images/0"
```

Should return an image or redirect to an image URL.

## Step 6: Test idempotency

Re-run the same curl command. Should complete faster (~10-20s) because:
- Products already exist in `products` collection
- Vector cache will hit for most products
- Only needs to update Firestore

## Error Test Cases

### Test 1: Missing reportId
```bash
curl -X POST https://us-central1-freya-7c812.cloudfunctions.net/api/report/enrich-products \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  -d '{"uid": "demoUser1"}'
```
Expected: `{"error":"uid and reportId required"}`

### Test 2: Report not found
```bash
curl -X POST https://us-central1-freya-7c812.cloudfunctions.net/api/report/enrich-products \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  -d '{
    "uid": "demoUser1",
    "reportId": "nonexistent"
  }'
```
Expected: `{"error":"Report not found"}`

### Test 3: No product recommendations
```bash
# Use a report that was generated but never had find-products run
curl -X POST https://us-central1-freya-7c812.cloudfunctions.net/api/report/enrich-products \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  -d '{
    "uid": "demoUser1",
    "reportId": "REPORT_WITHOUT_PRODUCTS"
  }'
```
Expected: `{"error":"No product recommendations found. Run /report/find-products first."}`

## Notes

- The endpoint runs all productResolve calls in parallel for speed
- Each productResolve can take 5-15s (web search + scrape + cache)
- Total time depends on number of products (typically 12-18 products across 5-6 steps)
- If some products fail to resolve, status will be "partial" instead of "complete"

