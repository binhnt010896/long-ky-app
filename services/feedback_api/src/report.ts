// What a request must look like, kept apart from the Worker entry: workerd
// treats every named export of the entry module as an entrypoint and refuses
// to start on plain constants.

export const MAX_SUBJECT = 200;
export const MAX_BODY = 4000;
export const MAX_EMAIL = 254;
export const SUBJECT_PREFIX = '[Long Ký] ';

/** An email to help@. [replyTo] is set only for a closed-test request, where
 * the visitor typed their own address so we can write back. */
export type Mail = { subject: string; body: string; replyTo?: string };

/** The report, if [json] is one; otherwise why not. */
export function parseReport(
  json: unknown,
): { subject: string; body: string } | { error: string } {
  if (typeof json !== 'object' || json === null) return { error: 'expected a JSON object' };
  const { subject, body } = json as Record<string, unknown>;
  if (typeof subject !== 'string' || typeof body !== 'string') {
    return { error: 'subject and body must be strings' };
  }
  // A header value: one line only, or a sender could inject headers.
  if (/[\r\n]/.test(subject)) return { error: 'subject must be a single line' };
  if (!subject.startsWith(SUBJECT_PREFIX) || subject.length > MAX_SUBJECT) {
    return { error: 'invalid subject' };
  }
  if (body.trim().length === 0 || body.length > MAX_BODY) return { error: 'invalid body' };
  return { subject, body };
}

/** A closed-test request from the landing page, if [json] is one; otherwise
 * why not. `website` is a honeypot field the page hides from people. */
export function parseTesterRequest(
  json: unknown,
): { email: string; lang: string; bot: boolean } | { error: string } {
  if (typeof json !== 'object' || json === null) return { error: 'expected a JSON object' };
  const { email, lang, website } = json as Record<string, unknown>;
  if (typeof email !== 'string') return { error: 'email must be a string' };
  const e = email.trim();
  // It becomes reply_to and part of the subject: one plain address, one line.
  if (e.length > MAX_EMAIL || !/^[^\s@<>",;]+@[^\s@<>",;]+\.[^\s@<>",;]+$/.test(e)) {
    return { error: 'invalid email' };
  }
  return { email: e, lang: lang === 'en' ? 'en' : 'vi', bot: typeof website === 'string' && website !== '' };
}
