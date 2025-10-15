import OpenAI from "openai";
import { defineSecret } from "firebase-functions/params";
import { searchProductWithPreference } from "./productSearch.js";

const openaiApiKey = defineSecret("OPENAI_API_KEY");
const productFinderForRoutineFastPromptOai = defineSecret("GPT5_PRODUCT_FINDER_FOR_STEP");

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

  const inputText = `USER SURVEY:\n${JSON.stringify(surveyData, null, 2)}\n\nSKIN SCORE:\n${JSON.stringify(skinScore, null, 2)}\n\nFULL ROUTINE:\n${JSON.stringify(fullRoutine, null, 2)}\n\nTARGET STEP:\n${targetStep.product} (${targetStep.period} Step ${targetStep.stepNumber})\n\nIMPORTANT: YOU MUST USE the search_product_url tool to verify URLs for every recommended product and prioritize allowed domains. Respond with JSON only (no markdown, no code fences).`;

  // Retry logic: try up to 3 times if parsing fails
  let prevAttemptOutput: string | null = null;
  let prevAttemptResponseId: string | null = null;
  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      console.log(`Product finder attempt ${attempt}/3`);
      if (attempt > 1) {
        try {
          console.log(`[ATTEMPT ${attempt}] prev_response_id:`, prevAttemptResponseId || "<none>");
          console.log(`[ATTEMPT ${attempt}] prev_output:`, (prevAttemptOutput || "") || "<none>");
          console.log(`[ATTEMPT ${attempt}] inputText:`, inputText);

        } catch {}
      }

      
      // Initial user message
      const userStart: any[] = [
        {
          role: "user",
          content: [
            {
              type: "input_text",
              text: inputText
            }
          ]
        }
      ];

      // Tool loop for reasoning models: keep responding to tool calls until none remain
      const functionToolDef: any = {
        type: "function",
        name: "search_product_url",
        description: "Search for product page URLs for a specific skincare product. Returns web search results prioritized by Sephora (if brand available), Amazon, or brand website. Use this to verify products exist before recommending them.",
        strict: true,
        parameters: {
          type: "object",
          properties: {
            product_name: {
              type: "string",
              description: "The full product name including brand (e.g. 'CeraVe Hydrating Facial Cleanser')"
            }
          },
          required: ["product_name"],
          additionalProperties: false
        }
      };

      // Strict schema for final structured output
      const finalResponseSchema: any = {
        type: "object",
        additionalProperties: false,
        properties: {
          routine_recommendations: {
            type: "array",
            minItems: 1,
            items: {
              type: "object",
              additionalProperties: false,
              properties: {
                routine_step: { type: "string" },
                time_of_day: { type: "string", enum: ["AM", "PM"] },
                step_number: { type: "integer" },
                recommended_products: {
                  type: "array",
                  minItems: 3,
                  items: {
                    type: "object",
                    additionalProperties: false,
                    properties: {
                      product_name: { type: "string" },
                      note_on_recommendation: { type: "string" },
                      product_urls: {
                        type: "array",
                        minItems: 1,
                        items: { type: "string" }
                      },
                      usage_notes: { anyOf: [ { type: "string" }, { type: "null" } ] }
                    },
                    required: ["product_name", "note_on_recommendation", "product_urls", "usage_notes"]
                  }
                }
              },
              required: ["routine_step", "time_of_day", "step_number", "recommended_products"]
            }
          }
        },
        required: ["routine_recommendations"]
      };

      let finalResponse: any = null;
      const MAX_TOOL_ROUNDS = 10;
      let previousId: string | null = null;
      let pendingItems: any[] = [];
      for (let round = 1; round <= MAX_TOOL_ROUNDS; round++) {
        if (previousId === null) {
          console.log(`[TOOL_LOOP] Round ${round} - sending initial input`);
        } else {
          console.log(`[TOOL_LOOP] Round ${round} - sending ${pendingItems.length} pending item(s)`);
        }

        const resp = await openai.responses.create({
          prompt: {
            id: productFinderForRoutineFastPromptOai.value(),
            version: "5"
          },
          input: previousId === null ? userStart : pendingItems,
          ...(previousId === null ? {} : { previous_response_id: previousId } as any),
          text: {
            format: {
              type: "json_schema",
              name: "routine_recommendations_response",
              schema: finalResponseSchema,
              strict: true
            }
          },
          reasoning: {},
          tools: [
            functionToolDef,
            {
              type: "web_search",
              search_context_size: "medium",
              user_location: { type: "approximate" }
            }
          ],
          max_output_tokens: 20000,
          store: true,
          include: ["reasoning.encrypted_content", "web_search_call.action.sources"]
        } as any);

        console.log(`[TOOL_LOOP] Round ${round} - received output_text length:`, (resp as any).output_text?.length || 0);
        console.log(`[TOOL_LOOP] Round ${round} - output items (truncated):`, JSON.stringify(resp.output || []).slice(0, 2000));

        const items = resp.output || [];
        const functionCalls: any[] = [];
        const nextPending: any[] = [];

        for (const it of items) {
          const itAny = it as any;
          // DO NOT send reasoning items back when using previous_response_id.
          // Only send function_call_output items to satisfy the tool call(s).
          if (itAny.type === "function_call" && itAny.name === "search_product_url") {
            functionCalls.push(itAny);
          }
        }

        if (functionCalls.length === 0) {
          finalResponse = resp;
          break; // No more tool calls; use this response as final
        }

        // Execute tools and prepare outputs to send back (linked via previous_response_id)
        for (const fc of functionCalls) {
          try {
            let args: any = {};
            try { args = JSON.parse(fc.arguments || "{}"); } catch { args = {}; }
            const productName: string = args.product_name || args.product || String(fc.arguments || "");
            console.log(`[TOOL_CALL] search_product_url args:`, args);
            const results = await searchProductWithPreference(productName);
            console.log(`[TOOL_CALL] Returning ${results.length} results for '${productName}'`);
            nextPending.push({
              type: "function_call_output",
              call_id: fc.call_id,
              output: JSON.stringify(results)
            } as any);
          } catch (e) {
            console.error(`[TOOL_CALL] search_product_url error:`, e);
            nextPending.push({
              type: "function_call_output",
              call_id: fc.call_id,
              output: JSON.stringify({ error: "Search failed" })
            } as any);
          }
        }

        // Prepare for next round
        pendingItems = nextPending;
        previousId = (resp as any).id as string;
      }

      const finalOutput = (finalResponse as any)?.output_text ?? "";
      console.log(`Raw OpenAI output (attempt ${attempt}):`, finalOutput);
      // Save for next attempt diagnostics
      prevAttemptOutput = finalOutput || prevAttemptOutput;
      prevAttemptResponseId = (finalResponse as any)?.id || prevAttemptResponseId;
      
      if (!finalOutput) {
        if (attempt === 3) return null;
        continue; // Try again
      }

      try {
        // Structured outputs should already be strict JSON
        const parsed = JSON.parse(finalOutput);
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
            rawResponse: { error: "parsing_failed_after_retries", raw_output: finalOutput, attempts: 3 }
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
