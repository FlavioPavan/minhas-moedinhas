-- ════════════════════════════════════════════════════════════════
-- Minhas Moedinhas · schema + segurança (RLS) do Supabase
-- Idempotente: pode rodar de novo sem efeito colateral.
-- Compatível com o banco existente (portfolios e usuarios_leads já
-- criados pelo app antigo): só cria o que falta e nunca apaga dados.
-- ════════════════════════════════════════════════════════════════

-- Carteira simulada (1 por usuário) — criada só se ainda não existir
create table if not exists public.portfolios (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null unique references auth.users(id) on delete cascade,
  aporte     numeric,
  perfil     text default 'moderado',
  updated_at timestamptz default now()
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

-- Metas ("quero juntar R$ X até tal mês")
create table if not exists public.metas (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null default auth.uid() references auth.users(id) on delete cascade,
  nome         text not null check (char_length(nome) between 1 and 60),
  valor_alvo   numeric(14,2) not null check (valor_alvo > 0),
  prazo        date not null,
  guardado     numeric(14,2) not null default 0 check (guardado >= 0),
  concluida_em timestamptz,
  created_at   timestamptz not null default now()
);
create index if not exists metas_user_idx on public.metas (user_id, created_at);

-- Leads (nome/WhatsApp) com registro do aceite de privacidade (LGPD)
create table if not exists public.usuarios_leads (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  nome       text not null,
  whatsapp   text,
  email      text not null,
  created_at timestamptz default now()
);
alter table public.usuarios_leads add column if not exists privacidade_aceita_em timestamptz;
alter table public.usuarios_leads alter column whatsapp drop not null; -- WhatsApp agora é opcional

-- ── Row Level Security: cada usuário só acessa as próprias linhas ──
alter table public.portfolios     enable row level security;
alter table public.transacoes     enable row level security;
alter table public.usuarios_leads enable row level security;
alter table public.metas          enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='portfolios') then
    create policy "portfolios_dono" on public.portfolios
      for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='transacoes') then
    create policy "transacoes_dono" on public.transacoes
      for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='metas') then
    create policy "metas_dono" on public.metas
      for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='usuarios_leads') then
    create policy "leads_dono_le" on public.usuarios_leads
      for select to authenticated using (auth.uid() = user_id);
  end if;
end $$;

-- ── Lead criado no servidor no momento do cadastro ──────────────
-- Antes o app gravava o lead pelo navegador logo após o signUp, o que
-- falha com RLS quando a confirmação de e-mail está ligada (sem sessão).
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  begin
    insert into public.usuarios_leads (user_id, nome, whatsapp, email, privacidade_aceita_em)
    values (
      new.id,
      coalesce(nullif(new.raw_user_meta_data->>'display_name', ''), split_part(new.email, '@', 1)),
      nullif(new.raw_user_meta_data->>'whatsapp', ''),
      new.email,
      (new.raw_user_meta_data->>'privacidade_aceita_em')::timestamptz
    )
    on conflict (user_id) do nothing;
  exception when others then
    -- Nunca bloquear um cadastro por causa do lead: só registra o aviso.
    raise warning 'handle_new_user: lead não gravado para %: %', new.id, sqlerrm;
  end;
  return new;
end; $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- Recupera leads de quem se cadastrou quando o bug impedia a gravação
insert into public.usuarios_leads (user_id, nome, whatsapp, email)
select u.id,
       coalesce(nullif(u.raw_user_meta_data->>'display_name', ''), split_part(u.email, '@', 1)),
       nullif(u.raw_user_meta_data->>'whatsapp', ''),
       u.email
from auth.users u
where u.email is not null
on conflict (user_id) do nothing;

-- Mantém updated_at da carteira
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$ begin new.updated_at = now(); return new; end; $$;
drop trigger if exists portfolios_touch on public.portfolios;
create trigger portfolios_touch before update on public.portfolios
  for each row execute function public.touch_updated_at();
