-- =====================================================================
-- Norelo Horaire, migration 02 : suppression des sauvegardes
-- Norelo Horaire, migration 02: delete backups
--
-- RUN ORDER : 2 of 3.  A lancer dans le SQL Editor de Supabase.
-- Idempotent : vous pouvez le relancer sans risque.
--
-- POURQUOI UNE POLITIQUE RLS PLUTOT QUE quick-api / WHY RLS NOT quick-api
--   La fonction edge quick-api n'est pas dans ce depot, elle vit dans
--   Supabase. Ajouter une politique DELETE reservee aux gestionnaires
--   donne le meme resultat sans redeployer la fonction, et l'app peut
--   appeler sb.from('backups').delete() directement.
--
-- CE QUI CHANGE / WHAT CHANGES
--   * une seule nouvelle politique : DELETE sur public.backups,
--     reservee aux gestionnaires (public.is_manager()).
--   * aucune politique existante (select / insert / update) n'est
--     touchee. Aucun autre acces n'est elargi.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Etat actuel, a lire avant d'appliquer / current state, read first
--    Verifiez que RLS est bien active sur backups et regardez les
--    politiques deja en place.
-- ---------------------------------------------------------------------
select relname          as table,
       relrowsecurity   as rls_enabled
  from pg_class
 where oid = 'public.backups'::regclass;

select policyname, cmd, roles, qual, with_check
  from pg_policies
 where schemaname = 'public'
   and tablename  = 'backups'
 order by cmd, policyname;


-- ---------------------------------------------------------------------
-- 2. La politique / the policy
-- ---------------------------------------------------------------------
drop policy if exists backups_delete_manager on public.backups;
create policy backups_delete_manager
  on public.backups
  for delete
  to authenticated
  using (public.is_manager());


-- ---------------------------------------------------------------------
-- 3. Verification / check
--    Attendu : une ligne backups_delete_manager avec cmd = DELETE.
-- ---------------------------------------------------------------------
select policyname, cmd, qual
  from pg_policies
 where schemaname = 'public'
   and tablename  = 'backups'
   and cmd = 'DELETE';
