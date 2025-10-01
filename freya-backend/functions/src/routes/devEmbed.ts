import { Request, Response } from "express";
import { vertexEmbedText } from "../lib/vertex.js";

export async function devEmbed(_req: Request, res: Response) {
  try {
    const emb = await vertexEmbedText("cerave sa cleanser", "RETRIEVAL_QUERY");
    res.json({ dim: emb.length, preview: emb.slice(0, 5) });
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : "Unknown error" });
  }
}
