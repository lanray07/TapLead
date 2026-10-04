import { z } from 'zod';
import { Buffer } from 'node:buffer';
const text = (max = 300) => z.string().max(max).default('');
const uuid = () => z.uuid().transform(v => v.toLowerCase());
const link = z.union([z.literal(''), z.url().refine(v => { const u = new URL(v); return u.protocol === 'https:' && !u.username && !u.password; })]).default('');
export const statuses = ['New', 'Follow Up', 'Active', 'Won', 'Archived'];
export const cardSchema = z.object({
  id: uuid(), persona: text(60), name: z.string().trim().min(1).max(120), preferredName: text(120), title: text(120), company: text(120),
  headline: text(240), bio: text(2000), email: z.union([z.literal(''), z.email()]).default(''), phone: text(60), location: text(200),
  website: link, portfolio: link, booking: link, cv: link.optional(),
  socials: z.array(z.object({id: uuid(), service: text(60), url: link})).max(20).default([]),
  theme: z.enum(['Minimal','Executive','Creator','Bold','Dark','Elegant','Sales','Consultant']).default('Executive'),
  accent: z.string().regex(/^[0-9a-fA-F]{6}$/).default('6654D9'),
  publicFields: z.array(z.enum(['email','phone','website','location','portfolio','booking','socials','cv'])).max(8).default([]),
  customBackground: z.string().regex(/^[0-9a-fA-F]{6}$/).optional(),
  typography: z.enum(['Standard','Rounded','Serif','Monospaced']).optional(),
  primaryAction: z.enum(['Save contact','Website','Portfolio','Book a meeting','View CV']).optional(),
  primaryActionLabel: z.string().trim().max(60).optional(),
  networkingMode: z.enum(['Networking','Sales','Recruiting','Event']).optional(),
  cornerImageKind: z.enum(['None','Photo','Logo']).optional(),
  cornerImagePosition: z.enum(['Top left','Top right','Bottom left','Bottom right']).optional(),
  sectionOrder: z.array(z.enum(['About','Contact','Links'])).length(3).refine(v => new Set(v).size === 3).default(['About','Contact','Links']),
  published: z.boolean().default(false), analyticsEnabled: z.boolean().default(false)
});
const timeline = z.object({id: uuid(), date: z.number().finite(), kind: text(80), text: text(4000)});
export const leadSchema = z.object({
  id: uuid(), name: z.string().trim().min(1).max(120), email: z.union([z.literal(''), z.email()]).default(''), phone: text(60), company: text(120),
  role: text(120), interest: text(500), message: text(2000), context: text(2000), source: text(40), cardID: uuid().nullable().optional(),
  metAt: z.number().finite(), status: z.enum(statuses).default('New'), notes: text(12000), tags: z.array(z.string().max(80)).max(30).default([]),
  followUp: z.number().finite().nullable().optional(), timeline: z.array(timeline).max(500).default([]), consent: z.boolean().default(false)
});
export const captureSchema = z.object({
  name: z.string().trim().min(1).max(120), email: z.union([z.literal(''), z.email()]).default(''), phone: text(60), company: text(120), role: text(120),
  interest: text(500), message: text(2000), consent: z.literal(true), website: z.literal('').default(''), source: z.enum(['qr','nfc','email','website','event','social','direct']).default('direct')
}).refine(v => v.email || v.phone, 'Provide an email address or phone number.');
export function publicCard(card) {
  const visible = new Set(card.publicFields);
  const {id, persona, name, preferredName, title, company, headline, bio, theme, accent, sectionOrder, customBackground, typography, primaryAction, primaryActionLabel, networkingMode, cornerImageKind, cornerImagePosition, publicImageAvailable} = card;
  return {id, persona, name, preferredName, title, company, headline, bio, theme, accent, sectionOrder, customBackground, typography, primaryAction, primaryActionLabel, networkingMode, cornerImageKind, cornerImagePosition, publicImageAvailable,
    ...Object.fromEntries(['email','phone','website','location','portfolio','booking','socials','cv'].filter(k => visible.has(k)).map(k => [k, card[k]]))};
}
export function cardCSS(card) {
  const backgrounds={Minimal:'F5F5F7',Executive:'292436',Creator:card.accent,Bold:'EAD99A',Dark:'17191D',Elegant:'EDE5DA',Sales:'183D38',Consultant:'263C56'};
  const background=card.customBackground || backgrounds[card.theme] || '292436';
  const contrast=hex=>{const rgb=[0,2,4].map(i=>parseInt(hex.slice(i,i+2),16)/255).map(c=>c<=.04045?c/12.92:((c+.055)/1.055)**2.4);const l=rgb[0]*.2126+rgb[1]*.7152+rgb[2]*.0722;return (l+.05)/.05>=1.05/(l+.05)?'#000':'#fff';};
  const fonts={Standard:'system-ui,sans-serif',Rounded:'ui-rounded,system-ui,sans-serif',Serif:'ui-serif,Georgia,serif',Monospaced:'ui-monospace,monospace'};
  // Only schema-validated hex colours and allowlisted font stacks enter CSS.
  return `.cover{background:#${background};color:${contrast(background)}}.cover span{color:inherit;opacity:.8}article{font-family:${fonts[card.typography]||fonts.Standard}}.primary{background:#${card.accent};color:${contrast(card.accent)}}`;
}
export function escapeHTML(value = '') { return String(value).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c])); }
export function vcard(card) {
  const c = publicCard(card);
  const esc = v => String(v || '').replace(/\\/g,'\\\\').replace(/\r\n|\r|\n/g,'\\n').replace(/;/g,'\\;').replace(/,/g,'\\,');
  const lines = ['BEGIN:VCARD','VERSION:4.0',`FN:${esc(c.name)}`,`ORG:${esc(c.company)}`,`TITLE:${esc(c.title)}`];
  if(c.email) lines.push(`EMAIL:${esc(c.email)}`);
  if(c.phone) lines.push(`TEL;VALUE=text:${esc(c.phone)}`);
  if(c.website) lines.push(`URL:${esc(c.website)}`);
  lines.push('END:VCARD');
  return lines.map(line => { let out='', bytes=0; for(const scalar of line) { const n=Buffer.byteLength(scalar); if(bytes+n>75){out+='\r\n ';bytes=1;} out+=scalar;bytes+=n;}return out; }).join('\r\n')+'\r\n';
}
