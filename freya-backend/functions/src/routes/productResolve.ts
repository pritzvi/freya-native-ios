import { Request, Response } from "express";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { vertexEmbedText } from "../lib/vertex.js";
import { fcSearch } from "../lib/firecrawl.js";
import { pickBestUrl } from "../lib/urlPicker.js";
import { fcScrapeProduct } from "../lib/fcScrape.js";
import { canon, slugify, parsePrice } from "../lib/normalize.js";

export async function productResolve(req: Request, res: Response) {
  try {
    const db = getFirestore();
    const q = (req.body?.query || "").toString();
    console.log("1. Query:", q);
    if (q.length < 2) {
      return res.status(400).json({ status: "not_found", reason: "invalid_payload" });
    }

    // 1) Try cache (top-1 vector search)
    const qEmb = await vertexEmbedText(q, "RETRIEVAL_QUERY");
    console.log("2. Query embedding length:", qEmb.length);
    const nearest = await (db.collection("product_index") as any).findNearest({
      vectorField: "embedding",
      queryVector: qEmb,
      distanceMeasure: "COSINE",
      limit: 1,
      distanceResultField: "vector_distance"
    }).get();
    console.log("3. Cache check - found:", !nearest.empty);

    if (!nearest.empty) {
      const distance = nearest.docs[0].get("vector_distance");
      console.log("3a. Cache hit distance:", distance);
      
      if (distance < 0.3) {
        console.log("3b. Distance below threshold - returning cache hit");
        return res.json({ status: "found", productId: nearest.docs[0].id });
      } else {
        console.log("3c. Distance above threshold (0.3) - treating as cache miss");
      }
    }

    // 2) Firecrawl search -> pick one URL
    let webResults: any[] = [];
    try {
      webResults = await fcSearch(q);
      console.log("4. Web search results:", webResults.length);
    } catch {
      return res.json({ status: "not_found", reason: "fetch_error" });
    }
    if (!webResults.length) return res.json({ status: "not_found", reason: "low_results" });

    let chosen: string | null = null;
    try {
      chosen = await pickBestUrl(webResults, q);
      console.log("5. URL picker result:", chosen);
    } catch {
      console.log("5. URL picker failed, using fallback");
    }
    if (!chosen) return res.json({ status: "not_found", reason: "no_url" });

    // 3) Scrape -> map to our snapshot
    let data: any;
    try {
      data = await fcScrapeProduct(chosen);
      console.log("7. Scraped data:", { product_name: data?.product_name, brand: data?.brand });
    } catch {
      return res.json({ status: "not_found", reason: "fetch_error" });
    }

    const name = canon(data?.product_name || q);
    const brand = canon(data?.brand || "");
    console.log("8. Normalized:", { name, brand });
    if (!name || !brand) {
      return res.json({ status: "not_found", reason: "invalid_payload" });
    }

    const productId = slugify(`${brand} ${name}`);
    console.log("9. Product ID:", productId);

    // 4) Idempotent write (if exists -> found)
    const prodRef = db.collection("products").doc(productId);
    const exists = await prodRef.get();
    console.log("10. Product exists check:", exists.exists);
    if (exists.exists) {
      return res.json({ status: "found", productId });
    }

    await prodRef.set({
      productId, name, brand,
      category: data?.category || null,
      highlights: data?.highlights ?? [],
      ingredients: data?.Ingredients ?? [],
      price: parsePrice(data?.price),
      howToUse: Array.isArray(data?.how_to_use) ? data.how_to_use.join("\n") : undefined,
      images: data?.product_image_url ? [data.product_image_url] : [],
      websiteUrls: [chosen],
      source: { type: "firecrawl", sourceUrl: chosen },
      updatedAt: FieldValue.serverTimestamp()
    }, { merge: true });
    console.log("11. Product created");

    // 5) Write vector index doc (store-side embedding)
    const idxEmb = await vertexEmbedText(`${brand} ${name}`, "RETRIEVAL_DOCUMENT");
    await db.collection("product_index").doc(productId).set({
      snapshotId: productId,
      name, brand,
      embedding: FieldValue.vector(idxEmb)
    });
    console.log("12. Vector index created");

    return res.json({ status: "created", productId });
  } catch (error) {
    console.log("ERROR:", error);
    return res.status(500).json({ error: error instanceof Error ? error.message : "Unknown error" });
  }
}
