-- =====================================================================
-- Norelo Horaire : diagnostic, ou sont passees les heures de Jasmine
-- Norelo Horaire: diagnostic, where did Jasmine's hours go
--
-- CE SCRIPT NE MODIFIE RIEN. Il ne fait que lire.
-- THIS SCRIPT CHANGES NOTHING. It only reads.
--
-- Lancez les 5 sections et envoyez-moi le resultat.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Le compte existe-t-il, et sous quel nom d'utilisateur exact
--    Si la colonne username ne dit pas exactement 'jasmine', c'est la
--    cause: la section 2 du script 05 n'a rien trouve pour elle.
-- ---------------------------------------------------------------------
select id, username, name, role, team, rate
  from public.profiles
 where name ilike '%jasmin%' or username ilike '%jasmin%';

-- Et la liste complete, au cas ou le prenom serait ecrit autrement
select username, name, role, team, rate
  from public.profiles
 order by name;


-- ---------------------------------------------------------------------
-- 2. Combien de quarts chacun a-t-il entre mai et juillet 2026
--    Attendu si tout a fonctionne: 24 lignes chacun.
--    Si Jasmine affiche 0, ses lignes n'ont jamais ete inserees.
-- ---------------------------------------------------------------------
select p.name, p.username,
       count(*) as quarts,
       min(s.work_date) as premiere,
       max(s.work_date) as derniere,
       round(sum(extract(epoch from (s.end_time - s.start_time)) / 3600.0)::numeric, 2) as heures_brutes,
       count(*) filter (where s.lunch) as avec_pause_30min
  from public.shifts s
  join public.profiles p on p.id = s.employee_id
 where s.work_date between date '2026-05-01' and date '2026-07-31'
 group by p.name, p.username
 order by p.name;


-- ---------------------------------------------------------------------
-- 3. Les semaines marquees payees, mai a juillet
--    Attendu: Dan paye jusqu'au 6 juillet inclusivement.
--             Jasmine payee jusqu'au 15 juin SEULEMENT.
--    Les semaines du 22 juin, 29 juin et 6 juillet ne doivent PAS
--    apparaitre pour Jasmine.
-- ---------------------------------------------------------------------
select p.name, w.week_start, w.paid
  from public.paid_weeks w
  join public.profiles p on p.id = w.employee_id
 where w.week_start between date '2026-04-27' and date '2026-07-31'
 order by w.week_start, p.name;


-- ---------------------------------------------------------------------
-- 4. Le solde impaye reconstitue semaine par semaine, pour comparer
--    avec l'ecran Gestion. Reproduit le calcul de l'app: regulier
--    jusqu'a 8 h au taux horaire, le reste en heures supplementaires
--    seulement si approuvees, et la pause de 30 min si lunch est vrai
--    et que la personne n'est pas gestionnaire.
-- ---------------------------------------------------------------------
with j as (
  select p.id, p.name, p.role, p.rate,
         date_trunc('week', s.work_date)::date as semaine,
         greatest(extract(epoch from (s.end_time - s.start_time)) / 3600.0
                  - case when s.lunch and p.role <> 'manager' then 0.5 else 0 end, 0) as h
    from public.shifts s
    join public.profiles p on p.id = s.employee_id
   where s.work_date between date '2026-05-01' and date '2026-07-31'
     and s.start_time is not null and s.end_time is not null
)
select j.name, j.semaine,
       round(sum(j.h)::numeric, 2) as heures,
       round(sum(least(j.h, 8) * j.rate)::numeric, 2) as paie_reguliere,
       coalesce(bool_or(w.paid), false) as marquee_payee
  from j
  left join public.paid_weeks w on w.employee_id = j.id and w.week_start = j.semaine
 group by j.name, j.semaine
 order by j.semaine, j.name;


-- ---------------------------------------------------------------------
-- 5. La vue de saisie existe-t-elle encore
--    Si elle a ete supprimee (section 7 du script 05), c'est normal.
--    Si elle existe, on peut comparer directement ce qui manque.
-- ---------------------------------------------------------------------
select count(*) as vue_encore_presente
  from information_schema.views
 where table_schema = 'public' and table_name = 'v_hours_batch';
