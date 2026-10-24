/** The one email a report becomes: plain text, UTF-8, base64-encoded so
 * Vietnamese survives every relay. No Reply-To — the reader never gives us an
 * address, and nothing here asks for one. */

function utf8ToBase64(text: string): string {
  const bytes = new TextEncoder().encode(text);
  let bin = '';
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin);
}

/** RFC 2047 encoded-word, so a non-ASCII subject is legal in a header. */
function encodeHeader(text: string): string {
  return /^[\x20-\x7e]*$/.test(text) ? text : `=?UTF-8?B?${utf8ToBase64(text)}?=`;
}

function wrap76(s: string): string {
  return s.match(/.{1,76}/g)?.join('\r\n') ?? '';
}

export interface MailParts {
  from: string;
  to: string;
  subject: string;
  body: string;
  /** Injected so tests are deterministic. */
  messageId?: string;
  date?: Date;
}

export function buildMime(p: MailParts): string {
  const domain = p.from.split('@')[1] ?? 'localhost';
  const headers = [
    `From: ${p.from}`,
    `To: ${p.to}`,
    `Subject: ${encodeHeader(p.subject)}`,
    `Date: ${(p.date ?? new Date()).toUTCString()}`,
    `Message-ID: <${p.messageId ?? crypto.randomUUID()}@${domain}>`,
    'MIME-Version: 1.0',
    'Content-Type: text/plain; charset=UTF-8',
    'Content-Transfer-Encoding: base64',
  ];
  return `${headers.join('\r\n')}\r\n\r\n${wrap76(utf8ToBase64(p.body))}\r\n`;
}
