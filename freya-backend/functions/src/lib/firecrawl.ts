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
