-- 事后诸葛亮：在它自己的 Supabase 项目里打开 SQL Editor，整段贴上，按 Run，只要跑一次。

create table if not exists public.decisions (
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  id text not null,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  primary key (user_id, id)
);
alter table public.decisions enable row level security;

drop policy if exists "decisions: read own" on public.decisions;
drop policy if exists "decisions: add own" on public.decisions;
drop policy if exists "decisions: change own" on public.decisions;
drop policy if exists "decisions: delete own" on public.decisions;
create policy "decisions: read own"   on public.decisions for select to authenticated using (user_id = auth.uid());
create policy "decisions: add own"    on public.decisions for insert to authenticated with check (user_id = auth.uid());
create policy "decisions: change own" on public.decisions for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "decisions: delete own" on public.decisions for delete to authenticated using (user_id = auth.uid());

-- 每次改动都盖上服务器的时间
create or replace function public.decisions_touch() returns trigger language plpgsql as $$
begin new.updated_at := now(); return new; end $$;
drop trigger if exists decisions_touch on public.decisions;
create trigger decisions_touch before insert or update on public.decisions for each row execute function public.decisions_touch();

-- 一台设备改了，另一台马上收到
do $$ begin
  alter publication supabase_realtime add table public.decisions;
exception when duplicate_object then null; end $$;
