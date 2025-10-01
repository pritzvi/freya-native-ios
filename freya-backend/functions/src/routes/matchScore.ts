import { Request, Response } from "express";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { scoreProductFit } from "../lib/productFit.js";

export async function matchScore(req: Request, res: Response) {
  try {
    const { uid, productId } = req.body || {};
    if (!uid || !productId) {
      return res.status(400).json({ error: "uid and productId required" });
    }

    const db = getFirestore();

    // 1. Fetch full product details
    const productDoc = await db.collection("products").doc(productId).get();
    if (!productDoc.exists) {
      return res.status(404).json({ error: "Product not found" });
    }
    const productData = productDoc.data();

    // 2. Mock user profile for testing (TODO: fetch from skinProfiles/{uid})
    const mockUserProfile = {
      skinType: "combination",
      concerns: ["acne", "dryness"],
      allergies: ["fragrance"],
      pregnancy: false,
      preferences: ["vegan", "cruelty-free"],
      ageBand: "25-34",
      reactivity: "sensitive"
    };

    console.log("Scoring product for user:", { uid, productId });
    console.log("Product data:", { name: productData?.name, brand: productData?.brand, category: productData?.category });

    // 3. Score product fit
    const fitResult = await scoreProductFit(mockUserProfile, productData);
    if (!fitResult) {
      return res.status(500).json({ error: "Failed to score product fit" });
    }

    console.log("Fit result:", fitResult);

    // 4. Upsert to productMatches collection
    const matchDoc = {
      productId,
      match_score: fitResult.match_score,
      match_level: fitResult.match_level,
      overall_assessment: fitResult.overall_assessment,
      ingredient_analysis: fitResult.ingredient_analysis,
      specific_notes: fitResult.specific_notes,
      updatedAt: FieldValue.serverTimestamp(),
      createdAt: FieldValue.serverTimestamp()
    };

    await db.collection("productMatches").doc(uid).collection("items").doc(productId).set(matchDoc, { merge: true });

    console.log("Saved match result to Firestore");

    // 5. Return response with product info
    return res.json({
      status: "ok",
      productId,
      match: fitResult,
      product: {
        name: productData?.name,
        brand: productData?.brand,
        category: productData?.category,
        image: productData?.images?.[0] || null
      }
    });

  } catch (error) {
    console.error("Match score error:", error);
    return res.status(500).json({ error: error instanceof Error ? error.message : "Unknown error" });
  }
}
