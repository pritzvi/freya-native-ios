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
    const directUrl = (req.body?.url || "").toString();
    const reqId = Date.now().toString(36) + Math.random().toString(36).slice(2, 8);
    const enterTs = Date.now();
    console.log(`[RESOLVE] ENTER id=${reqId} query="${q}" url="${directUrl || '<none>'}"`);
    console.log("1. Query:", q, "url:", directUrl ? directUrl.substring(0, 80) + "..." : "<none>");
    if (!directUrl && q.length < 2) {
      return res.status(400).json({ status: "not_found", reason: "invalid_payload" });
    }

    // Fast-path: if URL is provided, skip cache/search and scrape directly
    if (directUrl) {
      try {
        const scrapeStart = Date.now();
        console.log(`[RESOLVE] Scrape(URL) start id=${reqId} url=${directUrl}`);
        const data = await Promise.race([
          fcScrapeProduct(directUrl),
          new Promise((_, reject) => setTimeout(() => reject(new Error("scrape_timeout")), 30000))
        ]);
        console.log(`[RESOLVE] Scrape(URL) done id=${reqId} in ${Date.now() - scrapeStart}ms`);
        console.log("7(URL). Scraped data:", { product_name: (data as any)?.product_name, brand: (data as any)?.brand });
        const name = canon((data as any)?.product_name || q);
        const brand = canon((data as any)?.brand || "");
        console.log("8(URL). Normalized:", { name, brand });
        if (!name || !brand) {
          console.log(`[RESOLVE] EXIT id=${reqId} reason=invalid_payload`);
          return res.json({ status: "not_found", reason: "invalid_payload" });
        }
        const productId = slugify(`${brand} ${name}`);
        console.log("9(URL). Product ID:", productId);

        const prodRef = db.collection("products").doc(productId);
        const exists = await prodRef.get();
        if (exists.exists) {
          console.log(`[RESOLVE] EXIT id=${reqId} status=found productId=${productId} total=${Date.now() - enterTs}ms`);
          return res.json({ status: "found", productId });
        }

        console.log(`[RESOLVE] Firestore set(URL) id=${reqId} productId=${productId}`);
        await prodRef.set({
          productId,
          name,
          brand,
          category: (data as any)?.category || null,
          highlights: (data as any)?.highlights ?? [],
          ingredients: (data as any)?.Ingredients ?? [],
          price: parsePrice((data as any)?.price) ?? null,
          howToUse: Array.isArray((data as any)?.how_to_use) ? (data as any).how_to_use.join("\n") : null,
          images: (data as any)?.product_image_url ? [(data as any).product_image_url] : [],
          websiteUrls: [directUrl],
          source: { type: "firecrawl", sourceUrl: directUrl },
          updatedAt: FieldValue.serverTimestamp()
        }, { merge: true });
        console.log("11(URL). Product created");

        // Skip vector index creation in URL fast-path
        console.log(`[RESOLVE] EXIT id=${reqId} status=created productId=${productId} total=${Date.now() - enterTs}ms`);
        return res.json({ status: "created", productId });
      } catch (e: any) {
        console.log(`[RESOLVE] EXIT id=${reqId} reason=${e?.message || 'fetch_error'}`);
        return res.json({ status: "not_found", reason: e?.message === "scrape_timeout" ? "fetch_timeout" : "fetch_error" });
      }
    }

    // 1) Try cache (top-1 vector search)
    const embStart = Date.now();
    const qEmb = await vertexEmbedText(q, "RETRIEVAL_QUERY");
    console.log(`[RESOLVE] Embedding done id=${reqId} in ${Date.now() - embStart}ms`);
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
      const searchStart = Date.now();
      console.log(`[RESOLVE] Search start id=${reqId}`);
      webResults = await fcSearch(q);
      console.log(`[RESOLVE] Search done id=${reqId} results=${webResults.length} in ${Date.now() - searchStart}ms`);
      console.log("4. Web search results:", webResults.length);
    } catch {
      console.log(`[RESOLVE] EXIT id=${reqId} reason=fetch_error`);
      return res.json({ status: "not_found", reason: "fetch_error" });
    }
    if (!webResults.length) return res.json({ status: "not_found", reason: "low_results" });

    let chosen: string | null = null;
    try {
      const pickStart = Date.now();
      console.log(`[RESOLVE] Pick URL start id=${reqId}`);
      chosen = await pickBestUrl(webResults, q);
      console.log(`[RESOLVE] Pick URL done id=${reqId} url=${chosen} in ${Date.now() - pickStart}ms`);
      console.log("5. URL picker result:", chosen);
    } catch {
      console.log("5. URL picker failed, using fallback");
    }
    if (!chosen) return res.json({ status: "not_found", reason: "no_url" });

    // 3) Scrape -> map to our snapshot
    let data: any;
    try {
      const scrapeStart = Date.now();
      console.log(`[RESOLVE] Scrape start id=${reqId} url=${chosen}`);
      data = await Promise.race([
        fcScrapeProduct(chosen),
        new Promise((_, reject) => setTimeout(() => reject(new Error("scrape_timeout")), 30000))
      ]);
      console.log(`[RESOLVE] Scrape done id=${reqId} in ${Date.now() - scrapeStart}ms`);
      console.log("7. Scraped data:", { product_name: (data as any)?.product_name, brand: (data as any)?.brand });
    } catch (e: any) {
      console.log(`[RESOLVE] EXIT id=${reqId} reason=${e?.message || 'fetch_error'}`);
      return res.json({ status: "not_found", reason: e?.message === "scrape_timeout" ? "fetch_timeout" : "fetch_error" });
    }

    const name = canon(data?.product_name || q);
    const brand = canon(data?.brand || "");
    console.log("8. Normalized:", { name, brand });
    if (!name || !brand) {
      console.log(`[RESOLVE] EXIT id=${reqId} reason=invalid_payload`);
      return res.json({ status: "not_found", reason: "invalid_payload" });
    }

    const productId = slugify(`${brand} ${name}`);
    console.log("9. Product ID:", productId);

    // 4) Idempotent write (if exists -> found)
    const prodRef = db.collection("products").doc(productId);
    const exists = await prodRef.get();
    console.log("10. Product exists check:", exists.exists);
    if (exists.exists) {
      console.log(`[RESOLVE] EXIT id=${reqId} status=found productId=${productId} total=${Date.now() - enterTs}ms`);
      return res.json({ status: "found", productId });
    }

    console.log(`[RESOLVE] Firestore set id=${reqId} productId=${productId}`);
    await prodRef.set({
      productId,
      name,
      brand,
      category: data?.category || null,
      highlights: data?.highlights ?? [],
      ingredients: data?.Ingredients ?? [],
      price: parsePrice((data as any)?.price) ?? null,
      howToUse: Array.isArray((data as any)?.how_to_use) ? (data as any).how_to_use.join("\n") : null,
      images: data?.product_image_url ? [data.product_image_url] : [],
      websiteUrls: [chosen],
      source: { type: "firecrawl", sourceUrl: chosen },
      updatedAt: FieldValue.serverTimestamp()
    }, { merge: true });
    console.log("11. Product created");

    // 5) Write vector index doc (store-side embedding)
    const idxStart = Date.now();
    const idxEmb = await vertexEmbedText(`${brand} ${name}`, "RETRIEVAL_DOCUMENT");
    await db.collection("product_index").doc(productId).set({
      snapshotId: productId,
      name, brand,
      embedding: FieldValue.vector(idxEmb)
    });
    console.log(`12. Vector index created in ${Date.now() - idxStart}ms`);

    console.log(`[RESOLVE] EXIT id=${reqId} status=created productId=${productId} total=${Date.now() - enterTs}ms`);
    return res.json({ status: "created", productId });
  } catch (error) {
    console.log("ERROR:", error);
    return res.status(500).json({ error: error instanceof Error ? error.message : "Unknown error" });
  }
}
