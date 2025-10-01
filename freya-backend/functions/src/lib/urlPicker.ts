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

    // OAI Prompt ID from secrets manager
  const resp = await openai.responses.create({
    prompt: { id: productUrlPickerPromptOai.value(), version: "6" },
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
    tools: [
      {
        "type": "web_search",
        "user_location": { "type": "approximate" },
        "search_context_size": "medium"
      }
    ]
  } as any);

  const txt = (resp as any).output_text ?? "";
  if (!txt || /NOT_FOUND/i.test(txt)) return null;
  const m = txt.match(/https?:\/\/\S+/i);
  return m ? m[0] : null;
}
