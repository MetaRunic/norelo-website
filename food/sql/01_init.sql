-- Bouffe, schema initial
-- Projet Supabase SEPARE. Ne jamais rouler ceci dans le projet horaire.
-- Ordre: ce fichier est le premier, rouler en entier dans l'editeur SQL.
--
-- Avant de rouler:
--   1. Creer un nouveau projet Supabase.
--   2. Authentication, Providers, Email: activer, et Confirm email: DESACTIVER.
--   3. Creer les deux comptes a la main dans Authentication, Users, avec
--      "Auto Confirm User" coche.
--   4. Authentication, Sign up: DESACTIVER une fois les deux comptes crees.
-- Apres avoir roule: voir la derniere section, inserer les deux membres.
--
-- PAS DE COURRIEL. On se connecte avec un prenom et un mot de passe.
-- Supabase exige quand meme une adresse, alors l'application en fabrique
-- une a partir du prenom: "Marc" devient marc@bouffe.local. Cette adresse
-- ne sort jamais de l'application et aucune boite ne la recoit, c'est un
-- identifiant, rien d'autre. Donc a l'etape 3, creer les comptes avec
-- exactement ces adresses la, en minuscules, sans accent ni espace.

-- ============ liste blanche ============

create table if not exists members (
  id            uuid primary key references auth.users(id) on delete cascade,
  display_name  text not null,
  kcal_target   int,
  protein_target int,
  portion_mult  numeric not null default 1.0,
  budget_week   numeric,
  created_at    timestamptz not null default now()
);

-- Toute la securite du projet tient sur cette fonction.
-- Un compte qui n'est pas dans members ne voit rien et n'ecrit rien.
create or replace function is_member() returns boolean
language sql security definer stable set search_path = public as $$
  select exists (select 1 from members where id = auth.uid());
$$;

-- ============ plats ============

create table if not exists dishes (
  id          bigserial primary key,
  name_fr     text not null,
  name_en     text not null,
  tags        text[] not null default '{}',
  prep_min    int,
  servings    int not null default 2,
  kcal        int,
  protein_g   int,
  fibre_g     int,
  veg_serv    numeric,
  steps_fr    text,
  steps_en    text,
  photo_url   text,
  cost_est    numeric,
  lighten_fr  text,
  lighten_en  text,
  archived    boolean not null default false,
  created_at  timestamptz not null default now()
);

create table if not exists ingredients (
  id        bigserial primary key,
  dish_id   bigint not null references dishes(id) on delete cascade,
  item_fr   text not null,
  item_en   text not null,
  qty       numeric,
  unit      text,
  store     text,
  aisle     int,
  bulk_min  numeric
);
create index if not exists ingredients_dish_idx on ingredients(dish_id);

-- ============ plan de la semaine ============

create table if not exists plan (
  id        bigserial primary key,
  day       date not null,
  slot      text not null check (slot in ('lunch','supper')),
  dish_id   bigint references dishes(id) on delete set null,
  kind      text not null default 'cook'
            check (kind in ('cook','leftovers','takeout','restaurant','out')),
  leftover_of bigint references plan(id) on delete set null,
  cook_id   uuid references members(id) on delete set null,
  wash_id   uuid references members(id) on delete set null,
  note      text,
  updated_at timestamptz not null default now(),
  unique (day, slot)
);
create index if not exists plan_day_idx on plan(day);

-- ============ notes des repas ============

create table if not exists ratings (
  dish_id   bigint not null references dishes(id) on delete cascade,
  member_id uuid not null references members(id) on delete cascade,
  stars     int not null check (stars between 1 and 5),
  comment   text,
  rated_at  timestamptz not null default now(),
  primary key (dish_id, member_id)
);

-- ============ garde-manger et liste ============

create table if not exists pantry (
  id      bigserial primary key,
  item_fr text not null,
  item_en text not null,
  qty     numeric,
  unit    text
);

create table if not exists list_state (
  week_start date not null,
  item_key   text not null,
  checked    boolean not null default false,
  primary key (week_start, item_key)
);

-- ============ depenses ============

create table if not exists shops (
  id      bigserial primary key,
  day     date not null,
  store   text not null,
  amount  numeric not null,
  note    text
);
create index if not exists shops_day_idx on shops(day);

-- ============ pointage ============

create table if not exists score (
  id         bigserial primary key,
  week_start date not null,
  action     text not null,
  points     int not null,
  ref        text,
  scored_at  timestamptz not null default now(),
  unique (week_start, action, ref)
);
create index if not exists score_week_idx on score(week_start);

-- ============ Row Level Security ============
-- Un seul modele pour tout: membre de la maison, acces complet.
-- Non membre, aucun acces. Il n'y a pas de role intermediaire ici,
-- contrairement au projet horaire.

alter table members     enable row level security;
alter table dishes      enable row level security;
alter table ingredients enable row level security;
alter table plan        enable row level security;
alter table ratings     enable row level security;
alter table pantry      enable row level security;
alter table list_state  enable row level security;
alter table shops       enable row level security;
alter table score       enable row level security;

do $$
declare t text;
begin
  foreach t in array array['dishes','ingredients','plan','ratings',
                           'pantry','list_state','shops','score']
  loop
    execute format('drop policy if exists house_all on %I', t);
    execute format(
      'create policy house_all on %I for all to authenticated
         using (is_member()) with check (is_member())', t);
  end loop;
end $$;

-- members: chacun lit la maison, mais ne modifie que sa propre ligne,
-- pour que personne ne change la cible de l'autre par accident.
drop policy if exists members_read on members;
create policy members_read on members
  for select to authenticated using (is_member());

drop policy if exists members_self on members;
create policy members_self on members
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- ============ a faire a la main, une fois ============
-- Remplacer les prenoms et les cibles, puis rouler ce bloc.
-- L'adresse est toujours le prenom en minuscules suivi de @bouffe.local,
-- la meme que celle utilisee pour creer le compte a l'etape 3.
--
-- insert into members (id, display_name, kcal_target, protein_target, portion_mult, budget_week)
-- select id, 'Marc', 2200, 140, 1.2, 200 from auth.users where email = 'marc@bouffe.local'
-- on conflict (id) do nothing;
--
-- insert into members (id, display_name, kcal_target, protein_target, portion_mult, budget_week)
-- select id, 'Julie', 1600, 110, 0.85, 200 from auth.users where email = 'julie@bouffe.local'
-- on conflict (id) do nothing;
--
-- Verification, doit retourner exactement deux lignes:
-- select m.display_name, u.email from members m join auth.users u on u.id = m.id;
