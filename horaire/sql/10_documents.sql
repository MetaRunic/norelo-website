-- =====================================================================
-- Norelo Horaire, migration 10 : les documents partages
-- Norelo Horaire, migration 10: shared documents
--
-- RUN ORDER : apres 01. Idempotent, relancable sans risque.
--
-- CE QUE CA AJOUTE
--   Un onglet Documents ou les gestionnaires deposent des PDF et ou tout
--   le monde peut les lire. Un document peut avoir un parent: le fichier
--   maitre (l aide-memoire complet) et ses sections en dessous.
--
--   On note aussi qui a lu quoi, pour pouvoir montrer que l equipe a bien
--   vu les politiques.
--
-- OU SONT LES FICHIERS
--   Dans le bucket Storage prive nomme "documents". Prive: l application
--   demande une URL signee valable une heure. Un lien copie hors de
--   l application cesse donc de fonctionner rapidement.
--
-- CE QUE CA NE TOUCHE PAS
--   Ni la paie, ni les heures, ni les politiques RLS existantes.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Le bucket
--    Prive. On sert les fichiers par URL signee, jamais en acces direct.
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('documents', 'documents', false)
on conflict (id) do nothing;


-- ---------------------------------------------------------------------
-- 2. La table des documents
--    parent_id NULL  = un fichier maitre, affiche comme un dossier
--    parent_id rempli = une section rangee sous ce maitre
-- ---------------------------------------------------------------------
create table if not exists public.documents (
  id            uuid primary key default gen_random_uuid(),
  parent_id     uuid references public.documents(id) on delete cascade,
  title         text not null,
  storage_path  text not null unique,
  size_bytes    bigint,
  sort_order    integer not null default 0,
  created_by    uuid references public.profiles(id) on delete set null,
  created_at    timestamptz not null default now()
);

create index if not exists documents_parent_idx on public.documents(parent_id, sort_order);

-- un document ne peut pas etre son propre parent
alter table public.documents drop constraint if exists documents_not_self_parent;
alter table public.documents add  constraint documents_not_self_parent
  check (parent_id is null or parent_id <> id);


-- ---------------------------------------------------------------------
-- 3. Qui a lu quoi
-- ---------------------------------------------------------------------
create table if not exists public.document_reads (
  document_id uuid not null references public.documents(id)     on delete cascade,
  employee_id uuid not null references public.profiles(id)      on delete cascade,
  read_at     timestamptz not null default now(),
  primary key (document_id, employee_id)
);

create index if not exists document_reads_emp_idx on public.document_reads(employee_id);


-- ---------------------------------------------------------------------
-- 4. RLS sur les deux tables
--    Lecture pour toute personne connectee, ecriture pour les gestionnaires.
--    Chacun marque ses propres lectures, et seulement les siennes.
-- ---------------------------------------------------------------------
alter table public.documents      enable row level security;
alter table public.document_reads enable row level security;

drop policy if exists documents_read      on public.documents;
drop policy if exists documents_write     on public.documents;
drop policy if exists documents_update    on public.documents;
drop policy if exists documents_delete    on public.documents;

create policy documents_read   on public.documents for select
  to authenticated using (true);
create policy documents_write  on public.documents for insert
  to authenticated with check (public.is_manager());
create policy documents_update on public.documents for update
  to authenticated using (public.is_manager()) with check (public.is_manager());
create policy documents_delete on public.documents for delete
  to authenticated using (public.is_manager());

drop policy if exists document_reads_read   on public.document_reads;
drop policy if exists document_reads_insert on public.document_reads;
drop policy if exists document_reads_delete on public.document_reads;

-- chacun voit ses lectures, les gestionnaires voient tout le monde
create policy document_reads_read   on public.document_reads for select
  to authenticated using (employee_id = auth.uid() or public.is_manager());
-- on ne peut marquer comme lu que pour soi
create policy document_reads_insert on public.document_reads for insert
  to authenticated with check (employee_id = auth.uid());
create policy document_reads_delete on public.document_reads for delete
  to authenticated using (employee_id = auth.uid());


-- ---------------------------------------------------------------------
-- 5. RLS sur les fichiers eux-memes
--    Sans ca, la ligne existe mais le PDF reste inaccessible.
-- ---------------------------------------------------------------------
drop policy if exists documents_obj_read   on storage.objects;
drop policy if exists documents_obj_insert on storage.objects;
drop policy if exists documents_obj_update on storage.objects;
drop policy if exists documents_obj_delete on storage.objects;

create policy documents_obj_read   on storage.objects for select
  to authenticated using (bucket_id = 'documents');
create policy documents_obj_insert on storage.objects for insert
  to authenticated with check (bucket_id = 'documents' and public.is_manager());
create policy documents_obj_update on storage.objects for update
  to authenticated using (bucket_id = 'documents' and public.is_manager());
create policy documents_obj_delete on storage.objects for delete
  to authenticated using (bucket_id = 'documents' and public.is_manager());


-- ---------------------------------------------------------------------
-- 6. Verification
--    Une seule requete: l editeur Supabase n affiche que le dernier
--    resultat, donc tout est regroupe ici.
-- ---------------------------------------------------------------------
select 'bucket documents'                                as quoi,
       (select count(*)::text from storage.buckets
         where id = 'documents')                         as valeur
union all
select 'table documents',
       (select count(*)::text from information_schema.tables
         where table_schema = 'public' and table_name = 'documents')
union all
select 'table document_reads',
       (select count(*)::text from information_schema.tables
         where table_schema = 'public' and table_name = 'document_reads')
union all
select 'policies documents',
       (select count(*)::text from pg_policies
         where schemaname = 'public' and tablename = 'documents')
union all
select 'policies document_reads',
       (select count(*)::text from pg_policies
         where schemaname = 'public' and tablename = 'document_reads')
union all
select 'policies storage.objects (documents)',
       (select count(*)::text from pg_policies
         where schemaname = 'storage' and tablename = 'objects'
           and policyname like 'documents_obj_%');

-- Attendu : 1, 1, 1, 4, 3, 4
