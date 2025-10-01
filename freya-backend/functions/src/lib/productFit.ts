import OpenAI from "openai";
import { defineSecret } from "firebase-functions/params";

const openaiApiKey = defineSecret("OPENAI_API_KEY");
const productFitScorePromptOai = defineSecret("PRODUCT_FIT_SCORE_PROMPT_OAI");

let openaiClient: OpenAI | null = null;

function getOpenAIClient(): OpenAI {
  if (!openaiClient) {
    openaiClient = new OpenAI({ apiKey: openaiApiKey.value() });
  }
  return openaiClient;
}

export interface ProductFitResult {
  match_score: number;
  match_level: string;
  overall_assessment: string;
  ingredient_analysis: any;
  specific_notes: string[];
}

// Score product compatibility for a user (0-100 scale)
export async function scoreProductFit(userProfile: any, productData: any): Promise<ProductFitResult | null> {
  const openai = getOpenAIClient();

  const inputText = `USER PROFILE:\n${JSON.stringify(userProfile, null, 2)}\n\nPRODUCT DATA:\n${JSON.stringify(productData, null, 2)}`;

  try {
    const resp = await openai.responses.create({
      prompt: { id: productFitScorePromptOai.value(), version: "1" },
      input: [
        {
          role: "user",
          content: [
            {
              type: "input_text",
              text: inputText
            }
          ]
        }
      ],
    } as any);

    const output = (resp as any).output_text ?? "";
    if (!output) return null;

    // Parse structured response (save all fields from OpenAI)
    try {
      const parsed = JSON.parse(output);
      return {
        match_score: parsed.match_score || 0,
        match_level: parsed.match_level || "",
        overall_assessment: parsed.overall_assessment || "",
        ingredient_analysis: parsed.ingredient_analysis || {},
        specific_notes: parsed.specific_notes || []
      };
    } catch {
      // Fallback: basic structure
      return {
        match_score: 50,
        match_level: "Unknown",
        overall_assessment: "Analysis failed",
        ingredient_analysis: {},
        specific_notes: []
      };
    }
  } catch (error) {
    console.error("Product fit scoring error:", error);
    return null;
  }
}
