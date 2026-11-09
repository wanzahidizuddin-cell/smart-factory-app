-- Smart Factory QC - Phase 1 Supabase schema
-- Run in the Supabase SQL Editor on a fresh project.
-- New self-registered profiles remain pending until an administrator approves
-- them. Users may update their own contact details but cannot change access.

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null,
  role text not null default 'Warehouse',
  employee_id text not null unique,
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  constraint profiles_role_check
    check (role in ('Admin', 'QA Lead', 'QA', 'Warehouse')),
  constraint profiles_status_check
    check (status in ('pending', 'approved', 'rejected'))
);

-- Preserve access for profiles created by the original schema while requiring
-- approval for new registrations.
alter table public.profiles
  add column if not exists status text not null default 'approved';
alter table public.profiles alter column status set default 'pending';
alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles
  add constraint profiles_role_check
  check (role in ('Admin', 'QA Lead', 'QA', 'Warehouse'));
alter table public.profiles drop constraint if exists profiles_status_check;
alter table public.profiles
  add constraint profiles_status_check
  check (status in ('pending', 'approved', 'rejected'));

create table if not exists public.deliveries (
  id uuid primary key default gen_random_uuid(),
  batch_number text not null unique,
  supplier text not null,
  material text not null,
  material_code text not null default '',
  material_specs jsonb not null default '{}'::jsonb,
  packaging text not null default '',
  quantity numeric(14, 3) not null check (quantity > 0),
  unit text not null,
  status text not null default 'Quarantined'
    check (status in ('Passed', 'Quarantined', 'Released')),
  needs_review boolean not null default false,
  received_at timestamptz not null default now(),
  inspection_notes text not null default '',
  hold_reason text not null default '',
  release_note text not null default '',
  received_by uuid references public.profiles (id) on delete restrict,
  authorized_by uuid references public.profiles (id) on delete restrict,
  authorized_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.inventory_items (
  id uuid primary key default gen_random_uuid(),
  sku text not null unique,
  name text not null,
  rack_location text not null,
  current_quantity numeric(14, 3) not null default 0
    check (current_quantity >= 0),
  reorder_level numeric(14, 3) not null default 0
    check (reorder_level >= 0),
  target_level numeric(14, 3) not null default 0
    check (target_level >= 0),
  unit text not null default 'unit',
  supplier text not null default '',
  specifications text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists public.inspections (
  id uuid primary key default gen_random_uuid(),
  serial_number text not null,
  delivery_id uuid not null
    references public.deliveries (id) on delete restrict,
  machine text not null,
  defect_category text not null default '',
  result text not null check (result in ('Pass', 'Fail')),
  notes text not null default '',
  photo_url text,
  photo_count integer not null default 0 check (photo_count >= 0),
  inspector_id uuid not null
    references public.profiles (id) on delete restrict,
  recorded_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists public.audit_events (
  id uuid primary key default gen_random_uuid(),
  event_type text not null
    check (event_type in (
      'delivery_created',
      'delivery_status_changed',
      'inspection_recorded'
    )),
  title text not null,
  description text not null default '',
  record_id text not null,
  status text,
  delivery_id uuid references public.deliveries (id) on delete restrict,
  inspection_id uuid references public.inspections (id) on delete restrict,
  actor_id uuid references public.profiles (id) on delete restrict,
  created_at timestamptz not null default now(),
  check (status is null or status in (
    'Passed', 'Quarantined', 'Released', 'Pass', 'Fail'
  ))
);

create index if not exists deliveries_status_idx
  on public.deliveries (status);
create index if not exists inspections_delivery_id_idx
  on public.inspections (delivery_id);
create index if not exists inspections_inspector_id_idx
  on public.inspections (inspector_id);
create index if not exists audit_events_delivery_created_at_idx
  on public.audit_events (delivery_id, created_at desc);
create index if not exists audit_events_inspection_id_idx
  on public.audit_events (inspection_id);
create index if not exists profiles_status_created_at_idx
  on public.profiles (status, created_at);

alter table public.profiles enable row level security;
alter table public.deliveries enable row level security;
alter table public.inventory_items enable row level security;
alter table public.inspections enable row level security;
alter table public.audit_events enable row level security;

drop policy if exists profiles_authenticated_read on public.profiles;
create policy profiles_authenticated_read
  on public.profiles for select to authenticated
  using (true);

drop policy if exists profiles_self_register on public.profiles;
create policy profiles_self_register
  on public.profiles for insert to authenticated
  with check (
    id = (select auth.uid())
    and role = 'Warehouse'
    and status = 'pending'
  );

drop policy if exists profiles_self_update on public.profiles;
create policy profiles_self_update
  on public.profiles for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

drop policy if exists profiles_management_update on public.profiles;
create policy profiles_management_update
  on public.profiles for update to authenticated
  using (
    exists (
      select 1
      from public.profiles p
      where p.id = (select auth.uid())
        and p.role in ('Admin', 'QA Lead')
        and p.status = 'approved'
    )
  )
  with check (
    exists (
      select 1
      from public.profiles p
      where p.id = (select auth.uid())
        and p.role in ('Admin', 'QA Lead')
        and p.status = 'approved'
    )
  );

create or replace function public.prevent_profile_access_escalation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if (new.role is distinct from old.role
      or new.status is distinct from old.status)
    and not exists (
      select 1
      from public.profiles p
      where p.id = (select auth.uid())
        and p.role in ('Admin', 'QA Lead')
        and p.status = 'approved'
    ) then
    raise exception 'Only approved administrators may change profile access';
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_prevent_access_escalation on public.profiles;
create trigger profiles_prevent_access_escalation
  before update on public.profiles
  for each row execute function public.prevent_profile_access_escalation();

drop policy if exists deliveries_authenticated_read on public.deliveries;
create policy deliveries_authenticated_read
  on public.deliveries for select to authenticated
  using (true);

drop policy if exists deliveries_qa_or_warehouse_insert on public.deliveries;
create policy deliveries_qa_or_warehouse_insert
  on public.deliveries for insert to authenticated
  with check (
    exists (
      select 1
      from public.profiles p
      where p.id = (select auth.uid())
        and p.role in ('Admin', 'QA Lead', 'QA', 'Warehouse')
        and p.status = 'approved'
    )
  );

drop policy if exists deliveries_qa_update on public.deliveries;
create policy deliveries_qa_update
  on public.deliveries for update to authenticated
  using (
    exists (
      select 1
      from public.profiles p
      where p.id = (select auth.uid())
        and p.role in ('Admin', 'QA Lead', 'QA')
        and p.status = 'approved'
    )
  )
  with check (
    exists (
      select 1
      from public.profiles p
      where p.id = (select auth.uid())
        and p.role in ('Admin', 'QA Lead', 'QA')
        and p.status = 'approved'
    )
  );

drop policy if exists inventory_authenticated_read on public.inventory_items;
create policy inventory_authenticated_read
  on public.inventory_items for select to authenticated
  using (true);

drop policy if exists inventory_warehouse_insert on public.inventory_items;
create policy inventory_warehouse_insert
  on public.inventory_items for insert to authenticated
  with check (
    exists (
      select 1
      from public.profiles p
      where p.id = (select auth.uid())
        and p.role = 'Warehouse'
        and p.status = 'approved'
    )
  );

drop policy if exists inventory_warehouse_update on public.inventory_items;
create policy inventory_warehouse_update
  on public.inventory_items for update to authenticated
  using (
    exists (
      select 1
      from public.profiles p
      where p.id = (select auth.uid())
        and p.role = 'Warehouse'
        and p.status = 'approved'
    )
  )
  with check (
    exists (
      select 1
      from public.profiles p
      where p.id = (select auth.uid())
        and p.role = 'Warehouse'
        and p.status = 'approved'
    )
  );

create or replace view public.low_stock_inventory_items
with (security_invoker = true)
as
  select id
  from public.inventory_items
  where current_quantity <= reorder_level;

grant select on public.low_stock_inventory_items to authenticated;

drop policy if exists inspections_authenticated_read on public.inspections;
create policy inspections_authenticated_read
  on public.inspections for select to authenticated
  using (true);

drop policy if exists inspections_qa_insert on public.inspections;
create policy inspections_qa_insert
  on public.inspections for insert to authenticated
  with check (
    inspector_id = (select auth.uid())
    and exists (
      select 1
      from public.profiles p
      where p.id = (select auth.uid())
        and p.role in ('Admin', 'QA Lead', 'QA')
        and p.status = 'approved'
    )
  );

drop policy if exists audit_events_authenticated_read on public.audit_events;
create policy audit_events_authenticated_read
  on public.audit_events for select to authenticated
  using (true);

-- Clients may read audit events, but only the database triggers below may add
-- them. No UPDATE or DELETE policy is defined for this append-only ledger.

grant select on public.profiles, public.deliveries, public.inventory_items,
  public.inspections, public.audit_events to authenticated;
grant insert on public.profiles, public.deliveries, public.inventory_items,
  public.inspections to authenticated;
grant update (full_name, employee_id, role, status) on public.profiles
  to authenticated;
grant update on public.deliveries, public.inventory_items to authenticated;

create or replace function public.record_qc_audit_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_table_name = 'deliveries' then
    if tg_op = 'INSERT' then
      insert into public.audit_events (
        event_type, title, description, record_id, status, delivery_id, actor_id
      ) values (
        'delivery_created',
        'Delivery received',
        format('Batch %s created with status %s.', new.batch_number, new.status),
        new.batch_number,
        new.status,
        new.id,
        coalesce(auth.uid(), new.received_by)
      );
    elsif old.status is distinct from new.status then
      insert into public.audit_events (
        event_type, title, description, record_id, status, delivery_id, actor_id
      ) values (
        'delivery_status_changed',
        'Batch status changed',
        format('Batch %s changed from %s to %s.',
          new.batch_number, old.status, new.status),
        new.batch_number,
        new.status,
        new.id,
        auth.uid()
      );
    end if;
  elsif tg_table_name = 'inspections' then
    insert into public.audit_events (
      event_type, title, description, record_id, status,
      delivery_id, inspection_id, actor_id
    ) values (
      'inspection_recorded',
      'Inspection recorded',
      format('Inspection %s recorded with result %s.',
        new.serial_number, new.result),
      new.serial_number,
      new.result,
      new.delivery_id,
      new.id,
      new.inspector_id
    );
  end if;

  return new;
end;
$$;

drop trigger if exists deliveries_audit_insert on public.deliveries;
create trigger deliveries_audit_insert
  after insert on public.deliveries
  for each row execute function public.record_qc_audit_event();

drop trigger if exists deliveries_audit_status_update on public.deliveries;
create trigger deliveries_audit_status_update
  after update of status on public.deliveries
  for each row execute function public.record_qc_audit_event();

drop trigger if exists inspections_audit_insert on public.inspections;
create trigger inspections_audit_insert
  after insert on public.inspections
  for each row execute function public.record_qc_audit_event();

create or replace function public.prevent_audit_event_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'audit_events is append-only; corrections must be new events';
end;
$$;

drop trigger if exists audit_events_prevent_mutation on public.audit_events;
create trigger audit_events_prevent_mutation
  before update or delete on public.audit_events
  for each row execute function public.prevent_audit_event_mutation();
