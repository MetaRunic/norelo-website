-- =====================================================================
-- Norelo Horaire, migration 12 : paie preparee (comptee et mise en sac)
-- Norelo Horaire, migration 12: pay prepared (counted and bagged)
--
-- RUN ORDER : apres 08. Idempotent, relancable sans risque.
-- A executer avant ou juste apres le deploiement de la version 35.
-- Tant qu'elle n'est pas passee, l'application cache le bouton Preparer
-- et affiche une note sous le tableau de Gestion. Le bouton Paye, lui,
-- continue de fonctionner comme avant.
--
-- CE QUI CHANGE / WHAT CHANGES
--   * paid_weeks.prepared    : vrai quand l'enveloppe est comptee et en sac
--   * paid_weeks.prepared_at : quand elle l'a ete
--   * paid_weeks.paid recoit la valeur par defaut false, pour qu'une ligne
--     puisse etre creee par le bouton Preparer avant tout paiement.
--   * la table est ajoutee a la publication temps reel si elle n'y est
--     pas deja, pour que les autres gestionnaires voient le changement.
--
--   AUCUNE politique RLS n'est modifiee : les politiques existantes de
--   paid_weeks couvrent les nouvelles colonnes, car elles s'appliquent
--   par ligne. LE CALCUL DE PAIE NE CHANGE PAS : prepared n'est qu'un
--   drapeau d'organisation, il ne touche ni aux heures ni aux montants.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Les colonnes / the columns
-- ---------------------------------------------------------------------
alter table public.paid_weeks
  add column if not exists prepared    boolean not null default false,
  add column if not exists prepared_at timestamptz;

alter table public.paid_weeks alter column paid set default false;


-- ---------------------------------------------------------------------
-- 2. Temps reel / realtime
--    Sans effet si la table est deja publiee.
-- ---------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public' and tablename = 'paid_weeks')
  then
    alter publication supabase_realtime add table public.paid_weeks;
  end if;
end $$;


-- ---------------------------------------------------------------------
-- 3. Verification / check
--    Attendu : trois lignes, paid avec column_default = false,
--    prepared avec column_default = false, prepared_at nullable.
-- ---------------------------------------------------------------------
select column_name, data_type, is_nullable, column_default
  from information_schema.columns
 where table_schema = 'public' and table_name = 'paid_weeks'
   and column_name in ('paid', 'prepared', 'prepared_at')
 order by ordinal_position;
