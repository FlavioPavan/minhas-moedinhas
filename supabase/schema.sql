-- ════════════════════════════════════════════════════════════════
-- Minhas Moedinhas · schema + segurança (RLS) do Supabase
-- Rode no Supabase > SQL Editor. É idempotente: pode rodar de novo.
-- A chave "publishable" fica no front-end; quem protege os dados
-- são estas políticas: cada usuário só enxerga as próprias linhas.
-- ════════════════════════════════════════════════════════════════

-- Carteira simulada (1 por usuário)
create table if not exists public.portfolios (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  aporte     numeric(14,2) check (aporte is null or aporte > 0),
  perfil     text not null default 'moderado' check (perfil in ('conservador','moderado','arrojado')),
  updated_at timestamptz not null default now()
);

-- Lançamentos do gerenciador de moedinhas
create table if not exists public.transacoes (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  descricao  text not null check (char_length(descricao) between 1 and 80),
  valor      numeric(14,2) not null check (valor > 0),
  tipo       text not null check (tipo in ('entrada','saida')),
  created_at timestamptz not null default now()
);
create index if not exists transacoes_user_created_idx on public.transacoes (user_id, created_at desc);

-- Leads (nome/WhatsApp) com registro do aceite de privacidade (LGPD)
create table if not exists public.usuarios_leads (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  nome       text,
  whatsapp   text,
  email      text,
  privacidade_aceita_em timestamptz,
  created_at timestamptz not null default now()
);
alter table public.usuarios_leads add column if not exists privacidade_aceita_em timestamptz;

-- ── Row Level Security ──────────────────────────────────────────
alter table public.portfolios     enable row level security;
alter table public.transacoes     enable row level security;
alter table public.usuarios_leads enable row level security;

drop policy if exists "portfolios_dono" on public.portfolios;
create policy "portfolios_dono" on public.portfolios
  for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "transacoes_dono" on public.transacoes;
create policy "transacoes_dono" on public.transacoes
  for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "leads_dono_le" on public.usuarios_leads;
create policy "leads_dono_le" on public.usuarios_leads
  for select to authenticated using (auth.uid() = user_id);

-- ── Lead criado no servidor no momento do cadastro ──────────────
-- Antes o app tentava gravar o lead pelo navegador logo após o signUp,
-- o que falha com RLS quando a confirmação de e-mail está ligada (ainda não há sessão).
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.usuarios_leads (user_id, nome, whatsapp, email, privacidade_aceita_em)
  values (
    new.id,
    new.raw_user_meta_data->>'display_name',
    nullif(new.raw_user_meta_data->>'whatsapp', ''),
    new.email,
    (new.raw_user_meta_data->>'privacidade_aceita_em')::timestamptz
  )
  on conflict (user_id) do nothing;
  return new;
end; $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- Mantém updated_at da carteira
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$ begin new.updated_at = now(); return new; end; $$;
drop trigger if exists portfolios_touch on public.portfolios;
create trigger portfolios_touch before update on public.portfolios
  for each row execute function public.touch_updated_at();
