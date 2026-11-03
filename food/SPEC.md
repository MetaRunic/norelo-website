# Bouffe, planificateur de repas du menage

Cahier des charges. Application privee, deux utilisateurs.
Chemin `/food/` sur norelo.ca. Statut: specification, puis phase 1 construite.

## 1. Objectif

Planifier les diners et les soupers de la semaine a deux, generer la liste
d'epicerie par magasin, et rendre le choix des repas amusant plutot qu'une corvee.

Deuxieme objectif, explicite du proprietaire: des repas sante mais bons, avec
un appui concret a une perte de poids. L'application doit aider, jamais sermonner.

## 2. Decisions prises

| Sujet | Decision |
| --- | --- |
| Chemin | `/food/`, un seul `index.html` autonome. |
| Confidentialite | `noindex`, `Disallow: /food/` dans robots.txt, absent du sitemap, jamais lie depuis la navigation du site vitrine. |
| Base de donnees | Projet Supabase **separe**. Aucun lien avec le projet horaire, qui contient la paie. |
| Comptes | Deux comptes nommes, **sans courriel**. On entre un prenom et un mot de passe. Supabase exige une adresse, alors l'application la fabrique a partir du prenom, `marc@bouffe.local`, qui ne sort jamais de l'application et qu'aucune boite ne recoit. Inscription fermee dans Supabase. Table `members` en liste blanche, la RLS verifie l'appartenance. Un compte hors liste est renvoye a la porte avec une explication, plutot que de tomber dans une maison vide. |
| Creneaux | **Diner et souper**, sept jours. Le dejeuner est hors perimetre, il ne varie pas. |
| Navigation | Barre d'onglets **en bas**, cinq cibles pleine hauteur, la ou se trouve le pouce. L'en-tete tient sur une seule rangee. Mobile d'abord, c'est une application de cuisine et d'epicerie. |
| Etapes | Une etape par ligne, numerotees. Un **mode cuisson** plein ecran montre une etape a la fois en gros, garde l'ecran allume, et ouvre la note du plat a la derniere etape. Un plat ecrit d'un bloc est coupe aux phrases, donc rien a migrer. |
| Collations et extras | Table `extras`. Tout ce qui ne vient pas d'une recette, range par magasin comme le reste. `every_week` vrai pour ce qui revient chaque semaine. Seize suggestions, toutes passees par la liste des gouts. L'application tourne sans la table, la section disparait simplement. |
| Friteuse a air | **Aucune.** Le menage n'en a pas. L'etiquette a ete retiree et le seul plat concerne est passe au four. |
| Gouts de la maison | Liste des aliments que Catou et Dan ne mangent pas, tenue dans `AVOID` au haut du fichier. La bibliotheque livree la respecte en entier. Un plat ajoute plus tard qui contient un de ces articles est **marque**, jamais bloque. Deux pieges de mots sont neutralises: l'huile d'olive n'est pas une olive, une tomate cerise n'est pas une cerise. |
| Bibliotheque | 42 plats livres, dont 4 au poisson marques `t_fish` et tenus hors des plans tout faits. |
| Plans tout faits | Huit semaines deja montees, dans `PLANS`: equilibree, haute proteine, legere, express, mijoteuse, vege, economique, reconfort. Chaque jour porte un souper et un diner, et un diner a `=` veut dire les restes du souper de la veille, ce qui n'ajoute rien a l'epicerie. |
| Semis | Le bouton n'ajoute que les plats absents, jamais un doublon. Les plats du menage et les modifications ne sont jamais touches. |
| Images | **Tuiles generees**, jamais de photo ni d'image externe. Chaque plat tire un degrade deterministe de son nom et un glyphe de ses etiquettes. La colonne `photo_url` existe au schema pour qu'une photo devienne un simple ajout plus tard, sans migration. |
| Magasins | Costco, IGA, Maxi, Super C, Metro, Provigo, marche, depanneur. Saint-Jerome. |
| Circulaires | Hors perimetre. Aucune lecture de circulaire, aucun scraping. L'application rappelle seulement que les circulaires changent le jeudi. |
| Langues | Francais et anglais, francais par defaut, dictionnaires a cles identiques. |
| Nutrition | Valeurs par portion saisies a la main par plat. Aucune base alimentaire externe. |
| Cibles | **Saisies par les utilisateurs eux-memes**, jamais prescrites par l'application. |
| Pointage | **Cooperatif**, un seul score de menage. Voir section 5. |

## 3. Ce qui rend le projet utile

La liste d'epicerie. Le reste est agreable, la liste est la raison d'etre.

- Construite depuis le plan de la semaine, quantites additionnees entre les plats.
  Trois recettes qui demandent de l'oignon donnent une seule ligne.
- Groupee par magasin. Chaque ingredient retient ou on l'achete d'habitude.
- Ordonnee par allee a l'interieur d'un magasin, pour traverser le magasin une fois.
- Le garde-manger retire ce qu'on a deja.
- Un drapeau Costco quand le format en vrac n'a de sens qu'au dela d'une quantite.
- Cochable en magasin, hors ligne, synchronisee au retour du reseau.

## 4. Choisir le repas, quatre modes

Le choix est le point de friction reel du couple. Donc quatre facons, pas une.

0. **Plan tout fait.** On applique une des huit semaines montees d'avance.
1. **Manuel.** On choisit dans la bibliotheque de plats.
2. **Roulette.** Ponderee vers les plats non manges depuis trois semaines ou plus,
   pour ressortir les favoris oublies au lieu de proposer le meme poulet.
3. **Duel.** L'application montre deux plats, chacun vote, le gagnant avance.
   Tournoi court jusqu'au gagnant.
4. **Semaine surprise.** Remplissage automatique de la semaine sous contraintes:
   variete, temps disponible, cibles nutritionnelles, budget.

## 5. Le jeu, et pourquoi il est cooperatif

Un seul score, celui du menage. Les deux joueurs gagnent ou perdent ensemble.

C'est un choix de conception, pas une limite technique. Un pointage individuel
dans un couple ou une seule personne veut perdre du poids transforme la semaine
en competition que cette personne peut perdre. Le mode cooperatif evite ca et
reste un jeu.

Les points recompensent des **gestes**, jamais une privation:

| Geste | Points |
| --- | --- |
| Plan de la semaine complete avant le lundi | 50 |
| Repas cuisine a la maison plutot que commande | 10 |
| Plat qui atteint la cible de proteines | 5 |
| Deux portions de legumes ou plus au plat | 5 |
| Nouveau plat essaye | 15 |
| Plat note par les deux apres le repas | 5 |
| Semaine sous le budget fixe | 40 |
| Semaine d'epicerie sans achat hors liste | 20 |

Rien ne retire de points. Les series se brisent, elles ne penalisent pas.

Niveaux, badges, et confettis aux paliers. Le confetti est dessine au canvas,
aucune librairie.

## 6. Sante, la partie a traiter avec soin

- Valeurs par portion par plat: calories, proteines, fibres, legumes.
- Etiquettes utiles plutot que morales: riche en proteines, moins de 500 calories,
  beaucoup de legumes, friteuse a air, prepare d'avance, rapide.
- **Portions par personne.** Les deux n'ont pas la meme cible. Un multiplicateur
  de portion par personne donne deux assiettes correctes du meme plat, et c'est la
  fonction la plus utile de toute la section.
- Tableau de la semaine contre les cibles **que les utilisateurs ont saisies**.
- Suggestions d'allegement par plat, du concret: yogourt grec au lieu de creme.
- Aucun calcul de deficit, aucune prevision de perte de poids, aucun conseil
  medical. L'application montre ce qui a ete mange et planifie. Le reste
  appartient aux utilisateurs et a leur medecin.

## 7. Saisonnalite des Laurentides

Bandeau au-dessus de la semaine, ce qui est de saison et bon marche ce mois-ci.
Table statique de douze mois, FR et EN. Novembre: courges, poireaux, legumes
racines, choux, pommes.

## 8. Modele de donnees

- `members`: liste blanche des deux comptes, nom affiche, cible de calories et de
  proteines, multiplicateur de portion.
- `dishes`: nom FR et EN, etiquettes, minutes de preparation, portions de base,
  calories, proteines, fibres, portions de legumes, etapes, `photo_url`, cout estime.
- `ingredients`: plat, article, quantite, unite, magasin habituel, allee.
- `plan`: date, creneau diner ou souper, plat, type (cuisine, restes, commande,
  restaurant, sorti), qui cuisine, qui fait la vaisselle.
- `ratings`: plat, membre, note, commentaire.
- `pantry`: article, quantite, unite.
- `list_state`: semaine, article, coche.
- `shops`: date, magasin, montant paye.
- `score`: semaine, geste, points, horodatage.

## 9. Phases

- **Phase 1**: grille de la semaine, bibliotheque de plats, liste d'epicerie par
  magasin, quatre modes de choix, pointage, confettis, nutrition, saisonnalite.
- **Phase 2**: budget historique, graphiques de tendance, cette semaine l'an dernier.
- **Phase 3**: photos reelles, si le proprietaire change d'avis sur les tuiles.

## 10. Contraintes techniques

- `index.html` autonome, HTML, CSS et JavaScript natif
- Aucune librairie externe sauf le client Supabase
- Aucun outil de compilation, aucun npm
- Aucun tiret cadratin nulle part
- Tout bilingue, dictionnaires FR et EN aux cles identiques
- Mobile d'abord, c'est une application de cuisine et d'epicerie
- Les changements de schema partent en fichiers `.sql` numerotes dans `food/sql/`,
  copies a la main par le proprietaire dans l'editeur SQL de Supabase

## 11. Risque principal

**La saisie.** Un plat demande nom, ingredients, quantites, magasin et valeurs
nutritionnelles. C'est long. Si remplir la bibliotheque est penible, l'application
meurt a la troisieme semaine, comme toutes les applications de repas.

Deux reponses. La bibliotheque arrive **pre-remplie** de plats quebecois courants,
sante et deja chiffres, prets a manger ou a modifier. Et l'ajout d'un plat accepte
un plat minimal, un nom et des ingredients, le reste pouvant rester vide.
