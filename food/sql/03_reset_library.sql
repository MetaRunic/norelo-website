-- Bouffe, remise a neuf de la bibliotheque livree
-- Rouler apres 01_init.sql et 02_members.sql, une seule fois.
--
-- POURQUOI: les seize plats semes la premiere journee contenaient des
-- choses que la maison ne mange pas, champignons, poivrons, citron,
-- crevettes, tomates en des. La bibliotheque a ete refaite au complet,
-- quarante-deux plats qui respectent la liste.
--
-- Le bouton "Remplir la bibliotheque" n'ajoute que les plats absents, il
-- ne corrige pas ceux qui portent deja le bon nom. Donc "Chili de dinde"
-- resterait avec ses vieux poivrons. Ce fichier retire les seize anciens
-- pour que l'application les reinsere corriges.
--
-- CE QUI EST TOUCHE: uniquement les seize plats de la premiere version,
-- nommes un a un ci-dessous, leurs ingredients, leurs notes, et les
-- cases du plan qui les utilisaient.
-- CE QUI NE L'EST PAS: tout plat que vous avez cree ou renomme vous-meme,
-- le garde-manger, les depenses et le pointage.
--
-- APRES AVOIR ROULE: ouvrir /food/, onglet Plats, et toucher
-- "Remplir la bibliotheque". Les quarante-deux plats corriges arrivent.

begin;

create temporary table old_seed(name text) on commit drop;
insert into old_seed(name) values
 ('Poulet grillé, patate douce et brocoli'),
 ('Saumon à l''érable, quinoa et asperges'),
 ('Chili de dinde'),
 ('Pâté chinois allégé'),
 ('Bol burrito au poulet'),
 ('Soupe poulet et orzo'),
 ('Tofu général Tao au four'),
 ('Crevettes à l''ail et courgettes'),
 ('Boeuf et légumes à l''asiatique'),
 ('Omelette aux légumes et feta'),
 ('Salade césar au poulet, vinaigrette au yogourt'),
 ('Porc effiloché et salade de chou'),
 ('Pizza pita aux légumes'),
 ('Mijoteuse, boeuf et légumes racines'),
 ('Poisson blanc au four et patates grelots'),
 ('Dahl de lentilles');

-- Ce qu'on s'apprete a retirer, pour le voir avant.
select name_fr from dishes where name_fr in (select name from old_seed) order by name_fr;

-- Les cases du plan d'abord: la cle est "on delete set null", donc sans
-- ca il resterait des creneaux vides sans plat.
delete from plan where dish_id in (select id from dishes where name_fr in (select name from old_seed));

-- Les ingredients et les notes partent en cascade avec le plat.
delete from dishes where name_fr in (select name from old_seed);

commit;

-- Verification: doit retourner 0.
select count(*) as restants from dishes
where name_fr in (
 'Poulet grillé, patate douce et brocoli','Saumon à l''érable, quinoa et asperges',
 'Chili de dinde','Pâté chinois allégé','Bol burrito au poulet','Soupe poulet et orzo',
 'Tofu général Tao au four','Crevettes à l''ail et courgettes',
 'Boeuf et légumes à l''asiatique','Omelette aux légumes et feta',
 'Salade césar au poulet, vinaigrette au yogourt','Porc effiloché et salade de chou',
 'Pizza pita aux légumes','Mijoteuse, boeuf et légumes racines',
 'Poisson blanc au four et patates grelots','Dahl de lentilles');
