import { onRequest } from "firebase-functions/v2/https";
import { setGlobalOptions } from "firebase-functions/v2";
import { defineSecret } from "firebase-functions/params";
import { app } from "./app.js";

// Region matches Vertex endpoint region we're using (us-central1)
setGlobalOptions({ region: "us-central1" });

// Define secrets
const openaiApiKey = defineSecret("OPENAI_API_KEY");
const firecrawlApiKey = defineSecret("FIRECRAWL_API_KEY");
const productUrlPickerPromptOai = defineSecret("PRODUCT_URL_PICKER_PROMPT_OAI");
const productFitScorePromptOai = defineSecret("PRODUCT_FIT_SCORE_PROMPT_OAI");

export const api = onRequest(
  { secrets: [openaiApiKey, firecrawlApiKey, productUrlPickerPromptOai, productFitScorePromptOai] },
  app
);