import { Request, Response } from "express";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { vertexEmbedText } from "../lib/vertex.js";

export async function devIndexProduct(req: Request, res: Response) {
  try {
    const { name, brand } = req.body || {};
    if (!name || !brand) return res.status(400).json({ error: "name and brand required" });

    const display = `${brand} ${name}`.trim().replace(/\s+/g, " ");
    const db = getFirestore();

    // make a simple slug id
    const productId = display.toLowerCase().replace(/[™®]/g,"").replace(/[^a-z0-9]+/g,"-").replace(/^-+|-+$/g,"");

    // doc for products (minimal for now)
    await db.collection("products").doc(productId).set({
      productId, 
      name: name.trim(), 
      brand: brand.trim(),
      updatedAt: FieldValue.serverTimestamp()
    }, { merge: true });

    // embedding (RETRIEVAL_DOCUMENT) -> Firestore vector field
    const emb = await vertexEmbedText(display, "RETRIEVAL_DOCUMENT");
    await db.collection("product_index").doc(productId).set({
      snapshotId: productId,
      name: name.trim(),
      brand: brand.trim(),
      embedding: FieldValue.vector(emb),
    });

    res.json({ ok: true, productId });
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : "Unknown error" });
  }
}
