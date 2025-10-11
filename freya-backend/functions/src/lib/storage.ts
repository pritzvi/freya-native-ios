import { getStorage } from "firebase-admin/storage";

/**
 * Create a short-lived READ signed URL for an object at gs://{bucket}/{path}
 * @param gcsPath like "userImages/{uid}/items/{imageId}.jpg"
 * @param expiresMinutes default 10
 */
export async function signedReadUrl(gcsPath: string, expiresMinutes = 10): Promise<string> {
  const bucket = getStorage().bucket("freya-7c812.firebasestorage.app");
  const file = bucket.file(gcsPath);
  const expires = Date.now() + expiresMinutes * 60 * 1000;
  // v4 is default in @google-cloud/storage these days; v2 also works.
  const [url] = await file.getSignedUrl({ action: "read", expires });
  return url;
}

