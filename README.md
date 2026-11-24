# 🪙 Minhas Moedinhas

Plataforma web (PWA, mobile-first) de **educação e simulação financeira**. O objetivo é desmistificar as finanças pessoais e mostrar que investir pode ser simples, visual e acessível.

> Ferramenta exclusivamente educativa. Não é recomendação de investimento.

## Funcionalidades (MVP)
| Pilar | Como está implementado |
|---|---|
| Simulador de aporte | Divisão por perfil; o **Moderado segue a regra 50% RF · 40% FIIs · 10% Ações**. Projeção de 12 meses com aporte **mensal** (guardado × rendimentos). |
| Evolução patrimonial | Gráfico em Tailwind puro, calculado a partir dos **lançamentos reais** do usuário (saldo ao fim de cada mês). |
| Persistência | **Sem login**: `localStorage` (fricção zero). **Com login opcional**: Supabase, e o que estava no aparelho é migrado automaticamente. |
| Dados reais | Selic meta (SGS 432), CDI anual (SGS 4389) e IPCA 12m (SGS 13522) direto da API do Banco Central, com cache de 6h e valores de referência offline. |
| Responsividade/PWA | Mobile-first, instalável (manifest + service worker), funciona offline. |
| Compliance | Aviso legal CVM completo no rodapé; "Para estudar" no lugar de "oportunidades"; links de parceiros identificados (`rel="sponsored"`). |
| LGPD | Modal de privacidade, aceite no cadastro, botão **Apagar meus dados**, WhatsApp opcional. |
| Acessibilidade | Labels em todos os campos, `aria-*` nos controles, modais com foco e Esc, tabela oculta para leitores de tela nos gráficos, contraste e fonte mínima maiores, `prefers-reduced-motion`. |

## Estrutura
```
index.html            app completo (React 18 + htm + Tailwind via CDN, arquivo único)
manifest.webmanifest  PWA
sw.js                 service worker (offline)
icon.svg, icon-maskable.svg
supabase/schema.sql   tabelas + políticas RLS + trigger de leads
```

## Configuração
1. **Supabase**: rode `supabase/schema.sql` no SQL Editor (idempotente). Confirme que RLS está ativo nas 3 tabelas.
2. **Afiliados**: troque `CONFIG.parceiro` no topo do script do `index.html` pelo seu link com código de afiliado.
3. **Premissas**: rentabilidades educativas de FIIs/Ações ficam em `CONFIG.premissas`.

## Rodar localmente
```bash
npx serve .   # ou: python3 -m http.server 8080
```
Abra `http://localhost:8080` (o service worker só registra em https/localhost).

## Próximas fases (Bíblia)
- Login com Google (Supabase Auth) e exclusão de conta pelo próprio app (Edge Function).
- Simulador de cenários com inflação (IPCA) — candidato a recurso premium.
- Infoproduto "O Guia Definitivo das Suas Primeiras Moedinhas".
