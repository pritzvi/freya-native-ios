import OpenAI from "openai";
import { defineSecret } from "firebase-functions/params";

const openaiApiKey = defineSecret("OPENAI_API_KEY");
const productUrlPickerPromptOai = defineSecret("PRODUCT_URL_PICKER_PROMPT_OAI");

let openaiClient: OpenAI | null = null;

function getOpenAIClient(): OpenAI {
  if (!openaiClient) {
    openaiClient = new OpenAI({ apiKey: openaiApiKey.value() });
  }
  return openaiClient;
}

// returns one URL or null
export async function pickBestUrl(webResults: any[], query: string): Promise<string | null> {
  const openai = getOpenAIClient();
  
  const inputText = `${query}\n\n${JSON.stringify(webResults, null, 2)}`;
  
    // this is the openai hosted prompt id
    // You pick ONE product URL matching the user's query. Follow these strict priority rules:
    // 1) Return the Sephora.com product page URL if it exists (must be the page for this specific product)
    // 2) If no Sephora URL is found, return the Amazon.com product page URL. (must be URL for this product specifically, not a generic URL)
    // 3) If neither Sephora nor Amazon product-specific URLs are found, return the official brand product page URL.
    // Return ONLY ONE URL that matches the highest priority available. Do NOT return multiple URLs or URLs from any other sources.

  // Retry up to 3 times if result is not_found, blank, or null
  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      console.log(`[URL_PICKER] Attempt ${attempt}/3 for query: ${query}`);
      
      // OAI Prompt ID from secrets manager
      const resp = await openai.responses.create({
        prompt: { id: productUrlPickerPromptOai.value(), version: "8" },
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

      const txt = (resp as any).output_text ?? "";
      console.log(`[URL_PICKER] Attempt ${attempt} response: ${txt}`);
      
      // Check for invalid responses
      if (!txt || txt.trim() === "" || /NOT_FOUND/i.test(txt)) {
        console.log(`[URL_PICKER] Attempt ${attempt} returned invalid/not_found`);
        if (attempt === 3) {
          console.log(`[URL_PICKER] All 3 attempts failed for: ${query}`);
          return null;
        }
        continue; // Retry
      }
      
      const m = txt.match(/https?:\/\/\S+/i);
      if (m && m[0]) {
        console.log(`[URL_PICKER] SUCCESS on attempt ${attempt}: ${m[0]}`);
        return m[0];
      } else {
        console.log(`[URL_PICKER] Attempt ${attempt} no valid URL found in response`);
        if (attempt === 3) {
          console.log(`[URL_PICKER] All 3 attempts failed for: ${query}`);
          return null;
        }
        continue; // Retry
      }
    } catch (error) {
      console.error(`[URL_PICKER] Attempt ${attempt} error:`, error);
      if (attempt === 3) return null;
      continue; // Retry
    }
  }
  
  return null;
}
