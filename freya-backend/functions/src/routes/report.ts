import { Request, Response } from "express";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { generateSkinReport } from "../lib/reportGenerator.js";
import { findProductsForStep } from "../lib/productFinderForReport.js";
import { productResolve } from "./productResolve.js";

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

export async function enrichProducts(req: Request, res: Response) {
  try {
    const { uid, reportId } = req.body || {};
    if (!uid || !reportId) {
      return res.status(400).json({ error: "uid and reportId required" });
    }

    const db = getFirestore();
    console.log("Enriching products for user:", uid, "report:", reportId);

    // 1. Fetch existing report
    const reportDoc = await db.collection("skinReports").doc(uid).collection("items").doc(reportId).get();
    if (!reportDoc.exists) {
      return res.status(404).json({ error: "Report not found" });
    }

    const reportData = reportDoc.data();
    const productRecommendations = reportData?.productRecommendations;
    
    if (!productRecommendations || Object.keys(productRecommendations).length === 0) {
      return res.status(404).json({ error: "No product recommendations found. Run /report/find-products first." });
    }

    console.log(`Found ${Object.keys(productRecommendations).length} steps to enrich`);

    // 2. Enrich all products with productResolve in parallel
    const enrichmentPromises: Promise<any>[] = [];
    const stepKeys = Object.keys(productRecommendations);

    for (const stepKey of stepKeys) {
      const stepData = productRecommendations[stepKey];
      const products = stepData?.products || [];

      for (let i = 0; i < products.length; i++) {
        const product = products[i];
        
        enrichmentPromises.push(
          (async () => {
            const startTime = Date.now();
            try {
              console.log(`[ENRICH] Starting: ${product.product_name} (${stepKey}) index=${i}`);
              const enrichedUrl = Array.isArray(product?.product_urls) && product.product_urls.length > 0 ? product.product_urls[0] : undefined;
              console.log(`[ENRICH] CALL productResolve query="${product.product_name}" url="${enrichedUrl || '<none>'}" step=${stepKey}[${i}]`);
              
              // Call productResolve with proper Promise wrapper
              const reqBody: any = { query: product.product_name };
              if (enrichedUrl) {
                reqBody.url = enrichedUrl;
              }
              const mockReq = { body: reqBody } as Request;
              
              const resolveResult = await new Promise<any>((resolve, reject) => {
                let responded = false;
                const timeout = setTimeout(() => {
                  console.error(`[ENRICH] TIMEOUT: no response from productResolve within 60s for ${product.product_name} step=${stepKey}[${i}], responded=${responded}`);
                  reject(new Error(`Timeout after 60s for ${product.product_name}`));
                }, 60000); // 60s timeout per product

                const mockRes = {
                  json: (data: any) => {
                    responded = true;
                    clearTimeout(timeout);
                    console.log(`[ENRICH] productResolve returned for ${product.product_name}:`, JSON.stringify(data));
                    resolve(data);
                    return mockRes;
                  },
                  status: (code: number) => {
                    console.log(`[ENRICH] productResolve status ${code} for ${product.product_name}`);
                    return mockRes;
                  }
                } as any;

                productResolve(mockReq, mockRes).catch((err) => {
                  clearTimeout(timeout);
                  console.error(`[ENRICH] productResolve threw for ${product.product_name} step=${stepKey}[${i}]:`, err);
                  reject(err);
                });
              });
              
              const resolveTime = Date.now() - startTime;
              console.log(`[ENRICH] productResolve completed in ${resolveTime}ms for ${product.product_name}`);
              
              if (resolveResult?.productId) {
                console.log(`[ENRICH] Fetching product doc: ${resolveResult.productId}`);
                
                // Fetch product from Firestore to get image URL
                const productDoc = await db.collection("products").doc(resolveResult.productId).get();
                const productData = productDoc.data();
                const imageUrl = productData?.images?.[0] || null;
                
                const totalTime = Date.now() - startTime;
                console.log(`[ENRICH] SUCCESS for ${product.product_name}: productId=${resolveResult.productId}, imageUrl=${imageUrl ? imageUrl.substring(0, 50) + '...' : 'NULL'}, totalTime=${totalTime}ms`);
                
                return {
                  stepKey,
                  productIndex: i,
                  productId: resolveResult.productId,
                  imageUrl: imageUrl,
                  success: true
                };
              } else {
                const totalTime = Date.now() - startTime;
                console.error(`[ENRICH] FAILED (no productId) for ${product.product_name}, status=${resolveResult?.status}, reason=${resolveResult?.reason}, totalTime=${totalTime}ms`);
                return { stepKey, productIndex: i, success: false, error: `Product resolve returned: ${JSON.stringify(resolveResult)}` };
              }
            } catch (error) {
              const totalTime = Date.now() - startTime;
              console.error(`[ENRICH] EXCEPTION for ${product.product_name} after ${totalTime}ms:`, error);
              return { stepKey, productIndex: i, success: false, error: error instanceof Error ? error.message : "Unknown error" };
            }
          })()
        );
      }
    }

    console.log(`Running ${enrichmentPromises.length} product resolves in parallel...`);
    const results = await Promise.all(enrichmentPromises);

    // 3. Build enriched product recommendations
    const enrichedProducts: any = JSON.parse(JSON.stringify(productRecommendations)); // Deep clone
    let successCount = 0;
    let failCount = 0;

    let successWithImages = 0;
    let successWithoutImages = 0;
    
    results.forEach((result) => {
      if (result.success) {
        const products = enrichedProducts[result.stepKey]?.products;
        if (products && products[result.productIndex]) {
          products[result.productIndex].productId = result.productId;
          products[result.productIndex].imageUrl = result.imageUrl;
          
          if (result.imageUrl) {
            successWithImages++;
          } else {
            successWithoutImages++;
            console.log(`[ENRICH] Product resolved but NO IMAGE: ${products[result.productIndex].product_name}, productId=${result.productId}`);
          }
          successCount++;
        }
      } else {
        failCount++;
        console.log(`[ENRICH] Product FAILED: ${result.stepKey}[${result.productIndex}], error=${result.error}`);
      }
    });

    console.log(`[ENRICH] Enrichment complete: ${successCount} successful (${successWithImages} with images, ${successWithoutImages} without images), ${failCount} failed`);

    // 4. Update Firestore with enriched products
    await db.collection("skinReports").doc(uid).collection("items").doc(reportId).update({
      productRecommendations: enrichedProducts,
      enrichmentStatus: failCount === 0 ? "complete" : "partial",
      enrichmentCompletedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp()
    });

    // 5. Return response
    return res.json({
      success: true,
      enrichedProducts: enrichedProducts,
      totalProducts: enrichmentPromises.length,
      successfulResolves: successCount,
      failedResolves: failCount,
      status: failCount === 0 ? "complete" : "partial"
    });

  } catch (error) {
    console.error("Enrich products error:", error);
    return res.status(500).json({ error: error instanceof Error ? error.message : "Unknown error" });
  }
}
