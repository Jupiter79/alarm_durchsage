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
* **Hardware & Betriebssystem:** Ein kleiner Rechner, am besten ein **Raspberry Pi (Linux/Raspberry Pi OS)** oder ein handelsüblicher **Mini-PC mit Windows**. Das gesamte System ist zu 100% plattformunabhängig und läuft nativ auf Linux und Windows.
* **Audio-Verbindung:** Ein Adapterkabel (meist **AUX auf Cinch**), um den Audioausgang (Kopfhöreranschluss) des Raspberry Pi/PCs direkt mit dem Verstärker bzw. der Lautsprecheranlage des Feuerwehrhauses zu verbinden.
* **Netzwerk (LAN & WLAN):** Das System unterstützt vollumfänglich sowohl **LAN (Kabel)** als auch **WLAN (Drahtlos)** für Windows und Linux. Direkt auf der Webseite findest du einen eigenen Tab "Internet", in dem du ganz bequem WLAN-Netzwerke in deiner Umgebung suchen, dich mit einem Passwort verbinden oder jederzeit zurück auf LAN wechseln kannst. Für eine ausfallsichere Verbindung im Feuerwehrhaus wird dennoch ein festes LAN-Kabel empfohlen.
---

## 🚀 Installation

Es gibt 3 verschiedene Wege, das Alarmdurchsage-System zu installieren, je nachdem, welche Hardware du nutzt:

### 1. Fertiges Image (DietPi OS (64bit))
Die absolut einfachste Variante für den Raspberry Pi. Befolge einfach diese simplen Schritte, damit es garantiert klappt:

1. **Pi Imager laden:** Lade dir das offizielle Programm [Raspberry Pi Imager](https://www.raspberrypi.com/software/) herunter und installiere es auf deinem Computer.
2. **SD-Karte flashen:** Starte den Pi Imager. Wähle das Betriebssystem aus, wähle deine eingesteckte SD-Karte und klicke auf "Schreiben", um das System auf die Karte zu flashen.
3. **Dateien kopieren:** Wenn der Imager fertig ist, öffnest du die SD-Karte an deinem PC. Lade dir hier aus dem Projekt den Ordner `install_files` herunter und kopiere **beide Dateien** daraus direkt auf das Hauptverzeichnis deiner SD-Karte. **WICHTIG:** Wenn du gefragt wirst, ob Dateien ersetzt werden sollen, musst du das unbedingt mit **Ja (Überschreiben)** bestätigen!
4. **LAN-Kabel anschließen (ZWINGEND):** Stecke die fertige SD-Karte in deinen Raspberry Pi. Bevor du ihm Strom gibst, **musst** du ihn zwingend per LAN-Kabel an dein Netzwerk anschließen. Über WLAN wird diese erste Installation fehlschlagen!
5. **Einschalten & Warten:** Schließe den Strom an. Der Raspberry Pi installiert nun alles komplett vollautomatisch im Hintergrund. Je nach deiner Internetverbindung dauert das ca. **20 bis 30 Minuten**. Bitte lass den Pi in dieser Zeit einfach in Ruhe arbeiten und trenne nicht den Strom.
6. **Fertig:** Danach ist dein System einsatzbereit! Du kannst nun von jedem anderen Gerät (z.B. deinem Handy oder einem anderen PC, das sich im gleichen Netzwerk befindet) über deinen normalen Webbrowser auf das Web-GUI zugreifen. Die Adresse lautet meistens `http://alarmdurchsage.local:8122` (oder du nutzt die IP-Adresse des Pis, die du in deinem Router findest).

### 2. Manuelle Installation auf Linux / Pi (via Docker)
Wenn du bereits ein Linux (z.B. Ubuntu oder Raspberry Pi OS) am Laufen hast, empfehlen wir die Nutzung von **Docker**. Das Programm wird dabei isoliert und sicher in einem Container ausgeführt.
1. Lade dir **nur** das Installationsskript auf dein Linux-Gerät herunter: [👉 install_linux.sh herunterladen](https://raw.githubusercontent.com/Jupiter79/alarm_durchsage/main/install_linux.sh)
   *(Oder lade es per Terminal herunter: `curl -O https://raw.githubusercontent.com/Jupiter79/alarm_durchsage/main/install_linux.sh`)*
2. Führe das Skript im Terminal aus: `bash install_linux.sh`
3. Das Skript erledigt den Rest: Es lädt den aktuellen Code herunter, baut den Docker-Container und trägt ihn **automatisch in den Autostart** ein. Wenn du den Rechner oder Pi neu startest, fährt das Alarm-System ganz von alleine wieder hoch.

### 3. Manuelle Installation auf Windows
Wenn du lieber einen klassischen Windows Mini-PC im Feuerwehrhaus stehen hast, kannst du das System "nativ" installieren:
1. Lade dir **nur** die Installationsdatei herunter: [👉 install_windows.bat herunterladen](https://raw.githubusercontent.com/Jupiter79/alarm_durchsage/main/install_windows.bat)
   *(Rechtsklick auf die Seite -> "Speichern unter..." wählen, falls sich nur der Text öffnet)*
2. Mache einen einfachen Doppelklick auf die heruntergeladene Datei `install_windows.bat`.
3. Das Skript übernimmt die ganze Arbeit für dich: Es lädt den Code herunter, installiert Python und alle nötigen Hilfsprogramme und erstellt eigenständig eine Verknüpfung im Windows-Autostart. Nach einem kurzen PC-Neustart läuft das System unsichtbar im Hintergrund mit.

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
   👉 **http://alarmdurchsage.local:8122**
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
