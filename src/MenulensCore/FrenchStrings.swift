import Foundation

/// French translations, keyed by the English UI string.
enum FrenchStrings {
    static let table: [String: String] = [
        // Metrics, slots and styles
        "Battery": "Batterie", "Volume": "Volume", "Network": "Réseau", "Memory": "Mémoire", "Disk": "Disque",
        "Wi-Fi": "Wi-Fi", "Bluetooth": "Bluetooth", "VPN": "VPN",
        "Network Activity": "Activité réseau", "CPU Usage": "Utilisation CPU", "Sound": "Son",
        "Ring": "Anneau", "Center": "Centre", "Dots": "Points",
        "Solid": "Plein", "Gradient": "Dégradé", "Segmented": "Segmenté",
        "Thin": "Fin", "Regular": "Normal", "Bold": "Épais",
        "Automatic": "Automatique", "Monochrome": "Monochrome", "Ocean": "Océan", "Indigo": "Indigo",
        "Violet": "Violet", "Rose": "Rose", "Sunset": "Crépuscule", "Grass": "Herbe", "Aurora": "Aurore",
        "Mint": "Menthe", "Gold": "Or", "Crimson": "Carmin",
        "Work": "Travail", "Travel": "Voyage", "Minimal": "Minimal",
        "B": "o", "KB": "Ko", "MB": "Mo", "GB": "Go", "TB": "To", "PB": "Po",
        "KB/s": "Ko/s", "MB/s": "Mo/s", "GB/s": "Go/s",
        "1 day, %d h": "1 jour, %d h", "%d days, %d h": "%d jours, %d h",

        // Common states
        "Connected": "Connecté", "Not Connected": "Non connecté", "Connecting…": "Connexion…",
        "Disconnecting…": "Déconnexion…", "Off": "Désactivé", "Offline": "Hors ligne", "Not set up": "Non configuré",
        "Known": "Connu", "Joining…": "Connexion…", "Muted": "Muet", "Mute": "Couper le son", "Unmute": "Rétablir le son",
        "Now": "Maintenant", "Low": "Bas", "High": "Haut", "Unknown": "Inconnu",
        "Normal": "Normal", "Fair": "Moyen", "Serious": "Élevé", "Critical": "Critique",

        // Main popover
        "Profile": "Profil", "Menulens Settings…": "Réglages de Menulens…", "Quit Menulens": "Quitter Menulens",
        "No devices connected": "Aucun appareil connecté", "%@ of %@": "%@ sur %@", "%@ free": "%@ libres",
        "%@ user · %@ system": "%@ utilisateur · %@ système", "This device sets its own volume.": "Cet appareil règle son propre volume.",

        // Battery
        "Charging": "En charge", "Fully charged": "Chargée", "Not charging": "Pas en charge", "On battery": "Sur batterie",
        "No battery": "Pas de batterie", "Power Adapter": "Adaptateur secteur", "Power Source": "Source d'alimentation",
        "Time to Full Charge": "Temps avant charge complète", "Time Remaining": "Temps restant",
        "Estimating time remaining": "Estimation du temps restant", "Low Power Mode": "Mode économie d'énergie",
        "Maximum Capacity": "Capacité maximale", "Cycle Count": "Nombre de cycles", "Condition": "État",
        "This Mac has no battery.": "Ce Mac n'a pas de batterie.", "Battery Settings…": "Réglages Batterie…",

        // Network
        "Download": "Réception", "Upload": "Envoi", "Last minute": "Dernière minute", "Peak %@": "Pic %@",
        "Connection": "Connexion", "Received since startup": "Reçu depuis le démarrage", "Sent since startup": "Envoyé depuis le démarrage",
        "Network Settings…": "Réglages Réseau…", "Wired connection": "Connexion filaire", "Cellular": "Cellulaire",
        "Network disconnected": "Réseau déconnecté",

        // CPU, memory, disk
        "Load Averages": "Charge moyenne", "Cores": "Cœurs", "Thermal State": "État thermique", "Uptime": "Allumé depuis",
        "Activity Monitor…": "Moniteur d'activité…", "App Memory": "Mémoire des apps", "Wired Memory": "Mémoire résidente",
        "Compressed": "Compressée", "Cached Files": "Fichiers en cache", "Swap Used": "Swap utilisé",
        "%@ free of %@": "%@ libres sur %@", "Storage information isn't available.": "Les informations de stockage ne sont pas disponibles.",
        "Storage Settings…": "Réglages Stockage…",

        // Wi-Fi
        "No Wi-Fi interface found.": "Aucune interface Wi-Fi trouvée.", "Wi-Fi is off.": "Le Wi-Fi est désactivé.",
        "Disconnect": "Se déconnecter", "Disconnects from this network": "Se déconnecte de ce réseau",
        "Signal": "Signal", "Transmit Rate": "Débit", "Band": "Bande",
        "Excellent signal": "Excellent signal", "Good signal": "Bon signal", "Fair signal": "Signal moyen", "Weak signal": "Signal faible",
        "macOS treats Wi-Fi network names as location data, so Menulens needs Location access to show your network's name and the networks around you.":
            "macOS considère les noms de réseaux Wi-Fi comme des données de localisation : Menulens a donc besoin de l'accès à la localisation pour afficher le nom de votre réseau et ceux qui vous entourent.",
        "Allow Location Access": "Autoriser la localisation", "Open Privacy Settings": "Ouvrir les réglages de confidentialité",
        "Networks": "Réseaux", "No networks found.": "Aucun réseau trouvé.", "Password": "Mot de passe", "Join": "Rejoindre",
        "Turn on “Switch Wi-Fi networks and Bluetooth devices” in Menulens Settings to join networks from here.":
            "Activez « Changer de réseau Wi-Fi et d'appareil Bluetooth » dans les réglages de Menulens pour rejoindre un réseau d'ici.",
        "Couldn't join this network.": "Impossible de rejoindre ce réseau.",
        "Couldn't join. Check the password and try again.": "Connexion impossible. Vérifiez le mot de passe et réessayez.",
        "That network is no longer in range.": "Ce réseau n'est plus à portée.", "Wi-Fi Settings…": "Réglages Wi-Fi…",

        // Bluetooth
        "Turn Bluetooth on in Bluetooth Settings to use your devices.": "Activez le Bluetooth dans les réglages Bluetooth pour utiliser vos appareils.",
        "No devices are paired with this Mac.": "Aucun appareil n'est jumelé avec ce Mac.",
        "Click to Connect": "Cliquer pour connecter", "Click to Disconnect": "Cliquer pour déconnecter",
        "L %d%%": "G %d %%", "R %d%%": "D %d %%", "Case %d%%": "Boîtier %d %%", "Device": "Appareil",
        "Bluetooth Settings…": "Réglages Bluetooth…",

        // Sound
        "Output": "Sortie", "Sound Settings…": "Réglages Son…",

        // VPN
        "No VPN is set up on this Mac.": "Aucun VPN n'est configuré sur ce Mac.",
        "Click a VPN to connect or disconnect it.": "Cliquez sur un VPN pour le connecter ou le déconnecter.",
        "VPN Settings…": "Réglages VPN…", "VPN connected.": "VPN connecté.", "VPN disconnected.": "VPN déconnecté.",
        "Show the macOS %@ icon in the menu bar": "Afficher l'icône %@ de macOS dans la barre des menus",

        // Moments (VoiceOver)
        "Menulens. ": "Menulens. ", "%@ connected.": "%@ connecté.", "Charging, %@.": "En charge, %@.", "Unplugged, %@.": "Débranché, %@.",
        "Battery low, %d%%.": "Batterie faible, %d %%.", "Low Power Mode on.": "Mode économie d'énergie activé.",
        "Low Power Mode off.": "Mode économie d'énergie désactivé.", "Network connected.": "Réseau connecté.",
        "Network disconnected.": "Réseau déconnecté.", "Sound muted.": "Son coupé.", "Sound on.": "Son activé.",

        // Settings window
        "Menulens": "Menulens", "Menulens Settings": "Réglages de Menulens", "Mark": "Icône", "General": "Général", "Popover": "Popover",
        "Profiles": "Profils", "About": "À propos", "Language": "Langue", "Launch Menulens at login": "Ouvrir Menulens à la connexion",
        "When hovering over the Menulens icon": "Au survol de l'icône Menulens", "Do Nothing": "Ne rien faire",
        "Expand into Icons": "Déplier en icônes", "Open Popover": "Ouvrir le popover",
        "The icon unfolds into its metrics. Click one to open its page.": "L'icône se déplie en ses mesures. Cliquez sur l'une d'elles pour ouvrir sa page.",
        "The popover opens while the pointer rests on the icon, and closes when it leaves.": "Le popover s'ouvre quand le pointeur reste sur l'icône et se ferme quand il s'en va.",
        "Menulens only responds to clicks.": "Menulens ne réagit qu'aux clics.",
        "Flip unfolded icons horizontally": "Inverser l'ordre des icônes dépliées",
        "Right-click opens main popover": "Le clic droit ouvre le popover principal",
        "Live moments": "Moments en direct",
        "Briefly shows what just happened like plugging in, AirPods connecting, the battery getting low, the network dropping or a change in volume.":
            "Affiche brièvement ce qui vient de se passer : branchement du chargeur, connexion des AirPods, batterie faible, perte du réseau ou changement de volume.",
        "macOS menu bar icons": "Icônes macOS de la barre des menus",
        "Menulens replaces these icons. Turn one on to show macOS's own icon next to Menulens.":
            "Menulens remplace ces icônes. Activez-en une pour afficher l'icône d'origine de macOS à côté de Menulens.",
        "Switch Wi-Fi networks and Bluetooth devices": "Changer de réseau Wi-Fi et d'appareil Bluetooth",
        "Join networks and connect devices from the popover. This is experimental and may not always work. With this off, the popover still lists networks and devices and can turn Wi-Fi on and off.":
            "Rejoindre des réseaux et connecter des appareils depuis le popover. Cette fonction est expérimentale et peut ne pas toujours marcher. Désactivée, le popover liste quand même les réseaux et appareils et peut allumer ou éteindre le Wi-Fi.",
        "Show more details": "Afficher plus de détails",
        "Adds a second line to rows, like CPU's user and system split, free disk space and network speeds.":
            "Ajoute une deuxième ligne aux rangées : répartition utilisateur/système du CPU, espace disque libre, débits réseau…",
        "Show profiles at the top": "Afficher les profils en haut", "Rows": "Rangées",
        "Choose what the popover lists, and drag to set their order. Hiding a row doesn't change the menu bar mark.":
            "Choisissez ce que liste le popover et faites glisser pour changer l'ordre. Masquer une rangée ne change pas l'icône de la barre des menus.",
        "Restore Default Order": "Rétablir l'ordre par défaut",
        "Your menu bar, in one icon.": "Votre barre des menus, en une seule icône.", "Version %@": "Version %@",
        "No analytics, no tracking, no network requests": "Aucune analyse, aucun pistage, aucune requête réseau",
        "Everything is read on your Mac through Apple's APIs": "Tout est lu sur votre Mac via les API d'Apple",
        "Only the metrics you can see are sampled": "Seules les mesures visibles sont relevées",
        "Every feature included, free": "Toutes les fonctions incluses, gratuitement",
        "Preview of the mark: now, at a low level, and at a high level": "Aperçu de l'icône : maintenant, à un niveau bas et à un niveau haut",
        "Make it yours": "Personnalisez-la", "Color": "Couleur", "Ring style": "Style d'anneau", "Thickness": "Épaisseur",
        "Icon size": "Taille de l'icône", "Reset to Default Mark": "Rétablir l'icône par défaut",
        "A profile saves what the ring, center and dots show, and the mark's colors. Switch between them from the top of the popover.":
            "Un profil enregistre ce qu'affichent l'anneau, le centre et les points, ainsi que les couleurs de l'icône. Passez de l'un à l'autre en haut du popover.",
        "No profiles yet.": "Aucun profil pour l'instant.", "Add the three starters": "Ajouter les trois profils de départ",
        "Save what's showing now": "Enregistrer l'affichage actuel", "Name": "Nom", "Save": "Enregistrer",
        "Active": "Actif", "Use": "Utiliser", "Delete profile": "Supprimer le profil"
    ]
}
