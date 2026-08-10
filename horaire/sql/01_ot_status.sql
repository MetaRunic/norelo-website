-- =====================================================================
-- Norelo Horaire, migration 01 : refus des heures supplementaires
-- Norelo Horaire, migration 01: overtime deny
--
-- RUN ORDER : 1 of 3.  Run this in the Supabase SQL Editor BEFORE
-- deploying the new horaire/index.html.
--
-- Ce script est idempotent : vous pouvez le relancer sans risque.
-- This script is idempotent: it is safe to run more than once.
--
-- CE QUI CHANGE / WHAT CHANGES
--   * nouvelle colonne shifts.ot_status : 'pending' | 'approved' | 'denied'
--   * ot_approved reste le seul drapeau que la paie lit, donc le calcul
--     de paie est INCHANGE : approved = paye, pending = non paye,
--     denied = non paye.
--   * aucune politique RLS existante n'est modifiee. On ajoute seulement
--     un declencheur qui empeche un employe d'approuver ou de refuser
--     ses propres heures supplementaires, comme guard_ot le fait deja
--     pour ot_approved.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. La colonne / the column
-- ---------------------------------------------------------------------
alter table public.shifts
  add column if not exists ot_status text not null default 'pending';


-- ---------------------------------------------------------------------
-- 2. Seules les trois valeurs connues sont permises
--    Only the three known values are allowed
-- ---------------------------------------------------------------------
alter table public.shifts drop constraint if exists shifts_ot_status_chk;
alter table public.shifts
  add constraint shifts_ot_status_chk
  check (ot_status in ('pending', 'approved', 'denied'));


-- ---------------------------------------------------------------------
-- 3. Reprise des donnees existantes / backfill from the existing boolean
--    Tout ce qui est deja approuve devient 'approved', le reste 'pending'.
--    Aucune ligne ne devient 'denied' : un refus vient toujours de l'app.
-- ---------------------------------------------------------------------
update public.shifts
   set ot_status = case when ot_approved then 'approved' else 'pending' end
 where ot_status is distinct from
       (case when ot_approved then 'approved' else 'pending' end);


-- ---------------------------------------------------------------------
-- 4. ot_approved et ot_status ne peuvent jamais se contredire
--    ot_approved and ot_status can never disagree
--    C'est ce qui garantit que la paie ne bouge pas.
-- ---------------------------------------------------------------------
create or replace function public.sync_ot_status()
returns trigger
language plpgsql
as $$
begin
  if new.ot_status is null then
    new.ot_status := 'pending';
  end if;
  new.ot_approved := (new.ot_status = 'approved');
  return new;
end;
$$;

drop trigger if exists sync_ot_status on public.shifts;
create trigger sync_ot_status
  before insert or update on public.shifts
  for each row execute function public.sync_ot_status();


-- ---------------------------------------------------------------------
-- 5. Seul un gestionnaire peut approuver ou refuser
--    Only a manager can approve or deny
--
--    Un employe peut laisser la ligne a 'pending' (et toute modification
--    de ses heures la remet a 'pending'), mais il ne peut jamais decider
--    lui-meme. Meme regle que guard_ot, appliquee a la nouvelle colonne.
--
--    NOTE : les declencheurs BEFORE se declenchent par ordre alphabetique,
--    donc guard_ot, puis guard_ot_status, puis sync_ot_status. guard_ot
--    n'est pas touche par ce script.
-- ---------------------------------------------------------------------
create or replace function public.guard_ot_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.is_manager() then
    return new;
  end if;
  if tg_op = 'UPDATE' and new.ot_status is not distinct from old.ot_status then
    return new;                    -- inchange, rien a garder / unchanged
  end if;
  if new.ot_status <> 'pending' then
    raise exception 'Only a manager can approve or deny overtime';
  end if;
  return new;
end;
$$;

drop trigger if exists guard_ot_status on public.shifts;
create trigger guard_ot_status
  before insert or update on public.shifts
  for each row execute function public.guard_ot_status();


-- ---------------------------------------------------------------------
-- 6. Verification / check
--    Attendu : aucune ligne en desaccord, et un compte par statut.
--    Expected: zero mismatches, and one count per status.
-- ---------------------------------------------------------------------
select 'mismatch (doit etre 0 / must be 0)' as check,
       count(*) as n
  from public.shifts
 where ot_approved <> (ot_status = 'approved');

select ot_status, count(*) as n
  from public.shifts
 group by ot_status
 order by ot_status;
