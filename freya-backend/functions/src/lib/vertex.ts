import fetch from "node-fetch";
import { GoogleAuth } from "google-auth-library";

const LOCATION = "us-central1";
const MODEL = "text-embedding-005";

const ENDPOINT =
  `https://${LOCATION}-aiplatform.googleapis.com/v1/projects/${process.env.GOOGLE_CLOUD_PROJECT || process.env.GCLOUD_PROJECT}` +
  `/locations/${LOCATION}/publishers/google/models/${MODEL}:predict`;

const auth = new GoogleAuth({ scopes: ["https://www.googleapis.com/auth/cloud-platform"] });

export async function vertexEmbedText(
  text: string,
  taskType: "RETRIEVAL_QUERY" | "RETRIEVAL_DOCUMENT"
): Promise<number[]> {
  const client = await auth.getClient();
  const token = await client.getAccessToken();

  const body = {
    instances: [{ task_type: taskType, content: text }],
    parameters: { outputDimensionality: 768 }
  };

  const res = await fetch(ENDPOINT, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${token.token}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify(body)
  });

  if (!res.ok) {
    const msg = await res.text();
    throw new Error(`Vertex embed failed ${res.status}: ${msg}`);
  }

  const json = await res.json() as any;
  const values: number[] | undefined = json?.predictions?.[0]?.embeddings?.values;
  if (!values?.length) throw new Error("Vertex returned empty embedding");
  return values;
}
