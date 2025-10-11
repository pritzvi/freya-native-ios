import OpenAI from "openai";
import { defineSecret } from "firebase-functions/params";

const openaiApiKey = defineSecret("OPENAI_API_KEY");
const skinscorePromptOai = defineSecret("SKINSCORE_PROMPT_OAI");

let openaiClient: OpenAI | null = null;

function getOpenAIClient(): OpenAI {
  if (!openaiClient) {
    openaiClient = new OpenAI({ apiKey: openaiApiKey.value() });
  }
  return openaiClient;
}

export interface SkinScoreResult {
  skin_score_total_0_100: number;
  subscores: {
    barrier_hydration_0_100: number;
    complexion_pigment_0_100: number;
    acne_texture_0_100: number;
    fine_lines_wrinkles_0_100: number;
    eyebags_dark_circles_0_100: number;
  };
  confidence_0_100: number;
  full_analysis: any;
}

export async function deepScanScore(imageUrls: string[], emphasis: any): Promise<SkinScoreResult | null> {
  const openai = getOpenAIClient();

  const emphasisText = `Primary concern: ${emphasis.primary_concern}. Secondary concerns: ${emphasis.secondary_concerns?.join(', ') || 'none'}.`;

  try {
    const resp = await openai.responses.create({
      prompt: { id: skinscorePromptOai.value(), version: "2" },
      input: [
        {
          role: "user",
          content: [
            {"type": "input_text", "text": emphasisText},
            ...imageUrls.map(url => ({
              "type": "input_image",
              "image_url": url
            }))
          ]
        }
      ],
      text: {
        "format": {
          "type": "text"
        }
      },
    } as any);

    const output = (resp as any).output_text ?? "";
    console.log("Raw OpenAI output:", output);
    console.log("Output length:", output.length);
    console.log("First 200 chars:", output.substring(0, 200));
    if (!output) return null;

    try {
      // Step 1: Try to extract JSON from markdown code blocks
      const jsonMatch = output.match(/```(?:json)?\s*([\s\S]*?)\s*```/);
      let jsonString = jsonMatch ? jsonMatch[1] : output;
      
      // Step 2: Clean up whitespace
      jsonString = jsonString.trim();
      
      // Step 3: Fallback - try to find JSON object boundaries
      if (!jsonMatch) {
        const startBrace = output.indexOf('{');
        const lastBrace = output.lastIndexOf('}');
        if (startBrace !== -1 && lastBrace !== -1 && lastBrace > startBrace) {
          jsonString = output.substring(startBrace, lastBrace + 1);
        }
      }
      
      const parsed = JSON.parse(jsonString);
      return {
        skin_score_total_0_100: parsed.skin_score_total_0_100 || 50,
        subscores: parsed.subscores || {
          barrier_hydration_0_100: 50,
          complexion_pigment_0_100: 50,
          acne_texture_0_100: 50,
          fine_lines_wrinkles_0_100: 50,
          eyebags_dark_circles_0_100: 50
        },
        confidence_0_100: parsed.confidence_0_100 || 50,
        full_analysis: parsed
      };
    } catch {
      // Fallback: basic scores
      return {
        skin_score_total_0_100: 50,
        subscores: {
          barrier_hydration_0_100: 50,
          complexion_pigment_0_100: 50,
          acne_texture_0_100: 50,
          fine_lines_wrinkles_0_100: 50,
          eyebags_dark_circles_0_100: 50
        },
        confidence_0_100: 50,
        full_analysis: {}
      };
    }
  } catch (error) {
    console.error("DeepScan scoring error:", error);
    return null;
  }
}
