# 🚒 Feuerwehr Alarmdurchsage-System

Willkommen beim Alarmdurchsage-System! Dieses Dokument erklärt in einfachen Worten, was dieses System macht, wie es funktioniert und wie man es bedient.

---

## 👨‍🔧 Instandhaltung & Kontakt

Auszufüllen

---

## ℹ️ Worum geht es?

Dieses System sorgt für die automatische Alarmdurchsage im Feuerwehrhaus. 
Wenn ein echter Einsatz über die Leitstelle (Leitstellenverbund Kärnten / LAWZ) hereinkommt, reagiert das System sofort und völlig automatisch:

1. **Aufmerksamkeit:** Es spielt sofort einen lauten **Gong** über die Lautsprecheranlage ab.
2. **Information:** Es liest mit einer klaren, natürlichen Computerstimme die **Einsatzdaten** vor (z. B. Einsatzart, Adresse, Zusatzinformationen).
3. **Wiederholung:** Die Durchsage wird nach vorgegebenen Zeiten automatisch wiederholt (z.B. nach 1,5 und 3 Minuten). Das ist extrem hilfreich für alle Kameradinnen und Kameraden, die nicht sofort bei der Alarmierung im Rüsthaus sind, sondern erst nach und nach einrücken.

---

## 🔌 Voraussetzungen & Hardware

Um das System zuverlässig zu betreiben, wird folgende Grundausstattung benötigt:
* **Hardware:** Ein kleiner Rechner, am besten ein **Raspberry Pi** oder ein kompakter Mini-PC.
* **Audio-Verbindung:** Ein Adapterkabel (meist **AUX auf Cinch**), um den Audioausgang (Kopfhöreranschluss) des Raspberry Pi/PCs direkt mit dem Verstärker bzw. der Lautsprecheranlage des Feuerwehrhauses zu verbinden.
* **Netzwerk:** Für eine ausfallsichere und schnelle Verbindung zur Leitstelle sollte das Gerät im Idealfall immer über ein festes **LAN-Kabel** mit dem Netzwerk/Router verbunden sein. WLAN funktioniert auch, ist aber fehleranfälliger.

---

## ⚙️ Wie funktioniert das System?

Das Programm läuft als unsichtbarer Dienst dauerhaft im Hintergrund auf einem Rechner (z. B. einem Raspberry Pi oder Mini-PC) im Netzwerk des Feuerwehrhauses. 

* **Dauerhafte Verbindung:** Das System ist rund um die Uhr sicher mit dem Server der Leitstelle verbunden und lauscht auf Alarme für die eigene Feuerwehr.
* **Intelligente Übersetzung:** Sobald ein Alarm eingeht, bereitet das System den rohen Leitstellentext auf. Abkürzungen (z.B. "T VU" oder "BMA") werden in verständliche Sätze (wie "Technischer Einsatz, Verkehrsunfall" oder "Brandmeldeanlage") übersetzt.
* **Sprachsynthese:** Der übersetzte Text wird in Echtzeit in eine hochwertige Sprachausgabe (TTS) umgewandelt und an die Hausanlage geschickt.

---

## 💻 Bedienung & Zugriff (Das Web-Interface)

Das System verfügt über eine grafische Oberfläche (Webseite). Du musst absolut kein Computer-Experte sein, um das System zu bedienen oder Einstellungen zu ändern.

### 🌐 So greifst du auf das System zu:
1. Öffne auf einem beliebigen Gerät (PC, Tablet oder Smartphone), das mit dem **Feuerwehr-Netzwerk (WLAN/LAN)** verbunden ist, einen Internetbrowser (z.B. Chrome, Safari, Edge).
2. Gib oben in die Adresszeile folgende Adresse ein:
   👉 **http://alarmdurchsage.local**
   *(Sollte das nicht klappen, kann alternativ die direkte IP-Adresse des Geräts im Netzwerk eingegeben werden).*
3. Du landest auf der Anmeldeseite. Das Passwort lautet standardmäßig:
   👉 **`122`**
   *(Das System speichert die Anmeldung, sodass du dich nach einem Neustart nicht immer wieder neu einloggen musst).*

### 🛠️ Was kannst du auf der Webseite machen?
Sobald du eingeloggt bist, hast du Zugriff auf folgende Funktionen:

* **Manuelle Durchsagen (Info-Gong):** Du kannst jederzeit eigene Texte eintippen und sie manuell im Feuerwehrhaus vorlesen lassen.
* **Test-Einsatz simulieren:** Mit einem Klick kannst du einen kompletten Test-Alarm (inklusive Gong und Wiederholungen) auslösen, um zu prüfen, ob die Lautsprecher und die Sprachausgabe funktionieren.
* **Historie (Einsatz-Log):** Du kannst genau nachverfolgen, an welchem Datum und zu welcher Uhrzeit welche Alarme oder Durchsagen verarbeitet wurden.
* **Einstellungen (Config):** Hier können Wartezeiten, die Lautstärke der Stimme und die Zeiten für die Alarm-Wiederholungen konfiguriert werden. Außerdem kannst du hier Wörterbücher pflegen, damit das System neue Leitstellen-Abkürzungen richtig vorliest.
* **Gongs verwalten:** Hier hast du die Möglichkeit, neue Gong-Töne (als .mp3 Datei) hochzuladen und auszuwählen.

---
*Erstellt für den reibungslosen Ablauf im Einsatzfall.*
