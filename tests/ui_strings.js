// Checks that the window's English and Spanish strings have the same keys.
//   node tests/ui_strings.js
const fs = require('fs');
const html = fs.readFileSync(__dirname + '/../src/ui/app.html', 'utf8');
const m = html.match(/var L=(\{[\s\S]*?\}\});/);
if (!m) { console.log('FAIL: strings table not found'); process.exit(1); }
const L = eval('(' + m[1] + ')');
let fail = 0;
for (const [a, b] of [['en', 'es'], ['es', 'en']])
  for (const k of Object.keys(L[a])) if (!(k in L[b])) { console.log(`FAIL: ${b} is missing "${k}"`); fail++; }
for (const k of Object.keys(L.en)) {
  const n = s => (s.match(/%s/g) || []).length;
  if (k in L.es && n(L.en[k]) !== n(L.es[k])) { console.log(`FAIL: placeholders differ for "${k}"`); fail++; }
}
// every t('key') used in the page must exist
for (const [, k] of html.matchAll(/\bt\('([A-Za-z]+)'/g)) if (!(k in L.en)) { console.log(`FAIL: unknown key "${k}"`); fail++; }
console.log(`${Object.keys(L.en).length} keys per language, ${fail} problems`);
process.exit(fail ? 1 : 0);
