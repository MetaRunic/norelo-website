-- =====================================================================
-- Norelo Prospects, migration 01 : le suivi de prospection
-- Norelo Prospects, migration 01: the prospecting tracker
--
-- A EXECUTER dans le SQL Editor de Supabase AVANT de deployer
-- prospects/index.html.
--
-- Ce script est idempotent : vous pouvez le relancer sans risque.
-- This script is idempotent: it is safe to run more than once.
--
-- CE QUE CA CREE / WHAT IT CREATES
--   * public.prospects          : une ligne par entreprise reperee
--   * public.prospect_contacts  : le journal des contacts (qui, quand,
--                                 par quel moyen, resultat). C'est ce
--                                 journal qui empeche deux employes de
--                                 deranger la meme entreprise.
--   * un declencheur qui garde prospects.last_contact_at a jour
--   * RLS : seuls les comptes connectes (les memes que l'horaire)
--     peuvent lire et ecrire. Le site est public, la table ne l'est pas.
-- =====================================================================

create extension if not exists pgcrypto;


-- ---------------------------------------------------------------------
-- 1. La table des prospects / the prospects table
-- ---------------------------------------------------------------------
create table if not exists public.prospects (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  date_added timestamptz not null default now()
);

-- Colonnes ajoutees une par une : si la table existait deja avec
-- l'ancien schema, rien n'est perdu.
alter table public.prospects add column if not exists category        text;
alter table public.prospects add column if not exists town            text;
alter table public.prospects add column if not exists address         text;
alter table public.prospects add column if not exists website         text;
alter table public.prospects add column if not exists website_status  text not null default 'unknown';
alter table public.prospects add column if not exists email           text;
alter table public.prospects add column if not exists phone           text;
alter table public.prospects add column if not exists contact_name    text;
alter table public.prospects add column if not exists source          text;
alter table public.prospects add column if not exists notes           text;
alter table public.prospects add column if not exists status          text not null default 'nouveau';
alter table public.prospects add column if not exists next_followup   date;
alter table public.prospects add column if not exists archived        boolean not null default false;
alter table public.prospects add column if not exists added_by        text;
alter table public.prospects add column if not exists added_by_id     uuid;
alter table public.prospects add column if not exists last_contact_at timestamptz;
alter table public.prospects add column if not exists last_contact_by text;
alter table public.prospects add column if not exists updated_at      timestamptz not null default now();

-- Reprise de l'ancienne colonne booleenne "contacted", si elle existe.
do $$
begin
  if exists (
    select 1 from information_schema.columns
     where table_schema = 'public' and table_name = 'prospects'
       and column_name = 'contacted'
  ) then
    execute $q$
      update public.prospects
         set status = 'contacte'
       where contacted is true and status = 'nouveau'
    $q$;
  end if;
end $$;

-- L'ancienne colonne s'appelait "website" et contenait none/bad/good.
-- Si c'est le cas, on deplace la valeur vers website_status et on vide
-- website pour qu'il ne contienne plus qu'une vraie adresse web.
update public.prospects
   set website_status = website,
       website        = null
 where website in ('none', 'bad', 'good', 'unknown');


-- ---------------------------------------------------------------------
-- 2. Valeurs permises / allowed values
-- ---------------------------------------------------------------------
alter table public.prospects drop constraint if exists prospects_status_chk;
alter table public.prospects
  add constraint prospects_status_chk
  check (status in (
    'nouveau',          -- repere, jamais approche
    'a_contacter',      -- a faire cette semaine
    'contacte',         -- premier contact fait
    'relance',          -- on attend, relance prevue
    'interesse',        -- a repondu, veut en savoir plus
    'devis',            -- soumission envoyee
    'client',           -- gagne
    'pas_interesse',    -- a dit non
    'ne_pas_contacter'  -- a demande qu'on arrete. INTOUCHABLE.
  ));

alter table public.prospects drop constraint if exists prospects_website_status_chk;
alter table public.prospects
  add constraint prospects_website_status_chk
  check (website_status in ('none', 'bad', 'good', 'unknown'));


-- ---------------------------------------------------------------------
-- 3. Le journal des contacts / the contact log
--    Une ligne = une fois ou un humain a derange l'entreprise.
-- ---------------------------------------------------------------------
create table if not exists public.prospect_contacts (
  id uuid primary key default gen_random_uuid(),
  prospect_id uuid not null references public.prospects(id) on delete cascade,
  happened_at timestamptz not null default now(),
  channel text not null default 'appel',
  outcome text not null default 'aucune_reponse',
  notes text,
  by_name text,
  by_id uuid,
  created_at timestamptz not null default now()
);

alter table public.prospect_contacts drop constraint if exists prospect_contacts_channel_chk;
alter table public.prospect_contacts
  add constraint prospect_contacts_channel_chk
  check (channel in ('appel', 'courriel', 'sms', 'visite', 'facebook', 'autre'));

alter table public.prospect_contacts drop constraint if exists prospect_contacts_outcome_chk;
alter table public.prospect_contacts
  add constraint prospect_contacts_outcome_chk
  check (outcome in (
    'aucune_reponse',     -- pas de reponse, boite vocale
    'a_rappeler',         -- rappeler plus tard
    'interesse',          -- ouverture
    'rendez_vous',        -- rencontre fixee
    'pas_interesse',      -- non poli
    'ne_plus_contacter',  -- a demande qu'on arrete
    'autre'
  ));

create index if not exists prospect_contacts_prospect_idx
  on public.prospect_contacts (prospect_id, happened_at desc);

create index if not exists prospects_archived_idx
  on public.prospects (archived, date_added desc);


-- ---------------------------------------------------------------------
-- 4. prospects.last_contact_at suit toujours le journal
--    Recalcule a chaque insertion, modification ou suppression d'un
--    contact : impossible que l'affichage mente sur la derniere approche.
-- ---------------------------------------------------------------------
create or replace function public.prospect_sync_last_contact()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  pid uuid;
  mx timestamptz;
  who text;
begin
  pid := coalesce(new.prospect_id, old.prospect_id);

  select c.happened_at, c.by_name
    into mx, who
    from public.prospect_contacts c
   where c.prospect_id = pid
   order by c.happened_at desc
   limit 1;

  update public.prospects
     set last_contact_at = mx,
         last_contact_by = who
   where id = pid;

  return null;
end $$;

drop trigger if exists prospect_contacts_sync on public.prospect_contacts;
create trigger prospect_contacts_sync
  after insert or update or delete on public.prospect_contacts
  for each row execute function public.prospect_sync_last_contact();

-- Remise a niveau des lignes existantes / backfill
update public.prospects p
   set last_contact_at = c.mx,
       last_contact_by = c.who
  from (
    select distinct on (prospect_id)
           prospect_id, happened_at as mx, by_name as who
      from public.prospect_contacts
     order by prospect_id, happened_at desc
  ) c
 where c.prospect_id = p.id
   and p.last_contact_at is distinct from c.mx;


-- ---------------------------------------------------------------------
-- 5. updated_at
-- ---------------------------------------------------------------------
create or replace function public.prospects_touch_updated()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists prospects_touch on public.prospects;
create trigger prospects_touch
  before update on public.prospects
  for each row execute function public.prospects_touch_updated();


-- ---------------------------------------------------------------------
-- 6. RLS : connecte = acces, anonyme = rien
--    Les comptes sont les memes que ceux de l'horaire (table profiles).
-- ---------------------------------------------------------------------
alter table public.prospects          enable row level security;
alter table public.prospect_contacts  enable row level security;

drop policy if exists prospects_select on public.prospects;
drop policy if exists prospects_insert on public.prospects;
drop policy if exists prospects_update on public.prospects;
drop policy if exists prospects_delete on public.prospects;

create policy prospects_select on public.prospects
  for select to authenticated using (true);
create policy prospects_insert on public.prospects
  for insert to authenticated with check (true);
create policy prospects_update on public.prospects
  for update to authenticated using (true) with check (true);
-- Suppression reservee aux gestionnaires : l'app archive au lieu de
-- supprimer, pour ne jamais perdre la trace d'un contact deja fait.
create policy prospects_delete on public.prospects
  for delete to authenticated
  using (exists (
    select 1 from public.profiles pr
     where pr.id = auth.uid() and pr.role = 'manager'
  ));

drop policy if exists prospect_contacts_select on public.prospect_contacts;
drop policy if exists prospect_contacts_insert on public.prospect_contacts;
drop policy if exists prospect_contacts_update on public.prospect_contacts;
drop policy if exists prospect_contacts_delete on public.prospect_contacts;

create policy prospect_contacts_select on public.prospect_contacts
  for select to authenticated using (true);
create policy prospect_contacts_insert on public.prospect_contacts
  for insert to authenticated with check (true);
-- Un employe peut corriger ou effacer SA propre entree de journal.
-- Un gestionnaire peut corriger n'importe laquelle.
create policy prospect_contacts_update on public.prospect_contacts
  for update to authenticated
  using (by_id = auth.uid() or exists (
    select 1 from public.profiles pr
     where pr.id = auth.uid() and pr.role = 'manager'))
  with check (true);
create policy prospect_contacts_delete on public.prospect_contacts
  for delete to authenticated
  using (by_id = auth.uid() or exists (
    select 1 from public.profiles pr
     where pr.id = auth.uid() and pr.role = 'manager'));


-- ---------------------------------------------------------------------
-- 7. Temps reel / realtime, pour que deux employes se voient travailler
-- ---------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public' and tablename = 'prospects'
  ) then
    execute 'alter publication supabase_realtime add table public.prospects';
  end if;

  if not exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public' and tablename = 'prospect_contacts'
  ) then
    execute 'alter publication supabase_realtime add table public.prospect_contacts';
  end if;
end $$;
