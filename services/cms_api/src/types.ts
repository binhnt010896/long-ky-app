/** Everything the Worker reads from its wrangler.toml bindings/vars plus the
 * one real secret (`GITHUB_TOKEN`, set via `wrangler secret put`). */
export interface Env {
  SOURCES_BUCKET: R2Bucket;
  FIREBASE_PROJECT_ID: string;
  GITHUB_OWNER: string;
  GITHUB_REPO: string;
  GITHUB_TOKEN: string;
  ALLOWED_EMAILS: string;
  CMS_ORIGIN: string;
}
