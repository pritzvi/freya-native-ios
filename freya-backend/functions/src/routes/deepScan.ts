import { Request, Response } from "express";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { deepScanScore } from "../lib/deepScan.js";

function generateId(): string {
  return Date.now().toString(36) + Math.random().toString(36).substr(2);
}

export async function deepScanScoreRoute(req: Request, res: Response) {
  try {
    const { uid, images, emphasis } = req.body || {};
    if (!uid || !images || !Array.isArray(images) || images.length < 1 || images.length > 4) {
      return res.status(400).json({ error: "uid, images array (1-4 images), and emphasis required" });
    }

    const db = getFirestore();
    const sessionId = generateId();
    const scoreId = generateId();

    console.log("Starting DeepScan for user:", uid);

    // 1. Create session
    await db.collection("skinScanSessions").doc(uid).collection("items").doc(sessionId).set({
      phase: "onboarding",
      images: images,
      status: "processing",
      createdAt: FieldValue.serverTimestamp()
    });

    console.log("Created session:", sessionId);

    // 2. Call OpenAI Vision
    const scoreResult = await deepScanScore(images, emphasis);
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
