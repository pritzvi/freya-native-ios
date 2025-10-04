import OpenAI from "openai";
import { defineSecret } from "firebase-functions/params";

const openaiApiKey = defineSecret("OPENAI_API_KEY");
const skincareRoutineReportGeneratorPromptOai = defineSecret("SKINCAREROUTINE_REPORT_GENERATOR_PROMPT_OAI");

let openaiClient: OpenAI | null = null;

function getOpenAIClient(): OpenAI {
  if (!openaiClient) {
    openaiClient = new OpenAI({ apiKey: openaiApiKey.value() });
  }
  return openaiClient;
}

export interface ReportResult {
  reportData: any;
}

export async function generateSkinReport(surveyData: any, skinScore: any): Promise<ReportResult | null> {
  const openai = getOpenAIClient();

  // Combine survey and skin score data into input string
  const inputText = `SURVEY DATA:\n${JSON.stringify(surveyData, null, 2)}\n\nSKIN SCORE:\n${JSON.stringify(skinScore, null, 2)}`;

  try {
    const resp = await openai.responses.create({
      prompt: { id: skincareRoutineReportGeneratorPromptOai.value(), version: "1" },
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
      text: {
        "format": {
          "type": "text"
        }
      }
    } as any);

    const output = (resp as any).output_text ?? "";
    console.log("Raw report output length:", output.length);
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
        reportData: parsed
      };
    } catch {
      // Fallback: return raw output
      return {
        reportData: { raw_output: output }
      };
    }
  } catch (error) {
    console.error("Report generation error:", error);
    return null;
  }
}
