-- =====================================================================
-- Norelo Horaire : saisie groupee des heures, mai a juillet 2026
-- Norelo Horaire: bulk hours entry, May to July 2026
--
-- 24 dates pour 2 personnes. Les pauses sont DEJA comprises dans les
-- heures donnees, donc lunch = false partout: aucune demi-heure ne sera
-- retiree. Aucune journee ne depasse 8 h, donc aucune heure
-- supplementaire n'est creee.
--
-- MARCHE A SUIVRE / HOW TO USE
--   a) Section 1: verifiez les deux noms d'utilisateur et corrigez-les.
--   b) Section 2: creez la vue. Elle ne touche a rien.
--   c) Section 3: regardez ce qui existe deja, surtout en juillet.
--   d) Section 4: apercu de ce qui serait ecrit.
--   e) Section 5: l'ecriture. Par defaut elle N'ECRASE RIEN.
--   f) Section 7: menage.
-- =====================================================================


-- =====================================================================
-- SECTION 1 : QUI EST QUI / WHO IS WHO
-- Lancez ceci et notez les deux noms d'utilisateur exacts.
-- =====================================================================
select username, name, role, team, rate
  from public.profiles
 order by role desc, name;


-- =====================================================================
-- SECTION 2 : LES DONNEES / THE DATA
--
-- Remplacez 'dan' et 'jasmine' ligne suivante par les noms d'utilisateur
-- exacts vus en section 1. Tout le reste se deduit de la.
--
-- Deux exceptions sont deja encodees:
--   15 juin : Dan fait une heure de moins, donc 09:15 a 15:00.
--   16 juin : Dan arrive a 11:30, donc 11:30 a 16:15.
-- =====================================================================

create or replace view public.v_hours_batch as
with cfg(dan_user, jas_user) as (
  values ('dan', 'jasmine')            -- <== LES DEUX NOMS D'UTILISATEUR
),
d(work_date, dan_start, dan_end, jas_start, jas_end) as (values
  (date '2026-05-11', time '11:00', time '16:00', time '11:00', time '16:00'),
  (date '2026-05-12', time '09:30', time '15:00', time '09:30', time '15:00'),
  (date '2026-05-20', time '10:00', time '15:00', time '10:00', time '15:00'),
  (date '2026-05-26', time '10:15', time '15:15', time '10:15', time '15:15'),
  (date '2026-05-28', time '10:25', time '15:00', time '10:25', time '15:00'),
  (date '2026-06-01', time '10:20', time '16:35', time '10:20', time '16:35'),
  (date '2026-06-02', time '10:00', time '14:30', time '10:00', time '14:30'),
  (date '2026-06-03', time '09:20', time '14:10', time '09:20', time '14:10'),
  (date '2026-06-05', time '08:15', time '16:00', time '08:15', time '16:00'),
  (date '2026-06-08', time '09:15', time '15:15', time '09:15', time '15:15'),
  (date '2026-06-09', time '09:15', time '15:30', time '09:15', time '15:30'),
  (date '2026-06-11', time '09:15', time '13:45', time '09:15', time '13:45'),
  (date '2026-06-12', time '09:15', time '14:00', time '09:15', time '14:00'),
  (date '2026-06-15', time '09:15', time '15:00', time '09:15', time '16:00'),  -- Dan une heure de moins
  (date '2026-06-16', time '11:30', time '16:15', time '09:15', time '16:15'),  -- Dan arrive a 11:30
  (date '2026-06-22', time '09:30', time '16:30', time '09:30', time '16:30'),
  (date '2026-06-25', time '10:00', time '15:30', time '10:00', time '15:30'),
  (date '2026-06-29', time '10:00', time '16:00', time '10:00', time '16:00'),
  (date '2026-06-30', time '11:00', time '14:15', time '11:00', time '14:15'),
  (date '2026-07-06', time '10:30', time '15:00', time '10:30', time '15:00'),
  (date '2026-07-07', time '10:30', time '16:00', time '10:30', time '16:00'),
  (date '2026-07-09', time '10:15', time '14:00', time '10:15', time '14:00'),
  (date '2026-07-10', time '10:45', time '15:15', time '10:45', time '15:15'),
  (date '2026-07-13', time '10:15', time '16:00', time '10:15', time '16:00')
)
select p.id                as employee_id,
       p.name              as person,
       x.who               as who,
       x.uname             as username,
       d.work_date,
       x.st                as start_time,
       x.en                as end_time,
       round(extract(epoch from (x.en - x.st)) / 3600.0, 2) as hours
  from d
  cross join cfg
  cross join lateral (values
        ('dan', cfg.dan_user, d.dan_start, d.dan_end),
        ('jas', cfg.jas_user, d.jas_start, d.jas_end)
  ) as x(who, uname, st, en)
  join public.profiles p on lower(p.username) = lower(x.uname);


-- Controle: 48 lignes attendues, 24 par personne. Si vous en voyez 24,
-- un des deux noms d'utilisateur ne correspond a aucun compte.
select person, username, count(*) as lignes,
       round(sum(hours), 2) as total_heures,
       min(work_date) as du, max(work_date) as au
  from public.v_hours_batch
 group by person, username
 order by person;


-- =====================================================================
-- SECTION 3 : CE QUI EXISTE DEJA / WHAT IS ALREADY THERE
--
-- Vous avez dit avoir deja saisi quelques dates de juillet. Regardez
-- ici avant d'ecrire: ces lignes ne seront PAS touchees en section 5.
-- =====================================================================
select b.person, b.work_date,
       s.start_time as deja_debut, s.end_time as deja_fin,
       b.start_time as propose_debut, b.end_time as propose_fin,
       case when s.start_time = b.start_time and s.end_time = b.end_time
            then 'identique' else 'DIFFERENT' end as comparaison
  from public.v_hours_batch b
  join public.shifts s
    on s.employee_id = b.employee_id and s.work_date = b.work_date
 order by b.work_date, b.person;


-- =====================================================================
-- SECTION 4 : APERCU DE L'ECRITURE / PREVIEW
-- Les lignes qui seraient reellement ajoutees.
-- =====================================================================
select b.person, b.work_date, b.start_time, b.end_time, b.hours
  from public.v_hours_batch b
 where not exists (select 1 from public.shifts s
                    where s.employee_id = b.employee_id
                      and s.work_date  = b.work_date)
 order by b.work_date, b.person;

select count(*) as lignes_a_ajouter
  from public.v_hours_batch b
 where not exists (select 1 from public.shifts s
                    where s.employee_id = b.employee_id
                      and s.work_date  = b.work_date);


-- =====================================================================
-- SECTION 5 : L'ECRITURE / THE WRITE
--
-- N'ECRASE RIEN. Toute date qui a deja une ligne est laissee telle
-- quelle. lunch = false, car les pauses sont deja dans les heures.
-- =====================================================================

begin;

insert into public.shifts (employee_id, work_date, start_time, end_time, lunch, ot_approved, ot_status)
select b.employee_id, b.work_date, b.start_time, b.end_time, false, false, 'pending'
  from public.v_hours_batch b
 where not exists (select 1 from public.shifts s
                    where s.employee_id = b.employee_id
                      and s.work_date  = b.work_date);

commit;


-- ---------------------------------------------------------------------
-- SECTION 5b : VARIANTE QUI ECRASE / OVERWRITE VARIANT
-- A n'utiliser QUE si la section 3 montre des lignes DIFFERENT et que
-- vous voulez que la nouvelle valeur gagne. Decommentez pour l'utiliser.
-- ---------------------------------------------------------------------
-- begin;
-- insert into public.shifts (employee_id, work_date, start_time, end_time, lunch, ot_approved, ot_status)
-- select b.employee_id, b.work_date, b.start_time, b.end_time, false, false, 'pending'
--   from public.v_hours_batch b
-- on conflict (employee_id, work_date) do update
--   set start_time = excluded.start_time,
--       end_time   = excluded.end_time,
--       lunch      = false,
--       ot_status  = 'pending';
-- commit;


-- =====================================================================
-- SECTION 6 : VERIFICATION
-- Compare ce qui est en base avec ce qui etait demande.
-- =====================================================================
select b.person, b.work_date, b.start_time, b.end_time,
       case when s.id is null then 'MANQUANTE'
            when s.start_time = b.start_time and s.end_time = b.end_time and s.lunch = false
                 then 'ok'
            else 'a verifier' end as etat,
       s.lunch as pause_30min
  from public.v_hours_batch b
  left join public.shifts s
    on s.employee_id = b.employee_id and s.work_date = b.work_date
 order by b.work_date, b.person;

-- Totaux par personne et par semaine de paie
select b.person,
       date_trunc('week', b.work_date)::date as semaine,
       round(sum(b.hours), 2) as heures
  from public.v_hours_batch b
 group by b.person, 2
 order by 2, 1;


-- =====================================================================
-- SECTION 6b : MARQUER LES SEMAINES PAYEES / MARK THE PAID WEEKS
--
-- Tout ce qui precede la mention PAID est paye pour LES DEUX, soit
-- jusqu'a la semaine du 15 juin inclusivement.
--   Dan 80.42 h, Jasmine 83.67 h.
--
-- Ensuite, les 40 heures suivantes sont payees POUR DAN SEULEMENT.
-- Elles tombent pile sur trois semaines completes:
--   22 juin 12.50 + 29 juin 9.25 + 6 juillet 18.25 = 40.00 h exactement.
-- La semaine du 13 juillet reste impayee pour les deux.
--
-- Apercu d'abord, ecriture ensuite.
-- =====================================================================

-- Apercu: ce qui serait marque paye
select b.person, b.who,
       date_trunc('week', b.work_date)::date as semaine,
       round(sum(b.hours), 2) as heures,
       case when b.work_date <= date '2026-06-16' then 'paye, les deux'
            when b.who = 'dan' and date_trunc('week', b.work_date)::date < date '2026-07-13' then 'paye, Dan seulement'
            else 'impaye' end as statut
  from public.v_hours_batch b
 group by b.person, b.who, 3, 5
 order by 3, 1;

begin;

-- 1. Jusqu'au 16 juin: paye pour les deux
insert into public.paid_weeks (employee_id, week_start, paid)
select distinct b.employee_id, date_trunc('week', b.work_date)::date, true
  from public.v_hours_batch b
 where b.work_date <= date '2026-06-16'
on conflict (employee_id, week_start) do update set paid = true;

-- 2. Les 40 heures suivantes: Dan seulement, trois semaines completes
insert into public.paid_weeks (employee_id, week_start, paid)
select distinct b.employee_id, date_trunc('week', b.work_date)::date, true
  from public.v_hours_batch b
 where b.who = 'dan'
   and b.work_date > date '2026-06-16'
   and date_trunc('week', b.work_date)::date < date '2026-07-13'
on conflict (employee_id, week_start) do update set paid = true;

commit;

-- Verification: la semaine du 13 juillet doit rester absente ou a false,
-- et Jasmine ne doit rien avoir de paye apres le 16 juin.
select p.name, w.week_start, w.paid
  from public.paid_weeks w
  join public.profiles p on p.id = w.employee_id
 where w.week_start >= date '2026-05-11'
 order by w.week_start, p.name;


-- =====================================================================
-- SECTION 7 : MENAGE / CLEAN UP
-- La vue n'a servi qu'a cette saisie.
-- =====================================================================
drop view if exists public.v_hours_batch;
