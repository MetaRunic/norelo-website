# Prospects, suivi de prospection

Page interne (`/prospects`, `noindex`). Elle sert à savoir **qui a été
approché, par qui et quand**, pour que personne ne se fasse déranger deux
fois par deux personnes différentes.

## Mise en route (une seule fois)

1. Ouvrir le **SQL Editor** de Supabase (projet `wbdmwygvwdyinhwtsrwe`).
2. Coller le contenu de [`sql/01_prospects.sql`](sql/01_prospects.sql) et exécuter.
   Le script est idempotent : on peut le relancer sans rien casser.
3. Déployer. La page est prête.

Les comptes de connexion sont **les mêmes que ceux de l'horaire**
(table `profiles`). Sans connexion, la page ne montre rien et la base
refuse toute lecture : le site est public, les données ne le sont pas.

## Ce que fait la page

| Besoin | Où |
| --- | --- |
| Ajouter vite une entreprise | Zone **Collage rapide** : coller la fiche Google Maps, les champs se remplissent |
| Savoir si on la connaît déjà | Avertissement automatique sous le formulaire (nom, téléphone, courriel ou domaine identique) |
| Voir qui l'a approchée | Colonne **Dernière approche** + historique complet dans la fiche |
| Noter un appel | Bouton **Contact** sur la ligne. C'est ce qui alimente l'historique partagé |
| Ne plus déranger quelqu'un | Statut **NE PAS CONTACTER** : la ligne devient rouge et l'app bloque avant toute nouvelle approche |
| Reprendre le travail | Tuile **À relancer** et tri « Contact le plus ancien » |
| Sortir la liste | **Exporter CSV** (respecte les filtres affichés) |

## Les deux règles

1. **Un appel non noté n'existe pas.** Si ce n'est pas dans l'historique,
   le prochain employé rappellera les mêmes gens.
2. **On archive, on ne supprime pas.** Archiver garde la trace des
   approches déjà faites. Seul un gestionnaire peut supprimer.

Le délai de politesse entre deux approches est de 14 jours
(`COOLDOWN_DAYS` dans `index.html`). En deçà, l'app avertit mais laisse
passer si on insiste.
