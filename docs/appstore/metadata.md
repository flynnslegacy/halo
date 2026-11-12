# Fiche App Store de Menulens

## Informations de l'app

| Champ | Valeur |
|---|---|
| Nom | Menulens (repli si pris : « Menulens – Barre des menus ») |
| Identifiant de bundle | com.davidmarkowicz.menulens |
| SKU | menulens-macos |
| Langue principale | Français |
| Catégorie principale | Utilitaires |
| Catégorie secondaire | Productivité |
| Prix | Gratuit, toutes les régions |
| Copyright | 2026 David Markowicz |
| Classification | 4+ (aucun contenu sensible) |
| URL d'assistance | https://github.com/flynnslegacy/menulens |
| URL marketing | https://github.com/flynnslegacy/menulens |
| Politique de confidentialité | https://github.com/flynnslegacy/menulens/blob/main/docs/privacy.md |
| Confidentialité de l'app | Données non collectées |
| Chiffrement | Aucun (ITSAppUsesNonExemptEncryption = NO) |

## Français

**Sous-titre** (30 car. max)
Votre Mac en une seule icône

**Texte promotionnel** (170 car. max)
Batterie, Wi-Fi, Bluetooth, VPN, son, réseau, mémoire, CPU et disque réunis dans une seule icône élégante. Gratuit, sans pub, sans pistage.

**Mots-clés** (100 car. max)
barre des menus,batterie,wifi,bluetooth,vpn,cpu,mémoire,disque,réseau,airpods,moniteur,système

**Description**

Menulens remplace les icônes qui encombrent votre barre des menus par une seule icône, claire et personnalisable.

UNE ICÔNE, TROIS INFORMATIONS
Choisissez ce qu'affichent ses trois zones :
• l'anneau, qui se remplit selon une mesure (par exemple la force du Wi-Fi) ;
• le centre, qui affiche un symbole ou une valeur (par exemple le pourcentage de batterie) ;
• les points, pour une troisième mesure (par exemple le volume).

TOUT VOTRE MAC D'UN COUP D'ŒIL
Un clic ouvre un panneau qui détaille chaque mesure :
• Batterie : niveau, temps restant, source d'alimentation, capacité maximale, nombre de cycles
• Wi-Fi : réseau, signal, débit, réseaux alentour
• Bluetooth : appareils jumelés et batterie des AirPods, souris et claviers
• VPN : connectez ou déconnectez vos VPN en un clic
• Son : volume, muet et choix de la sortie audio
• Réseau : débits en temps réel et graphique de la dernière minute
• Mémoire, processeur et disque

FAITE POUR VOUS
• 12 palettes de couleurs, 3 styles d'anneau, 3 épaisseurs
• Des profils (Travail, Voyage…) pour passer d'une configuration à l'autre
• L'icône peut se déplier en icônes séparées au survol
• Des « moments en direct » : chargeur branché, AirPods connectés, batterie faible, changement de volume…
• Français et anglais

RESPECT DE VOTRE VIE PRIVÉE
Menulens ne collecte aucune donnée, n'effectue aucune requête réseau et ne contient ni publicité ni pistage. Tout est lu localement sur votre Mac via les API d'Apple, et seules les mesures affichées sont relevées, pour économiser la batterie.

GRATUIT
Toutes les fonctions sont incluses, sans abonnement. Si Menulens vous est utile, vous pouvez soutenir son développement avec le bouton « Faire un don ».

**Nouveautés de cette version**
Première version de Menulens.

## English (U.S.)

**Subtitle**
Your Mac in one menu bar icon

**Promotional text**
Battery, Wi-Fi, Bluetooth, VPN, sound, network, memory, CPU and disk in one elegant menu bar icon. Free, no ads, no tracking.

**Keywords**
menu bar,battery,wifi,bluetooth,vpn,cpu,memory,disk,network,airpods,monitor,stats,system

**Description**

Menulens replaces the icons cluttering your menu bar with a single, clear and customizable icon.

ONE ICON, THREE READINGS
Choose what each part shows:
• the ring fills up with one metric (for example Wi-Fi strength);
• the center shows a symbol or a value (for example battery percentage);
• the dots show a third metric (for example volume).

YOUR WHOLE MAC AT A GLANCE
One click opens a panel with the details of every metric:
• Battery: level, time remaining, power source, maximum capacity, cycle count
• Wi-Fi: network, signal, transmit rate, nearby networks
• Bluetooth: paired devices and the battery of AirPods, mice and keyboards
• VPN: connect or disconnect your VPNs in one click
• Sound: volume, mute and output device
• Network: live throughput and a graph of the last minute
• Memory, CPU and disk

MADE FOR YOU
• 12 color palettes, 3 ring styles, 3 thicknesses
• Profiles (Work, Travel…) to switch setups in one click
• The icon can unfold into separate icons when you hover over it
• Live moments: charger plugged in, AirPods connected, low battery, volume change…
• English and French

PRIVATE BY DESIGN
Menulens collects no data, makes no network requests and has no ads or tracking. Everything is read locally on your Mac through Apple's APIs, and only the metrics you can see are sampled, to save battery.

FREE
Every feature is included, with no subscription. If Menulens helps you, you can support its development with the "Make a Donation" button.

**What's new**
First release of Menulens.

## Notes pour l'examen (App Review)

Menulens is a menu bar app (LSUIElement): it has no Dock icon and no main window. After launch, click the round icon in the menu bar to open its panel; click a row to see its details. Right-click the icon (or use the panel's footer) for Settings.

- Bluetooth access lists the user's paired devices and their battery level.
- Location access is only requested from the Wi-Fi page, because macOS requires it to read Wi-Fi network names (SSID). The location itself is never used.
- The VPN page lists the VPN configurations macOS already has (System Settings › VPN) and starts or stops them on request, using the system's `scutil --nc` command. It does not create or modify VPN configurations. If no VPN is set up, the page says so.
- The "Make a Donation" button opens the developer's Buy Me a Coffee page in the default browser. It is optional and unlocks nothing: every feature is free.
- The app makes no network requests and collects no data.

## Captures d'écran

`docs/appstore/screenshots/fr/` et `docs/appstore/screenshots/en/` : 5 images 2880 × 1800.
