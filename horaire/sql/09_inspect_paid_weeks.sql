-- =====================================================================
-- Diagnostic : la vraie structure de paid_weeks
-- UNE SEULE REQUETE, parce que l'editeur Supabase n'affiche que le
-- resultat de la derniere instruction quand on en lance plusieurs.
--
-- NE MODIFIE RIEN. Lancez et envoyez-moi le tableau.
-- =====================================================================

select
  (select string_agg(column_name || '  ' || data_type, ' | ' order by ordinal_position)
     from information_schema.columns
    where table_schema = 'public' and table_name = 'paid_weeks')          as colonnes,
  (select count(*) from public.paid_weeks)                               as lignes,
  (select count(*) from information_schema.columns
    where table_schema = 'public' and table_name = 'paid_weeks'
      and column_name = 'paid')                                          as a_colonne_paid,
  (select count(*) from information_schema.columns
    where table_schema = 'public' and table_name = 'paid_weeks'
      and column_name = 'paid_amount')                                   as a_colonne_paid_amount;
