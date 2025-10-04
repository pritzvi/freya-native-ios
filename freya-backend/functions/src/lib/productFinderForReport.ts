import OpenAI from "openai";
import { defineSecret } from "firebase-functions/params";

const openaiApiKey = defineSecret("OPENAI_API_KEY");
const productFinderForRoutineFastPromptOai = defineSecret("PRODUCT_FINDER_FOR_ROUTINE_FAST_PROMPT_OAI");

let openaiClient: OpenAI | null = null;

function getOpenAIClient(): OpenAI {
  if (!openaiClient) {
    openaiClient = new OpenAI({ apiKey: openaiApiKey.value() });
  }
  return openaiClient;
}

export interface ProductFinderResult {
  stepInfo: {
    routine_step: string;
    time_of_day: string;
    step_number: number;
  };
  products: any[];
  rawResponse: any;
}

export async function findProductsForStep(
  surveyData: any, 
  skinScore: any, 
  fullRoutine: any, 
  targetStep: any
): Promise<ProductFinderResult | null> {
  const openai = getOpenAIClient();

  const inputText = `USER SURVEY:\n${JSON.stringify(surveyData, null, 2)}\n\nSKIN SCORE:\n${JSON.stringify(skinScore, null, 2)}\n\nFULL ROUTINE:\n${JSON.stringify(fullRoutine, null, 2)}\n\nTARGET STEP:\n${targetStep.product} (${targetStep.period} Step ${targetStep.stepNumber})

**IMPORTANT: Please format your response as JSON wrapped in markdown code blocks like this:**

\`\`\`json
{
  "routine_recommendations": [
    {
      "routine_step": "${targetStep.product}",
      "time_of_day": "${targetStep.period}",
      "step_number": ${targetStep.stepNumber},
      "recommended_products": [
        {
          "product_name": "Product Name Here",
          "barcode": "1234567890123",
          "note_on_recommendation": "Why this product fits...",
          "key_ingredients": ["ingredient1", "ingredient2"],
          "reddit_source": "[URL]"
        }
      ]
    }
  ]
}
\`\`\`

**Please ensure your response is ONLY the JSON block above, no additional text.**`;

  // Retry logic: try up to 3 times if parsing fails
  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      console.log(`Product finder attempt ${attempt}/3`);
      
      const response = await openai.responses.create({
        prompt: {
          id: productFinderForRoutineFastPromptOai.value(),
          version: "2"
        },
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
          format: {
            type: "text"
          }
        },
        reasoning: {},
        tools: [
          {
            type: "web_search",
            user_location: {
              type: "approximate"
            },
            search_context_size: "high"
          }
        ],
        max_output_tokens: 2048,
        store: true,
        include: ["web_search_call.action.sources"]
      } as any);

      const output = (response as any).output_text ?? "";
      console.log(`Raw OpenAI output (attempt ${attempt}):`, output);
      
      if (!output) {
        if (attempt === 3) return null;
        continue; // Try again
      }

      try {
        // Robust JSON parsing (same pattern as other functions)
        const jsonMatch = output.match(/```(?:json)?\s*([\s\S]*?)\s*```/);
        let jsonString = jsonMatch ? jsonMatch[1] : output;
        jsonString = jsonString.trim();

        if (!jsonMatch) {
          const startBrace = output.indexOf('{');
          const lastBrace = output.lastIndexOf('}');
          if (startBrace !== -1 && lastBrace !== -1 && lastBrace > startBrace) {
            jsonString = output.substring(startBrace, lastBrace + 1);
          }
        }

        const parsed = JSON.parse(jsonString);
        const recommendation = parsed.routine_recommendations?.[0]; // Should be exactly 1 step

        if (!recommendation || !recommendation.recommended_products || recommendation.recommended_products.length < 3) {
          console.error(`Invalid recommendation structure or < 3 products found (attempt ${attempt}). Products: ${recommendation?.recommended_products?.length || 0}`);
          if (attempt === 3) return null;
          continue; // Try again
        }

        console.log(`Successfully parsed response on attempt ${attempt}`);
        return {
          stepInfo: {
            routine_step: recommendation.routine_step || targetStep.product,
            time_of_day: recommendation.time_of_day || targetStep.period,
            step_number: recommendation.step_number || targetStep.stepNumber
          },
          products: recommendation.recommended_products || [],
          rawResponse: parsed
        };

      } catch (parseError) {
        console.error(`JSON parsing error on attempt ${attempt}:`, parseError);
        if (attempt === 3) {
          // Final fallback: return basic structure
          return {
            stepInfo: {
              routine_step: targetStep.product,
              time_of_day: targetStep.period,
              step_number: targetStep.stepNumber
            },
            products: [],
            rawResponse: { error: "parsing_failed_after_retries", raw_output: output, attempts: 3 }
          };
        }
        continue; // Try again
      }

    } catch (error) {
      console.error(`Product finder error on attempt ${attempt}:`, error);
      if (attempt === 3) return null;
      continue; // Try again
    }
  }

  return null;
}
