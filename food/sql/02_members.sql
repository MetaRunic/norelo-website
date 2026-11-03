-- Bouffe, les deux membres de la maison
-- Rouler apres 01_init.sql, dans le projet norelo-food.
-- A rouler une seule fois. Les deux comptes doivent deja exister dans
-- Authentication, Users, avec exactement ces deux adresses.
--
-- Rappel: ces adresses ne sont pas des courriels, aucune boite ne les
-- recoit. Ce sont les identifiants fabriques a partir des prenoms.
-- Dan se connecte en tapant "Dan", Catou en tapant "Catou".
--
-- Les quatre valeurs chiffrees ci-dessous sont des valeurs de depart.
-- Ne pas y passer de temps: chacun change les siennes dans l'application,
-- sous "Mes cibles", et ca ecrit dans cette meme table.
--
--   kcal_target     calories par jour, sert seulement a dessiner une barre
--   protein_target  proteines par jour, en grammes
--   portion_mult    la taille de l'assiette, les deux sortent du meme plat
--                   1.15 sert un peu plus, 0.85 sert un peu moins
--   budget_week     budget d'epicerie de la semaine, en dollars

insert into members (id, display_name, kcal_target, protein_target, portion_mult, budget_week)
select id, 'Dan', 2200, 140, 1.15, 200
from auth.users where email = 'dan@bouffe.local'
on conflict (id) do nothing;

insert into members (id, display_name, kcal_target, protein_target, portion_mult, budget_week)
select id, 'Catou', 1600, 110, 0.85, 200
from auth.users where email = 'catou@bouffe.local'
on conflict (id) do nothing;

-- Verification. Doit retourner exactement deux lignes, Dan et Catou.
-- Zero ligne veut dire que les adresses ne concordent pas avec celles
-- creees dans Authentication, Users.
select m.display_name, u.email, m.portion_mult, m.budget_week
from members m join auth.users u on u.id = m.id
order by m.display_name;
