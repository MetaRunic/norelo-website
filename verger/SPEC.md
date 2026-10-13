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
| Coordonnees | Stockees en fractions de l'image, 0 a 1. Resistantes au remplacement de la photo. Converties en latitude et longitude par une transformation affine. |
| Commentaires publics | Moderes. Invisibles jusqu'a approbation par un gestionnaire. |
| Commentaires internes | Visibles par le personnel seulement. |
| Comptes | Comptes individuels. Deux roles, employe et gestionnaire. |
| Etat des arbres | Trois etats, plein, pommes en hauteur seulement, vide. Modifiable par tout employe. |
| Zonage | Polygones traces par un gestionnaire, statut ouvert ou restreint, change quotidiennement. |
| Appartenance a une zone | Calculee par geometrie, jamais stockee en dur, pour rester juste quand une zone est redessinee. |
| GPS | Position du visiteur, arbre le plus proche d'une variete, ligne droite, distance en metres. **Aucun calcul d'itineraire.** |
| Maturite | Aucune donnee operationnelle. Le calendrier du site du verger sert de reference approximative. L'ouverture d'une zone est la vraie decision. |
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

## 4. Modele de donnees, esquisse

- `varieties`: nom, description, gout, conservation, utilisations recommandees,
  lien vers le calendrier du verger, texte FR et EN.
- `trees`: position x et y en fraction d'image, variete, section, etat de cueillette,
  date de mise a jour de l'etat, qui l'a mise a jour.
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

Un arbre est disponible s'il est dans une zone ouverte et qu'il n'est pas vide.
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

1. Une zone contient-elle une seule variete, ou plusieurs melangees? Si melangees,
   il faudra un interrupteur par variete en plus du statut de zone.
2. La photo aerienne existe-t-elle, et a quelle resolution?
3. Les fiches de varietes sont-elles redigees, ou a ecrire?
4. Quelle est l'adresse du calendrier de maturite, pour y pointer?
5. Les sections P1 a P4 sont-elles fixes, ou y en aura-t-il d'autres?
6. Format attendu pour l'import et l'export CSV.

## 10. Risque principal

L'etat des arbres n'a de valeur que s'il est a jour. Une carte qui annonce des arbres
pleins dans une section cueillie hier est pire que pas de carte, parce qu'elle envoie
les gens marcher pour rien. L'edition en lot doit etre construite en premier, avant
meme le selecteur a trois etats, pour qu'un employe puisse corriger une section
entiere en quelques secondes.
