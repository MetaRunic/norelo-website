-- =====================================================================
-- Norelo Horaire, migration 08 : retenir COMBIEN a ete paye
-- Norelo Horaire, migration 08: remember HOW MUCH was paid
--
-- RUN ORDER : apres 01. Idempotent, relancable sans risque.
--
-- LE PROBLEME
--   paid_weeks ne retenait qu'un oui ou non. Si une semaine est marquee
--   payee le samedi et que la personne travaille le dimanche, la semaine
--   reste marquee payee et les heures du dimanche sont comptees comme
--   deja versees. L'argent disparait du solde sans que rien ne l'indique.
--
--   Exemple mesure: 48 h payees, puis 8 h de plus le dimanche.
--   Avant: solde impaye 0,00 $. En realite 160,00 $ etaient dus.
--
-- LA CORRECTION
--   On enregistre le montant et les heures au moment du paiement. Ce qui
--   est du pour une semaine devient: total actuel moins montant deja
--   verse, jamais negatif.
--
--   LE CALCUL DE PAIE NE CHANGE PAS. Heures fois taux reste identique.
--   On ajoute seulement la memoire de ce qui a ete remis.
--
--   Les lignes existantes gardent paid_amount a NULL et restent traitees
--   comme entierement payees, donc rien ne devient du retroactivement.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Les colonnes
-- ---------------------------------------------------------------------
alter table public.paid_weeks
  add column if not exists paid_amount numeric(10,2),
  add column if not exists paid_hours  numeric(8,2),
  add column if not exists paid_at     timestamptz;


-- ---------------------------------------------------------------------
-- 2. Etat des lieux
--    Les lignes sans montant sont les anciennes: elles resteront
--    considerees comme entierement reglees.
-- ---------------------------------------------------------------------
select count(*) filter (where paid)                              as semaines_payees,
       count(*) filter (where paid and paid_amount is null)       as sans_montant_ancien,
       count(*) filter (where paid and paid_amount is not null)   as avec_montant;


-- ---------------------------------------------------------------------
-- 3. Verification des colonnes
-- ---------------------------------------------------------------------
select column_name, data_type, is_nullable
  from information_schema.columns
 where table_schema = 'public' and table_name = 'paid_weeks'
 order by ordinal_position;
