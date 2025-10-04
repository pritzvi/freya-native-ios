import { Request, Response } from "express";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { generateSkinReport } from "../lib/reportGenerator.js";
import { findProductsForStep } from "../lib/productFinderForReport.js";

function generateId(): string {
  return Date.now().toString(36) + Math.random().toString(36).substr(2);
}

function extractAllSteps(routine: any) {
  const steps: any[] = [];
  
  // Handle AM steps (dynamic count)
  if (routine.AM && Array.isArray(routine.AM)) {
    routine.AM.forEach((stepObj: any) => {
      if (stepObj.step && stepObj.product) {
        steps.push({
          stepId: `AM_step_${stepObj.step}`,
          product: stepObj.product,
          period: "AM",
          stepNumber: stepObj.step,
          note: stepObj.note || null
        });
      }
    });
  }
  
  // Handle PM steps (dynamic count)  
  if (routine.PM && Array.isArray(routine.PM)) {
    routine.PM.forEach((stepObj: any) => {
      if (stepObj.step && stepObj.product) {
        steps.push({
          stepId: `PM_step_${stepObj.step}`,
          product: stepObj.product,
          period: "PM",
          stepNumber: stepObj.step,
          note: stepObj.note || null
        });
      }
    });
  }
  
  return steps;
}

export async function generateReport(req: Request, res: Response) {
  try {
    const { uid, scoreId } = req.body || {};
    if (!uid) {
      return res.status(400).json({ error: "uid required" });
    }

    const db = getFirestore();

    console.log("Generating report for user:", uid, "scoreId:", scoreId);

    // 1. Fetch survey data
    const profileDoc = await db.collection("skinProfiles").doc(uid).get();
    if (!profileDoc.exists) {
      return res.status(404).json({ error: "Survey data not found. Please complete survey first." });
    }
    const surveyData = profileDoc.data();

    // 2. Fetch skin score (latest if no scoreId provided)
    let skinScoreData;
    let actualScoreId: string;
    
    if (scoreId) {
      const scoreDoc = await db.collection("skinScores").doc(uid).collection("items").doc(scoreId).get();
      if (!scoreDoc.exists) {
        return res.status(404).json({ error: "Skin score not found" });
      }
      skinScoreData = scoreDoc.data();
      actualScoreId = scoreId;
    } else {
      // Get latest skin score
      const scoresQuery = await db.collection("skinScores").doc(uid).collection("items")
        .orderBy("createdAt", "desc")
        .limit(1)
        .get();
      
      if (scoresQuery.empty) {
        return res.status(404).json({ error: "No skin scores found. Please complete DeepScan first." });
      }
      
      skinScoreData = scoresQuery.docs[0].data();
      actualScoreId = scoresQuery.docs[0].id;
      console.log("Using latest score:", actualScoreId);
    }

    console.log("Survey data keys:", Object.keys(surveyData || {}));
    console.log("Skin score keys:", Object.keys(skinScoreData || {}));

    // 3. Generate report
    const reportResult = await generateSkinReport(surveyData, skinScoreData);
    if (!reportResult) {
      return res.status(500).json({ error: "Failed to generate report" });
    }

    console.log("Report generated successfully");

    // 4. Store report
    const reportId = generateId();
    await db.collection("skinReports").doc(uid).collection("items").doc(reportId).set({
      surveyRef: uid,
      scoreId: actualScoreId,
      reportData: reportResult.reportData,
      createdAt: FieldValue.serverTimestamp()
    });

    // 5. Extract and store routine (if available in report)
    if (reportResult.reportData.routine || reportResult.reportData.initial_routine) {
      const routine = reportResult.reportData.routine || reportResult.reportData.initial_routine;
      await db.collection("routines").doc(uid).set({
        ...routine,
        templateVersion: 1,
        updatedAt: FieldValue.serverTimestamp()
      }, { merge: true });
      console.log("Routine materialized");
    }

    console.log("Report saved:", reportId);

    // 6. Return response
    return res.json({
      reportId: reportId,
      status: "generated",
      reportData: reportResult.reportData
    });

  } catch (error) {
    console.error("Report generation error:", error);
    return res.status(500).json({ error: error instanceof Error ? error.message : "Unknown error" });
  }
}

export async function testProductFinder(req: Request, res: Response) {
  try {
    const { uid, reportId, testStep } = req.body || {};
    if (!uid || !reportId) {
      return res.status(400).json({ error: "uid and reportId required" });
    }

    const db = getFirestore();
    console.log("Testing product finder for user:", uid, "report:", reportId);

    // 1. Fetch existing report data
    const reportDoc = await db.collection("skinReports").doc(uid).collection("items").doc(reportId).get();
    if (!reportDoc.exists) {
      return res.status(404).json({ error: "Report not found" });
    }

    // 2. Fetch survey data
    const surveyDoc = await db.collection("skinProfiles").doc(uid).get();
    if (!surveyDoc.exists) {
      return res.status(404).json({ error: "Survey data not found" });
    }

    // 3. Get skin score (from report reference)
    const reportData = reportDoc.data();
    const scoreId = reportData?.scoreId;
    if (!scoreId) {
      return res.status(404).json({ error: "No scoreId found in report" });
    }

    const scoreDoc = await db.collection("skinScores").doc(uid).collection("items").doc(scoreId).get();
    if (!scoreDoc.exists) {
      return res.status(404).json({ error: "Skin score not found" });
    }

    // 4. Get routine and determine test step
    const routine = reportData?.reportData?.initial_routine;
    if (!routine) {
      return res.status(404).json({ error: "No initial_routine found in report" });
    }

    // Use provided testStep or default to first AM step
    const targetStep = testStep || {
      product: routine.AM?.[0]?.product || "Unknown Product",
      period: "AM",
      stepNumber: routine.AM?.[0]?.step || 1
    };

    console.log("Testing with step:", targetStep);

    // 5. Call product finder
    const result = await findProductsForStep(
      surveyDoc.data(),
      scoreDoc.data(),
      routine,
      targetStep
    );

    if (!result) {
      return res.status(500).json({ error: "Product finding failed" });
    }

    // 6. Return test result (don't store yet)
    return res.json({
      success: true,
      testStep: targetStep,
      result: result,
      productCount: result.products?.length || 0
    });

  } catch (error) {
    console.error("Test product finder error:", error);
    return res.status(500).json({ error: error instanceof Error ? error.message : "Unknown error" });
  }
}

export async function findProductsForReport(req: Request, res: Response) {
  try {
    const { uid, reportId } = req.body || {};
    if (!uid || !reportId) {
      return res.status(400).json({ error: "uid and reportId required" });
    }

    const db = getFirestore();
    console.log("Finding products for user:", uid, "report:", reportId);

    // 1. Fetch existing report data
    const reportDoc = await db.collection("skinReports").doc(uid).collection("items").doc(reportId).get();
    if (!reportDoc.exists) {
      return res.status(404).json({ error: "Report not found" });
    }

    // 2. Fetch survey data
    const surveyDoc = await db.collection("skinProfiles").doc(uid).get();
    if (!surveyDoc.exists) {
      return res.status(404).json({ error: "Survey data not found" });
    }

    // 3. Get skin score (from report reference)
    const reportData = reportDoc.data();
    const scoreId = reportData?.scoreId;
    if (!scoreId) {
      return res.status(404).json({ error: "No scoreId found in report" });
    }

    const scoreDoc = await db.collection("skinScores").doc(uid).collection("items").doc(scoreId).get();
    if (!scoreDoc.exists) {
      return res.status(404).json({ error: "Skin score not found" });
    }

    // 4. Get routine and extract all steps
    const routine = reportData?.reportData?.initial_routine;
    if (!routine) {
      return res.status(404).json({ error: "No initial_routine found in report" });
    }

    const allSteps = extractAllSteps(routine);
    if (allSteps.length === 0) {
      return res.status(400).json({ error: "No valid steps found in routine" });
    }

    console.log(`Processing ${allSteps.length} products in parallel:`, allSteps.map(s => s.stepId));

    // 5. Run parallel processing with individual error handling
    const productPromises = allSteps.map(async (step) => {
      try {
        const result = await findProductsForStep(
          surveyDoc.data(),
          scoreDoc.data(),
          routine,
          step
        );
        return { stepId: step.stepId, success: true, result };
      } catch (error) {
        console.error(`Failed to find products for ${step.stepId}:`, error);
        return { stepId: step.stepId, success: false, error: error instanceof Error ? error.message : "Unknown error" };
      }
    });

    const results = await Promise.all(productPromises);

    // 6. Process results
    const successfulProducts: any = {};
    const failedProducts: any[] = [];

    results.forEach(({ stepId, success, result, error }) => {
      if (success && result) {
        successfulProducts[stepId] = result;
      } else {
        failedProducts.push({ stepId, error });
      }
    });

    console.log(`Results: ${Object.keys(successfulProducts).length} successful, ${failedProducts.length} failed`);

    // 7. Store results in Firestore
    const status = failedProducts.length === 0 ? "products_complete" : 
                   Object.keys(successfulProducts).length > 0 ? "products_partial" : "products_failed";

    await db.collection("skinReports").doc(uid).collection("items").doc(reportId).update({
      productRecommendations: successfulProducts,
      productFindingStatus: {
        totalSteps: allSteps.length,
        successfulSteps: Object.keys(successfulProducts).length,
        failedSteps: failedProducts,
        completedAt: FieldValue.serverTimestamp()
      },
      status: status,
      updatedAt: FieldValue.serverTimestamp()
    });

    // 8. Return response
    return res.json({
      success: true,
      totalSteps: allSteps.length,
      successfulProducts: Object.keys(successfulProducts).length,
      failedProducts: failedProducts.length,
      status: status,
      productRecommendations: successfulProducts,
      failedSteps: failedProducts
    });

  } catch (error) {
    console.error("Find products for report error:", error);
    return res.status(500).json({ error: error instanceof Error ? error.message : "Unknown error" });
  }
}
