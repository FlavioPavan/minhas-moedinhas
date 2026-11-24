// Carrega o <script> do index.html com stubs mínimos e testa as funções puras.
const fs = require('fs'); const vm = require('vm'); const assert = require('assert');
const htmlSrc = fs.readFileSync(process.argv[2], 'utf8');
const code = htmlSrc.split('<script>').pop().split('</script>')[0];
const store = {};
const h = () => null;
const ctx = {
  console, Intl, Math, Date, JSON, Number, String, Promise, Object, Array, setTimeout, clearTimeout, AbortController,
  crypto: { randomUUID: () => 'id-' + Math.random() },
  localStorage: { getItem: k => (k in store ? store[k] : null), setItem: (k, v) => { store[k] = String(v); }, removeItem: k => { delete store[k]; } },
  React: { useState: v => [v, () => {}], useEffect() {}, useCallback: f => f, useMemo: f => f(), useRef: () => ({}), createElement: h },
  ReactDOM: { createRoot: () => ({ render() {} }) },
  htm: { bind: () => () => null },
  navigator: {}, location: { protocol: 'file:' }, document: { getElementById: () => ({}) },
};
ctx.window = ctx; ctx.window.supabase = undefined;
vm.createContext(ctx); vm.runInContext(code, ctx);
const { parseValor, projetarAportes, evolucaoPatrimonio, anualParaMensal, mesesAte, aporteNecessario, sugestaoParaMeta, PERFIS } = ctx.__MM__;

// parseValor: formatos brasileiros e internacionais
assert.strictEqual(parseValor('150'), 150);
assert.strictEqual(parseValor('150,50'), 150.5);
assert.strictEqual(parseValor('1.234,56'), 1234.56);
assert.strictEqual(parseValor('1234.56'), 1234.56);
assert.strictEqual(parseValor('R$ 2.000'), 2000);
assert.strictEqual(parseValor('2.5'), 2.5);
assert.strictEqual(parseValor('1.000.000'), 1000000);
assert.ok(Number.isNaN(parseValor('')));
assert.ok(Number.isNaN(parseValor('abc')));

// alocações somam 100% e moderado = 50/40/10 (Bíblia)
for (const [k, p] of Object.entries(PERFIS)) assert.ok(Math.abs(p.alocacao.reduce((a, x) => a + x.pct, 0) - 1) < 1e-9, k);
assert.strictEqual(JSON.stringify(PERFIS.moderado.alocacao.map(a => a.pct)), JSON.stringify([0.5, 0.4, 0.1]));

// taxa anual -> mensal composta
assert.ok(Math.abs(Math.pow(1 + anualParaMensal(12), 12) - 1.12) < 1e-12);

// projeção com aportes mensais
const proj = projetarAportes(100, 'moderado', 13.75, 12, new Date(2026, 10, 24));
assert.strictEqual(proj.length, 12);
assert.strictEqual(proj[0].rotulo, 'Nov'); assert.strictEqual(proj[2].rotulo, 'Jan'); assert.strictEqual(proj[2].ano, 2027);
assert.strictEqual(proj[0].total, 100); // 1º mês: só o aporte
assert.strictEqual(proj[11].investido, 1200);
assert.ok(proj[11].total > 1200 && proj[11].total < 1300, 'total plausível: ' + proj[11].total);
for (let i = 1; i < 12; i++) assert.ok(proj[i].total > proj[i - 1].total);

// evolução real a partir dos lançamentos
const hoje = new Date(2026, 10, 24);
const tx = [
  { tipo: 'entrada', valor: 500, created_at: new Date(2026, 8, 5).toISOString() },
  { tipo: 'entrada', valor: 300, created_at: new Date(2026, 9, 10).toISOString() },
  { tipo: 'saida', valor: 100, created_at: new Date(2026, 10, 2).toISOString() },
];
const ev = evolucaoPatrimonio(tx, 6, hoje);
assert.strictEqual(JSON.stringify(ev.map(e => e.rotulo)), JSON.stringify(['Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov']));
assert.strictEqual(JSON.stringify(ev.map(e => e.total)), JSON.stringify([0, 0, 0, 500, 800, 700]));
// metas: meses até o prazo (conta o mês atual)
const nov26 = new Date(2026, 10, 24);
assert.strictEqual(mesesAte('2026-11', nov26), 1);
assert.strictEqual(mesesAte('2027-06', nov26), 8);
assert.strictEqual(mesesAte('2026-10', nov26), 0);
assert.strictEqual(mesesAte('lixo', nov26), 0);

// metas: aporte necessário
assert.strictEqual(aporteNecessario(1200, 0, 12, 0), 100);
assert.strictEqual(aporteNecessario(1000, 1000, 5, 0.01), 0);
assert.strictEqual(aporteNecessario(1000, 400, 0, 0.01), 600);
const pmt = aporteNecessario(5000, 0, 8, anualParaMensal(13.75));
assert.ok(pmt < 625 && pmt > 590, 'pmt com rendimento menor que sem: ' + pmt);
// confere que o pmt realmente atinge o alvo
let saldo = 0; const i = anualParaMensal(13.75);
for (let k = 0; k < 8; k++) saldo = saldo * (1 + i) + pmt;
assert.ok(Math.abs(saldo - 5000) < 0.01, 'saldo final ' + saldo);
// guardado que rende sozinho até o alvo => 0
assert.strictEqual(aporteNecessario(1010, 1000, 12, 0.01), 0);

// metas: sugestão por prazo
assert.ok(/Selic/.test(sugestaoParaMeta({ nome: 'Viagem' }, 6).titulo));
assert.ok(/Selic/.test(sugestaoParaMeta({ nome: 'Reserva de emergência' }, 48).titulo));
assert.ok(/CDB/.test(sugestaoParaMeta({ nome: 'Carro' }, 24).titulo));
assert.ok(/IPCA/.test(sugestaoParaMeta({ nome: 'Casa' }, 60).titulo));

console.log('OK: todos os testes de lógica passaram. Projeção 12m de R$100/mês =', proj[11].total.toFixed(2));
