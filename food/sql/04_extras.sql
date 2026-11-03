-- Bouffe, collations, gateries et extras
-- Rouler apres 01_init.sql, dans le projet norelo-food.
-- A rouler une seule fois.
--
-- POURQUOI: la liste d'epicerie se construisait uniquement a partir des
-- repas de la semaine. Tout ce qui ne vient pas d'une recette, les
-- collations, les gateries, le papier de toilette, n'avait nulle part ou
-- aller. Cette table porte ces articles la.
--
-- every_week a vrai: l'article revient sur la liste toutes les semaines.
-- every_week a faux: l'article ne sort que pour la semaine de week_start.
--
-- L'application fonctionne sans cette table, la section des extras est
-- simplement absente tant qu'elle n'existe pas. Rien ne casse.

create table if not exists extras (
  id          bigserial primary key,
  item_fr     text not null,
  item_en     text not null,
  qty         numeric,
  unit        text,
  store       text,
  aisle       int,
  every_week  boolean not null default false,
  week_start  date,
  created_at  timestamptz not null default now()
);

create index if not exists extras_week_idx on extras(week_start);

alter table extras enable row level security;

drop policy if exists house_all on extras;
create policy house_all on extras for all to authenticated
  using (is_member()) with check (is_member());

-- Verification: doit retourner la table avec zero ligne.
select count(*) as extras_existants from extras;
