// src/app.ts
import express from "express";
import { getApps, initializeApp } from "firebase-admin/app"; // 
import { devEmbed } from "./routes/devEmbed.js";
import { devIndexProduct } from "./routes/devIndexProduct.js";
import { devKnn } from "./routes/devKnn.js";
import { fcSearch } from "./lib/firecrawl.js";
import { pickBestUrl } from "./lib/urlPicker.js";
import { fcScrapeProduct } from "./lib/fcScrape.js";
import { productResolve } from "./routes/productResolve.js";
import { matchScore } from "./routes/matchScore.js";

if (getApps().length === 0) {
  initializeApp();
}

export const app = express();
app.use(express.json());

app.get("/health", (_req, res) => res.json({ ok: true, now: Date.now() }));
app.get("/dev/embed", devEmbed);
app.post("/dev/indexProduct", devIndexProduct);
app.post("/dev/knn", devKnn);

app.post("/dev/search", async (req, res) => {
  try {
    const { query } = req.body || {};
    if (!query) return res.status(400).json({ error: "query required" });
    const webResults = await fcSearch(query);
    res.json({ webResults });
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : "Unknown error" });
  }
});

app.post("/dev/pickUrl", async (req, res) => {
  try {
    const { webResults, query } = req.body || {};
    if (!webResults || !query) return res.status(400).json({ error: "webResults and query required" });
    const chosen = await pickBestUrl(webResults, query);
    res.json({ chosen });
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : "Unknown error" });
  }
});

app.post("/dev/scrape", async (req, res) => {
  try {
    const { url } = req.body || {};
    if (!url) return res.status(400).json({ error: "url required" });
    const data = await fcScrapeProduct(url);
    res.json({ ok: true, data });
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : "Unknown error" });
  }
});

// Main API
app.post("/product/resolve", productResolve);
app.post("/match/score", matchScore);
