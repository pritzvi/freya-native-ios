import fetch from "node-fetch";
import { defineSecret } from "firebase-functions/params";

const FC_API = "https://api.firecrawl.dev/v2";
const firecrawlApiKey = defineSecret("FIRECRAWL_API_KEY");

const schema = {
  type: "object",
  properties: {
    product_name: { type: "string" },
    brand: { type: "string" },
    category: { 
      type: "string", 
      enum: ["cleanser", "moisturizer", "serum", "sunscreen", "foundation", "concealer", "mascara", "lipstick", "shampoo", "conditioner", "treatment", "other"],
      nullable: true 
    },
    price: { type: "string" },
    highlights: { type: "array", items: { type: "string" } },
    Ingredients: { type: "array", items: { type: "string" } },
    how_to_use: { type: "array", items: { type: "string" } },
    product_image_url: { type: "string" },
    website_url: { type: "string" }
  }
};

export async function fcScrapeProduct(url: string): Promise<any> {
  const r = await fetch(`${FC_API}/scrape`, {
    method: "POST",
    headers: { "Authorization": `Bearer ${firecrawlApiKey.value()}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      url,
      onlyMainContent: true,
      maxAge: 172800000,
      formats: [{ type: "json", schema }]
    })
  });
  if (!r.ok) throw new Error(`firecrawl scrape ${r.status}`);
  const j = await r.json() as any;
  return j?.data?.json ?? j?.data ?? j;
}
