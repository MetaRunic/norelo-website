-- =====================================================================
-- Diagnostic : qui a le droit d'ecrire dans paid_weeks, et quoi
-- Diagnostic: who may write paid_weeks, and what fires on it
--
-- NE MODIFIE RIEN. Lancez et envoyez-moi le tableau.
-- UNE SEULE REQUETE, parce que l'editeur Supabase n'affiche que le
-- resultat de la derniere instruction quand on en lance plusieurs.
--
-- POURQUOI
--   Une gestionnaire n'arrive pas a marquer sa propre semaine comme
--   payee depuis son telephone, alors que le proprietaire y arrive depuis
--   le PC. L'application ne fait rien de particulier pour sa propre
--   ligne, donc soit une regle cote serveur (politique RLS ou
--   declencheur) refuse ou annule l'ecriture, soit le probleme vient du
--   telephone. Ce tableau montre les regles; le Journal (action
--   "Paiement refuse", version 36) montrera le message exact recu par
--   le telephone.
-- =====================================================================

select
  (select relrowsecurity from pg_class where oid = 'public.paid_weeks'::regclass)  as rls_active,

  (select string_agg(policyname || ' [' || cmd || '] roles=' || roles::text
                     || ' using=' || coalesce(qual, '-')
                     || ' check=' || coalesce(with_check, '-'), '  ||  '
                     order by cmd, policyname)
     from pg_policies
    where schemaname = 'public' and tablename = 'paid_weeks')                       as politiques,

  (select string_agg(t.tgname || ' -> ' || p.proname
                     || ' (' || pg_get_triggerdef(t.oid) || ')', '  ||  ' order by t.tgname)
     from pg_trigger t
     join pg_proc p on p.oid = t.tgfoid
    where t.tgrelid = 'public.paid_weeks'::regclass and not t.tgisinternal)        as declencheurs,

  (select string_agg(pg_get_functiondef(p.oid), '  ||  ')
     from pg_trigger t
     join pg_proc p on p.oid = t.tgfoid
    where t.tgrelid = 'public.paid_weeks'::regclass and not t.tgisinternal)        as code_declencheurs,

  (select pg_get_functiondef('public.is_manager()'::regprocedure))                 as is_manager,

  (select string_agg(username || ' = ' || role, ', ' order by username)
     from public.profiles where role = 'manager')                                  as gestionnaires,

  (select string_agg(column_name || ' ' || data_type
                     || coalesce(' default ' || column_default, ''), ', '
                     order by ordinal_position)
     from information_schema.columns
    where table_schema = 'public' and table_name = 'paid_weeks')                   as colonnes,

  (select string_agg(to_char(created_at, 'MM-DD HH24:MI') || ' ' || actor_name
                     || ' : ' || action || ' ' || coalesce(detail, ''), '  ||  '
                     order by created_at desc)
     from (select * from public.audit_log
            where action in ('mark_paid', 'mark_unpaid', 'pay_refused')
            order by created_at desc limit 25) x)                                  as journal_paiements;
