- firebase project is freya-7c812
- need to set API keys in prod
- have set firebase vector db index to prefilter using brand, check if that makes sense + edge cases

{"kind":"identitytoolkit#SignupNewUserResponse","localId":"lp2uVtbPxWwFegwclEJIhVc0zIHE","idToken":"eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0.eyJwcm92aWRlcl9pZCI6ImFub255bW91cyIsImF1dGhfdGltZSI6MTc1OTA2NzA4NSwidXNlcl9pZCI6ImxwMnVWdGJQeFd3RmVnd2NsRUpJaFZjMHpJSEUiLCJmaXJlYmFzZSI6eyJpZGVudGl0aWVzIjp7fSwic2lnbl9pbl9wcm92aWRlciI6ImFub255bW91cyJ9LCJpYXQiOjE3NTkwNjcwODUsImV4cCI6MTc1OTA3MDY4NSwiYXVkIjoiZnJleWEtN2M4MTIiLCJpc3MiOiJodHRwczovL3NlY3VyZXRva2VuLmdvb2dsZS5jb20vZnJleWEtN2M4MTIiLCJzdWIiOiJscDJ1VnRiUHhXd0ZlZ3djbEVKSWhWYzB6SUhFIn0.","refreshToken":"eyJfQXV0aEVtdWxhdG9yUmVmcmVzaFRva2VuIjoiRE8gTk9UIE1PRElGWSIsImxvY2FsSWQiOiJscDJ1VnRiUHhXd0ZlZ3djbEVKSWhWYzB6SUhFIiwicHJvdmlkZXIiOiJhbm9ueW1vdXMiLCJleHRyYUNsYWltcyI6e30sInByb2plY3RJZCI6ImZyZXlhLTdjODEyIn0=","expiresIn":"3600"}

lp2uVtbPxWwFegwclEJIhVc0zIHE
eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0.eyJwcm92aWRlcl9pZCI6ImFub255bW91cyIsImF1dGhfdGltZSI6MTc1OTA2NzA4NSwidXNlcl9pZCI6ImxwMnVWdGJQeFd3RmVnd2NsRUpJaFZjMHpJSEUiLCJmaXJlYmFzZSI6eyJpZGVudGl0aWVzIjp7fSwic2lnbl9pbl9wcm92aWRlciI6ImFub255bW91cyJ9LCJpYXQiOjE3NTkwNjcwODUsImV4cCI6MTc1OTA3MDY4NSwiYXVkIjoiZnJleWEtN2M4MTIiLCJpc3MiOiJodHRwczovL3NlY3VyZXRva2VuLmdvb2dsZS5jb20vZnJleWEtN2M4MTIiLCJzdWIiOiJscDJ1VnRiUHhXd0ZlZ3djbEVKSWhWYzB6SUhFIn0.


This is how we initialize secrets from Cloud Secrets Manager
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

export const api = onRequest(
  { secrets: [openaiApiKey, firecrawlApiKey, productUrlPickerPromptOai] },
  app
);

Then we use in the right file as so:
import fetch from "node-fetch";
import { defineSecret } from "firebase-functions/params";

const FC_API = "https://api.firecrawl.dev/v2";
const firecrawlApiKey = defineSecret("FIRECRAWL_API_KEY");

export async function fcSearch(query: string): Promise<any[]> {
  const body = {
    query: `Find the sephora.com product page for ${query}, if you can't find that then return amazon.com page, else the official product page.`,
    sources: ["web"], 
    categories: [], 
    limit: 10,
    scrapeOptions: { onlyMainContent: true, maxAge: 172800000, parsers: ["pdf"], formats: [] },
    origin: "website"
  };
  
  const r = await fetch(`${FC_API}/search`, {
    method: "POST",
    headers: { "Authorization": `Bearer ${firecrawlApiKey.value()}`, "Content-Type": "application/json" },
    body: JSON.stringify(body)
  });
  
  if (!r.ok) throw new Error(`firecrawl search ${r.status}`);
  const j = await r.json() as any;
  const webResults: any[] = j?.data?.web ?? [];
  return webResults;
}


NEVER do this:
const db = getFirestore(); // At module level
export function myFunction() { ... }
ALWAYS do this:
export function myFunction() {
  const db = getFirestore(); // Inside function
}
Rule: Firebase admin calls (getFirestore(), etc.) must be inside functions, never at module/top level. Module-level code runs at import time, before initializeApp().

Do some pre-processing to get brand from user query, prefilter by that and then vector search the right product + set good distance thresholds

Prod Notes

- Need to speed this thing up to <10s 
- Skin Score alone takes 30s
- for urlPicker, need to make sure OAI LLM does the search to confirm if its real
- Use structured output, maybe zod
- Cleanup code being in random places
- Can use openbeautyfacts DB to filter for user needs first (like Vegan)

Next Steps:

- Get the syntax down for adding secret, creating in lib, routes, and mounting in express app, then testing with simple curl and creating document/collections in emulator before running the curl

- Product Fit Score function, this is specific to the user
- Skincare Report generator
- Routine generator
- Then "explore" within the products


This is our product fit score output:
{"status":"ok","productId":"cerave-cerave-hydrating-facial-cleanser","match":{"match_score":95,"match_level":"Great Match","overall_assessment":"CeraVe Hydrating Facial Cleanser could be a Great Match for you because it contains ceramides, hyaluronic acid, and glycerin, which are good for your dryness and help support your sensitive, combination skin. Its non-comedogenic, fragrance-free formula makes it especially suitable for acne-prone and reactive skin.","ingredient_analysis":{"GLYCERIN":{"status":"good","reason":"Hydrates and supports dryness and sensitive skin."},"CERAMIDE NP/AP/EOP":{"status":"good","reason":"Ceramides restore skin barrier, addressing dryness and sensitivity."},"SODIUM HYALURONATE":{"status":"good","reason":"Hydrating active, holds moisture, alleviates dryness."},"PHYTOSPHINGOSINE":{"status":"good","reason":"Supports skin barrier, reduces inflammation, good for acne."},"CETEARYL ALCOHOL":{"status":"neutral","reason":"Fatty alcohol, non-irritating, conditions skin, but not comedogenic."},"STEARYL ALCOHOL":{"status":"neutral","reason":"Fatty alcohol, emollient, non-comedogenic."},"PHENOXYETHANOL":{"status":"neutral","reason":"Preservative; generally well-tolerated, but can rarely cause irritation in the highly sensitive."},"ETHYLHEXYLGLYCERIN":{"status":"neutral","reason":"Mild preservative booster, generally non-irritating."},"PEG-40 STEARATE":{"status":"neutral","reason":"Emulsifier, not comedogenic or irritating."}},"specific_notes":["No fragrance detected; no allergen conflict for fragrance-sensitive users.","No flagged comedogenic ingredients—suitable for acne-prone skin.","Contains ceramides, glycerin, and hyaluronic acid, which directly address your dryness and barrier sensitivity.","Creamy, non-foaming formula is ideal for your combination, sensitive skin and won't strip moisture.","Product is listed as vegan and cruelty-free; aligns with your preferences."]},"product":{"name":"CeraVe Hydrating Facial Cleanser","brand":"CeraVe","category":"cleanser","image":"https://m.media-amazon.com/images/I/51DbQev1thL._SX425_.jpg"}}




- Dont wanna waste CPU time from OpenAI, so do Async polling, and also reduce time, dont wanna spend more than 60s per product call, want it to be strictly <60s.
- Finish the product filling into routine function