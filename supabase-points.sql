create table if not exists public.point_balances (
  user_id uuid primary key references auth.users(id) on delete cascade,
  points bigint not null default 0 check (points >= 0),
  updated_at timestamptz not null default now()
);

create table if not exists public.point_events (
  user_id uuid not null references auth.users(id) on delete cascade,
  action_key text not null,
  points integer not null check (points > 0),
  created_at timestamptz not null default now(),
  primary key (user_id, action_key),
  constraint point_events_known_action check (
    action_key in (
      'support:plastic-waste',
      'support:streetlight',
      'support:drainage',
      'support:harbor-trash',
      'waste:deposit-demo',
      'route:green-demo',
      'community:cleanup-demo'
    )
  )
);

alter table public.point_balances enable row level security;
alter table public.point_events enable row level security;

drop policy if exists "Users can read own point balance" on public.point_balances;
create policy "Users can read own point balance"
on public.point_balances for select to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "Users can read own point events" on public.point_events;
create policy "Users can read own point events"
on public.point_events for select to authenticated
using ((select auth.uid()) = user_id);

revoke all on public.point_balances, public.point_events from anon, authenticated;
grant select on public.point_balances, public.point_events to authenticated;

create or replace function public.initialize_point_balance()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.point_balances (user_id, points)
  values (new.id, 0)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists initialize_user_point_balance on auth.users;
create trigger initialize_user_point_balance
after insert on auth.users
for each row execute function public.initialize_point_balance();

insert into public.point_balances (user_id, points)
select id, 0 from auth.users
on conflict (user_id) do nothing;

create or replace function public.award_points(p_action_key text)
returns table(points_awarded integer, balance bigint, already_awarded boolean)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_reward integer;
  v_awarded boolean := false;
  v_balance bigint;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  case p_action_key
    when 'support:plastic-waste' then v_reward := 5;
    when 'support:streetlight' then v_reward := 5;
    when 'support:drainage' then v_reward := 5;
    when 'support:harbor-trash' then v_reward := 5;
    when 'waste:deposit-demo' then v_reward := 10;
    when 'route:green-demo' then v_reward := 25;
    when 'community:cleanup-demo' then v_reward := 100;
    else raise exception 'Unknown point action';
  end case;

  insert into public.point_balances (user_id, points)
  values (v_user_id, 0)
  on conflict (user_id) do nothing;

  insert into public.point_events (user_id, action_key, points)
  values (v_user_id, p_action_key, v_reward)
  on conflict (user_id, action_key) do nothing
  returning true into v_awarded;

  if coalesce(v_awarded, false) then
    update public.point_balances as pb
    set points = pb.points + v_reward, updated_at = now()
    where pb.user_id = v_user_id
    returning pb.points into v_balance;
  else
    select pb.points into v_balance
    from public.point_balances as pb
    where pb.user_id = v_user_id;
  end if;

  return query
  select
    case when coalesce(v_awarded, false) then v_reward else 0 end,
    v_balance,
    not coalesce(v_awarded, false);
end;
$$;

revoke all on function public.initialize_point_balance() from public, anon, authenticated;
revoke all on function public.award_points(text) from public, anon, authenticated;
