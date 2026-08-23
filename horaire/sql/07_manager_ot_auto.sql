-- =====================================================================
-- Norelo Horaire, migration 07 : un gestionnaire n'approuve pas ses
-- propres heures supplementaires
-- Norelo Horaire, migration 07: managers do not approve their own overtime
--
-- RUN ORDER : apres 01. Idempotent, relancable sans risque.
--
-- CE QUI CHANGE / WHAT CHANGES
--   Les heures supplementaires d'un compte dont le role est 'manager'
--   passent automatiquement a 'approved'. Elles ne s'affichent plus dans
--   la file d'Approbations et ne peuvent pas etre refusees.
--
--   ATTENTION, CECI TOUCHE LA PAIE. Les heures supplementaires d'un
--   gestionnaire etaient impayees tant qu'elles restaient 'pending'.
--   Elles seront desormais payees, a son propre taux horaire.
--   La section 1 chiffre exactement l'effet avant que vous ecriviez quoi
--   que ce soit.
--
--   Aucune politique RLS n'est modifiee. Un seul declencheur existant,
--   sync_ot_status, est remplace.
-- =====================================================================


-- =====================================================================
-- SECTION 1 : L'EFFET SUR LA PAIE, AVANT / THE PAY IMPACT, BEFORE
-- Ne modifie rien. Lisez ce total avant de continuer.
-- =====================================================================
with mgr_ot as (
  select p.name,
         p.rate,
         s.work_date,
         greatest(
           extract(epoch from (s.end_time::time - s.start_time::time)) / 3600.0
           - case when s.lunch and p.role <> 'manager' then 0.5 else 0 end, 0) as h
    from public.shifts s
    join public.profiles p on p.id = s.employee_id
   where p.role = 'manager'
     and s.ot_status = 'pending'
     and s.start_time is not null and s.end_time is not null
)
select name,
       count(*)                                             as journees,
       round(sum(greatest(h - 8, 0))::numeric, 2)           as heures_supp_a_payer,
       round(sum(greatest(h - 8, 0) * rate)::numeric, 2)    as montant_ajoute
  from mgr_ot
 group by name, rate
 order by name;

-- Le total, toutes personnes confondues
with mgr_ot as (
  select p.rate,
         greatest(
           extract(epoch from (s.end_time::time - s.start_time::time)) / 3600.0
           - case when s.lunch and p.role <> 'manager' then 0.5 else 0 end, 0) as h
    from public.shifts s
    join public.profiles p on p.id = s.employee_id
   where p.role = 'manager'
     and s.ot_status = 'pending'
     and s.start_time is not null and s.end_time is not null
)
select round(sum(greatest(h - 8, 0))::numeric, 2)        as total_heures_supp,
       round(sum(greatest(h - 8, 0) * rate)::numeric, 2) as total_ajoute_a_la_paie
  from mgr_ot;


-- =====================================================================
-- SECTION 2 : LA REGLE / THE RULE
--
-- On remplace sync_ot_status, qui tourne deja en dernier et qui tient
-- ot_approved aligne sur ot_status. Il force maintenant 'approved' pour
-- un gestionnaire. Pas de nouveau declencheur, donc pas de question
-- d'ordre d'execution.
--
-- SECURITY DEFINER parce que la fonction lit profiles, qui est protege
-- par RLS: sans cela, un employe qui enregistre ses heures ne verrait pas
-- la ligne et la regle ne s'appliquerait pas de facon fiable.
-- =====================================================================
create or replace function public.sync_ot_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  est_gestionnaire boolean;
begin
  if new.ot_status is null then
    new.ot_status := 'pending';
  end if;

  select (p.role = 'manager')
    into est_gestionnaire
    from public.profiles p
   where p.id = new.employee_id;

  if coalesce(est_gestionnaire, false) then
    new.ot_status := 'approved';   -- il n'approuve pas ses propres heures
  end if;

  new.ot_approved := (new.ot_status = 'approved');
  return new;
end;
$$;

-- Le declencheur existe deja depuis la migration 01, on le recree au cas ou.
drop trigger if exists sync_ot_status on public.shifts;
create trigger sync_ot_status
  before insert or update on public.shifts
  for each row execute function public.sync_ot_status();


-- =====================================================================
-- SECTION 3 : LES LIGNES DEJA EN BASE / THE ROWS ALREADY THERE
-- A lancer quand le chiffre de la section 1 vous convient.
-- =====================================================================
begin;

update public.shifts s
   set ot_status = 'approved'
  from public.profiles p
 where p.id = s.employee_id
   and p.role = 'manager'
   and s.ot_status <> 'approved';

commit;


-- =====================================================================
-- SECTION 4 : VERIFICATION
-- Attendu: aucun gestionnaire hors 'approved', et ot_approved partout
-- d'accord avec ot_status.
-- =====================================================================
select p.role, s.ot_status, count(*) as lignes
  from public.shifts s
  join public.profiles p on p.id = s.employee_id
 group by p.role, s.ot_status
 order by p.role desc, s.ot_status;

select 'desaccord ot_approved / ot_status (doit etre 0)' as controle,
       count(*) as n
  from public.shifts
 where ot_approved <> (ot_status = 'approved');
