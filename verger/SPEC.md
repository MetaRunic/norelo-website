# Verger, application web du verger

Cahier des charges consolide. Reprend le document original et toutes les decisions
prises en session de cadrage.

Statut: specification. Aucun code ecrit.
Client: A la Croisee des Pommes, Saint-Joseph-du-Lac.

## 1. Objectif

Application web accessible par code QR dans le verger. Elle permet au visiteur
d'identifier les varietes, de voir ce qui est ouvert a la cueillette aujourd'hui,
de trouver l'arbre le plus proche d'une variete donnee, et de laisser un commentaire.
Elle permet au personnel de tenir la carte a jour sur le terrain.

Elle sert aussi de vitrine Norelo. Elle est hebergee sur le site Norelo et pourra
migrer vers le domaine du verger plus tard.

## 2. Decisions prises

| Sujet | Decision |
| --- | --- |
| Hebergement | `norelo-website`, chemin `/verger/`. Migration future vers le domaine du verger, preservee par une redirection permanente depuis norelo.ca. |
| Unite de carte | Arbres individuels, en points. Pas de zones comme unite de catalogue. |
| Base de donnees | Projet Supabase **separe**. Aucun lien avec le projet horaire, qui contient la paie. |
| Fond de carte | Photo aerienne fournie par le proprietaire, **georeferencee**. Pas de tuiles externes, donc aucune librairie de cartographie. |
| Depart sans photo | La carte est d'abord **schematique**, construite sur la grille du releve existant, 11 rangees par 77 positions. Aucune photo n'est requise pour commencer. La photo devient un fond pose sous la grille, les positions sont ancrees ensuite. |
| Sections | P1 a P4, **fixes**, ne changeront jamais. |
| Coordonnees | Stockees en fractions de l'image, 0 a 1. Resistantes au remplacement de la photo. Converties en latitude et longitude par une transformation affine. |
| Commentaires publics | Moderes. Invisibles jusqu'a approbation par un gestionnaire. |
| Commentaires internes | Visibles par le personnel seulement. |
| Comptes | Comptes individuels. Deux roles, employe et gestionnaire. |
| Etat des arbres | Trois etats, plein, pommes en hauteur seulement, vide. Modifiable par tout employe. |
| Zonage | Polygones traces par un gestionnaire, statut ouvert ou restreint, change quotidiennement. |
| Appartenance a une zone | Calculee par geometrie, jamais stockee en dur, pour rester juste quand une zone est redessinee. |
| GPS | Position du visiteur, arbre le plus proche d'une variete, ligne droite, distance en metres. **Aucun calcul d'itineraire.** |
| Contenu des zones | Une zone contient **plusieurs varietes melangees**. Une zone sert donc au controle d'acces, jamais a identifier une variete. |
| Maturite | Interrupteur par variete, ouverte ou non a la cueillette, bascule par un gestionnaire quand la variete rentre. Le calendrier du site du verger reste une reference approximative affichee au visiteur. |
| Fiabilite des donnees | Le verger est irregulier et les erreurs d'identification sont attendues. L'application doit les rendre visibles et faciles a corriger. |
| Langues | Francais et anglais, francais par defaut. |
| Demo | Aucune. Les visiteurs sont anonymes, l'application publique est sa propre demo. |

## 3. Roles et permissions

| | Visiteur anonyme | Employe | Gestionnaire |
| --- | --- | --- | --- |
| Voir arbres, varietes, zones ouvertes | oui | oui | oui |
| Voir commentaires approuves | oui | oui | oui |
| Soumettre un commentaire public | oui, en attente | oui | oui |
| Voir et ecrire les commentaires internes | non | oui | oui |
| Changer l'etat des arbres, en lot | non | oui | oui |
| Ajouter, deplacer, supprimer des arbres | non | non | oui |
| Tracer et modifier les zones | non | non | oui |
| Approuver ou rejeter les commentaires | non | non | oui |
| Modifier varietes et FAQ | non | non | oui |
| Import et export CSV | non | non | oui |

Tout cela passe par Row Level Security. Aucune fonction edge.

## 3bis. Ce que le releve existant nous apprend

Le fichier `Orchard_Map.xlsx` couvre la section P2 et contient 563 arbres sur une
grille de 11 rangees par 77 positions. Extrait dans `verger/data/p2.json`.

| Variete | Arbres |
| --- | --- |
| Honeycrisp | 99 |
| **Non identifie** | **92** |
| Cortland | 85 |
| Macintosh | 83 |
| Empire | 77 |
| Lobo | 47 |
| Paulared | 38 |
| Spartan | 27 |
| Sunrise | 5 |
| Rose Pointillee | 4 |
| Laufane, Golden Russet, Ginger Gold | 2 chacune |

Trois constats importants.

**Le non identifie est la deuxieme categorie du verger**, 92 arbres sur 563, soit
16 pour cent. Ce n'est donc pas une erreur a corriger, c'est un etat normal qui doit
exister dans le modele. Un arbre non identifie ne doit jamais etre propose a un
visiteur qui cherche une variete.

**Le doute est deja note dans le releve.** Dix-sept cellules portent un `???`.
Cela confirme le besoin du marqueur variete confirmee ou supposee, et nous donne
la valeur de depart gratuitement.

**Les rangees ne se ressemblent pas.** Les rangees 1, 2 et 6 sont pures, Honeycrisp,
Honeycrisp et Cortland. Les rangees 7 a 11 sont des melanges de quatre a six varietes.
C'est exactement l'irregularite decrite par le proprietaire, et c'est ce qui rend
l'application utile plutot que decorative.

Le releve porte aussi une taille d'arbre, petit, moyen ou standard. Conservee.

## 4. Modele de donnees, esquisse

- `varieties`: nom, description, gout, conservation, utilisations recommandees,
  lien vers le calendrier du verger, texte FR et EN, **couleur d'affichage**,
  **ouverte a la cueillette** oui ou non.
- `trees`: rangee et position dans la grille, position x et y en fraction d'image,
  variete, numero dans la variete, taille, section, etat de cueillette,
  date de mise a jour de l'etat, qui l'a mise a jour, **variete confirmee ou supposee**,
  **signalement d'erreur en attente**.
- `zones`: polygone en fractions d'image, statut, nom, date de modification.
- `comments`: arbre vise, texte, auteur, interne ou public, statut de moderation,
  lu ou non lu.
- `faq`: question et reponse, FR et EN, ordre d'affichage.
- `map_config`: image active, et les points de reference qui donnent la
  transformation vers latitude et longitude.

## 5. Phase 1, le catalogue

Utilisable et presentable seule, sans aucun GPS.

- Carte sur photo aerienne, lecture mobile d'abord
- Arbres places par outil de rangee, de grille, et import CSV
- Fiches de varietes, FR et EN
- Trois etats de cueillette, avec edition en lot au lasso
- Arbres colores par variete sur la carte, pour que les erreurs sautent aux yeux
- Signalement d'erreur de variete par un employe, confirmation par un gestionnaire
- Interrupteur par variete, ouverte ou non a la cueillette
- Zones tracees par gestionnaire, affichage de ce qui est ouvert aujourd'hui
- Commentaires publics moderes, commentaires internes, marquage lu et non lu
- FAQ
- Panneau d'administration, comptes individuels, roles employe et gestionnaire
- Liens profonds, `?s=p1` par section pour les codes QR, `?t=<id>` vers un arbre
- Mise en cache pour signal cellulaire faible
- Entree au portfolio de la page d'accueil Norelo, FR et EN

## 6. Phase 2, le reperage

- Georeferencement de la photo, trois points de repere suffisent
- Position du visiteur en direct sur la carte
- Choix d'une variete, mise en evidence de l'arbre disponible le plus proche
- Ligne droite et distance en metres
- Les zones restreintes ne fournissent jamais de candidat

Un arbre est disponible si les trois conditions sont remplies: sa zone est ouverte,
sa variete est ouverte a la cueillette, et il n'est pas vide.
Les arbres pleins passent avant ceux en hauteur seulement.

## 7. Hors perimetre

Retire volontairement, et pourquoi.

- **Itineraire pas a pas.** Le verger est un grand rectangle ouvert, on marche entre
  les rangees. Une ligne droite est le vrai chemin.
- **Contournement d'obstacles.** Sans itineraire, les fosses et les haies n'ont pas
  besoin d'etre cartographies.
- **Reseau d'allees.** Meme raison.
- **Boussole.** Le cap du telephone est peu fiable. La carte suffit pour s'orienter.
- **Precision a l'arbre pres.** Le GPS d'un telephone a une erreur de 3 a 10 metres,
  davantage sous le feuillage, ce qui depasse l'espacement entre deux arbres.
  L'application vise le bloc, pas l'arbre exact.
- **Fenetres de maturite.** Remplacees par le statut des zones.
- **Photos envoyees par les visiteurs.** Reporte.
- **Filtre par usage,** croquer, tarte, jus. Reporte, facile a ajouter ensuite.

## 8. Contraintes techniques

- `index.html` autonome, HTML, CSS et JavaScript natif
- Aucune librairie externe sauf le client Supabase
- Aucun outil de compilation, aucun npm
- Aucun tiret cadratin nulle part
- Tout bilingue, dictionnaires FR et EN aux cles identiques
- Chrome, Safari, Firefox, Edge. Mobile d'abord.

## 9. Questions ouvertes

1. Source de la photo aerienne. Une capture de Google Satellite pose un probleme
   de licence sur un site commercial. Les orthophotos ouvertes du Quebec ou une
   photo de drone prise sur place evitent la question et sont souvent de meilleure
   resolution.
2. Les fiches de varietes sont-elles redigees, ou a ecrire?
3. Quelle est l'adresse du calendrier de maturite, pour y pointer?
4. Existe-t-il un releve equivalent pour P1, P3 et P4, ou seulement pour P2?
5. Format attendu pour l'import et l'export CSV.
6. La taille d'arbre doit-elle etre montree au visiteur, ou rester interne?

## 10. Risque principal

Deux risques, pas un.

**La fraicheur.** L'etat des arbres n'a de valeur que s'il est a jour. Une carte qui annonce des arbres
pleins dans une section cueillie hier est pire que pas de carte, parce qu'elle envoie
les gens marcher pour rien. L'edition en lot doit etre construite en premier, avant
meme le selecteur a trois etats, pour qu'un employe puisse corriger une section
entiere en quelques secondes.

**L'exactitude.** Le verger est irregulier et le personnel lui-meme confond des
varietes. Une carte qui se trompe de variete envoie le visiteur cueillir autre chose
que ce qu'il voulait, et il ne le decouvre qu'une fois rentre a la maison. C'est
pour cela que la couleur par variete, le signalement par les employes et la
distinction entre variete confirmee et supposee ne sont pas optionnels.

C'est aussi la justification du projet. Un verger bien range se reglerait avec
quatre pancartes. Celui-ci ne peut pas, et c'est exactement ce que l'application
apporte.
