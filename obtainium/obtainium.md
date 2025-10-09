[RETROID POCKET FLIP 2 - Tools](./README.md)

# OBTAINIUM
> Gestionnaire d'Applications Open-Source

## Qu'est-ce qu'Obtainium ?

**Obtainium** est une application Android open-source gratuite qui permet de télécharger, installer et maintenir à jour des applications directement depuis leurs sources officielles, comme GitHub, sans dépendre du Google Play Store. 

Contrairement aux stores traditionnels, Obtainium récupère les versions les plus récentes des apps en vérifiant automatiquement les mises à jour sur les repositories en ligne (par exemple, via des liens RSS, GitHub Releases ou des pages web). C'est un outil idéal pour les utilisateurs avancés qui veulent éviter les trackers, les pubs ou les restrictions des stores propriétaires.

Développé par une communauté open-source, **Obtainium** est léger, respectueux de la vie privée et hautement personnalisable. Il supporte l'importation de fichiers de configuration au format JSON, ce qui permet de gérer facilement une liste d'applications prédéfinies. Vous pouvez l'installer via son repository GitHub officiel : [github.com/ImranR98/Obtainium](https://github.com/ImranR98/Obtainium) - __ARMv8__.

## Pourquoi Utiliser Obtainium sur le Retroid Pocket Flip 2 ?

Le **Retroid Pocket Flip 2**, avec son système Android 13, est parfait pour l'émulation et le rétrogaming, mais les applications pré-installées (comme certains launchers ou émulateurs basiques) peuvent être limitées ou obsolètes. 

**Obtainium** vous permet de :
- **Personnaliser votre console** : Ajouter ou remplacer des apps adaptées au format clamshell, comme des launchers rétro (Daijisho, ES-DE), des émulateurs avancés (RetroArch, Dolphin pour GameCube/Wii) ou des outils d'optimisation (performance boosters, thèmes custom).
- **Maintenir les mises à jour** : Vérifiez et installez automatiquement les dernières versions pour une meilleure compatibilité avec le Snapdragon 865, sans risquer de brick votre appareil.
- **Éviter les bloatwares** : Remplacez les apps pré-installées par des alternatives open-source, sécurisées et optimisées pour les petits écrans et les contrôles physiques de la console.
- **Gérer facilement** : Importez une liste d'apps en un clic via un fichier JSON, et laissez Obtainium s'occuper du reste.

**Obtainium** est particulièrement utile sur des appareils comme le Retroid Pocket Flip 2, où l'espace est limité et où vous voulez une expérience fluide pour l'émulation de consoles DS, PSP, PS1, etc. Il ne nécessite pas de root et fonctionne en arrière-plan pour des notifications discrètes.

## Comment Commencer avec Obtainium ?

1. **Installation** : Téléchargez l'APK depuis le [GitHub d'Obtainium](https://github.com/ImranR98/Obtainium/releases) et installez-le sur votre Retroid Pocket Flip 2 (activez "Sources inconnues" dans les paramètres Android si nécessaire).
2. **Ajout d'Apps** : Dans l'app, ajoutez manuellement l'URL d'un repository (ex. : GitHub d'un émulateur) ou importez un fichier JSON pour une configuration rapide.
3. **Mises à Jour** : Configurez des vérifications périodiques (quotidiennes ou hebdomadaires) pour que Obtainium vous alerte des nouvelles versions.
4. **Conseils pour la Console** : Utilisez Obtainium pour des apps comme RetroArch (émulation multi-consoles), Moonlight (streaming PC), ou des outils comme AetherSX2 (émulateur PS2 optimisé pour SD865). Assurez-vous de tester la compatibilité avec les contrôles Hall Effect de la Flip 2.

Pour une expérience optimale, combinez **Obtainium** avec des launchers comme **Daijisho** pour une interface "console-like" qui cache les éléments Android inutiles.

## Fichier JSON Personnalisé pour le Retroid Pocket Flip 2

Pour simplifier la personnalisation, nous avons préparé un fichier JSON dédié aux applications adaptées à votre Retroid Pocket Flip 2. 

Ce fichier liste des apps open-source essentielles pour compléter ou remplacer les pré-installées : émulateurs, launchers, optimiseurs et outils de gestion ... 

- **Téléchargez le fichier JSON ici** : [obtainium-rpflip2-emu-pack](./obtainium-rpflip2-emu-pack.json) (fichier hébergé dans ce repository public).

### Contenu du Fichier JSON (Exemple Aperçu)
Le JSON contient des apps triées par catégorie. Voici un extrait simplifié (format Obtainium standard) :

```json
{
  "apps": [
    {
            "id": "io.github.lime3ds.android",
            "url": "https://github.com/azahar-emu/azahar",
            "author": "azahar-emu",
            "name": "Azahar",
            "description": "Émulateur Nintendo 3DS (fork de Citra).",         
            "categories": [
                "Emulator"
            ],
            "overrideSource": "GitHub"
        },
        {
            "id": "info.cemu.cemu",
            "url": "https://github.com/SSimco/Cemu",
            "author": "SSimco",
            "name": "Cemu",
            "description": "Émulateur Wii U (Cemu) — émule les jeux Wii U.",           
            "categories": [
                "Emulator"
            ],
            "overrideSource": "GitHub"
        },
    // ... Autres apps : Dolphin (GameCube/Wii) .. etc ..
  ]
}
```

**Comment Importer ?**
- Ouvrez Obtainium sur votre console.
- Allez dans "Ajouter une App" > "Importer depuis JSON".
- Sélectionnez le fichier téléchargé.
- Obtainium analysera et ajoutera les apps ; installez-les une par une et configurez les mises à jour.

Ce fichier est maintenu dans le repository et sera mis à jour régulièrement pour inclure de nouvelles apps compatibles. 

Si vous avez des suggestions d'apps à ajouter (ex. : pour Nintendo Switch emulation via (feu) Yuzu), contribuez via une pull request sur GitHub !

Obtainium transforme votre Retroid Pocket Flip 2 en une console véritablement personnalisée. 

Pour toute question, consultez la [documentation officielle](https://github.com/ImranR98/Obtainium/wiki) ou les forums Retroid. 

Bonne émulation !