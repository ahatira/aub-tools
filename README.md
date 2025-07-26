# DevxTools

DevxTools est une suite d'outils en ligne de commande conçue pour simplifier et automatiser les tâches courantes de développement et d'administration de projets Drupal, avec des intégrations pour Git, Composer, Drush, IBM Cloud et Kubernetes. Il offre une interface conviviale et interactive pour gérer vos projets au quotidien.

-----

## Table des matières

  * [Fonctionnalités](https://www.google.com/search?q=%23fonctionnalit%C3%A9s)
  * [Installation](https://www.google.com/search?q=%23installation)
      * [Prérequis](https://www.google.com/search?q=%23pr%C3%A9requis)
      * [Étapes d'installation](https://www.google.com/search?q=%23%C3%A9tapes-dinstallation)
  * [Utilisation](https://www.google.com/search?q=%23utilisation)
      * [Menu Principal](https://www.google.com/search?q=%23menu-principal)
      * [Gestion de Projet](https://www.google.com/search?q=%23gestion-de-projet)
      * [Gestion Git](https://www.google.com/search?q=%23gestion-git)
      * [Gestion Drush](https://www.google.com/search?q=%23gestion-drush)
      * [Gestion de Base de Données](https://www.google.com/search?q=%23gestion-de-base-de-donn%C3%A9es)
      * [Gestion Search API Solr](https://www.google.com/search?q=%23gestion-search-api-solr)
      * [Intégration IBM Cloud](https://www.google.com/search?q=%23int%C3%A9gration-ibm-cloud)
      * [Gestion Kubernetes](https://www.google.com/search?q=%23gestion-kubernetes)
      * [Historique des Commandes](https://www.google.com/search?q=%23historique-des-commandes)
      * [Favoris Personnalisés](https://www.google.com/search?q=%23favoris-personnalis%C3%A9s)
  * [Configuration](https://www.google.com/search?q=%23configuration)
  * [Dépannage](https://www.google.com/search?q=%23d%C3%A9pannage)
  * [Contribution](https://www.google.com/search?q=%23contribution)
  * [Licence](https://www.google.com/search?q=%23licence)

-----

## Fonctionnalités

DevxTools regorge de fonctionnalités pour optimiser votre flux de travail :

  * **Installation et gestion de projet :** Cloner des dépôts Git, lancer des installations Composer, générer des fichiers `.env` et détecter la racine Drupal automatiquement.
  * **Gestion Git :** Vérifier le statut et l'historique, gérer les branches (créer, basculer, lister), `pull` et `push` vos changements, et gérer vos stashes.
  * **Gestion Drush :** Exécuter des commandes Drush sur des cibles spécifiques (alias ou URI de site) pour le cache, la configuration (import/export), les modules/thèmes, les utilisateurs, les logs Watchdog, les Webforms et les outils de développement.
  * **Gestion de Base de Données :** Mettre à jour les bases de données, créer des dumps SQL, interagir avec la CLI SQL, exécuter des requêtes et synchroniser/restaurer des bases à partir de divers formats de dump.
  * **Gestion Search API Solr :** Lister les serveurs et index Solr, exporter les configurations, indexer le contenu et vider les index.
  * **Intégration IBM Cloud :** Connectez-vous et déconnectez-vous d'IBM Cloud, listez les clusters Kubernetes et configurez `kubectl` en un clin d'œil.
  * **Gestion Kubernetes :** Vérifiez le contexte `kubectl`, listez les pods, redémarrez-les, affichez leurs logs et copiez-y des fichiers. Des menus spécifiques sont là pour les pods Solr et PostgreSQL.
  * **Historique des commandes :** Enregistrez et rejouez facilement les commandes que vous avez exécutées.
  * **Favoris personnalisés :** Définissez et lancez vos propres fonctions ou alias Bash.
  * **Internationalisation (i18n) :** L'outil est disponible en anglais (en\_US) et en français (fr\_FR), avec détection automatique de la langue de votre système.
  * **Journalisation robuste :** Tous les événements sont journalisés pour un suivi et un débogage facilités.
  * **Rapports d'erreurs :** Génération de rapports détaillés pour vous aider en cas de problème.

-----

## Installation

### Prérequis

Assurez-vous d'avoir les outils suivants installés sur votre système avant de commencer :

  * **Git :** Indispensable pour cloner le dépôt.
  * **Curl :** Nécessaire pour télécharger `jq`.
  * **Unzip/Tar :** Utile pour décompresser certains formats de dumps de base de données.
  * **Drush :** Fortement recommandé pour la gestion des projets Drupal.
  * **Composer :** Recommandé pour la gestion des dépendances PHP.
  * **IBM Cloud CLI :** Optionnel, si vous utilisez les fonctionnalités IBM Cloud.
  * **Kubectl :** Optionnel, si vous utilisez les fonctionnalités Kubernetes.

### Étapes d'installation

1.  **Cloner le dépôt DevxTools :**

    ```bash
    git clone https://github.com/votre_utilisateur/devxtools.git ~/.dev-tools
    ```

    *(N'oubliez pas de remplacer `https://github.com/votre_utilisateur/devxtools.git` par l'URL réelle de votre dépôt.)*

2.  **Exécuter le script d'installation :**
    Naviguez vers le répertoire que vous venez de cloner et lancez le script `install.sh` :

    ```bash
    cd ~/.dev-tools
    chmod +x install.sh
    ./install.sh
    ```

    Ce script va créer la structure de répertoires (`~/.aub-tools`, `~/.aub-tools_config`), télécharger `jq` (un outil de traitement JSON essentiel) et mettre en place les fichiers de base.

3.  **Ajouter DevxTools à votre PATH :**
    Pour lancer `aub-tools` depuis n'importe où dans votre terminal, ajoutez son répertoire `bin` à votre variable d'environnement `PATH`.

    Pour une utilisation immédiate dans votre session actuelle :

    ```bash
    source ~/.aub-tools/install.sh
    ```

    Pour une disponibilité permanente, ajoutez cette ligne à votre fichier de configuration de shell (généralement `~/.bashrc` ou `~/.zshrc`) :

    ```bash
    export PATH="${HOME}/.aub-tools/bin:$PATH"
    ```

    N'oubliez pas de recharger votre fichier de configuration après l'avoir modifié :

    ```bash
    source ~/.bashrc # ou source ~/.zshrc
    ```

-----

## Utilisation

Une fois l'installation terminée, vous pouvez démarrer DevxTools en tapant simplement `aub-tools` dans votre terminal :

```bash
aub-tools
```

Vous serez accueilli par un **menu principal interactif**. Utilisez les **flèches haut/bas** pour naviguer et appuyez sur **Entrée** pour sélectionner une option. Appuyez sur la touche **Échap (ESC)** pour annuler une opération ou revenir au menu précédent.

### Menu Principal

C'est votre point de départ pour accéder à toutes les fonctionnalités de DevxTools :

```
----------------------------------------------------
           DevxTools 1.0
----------------------------------------------------

Veuillez sélectionner une option :
> Gestion de Projet
  Gestion Git
  Gestion Drush
  Gestion de la Base de Données
  Gestion Search API Solr
  Intégration IBM Cloud
  Gestion Kubernetes
  Historique des Commandes
  Favoris Personnalisés
  Quitter AUB Tools
```

### Gestion de Projet

Cette section vous permet d'initialiser de nouveaux projets Drupal ou de passer à un projet existant.

  * **Initialiser un Nouveau Projet :** Cloner un dépôt Git, lancer `composer install` et générer un fichier `.env` à partir de votre `.env.dist`.
  * **Sélectionner un projet existant :** Changer le répertoire de travail vers un projet déjà présent dans `~/Projects` (ou le chemin que vous avez configuré) et détecter automatiquement sa racine Drupal.

### Gestion Git

Accédez rapidement aux opérations Git les plus utilisées.

  * **Statut Git :** Affiche le statut actuel de votre dépôt.
  * **Historique Git :** Présente les 20 derniers commits.
  * **Gestion des Branches :**
      * **Lister toutes les branches (locales et distantes) :** Pour une vue d'ensemble de vos branches.
      * **Basculer vers une branche existante :** DevxTools vous offrira même de stasher vos modifications non-commitées avant de changer de branche.
      * **Créer une nouvelle branche :** Crée et bascule immédiatement vers votre nouvelle branche.
  * **Git Pull :** Récupère et intègre les dernières modifications du dépôt distant.
  * **Git Push :** Pousse vos commits locaux vers le dépôt distant.
  * **Gestion des Stashs :**
      * **Sauvegarder les modifications dans un stash :** Mettez de côté vos modifications non-commitées.
      * **Lister les stashs :** Affichez la liste de vos stashes.
      * **Appliquer un stash :** Réintégrez les modifications d'un stash choisi.
      * **Pop un stash (appliquer et supprimer) :** Applique et supprime un stash.
      * **Supprimer un stash :** Efface définitivement un stash.
  * **Annuler les Modifications :**
      * **Git Reset --hard :** **Attention, cette action est irréversible \!** Elle annule toutes les modifications locales non-commitées.
      * **Git Revert :** Annule un commit spécifique en créant un nouveau commit qui inverse ses changements.
      * **Git Clean -df :** **Attention, cette action est irréversible \!** Elle supprime définitivement les fichiers et répertoires non suivis par Git.

### Gestion Drush

Gérez votre projet Drupal avec la puissance de Drush. Vous devrez d'abord sélectionner une cible Drush (alias de site ou URI) si ce n'est pas déjà fait.

  * **Commandes Drush Générales :** Accédez à des commandes comme `drush status` et `drush cr` (reconstruction du cache).
  * **Gestion de la Configuration :** Effectuez des `drush cim` (importation de configuration) et `drush cex` (exportation de configuration).
  * **Gestion de la Base de Données :** Ce sous-menu vous mènera aux fonctions de gestion de base de données.
  * **Modules et Thèmes :** `pm:list`, `pm:enable`, `pm:disable`, `pm:uninstall`.
  * **Gestion des Utilisateurs :** `user:login`, `user:block`, `user:unblock`, `user:password`.
  * **Logs Watchdog :** `wd-show`, `wd-list`, `wd-del`, `wd-tail`.
  * **Search API Solr :** Accédez au sous-menu de gestion Solr.
  * **Gestion des Webforms :** `webform:list`, `webform:export`, `webform:purge`.
  * **Outils de Développement :** `drush ev` (exécuter du code PHP), `drush php` (shell PHP interactif), `drush cron`.

### Gestion de Base de Données

Ces fonctions sont conçues pour interagir avec la base de données de votre projet Drupal, souvent via Drush.

  * **Mises à jour de la Base de Données Drush (drush updb) :** Applique les mises à jour de base de données en attente.
  * **Dump SQL Drush (drush sql:dump) :** Crée un dump SQL de votre base de données.
  * **CLI SQL Drush (drush sql:cli) :** Ouvre une interface de ligne de commande SQL interactive.
  * **Requête SQL Drush (drush sql:query) :** Exécute directement une requête SQL sur la base de données.
  * **Synchronisation SQL Drush (drush sql:sync) :** Synchronise une base de données source vers une base de données de destination.
  * **Restaurer la Base de Données à partir d'un Dump :** Restaure une base de données à partir d'un fichier de dump. DevxTools gère plusieurs formats (`.sql`, `.sql.gz`, `.zip`, `.tar` et les dumps PostgreSQL) et tente de décompresser et d'importer le fichier automatiquement.

### Gestion Search API Solr

Gérez vos serveurs et index Solr directement depuis l'outil.

  * **Lister les serveurs Solr :** Affiche la liste des serveurs Solr configurés.
  * **Lister les index Solr :** Affiche la liste des index Solr configurés.
  * **Exporter les Configurations Solr :** Exporte les configurations Solr vers le répertoire `solr_configs/` de votre projet (chemin configurable).
  * **Indexer le Contenu :** Lance le processus d'indexation du contenu.
  * **Vider l'Index Solr :** Supprime toutes les données de l'index Solr.
  * **Statut Solr :** Vérifie l'état de vos index Solr.

### Intégration IBM Cloud

Simplifiez vos interactions avec IBM Cloud.

  * **Connexion IBM Cloud :** Connectez-vous à votre compte IBM Cloud via SSO, avec la possibilité de définir votre région et votre groupe de ressources.
  * **Déconnexion IBM Cloud :** Déconnectez-vous de votre session IBM Cloud.
  * **Lister les Clusters Kubernetes :** Affiche tous les clusters Kubernetes auxquels vous avez accès.
  * **Configurer Kubectl pour un Cluster :** Configure votre client `kubectl` local pour qu'il se connecte à un cluster Kubernetes IBM Cloud spécifique.

### Gestion Kubernetes

Une fois votre contexte `kubectl` configuré, gérez vos pods et conteneurs.

  * **Vérifier le Contexte Kubectl :** Affiche le contexte `kubectl` actuellement actif.
  * **Statut des Pods (Tous les pods) :** Liste tous les pods de votre contexte actuel, avec une option pour filtrer par label.
  * **Gestion des Pods Solr :** Un menu dédié pour gérer spécifiquement vos pods Solr (statut, redémarrage, logs).
  * **Gestion des Pods PostgreSQL :** Un menu dédié pour gérer spécifiquement vos pods PostgreSQL (statut, accès CLI, logs).
  * **Copier des Fichiers vers un Pod (kubectl cp) :** Copiez facilement des fichiers ou des répertoires depuis votre machine locale vers un conteneur de pod.

### Historique des Commandes

DevxTools garde une trace de vos actions pour vous.

  * **Afficher l'Historique :** Visualisez une liste des commandes que vous avez exécutées, avec la possibilité de les relancer directement.
  * **Exécuter une commande de l'historique :** Rejouez rapidement une commande passée.
  * **Nettoyer l'Historique :** Supprime toutes les entrées de l'historique.

### Favoris Personnalisés

Créez et gérez vos propres commandes ou fonctions Bash.

  * **Afficher les Favoris :** Visualisez les fonctions et alias que vous avez définis dans le fichier `~/.aub-tools_config/aub-tools_favorites.sh`.
  * **Exécuter un Favori :** Lancez l'une de vos fonctions favorites.
  * **Modifier le Fichier des Favoris :** Ouvre `aub-tools_favorites.sh` dans votre éditeur de texte par défaut (`code`, `atom`, `subl` ou `vi`) pour que vous puissiez ajouter ou modifier vos commandes personnalisées.

-----

## Configuration

DevxTools est hautement configurable via le fichier `~/.aub-tools_config/config.sh`. Ce fichier contient des variables que vous pouvez ajuster pour personnaliser l'outil.

Quelques exemples de configurations importantes :

  * `AUB_TOOLS_CONFIG_DIR` : Le répertoire racine pour vos fichiers de configuration.
  * `AUB_TOOLS_LOG_FILE` : Le chemin du fichier où les logs sont enregistrés.
  * `DEFAULT_LANG` : La langue par défaut de l'interface (`en_US` ou `fr_FR`).
  * `CURRENT_LOG_LEVEL_DISPLAY` : Le niveau de verbosité pour les messages affichés dans le terminal (par exemple, `INFO` pour les informations générales, `DEBUG` pour plus de détails).
  * `CURRENT_LOG_LEVEL_FILE` : Le niveau de verbosité pour les logs écrits dans le fichier.
  * `ENABLE_HISTORY` : Active ou désactive l'enregistrement de l'historique des commandes (`true`/`false`).
  * `ENABLE_FAVORITES` : Active ou désactive la fonctionnalité des favoris personnalisés (`true`/`false`).
  * `ENABLE_ERROR_REPORTING` : Active ou désactive la génération automatique de rapports d'erreurs (`true`/`false`).
  * `DRUPAL_ROOT_DIR` : Le chemin par défaut de la racine Drupal, relatif à la racine de votre projet (par exemple, `'src/web'`).
  * `DRUPAL_DUMP_DIR` : Le répertoire par défaut où chercher les dumps de base de données au sein d'un projet (par exemple, `'/data'`).
  * `IBMCLOUD_REGION` / `IBMCLOUD_RESOURCE_GROUP` : Vos identifiants IBM Cloud par défaut.
  * `SOLR_CONFIG_EXPORT_DIR` : Le répertoire où exporter les configurations Solr.

**Important :** N'éditez jamais directement les fichiers situés dans le répertoire `~/.aub-tools/` (à l'exception de `install.sh` lors de la première installation). Toutes vos personnalisations et configurations doivent être effectuées dans le répertoire `~/.aub-tools_config/`.

-----

## Dépannage

Rencontrez-vous un problème ? Voici quelques solutions courantes :

  * **"command not found: aub-tools"** : Assurez-vous d'avoir bien ajouté `~/.aub-tools/bin` à votre `PATH` et d'avoir rechargé votre shell après l'installation.
  * **"jq: command not found"** : L'outil `jq` est téléchargé automatiquement. Vérifiez que `install.sh` s'est déroulé sans erreur. Si le problème persiste, installez `jq` manuellement via votre gestionnaire de paquets (`sudo apt-get install jq` sur Debian/Ubuntu, `brew install jq` sur macOS).
  * **Problèmes avec Drush/Composer/Kubectl/IBM Cloud CLI :** Vérifiez que ces outils sont correctement installés sur votre système et qu'ils sont accessibles via votre `PATH`.
  * **Erreurs de traduction (messages affichant des clés comme `MSG_WELCOME`) :** Assurez-vous que les fichiers de messages (`messages.sh`) existent pour votre langue dans `~/.aub-tools/lang/` et que le script `i18n.sh` les charge correctement.
  * **Rapports d'erreurs :** Si une erreur inattendue survient, DevxTools vous proposera de générer un rapport d'erreurs détaillé dans `~/.aub-tools_config/`. Ce rapport contient des informations système et des logs qui peuvent être très utiles pour identifier la cause du problème.

-----

## Contribution

DevxTools est un projet open-source et nous accueillons toutes les contributions \! Si vous souhaitez participer à son amélioration :

1.  Faites un "fork" du dépôt sur GitHub.
2.  Créez une nouvelle branche pour vos modifications : `git checkout -b feature/nouvelle-fonctionnalite`.
3.  Commitez vos changements avec un message clair : `git commit -am 'Ajouter une nouvelle fonctionnalité'`.
4.  Poussez vos modifications vers votre branche : `git push origin feature/nouvelle-fonctionnalite`.
5.  Ouvrez une "pull request" sur le dépôt principal.

-----

## Licence

Ce projet est distribué sous la [Licence MIT](https://opensource.org/licenses/MIT). Consultez le fichier `LICENSE` (qui sera créé à la racine de votre dépôt) pour plus de détails.
