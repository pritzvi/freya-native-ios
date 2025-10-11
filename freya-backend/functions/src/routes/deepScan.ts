import { Request, Response } from "express";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { deepScanScore } from "../lib/deepScan.js";
import { signedReadUrl } from "../lib/storage.js";

function generateId(): string {
  return Date.now().toString(36) + Math.random().toString(36).substr(2);
}

export async function deepScanScoreRoute(req: Request, res: Response) {
  try {
    const { uid, images, gcsPaths, emphasis } = req.body || {};
    if (!uid) return res.status(400).json({ error: "uid required" });
    if ((!images || !Array.isArray(images)) && (!gcsPaths || !Array.isArray(gcsPaths))) {
      return res.status(400).json({ error: "Provide images (URLs) or gcsPaths (paths in bucket)" });
    }

    // Resolve to URLs we can hand to OpenAI Vision
    let imageUrls: string[] = [];
    if (Array.isArray(images) && images.length) {
      imageUrls = images;
    } else {
      // Mint signed URLs for each gs path
      imageUrls = await Promise.all(
        gcsPaths.map((p: string) => signedReadUrl(p, 10)) // 10 minutes
      );
    }
    if (imageUrls.length < 1 || imageUrls.length > 4) {
      return res.status(400).json({ error: "Must supply 1-4 images" });
    }

    const db = getFirestore();
    const sessionId = generateId();
    const scoreId = generateId();

    console.log("Starting DeepScan for user:", uid);

    // 1. Create session
    await db.collection("skinScanSessions").doc(uid).collection("items").doc(sessionId).set({
      phase: "onboarding",
      images: imageUrls,
      status: "processing",
      createdAt: FieldValue.serverTimestamp()
    });

    console.log("Created session:", sessionId);

    // 2. Call OpenAI Vision
    const scoreResult = await deepScanScore(imageUrls, emphasis);
    if (!scoreResult) {
      return res.status(500).json({ error: "Failed to analyze images" });
    }

    console.log("DeepScan result:", scoreResult);

    // 3. Store score
    await db.collection("skinScores").doc(uid).collection("items").doc(scoreId).set({
      skin_score_total_0_100: scoreResult.skin_score_total_0_100,
      subscores: scoreResult.subscores,
      confidence_0_100: scoreResult.confidence_0_100,
      full_analysis: scoreResult.full_analysis,
      createdAt: FieldValue.serverTimestamp()
    });

    // 4. Update session
    await db.collection("skinScanSessions").doc(uid).collection("items").doc(sessionId).update({
      scoreId: scoreId,
      status: "succeeded"
    });

    console.log("Saved score:", scoreId);

    // 5. Return response
    return res.json({
      scoreId: scoreId,
      overall: scoreResult.skin_score_total_0_100,
      subscores: scoreResult.subscores,
      confidence: scoreResult.confidence_0_100
    });

  } catch (error) {
    console.error("DeepScan route error:", error);
    return res.status(500).json({ error: error instanceof Error ? error.message : "Unknown error" });
  }
}
