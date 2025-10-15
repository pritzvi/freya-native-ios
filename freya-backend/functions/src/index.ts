import { onRequest } from "firebase-functions/v2/https";
import { setGlobalOptions } from "firebase-functions/v2";
import { defineSecret } from "firebase-functions/params";
import { app } from "./app.js";

// Region and timeout for all functions (gen2)
setGlobalOptions({ region: "us-central1", timeoutSeconds: 120 });

// Define secrets
const openaiApiKey = defineSecret("OPENAI_API_KEY");
const firecrawlApiKey = defineSecret("FIRECRAWL_API_KEY");
const productUrlPickerPromptOai = defineSecret("PRODUCT_URL_PICKER_PROMPT_OAI");
const productFitScorePromptOai = defineSecret("PRODUCT_FIT_SCORE_PROMPT_OAI");
const skinscorePromptOai = defineSecret("SKINSCORE_PROMPT_OAI");
const skincareRoutineReportGeneratorPromptOai = defineSecret("SKINCAREROUTINE_REPORT_GENERATOR_PROMPT_OAI");
const productFinderForRoutineFastPromptOai = defineSecret("PRODUCT_FINDER_FOR_ROUTINE_FAST_PROMPT_OAI");
const gpt5ProductFinderForStepPromptOai = defineSecret("GPT5_PRODUCT_FINDER_FOR_STEP");

export const api = onRequest(
  { secrets: [openaiApiKey, firecrawlApiKey, productUrlPickerPromptOai, productFitScorePromptOai, skinscorePromptOai, skincareRoutineReportGeneratorPromptOai, productFinderForRoutineFastPromptOai, gpt5ProductFinderForStepPromptOai] },
  app
);