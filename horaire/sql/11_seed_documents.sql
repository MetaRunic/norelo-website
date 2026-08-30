-- =====================================================================
-- Norelo Horaire, migration 11 : inscrire l aide-memoire du verger
-- Norelo Horaire, migration 11: register the orchard handbook
--
-- RUN ORDER : apres 10, et APRES avoir depose les fichiers.
-- Idempotent: relancable sans creer de doublon.
--
-- AVANT DE LANCER CECI
--   Deposez les 9 fichiers PDF a la racine du bucket "documents", dans
--   Supabase > Storage > documents > Upload files. Vous pouvez les
--   selectionner tous les neuf d un coup.
--
--   Les noms doivent rester exactement ceux-la, sans dossier autour,
--   sinon les liens ne pointeront sur rien.
--
-- CE QUE CA FAIT
--   Cree la fiche de chaque document et rattache les huit sections au
--   fichier maitre. Les fichiers eux-memes ne sont pas touches.
--
-- SI VOUS VOUS TROMPEZ
--   La section 3 en bas, mise en commentaire, efface uniquement ces neuf
--   fiches pour que vous puissiez recommencer.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Le fichier maitre
--    created_by pointe sur Dan s il existe, sinon reste vide.
-- ---------------------------------------------------------------------
insert into public.documents (title, storage_path, size_bytes, parent_id, sort_order, created_by)
values ('Verger aide-mémoire', '00-verger-aide-memoire.pdf', 12103314, null, 0,
        (select id from public.profiles where lower(username) = 'dan' limit 1))
on conflict (storage_path) do nothing;


-- ---------------------------------------------------------------------
-- 2. Les huit sections, rattachees au maitre
--    Le parent est retrouve par son chemin, pas par un identifiant fixe,
--    donc l ordre d execution n a pas d importance.
-- ---------------------------------------------------------------------
insert into public.documents (title, storage_path, size_bytes, parent_id, sort_order, created_by)
select v.title, v.path, v.bytes,
       (select id from public.documents where storage_path = '00-verger-aide-memoire.pdf'),
       v.ord,
       (select id from public.profiles where lower(username) = 'dan' limit 1)
  from (values
    ('Politiques du verger',            '01-politiques-du-verger.pdf',      45047::bigint, 1),
    ('Raccourci de l''application',     '02-raccourci-application.pdf',   2101481::bigint, 2),
    ('Instructions de l''application',  '03-instructions-application.pdf',1282580::bigint, 3),
    ('Discours d''accueil et cueillette','04-discours-accueil.pdf',         64714::bigint, 4),
    ('Paniers de pommes',               '05-paniers-de-pommes.pdf',       5158542::bigint, 5),
    ('Jus',                             '06-jus.pdf',                     3514844::bigint, 6),
    ('Ménage',                          '07-menage.pdf',                   168703::bigint, 7),
    ('Rabais en cours',                 '08-rabais-en-cours.pdf',           43774::bigint, 8)
  ) as v(title, path, bytes, ord)
on conflict (storage_path) do nothing;


-- ---------------------------------------------------------------------
-- 3. Verification
--    Compare ce qui est inscrit avec ce qui est reellement depose.
--    "fichier manquant" veut dire que la fiche existe mais pas le PDF:
--    verifiez le nom dans Storage.
-- ---------------------------------------------------------------------
select case when d.parent_id is null then 'MAITRE' else '  section' end  as niveau,
       d.title                                                           as titre,
       d.storage_path                                                    as fichier,
       pg_size_pretty(d.size_bytes)                                      as taille,
       case when o.name is null then 'FICHIER MANQUANT' else 'ok' end    as depose
  from public.documents d
  left join storage.objects o
         on o.bucket_id = 'documents' and o.name = d.storage_path
 order by d.parent_id nulls first, d.sort_order;

-- Attendu : 9 lignes, 1 MAITRE puis 8 sections, toutes marquees ok.


-- ---------------------------------------------------------------------
-- 4. Pour tout recommencer, retirez les deux tirets de la ligne suivante.
--    Efface les fiches, pas les fichiers. Les sections partent en cascade.
-- ---------------------------------------------------------------------
-- delete from public.documents where storage_path = '00-verger-aide-memoire.pdf';
