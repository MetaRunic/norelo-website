-- =====================================================================
-- Norelo Horaire, diagnostic 04 : pourquoi une saisie est refusee
-- Norelo Horaire, diagnostic 04: why a save is refused
--
-- CE SCRIPT NE MODIFIE RIEN. Il ne fait que lire.
-- THIS SCRIPT CHANGES NOTHING. It only reads.
--
-- Lancez-le dans le SQL Editor et envoyez-moi le resultat des 4 sections.
-- Run it in the SQL Editor and send me the output of all 4 sections.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Les politiques RLS sur shifts
--    C'est ici que vit la regle des 24h, et peut-etre une regle de saison.
-- ---------------------------------------------------------------------
select policyname, cmd, roles, qual as using_clause, with_check
  from pg_policies
 where schemaname = 'public' and tablename = 'shifts'
 order by cmd, policyname;


-- ---------------------------------------------------------------------
-- 2. Les droits colonne par colonne sur shifts
--    Si le role authenticated a des droits par colonne, la nouvelle
--    colonne ot_status n'y est peut-etre pas, et TOUTE ecriture echoue.
--    C'est le suspect numero un depuis la migration 01.
-- ---------------------------------------------------------------------
select grantee, privilege_type, column_name
  from information_schema.column_privileges
 where table_schema = 'public' and table_name = 'shifts'
   and grantee in ('authenticated', 'anon', 'public')
 order by grantee, privilege_type, column_name;

-- Et les droits sur la table entiere, pour comparer
select grantee, privilege_type
  from information_schema.role_table_grants
 where table_schema = 'public' and table_name = 'shifts'
   and grantee in ('authenticated', 'anon', 'public')
 order by grantee, privilege_type;


-- ---------------------------------------------------------------------
-- 3. Le code des declencheurs et des fonctions d'aide
--    On cherche une condition sur la date d'ouverture de saison.
-- ---------------------------------------------------------------------
select p.proname as fonction, pg_get_functiondef(p.oid) as code
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and p.proname in ('guard_ot','guard_ot_status','sync_ot_status',
                     'guard_timeoff','is_manager','qc_today')
 order by p.proname;


-- ---------------------------------------------------------------------
-- 4. Les declencheurs actifs sur shifts, et leur ordre d'execution
--    Les declencheurs BEFORE se declenchent par ordre alphabetique.
-- ---------------------------------------------------------------------
select tgname as declencheur,
       case when tgenabled = 'D' then 'DESACTIVE' else 'actif' end as etat,
       pg_get_triggerdef(oid) as definition
  from pg_trigger
 where tgrelid = 'public.shifts'::regclass and not tgisinternal
 order by tgname;
