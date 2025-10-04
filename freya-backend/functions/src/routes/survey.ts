import { Request, Response } from "express";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

export async function saveSurvey(req: Request, res: Response) {
  try {
    const { uid, ...surveyData } = req.body || {};
    if (!uid) {
      return res.status(400).json({ error: "uid required" });
    }

    const db = getFirestore();
    
    console.log("Saving survey for user:", uid);
    console.log("Survey data keys:", Object.keys(surveyData));

    // Store all survey responses in skinProfiles collection
    await db.collection("skinProfiles").doc(uid).set({
      ...surveyData,
      updatedAt: FieldValue.serverTimestamp()
    }, { merge: true });

    console.log("Survey saved successfully");

    return res.json({ 
      ok: true,
      message: "Survey saved successfully"
    });

  } catch (error) {
    console.error("Survey save error:", error);
    return res.status(500).json({ error: error instanceof Error ? error.message : "Unknown error" });
  }
}
