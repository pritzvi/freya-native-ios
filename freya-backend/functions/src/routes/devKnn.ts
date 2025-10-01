import { Request, Response } from "express";
import { getFirestore } from "firebase-admin/firestore";
import { vertexEmbedText } from "../lib/vertex.js";

export async function devKnn(req: Request, res: Response) {
  try {
    const { query } = req.body || {};
    if (!query) return res.status(400).json({ error: "query required" });

    const db = getFirestore();
    const qEmb = await vertexEmbedText(query, "RETRIEVAL_QUERY");

    const vq = (db.collection("product_index") as any).findNearest({
      vectorField: "embedding",
      queryVector: qEmb,
      distanceMeasure: "COSINE",
      limit: 1,
      distanceResultField: "vector_distance"
    });
    
    const snap = await vq.get();
    if (snap.empty) return res.json({ found: false });

    const doc = snap.docs[0];
    res.json({ 
      found: true, 
      productId: doc.id,
      distance: doc.get("vector_distance")
    });
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : "Unknown error" });
  }
}
