-- =====================================================================
-- Norelo Horaire, migration 03 : menage des donnees de test
-- Norelo Horaire, migration 03: clear the test data
--
-- RUN ORDER : 3 of 3, EN DERNIER.
--
-- CE QUE FAIT CE SCRIPT / WHAT THIS SCRIPT DOES
--   Il vide les heures et tout ce qui en depend, et il garde TOUS les
--   comptes tels quels.
--   It clears the hours and everything derived from them, and keeps
--   EVERY account exactly as it is.
--
--   EFFACE / DELETED          public.shifts       (tous les quarts)
--                             public.time_off     (toutes les demandes)
--                             public.paid_weeks   (tous les marquages payes)
--                             public.backups      (section 4, optionnelle)
--                             public.audit_log    (section 5, optionnelle)
--
--   GARDE / KEPT              public.profiles     INTACT : chaque compte
--                                                 garde son nom, son nom
--                                                 d'utilisateur, son role,
--                                                 son equipe et son taux.
--                             auth.users          INTACT : aucun mot de
--                                                 passe ni acces n'est
--                                                 touche. Tout le monde se
--                                                 reconnecte normalement.
--                             le schema           INTACT : aucune table,
--                                                 colonne, politique RLS,
--                                                 fonction ou declencheur
--                                                 n'est modifie ici.
--
-- APRES / AFTER
--   L'horaire repart vide. Les employes voient une semaine vierge et
--   peuvent saisir leurs heures normalement. Rien a reconfigurer.
--
-- AVANT DE LANCER / BEFORE YOU RUN
--   a) Dans l'app, onglet Sauvegardes : cliquez "Sauvegarder maintenant",
--      puis "Exporter les heures (CSV)". Gardez le fichier CSV hors de
--      Supabase. C'est votre filet de securite.
--   b) Lancez la section 1 et lisez ce qui va disparaitre.
--   c) Lancez la section 2 quand vous etes pret.
-- =====================================================================


-- =====================================================================
-- SECTION 1 : APERCU, ne supprime rien / PREVIEW, deletes nothing
-- =====================================================================

-- Ce qui va disparaitre, par employe / what goes, per employee
select p.name,
       p.username,
       p.role,
       p.team,
       p.rate,
       (select count(*) from public.shifts s
         where s.employee_id = p.id)                                as quarts,
       (select count(*) from public.shifts s
         where s.employee_id = p.id
           and (s.start_time is not null or s.end_time is not null)) as quarts_avec_heures,
       (select min(s.work_date) from public.shifts s
         where s.employee_id = p.id)                                as premiere_date,
       (select max(s.work_date) from public.shifts s
         where s.employee_id = p.id)                                as derniere_date,
       (select count(*) from public.time_off o
         where o.employee_id = p.id)                                as conges,
       (select count(*) from public.paid_weeks w
         where w.employee_id = p.id)                                as semaines_payees
  from public.profiles p
 order by p.role desc, p.name;

-- Les totaux / the totals
select (select count(*) from public.shifts)     as quarts_effaces,
       (select count(*) from public.time_off)   as conges_effaces,
       (select count(*) from public.paid_weeks) as semaines_effacees,
       (select count(*) from public.backups)    as sauvegardes_existantes,
       (select count(*) from public.profiles)   as comptes_conserves;


-- =====================================================================
-- SECTION 2 : LA SUPPRESSION DES HEURES / CLEAR THE HOURS
--
-- Tout dans une seule transaction : si une etape echoue, rien n'est
-- supprime. One transaction: if any step fails, nothing is deleted.
--
-- Selectionnez et lancez ce bloc quand l'apercu vous convient.
-- =====================================================================

begin;

  delete from public.paid_weeks;   -- marquages "paye" par semaine
  delete from public.time_off;     -- demandes de conge
  delete from public.shifts;       -- les quarts et donc toutes les heures

  -- public.profiles n'est volontairement pas touche.
  -- public.profiles is deliberately left alone.

commit;


-- =====================================================================
-- SECTION 3 : VERIFICATION / CHECK
--    Attendu : 0, 0, 0 pour les heures et le nombre de comptes inchange.
--    Expected: 0, 0, 0 for the hours and an unchanged account count.
-- =====================================================================

select (select count(*) from public.shifts)     as quarts_restants,
       (select count(*) from public.time_off)   as conges_restants,
       (select count(*) from public.paid_weeks) as semaines_restantes,
       (select count(*) from public.profiles)   as comptes_restants;

-- Les comptes conserves, pour confirmer qu'ils sont tous la
select name, username, role, team, rate
  from public.profiles
 order by role desc, name;


-- =====================================================================
-- SECTION 4 : LES SAUVEGARDES, OPTIONNELLE / BACKUPS, OPTIONAL
--
-- Les sauvegardes contiennent une copie des anciennes heures. Tant
-- qu'elles sont la, les donnees de test sont encore dans la base et
-- restaurables. Videz-les si vous voulez vraiment repartir a zero.
--
-- L'app recree automatiquement une sauvegarde a la prochaine connexion
-- d'un gestionnaire, donc vous ne restez pas sans filet.
--
-- Decommentez la ligne voulue puis lancez-la.
-- =====================================================================

-- Tout effacer / delete them all :
-- delete from public.backups;

-- Ou garder seulement la plus recente / or keep only the newest one :
-- delete from public.backups
--  where id not in (select id from public.backups
--                    order by created_at desc limit 1);


-- =====================================================================
-- SECTION 5 : LE JOURNAL D'ACTIVITE, OPTIONNELLE / ACTIVITY LOG, OPTIONAL
--
-- Le journal garde la trace des actions passees (comptes crees, heures
-- modifiees, approbations). Il ne contient aucune heure travaillee, donc
-- vous pouvez tres bien le garder comme historique.
--
-- Decommentez si vous voulez aussi repartir a zero de ce cote.
-- =====================================================================

-- delete from public.audit_log;
