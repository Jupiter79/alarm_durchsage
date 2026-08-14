# 🚒 Feuerwehr Alarm Durchsage Server

Willkommen beim Alarm Durchsage Server! Dieses Dokument erklärt in ganz einfachen Worten, was dieses System macht, wie es dir und deiner Feuerwehr im Einsatzfall hilft und wie man es bedient.

<img width="1339" height="702" alt="image" src="https://github.com/user-attachments/assets/63941f2a-043c-4ad1-9797-6b7efd7d1730" />

---

## 👨‍🔧 Instandhaltung & Kontakt

Ich (Sergio Huainigg von der Feuerwehr Spittal/Drau) entwickle und betreue das System. Falls es Probleme, Vorschläge oder Fragen gibt, bitte per E-Mail an mich wenden: **kamerafotos32@gmail.com**. Alternativ können neue Features oder Probleme jederzeit mittels eines Issues auf der GitHub-Seite eröffnet werden.

---

## ℹ️ Worum geht es?

Stell dir vor, der Peeper geht und es gibt einen Einsatz. Anstatt dass die ankommenden Kameraden erst auf einen kleinen Pager oder einen Einsatzmonitor an der Wand schauen müssen, um zu wissen, worum es überhaupt geht, übernimmt dieses System die Informationsweitergabe: **Es spricht zu euch!**

Das Programm läuft als "unsichtbarer" Helfer im Hintergrund und lauscht vollautomatisch auf Alarme der Leitstelle (Leitstellenverbund Kärnten / LAWZ). Wenn ein echter Einsatz für deine Feuerwehr eingeht, passiert sofort Folgendes:

1. **Aufmerksamkeit (Der Gong):** Es ertönt ein lauter Alarm-Gong im Feuerwehrhaus, damit jeder weiß: Jetzt geht's los.
2. **Information (Die Sprachausgabe):** Eine sehr deutliche und natürliche Computerstimme liest sofort alle wichtigen Einsatzdaten vor (z. B. "Brandeinsatz! Hauptstraße 5! Information: Rauchentwicklung im Gebäude!").
3. **Wiederholungen für Nachzügler:** Weil bei einer Alarmierung nicht alle gleichzeitig im Rüsthaus eintreffen, wiederholt das System die komplette Durchsage nach ein paar Minuten automatisch (z.B. nach 1,5 und nach 3 Minuten). So sind auch die Nachzügler sofort informiert, während sie sich in der Umkleide umziehen.

**Der große Vorteil:** Zeitersparnis und sofortige, unüberhörbare Information für alle anwesenden Einsatzkräfte, ohne dass jemand aktiv etwas ablesen muss.

*(Hinweis: Bei selbst angelegten Einsätzen über Kommando-Login erfolgt keine automatische Durchsage).*

---

## 👥 Bedienung: Admin- und User-Ansicht

Das System bietet eine einfache Webseite (Web-Interface) zur Steuerung. Es gibt zwei Ansichten:

### 🔴 Admin-Ansicht
In der passwortgeschützten Admin-Ansicht hast du die volle Kontrolle. Hier konfigurierst du das System, passt Wartezeiten und die Stimme an, verwaltest WLAN-Netzwerke, lädst neue Gongs hoch und machst Systemupdates.

### 🔵 User-Ansicht (Eingeschränkter Modus)
Diese Ansicht ist für den alltäglichen Gebrauch gedacht – ideal für einen Touch-PC direkt neben dem Funk in der Funkfixstation.
Über einen speziellen Direkt-Link gelangt man sofort in diesen Modus, ganz ohne Passwort. Hier kann man lediglich manuell Durchsagen starten z.B. für Übungen und die Historie einsehen. Alle kritischen Einstellungen sind unsichtbar und gesperrt. So kann nichts versehentlich verstellt werden!

---

## 🔌 Voraussetzungen & Hardware

Um das System zuverlässig zu betreiben, wird nur wenig Ausstattung benötigt:

* **Hardware:** Ein kleiner Rechner, am besten ein **Raspberry Pi (Linux)** oder ein günstiger **Mini-PC mit Windows**. Das System läuft auf beiden Plattformen problemlos.
* **Audio-Ausgabe (Lautsprecher):** Du bist hier völlig flexibel, wie der Ton im Haus wiedergegeben wird:
  * **Große Hausanlage:** Über ein Adapterkabel (meist AUX auf Cinch) kannst du den Rechner direkt an die große Lautsprecher- oder ELA-Anlage des Feuerwehrhauses anschließen.
  * **PC-Lautsprecher:** Keine große Anlage vorhanden? Schließe einfach normale PC-Lautsprecher an und platziere sie gut hörbar in der Umkleide.
  * **Bluetooth-Lautsprecher:** Die kabellose und modernste Variante! Verbinde deinen Raspberry Pi oder PC einfach per Bluetooth mit einem handelsüblichen Bluetooth-Lautsprecher (z.B. JBL Box, Soundbar). Das erspart lästiges Kabelverlegen und funktioniert hervorragend!
* **Netzwerk:** Das System unterstützt sowohl **LAN (Kabel)** als auch **WLAN (Drahtlos)**. Für maximale Ausfallsicherheit im Feuerwehrhaus wird ein LAN-Kabel empfohlen, WLAN funktioniert aber ebenso einwandfrei und lässt sich direkt über das Web-Interface einrichten.
* **FWEI Zugang:** Um die Einsatzdaten der Leitstelle empfangen zu können, wird ein **Mannschafts- oder Kommando-Login** der FWEI (FeuerwehrEinsatzInfo) benötigt. **ZWINGEND mit Benutzername und Passwort.** Login-Token werden nicht unterstützt.

---

## 🚀 Installation

Es gibt 3 verschiedene Wege, den Alarm Durchsage Server zu installieren, je nachdem, welche Hardware du nutzt:

### 1. Fertiges Image (DietPi OS - 64bit)

Die absolut einfachste Variante für den Raspberry Pi. Befolge einfach diese simplen Schritte, damit es garantiert klappt:

1. **Pi Imager laden:** Lade dir das offizielle Programm [Raspberry Pi Imager](https://www.raspberrypi.com/software/) herunter und installiere es auf deinem Computer.
2. **SD-Karte flashen:** Starte den Pi Imager. Wähle das Betriebssystem aus, wähle deine eingesteckte SD-Karte und klicke auf "Schreiben", um das System auf die Karte zu flashen.
3. **Dateien kopieren:** Wenn der Imager fertig ist, öffnest du die SD-Karte an deinem PC. Lade dir hier aus dem Projekt den Ordner `install_files` herunter und kopiere **beide Dateien** daraus direkt auf das Hauptverzeichnis deiner SD-Karte. **WICHTIG:** Wenn du gefragt wirst, ob Dateien ersetzt werden sollen, musst du das unbedingt mit **Ja (Überschreiben)** bestätigen!
4. **LAN-Kabel anschließen (ZWINGEND):** Stecke die fertige SD-Karte in deinen Raspberry Pi. Bevor du ihm Strom gibst, **musst** du ihn zwingend per LAN-Kabel an dein Netzwerk anschließen. Über WLAN wird diese erste Installation fehlschlagen!
5. **Einschalten & Warten:** Schließe den Strom an. Der Raspberry Pi installiert nun alles komplett vollautomatisch im Hintergrund. Je nach deiner Internetverbindung dauert das ca. **20 bis 30 Minuten**. Bitte lass den Pi in dieser Zeit einfach in Ruhe arbeiten und trenne nicht den Strom.
6. **Fertig:** Danach ist dein System einsatzbereit! Du kannst nun von jedem anderen Gerät über deinen normalen Webbrowser auf das Web-GUI zugreifen. Die Adresse lautet meistens `http://alarmdurchsage.local:8122`.

**🔊 Wichtiger Hinweis zur Audioausgabe:** 
Das System erkennt automatisch alle verfügbaren Audioanschlüsse:
* **Klassisch (AUX/Kopfhörer):** Einfach das AUX-Kabel einstecken.
* **Bluetooth:** Verbinde den Pi über das Betriebssystem mit dem Lautsprecher. Das System erkennt den Bluetooth-Lautsprecher sofort als wählbares Ausgabegerät auf der Webseite!
* **HDMI & USB:** Das Audiosignal kann auch über HDMI oder eine angesteckte USB-Soundkarte ausgegeben werden. Im Einstellungs-Menü der Webseite kannst du das gewünschte Gerät jederzeit auswählen.

### 2. Manuelle Installation auf Linux / Pi (via Docker)

Wenn du bereits ein Linux (z.B. Ubuntu oder Raspberry Pi OS) am Laufen hast, empfehlen wir die Nutzung von **Docker**. Das Programm wird dabei isoliert und sicher ausgeführt.

1. Lade dir das Installationsskript herunter: [👉 install_linux.sh herunterladen](https://raw.githubusercontent.com/Jupiter79/alarm_durchsage/main/install_linux.sh)  
   *(Oder per Terminal: `curl -O https://raw.githubusercontent.com/Jupiter79/alarm_durchsage/main/install_linux.sh`)*
2. Führe das Skript im Terminal aus: `bash install_linux.sh`  
   *(Für inkludierte WLAN-Verwaltung: `bash install_linux.sh --install-networkmanager`)*
3. Das Skript lädt den Code, baut den Container und richtet einen **Autostart** ein. Bei einem Neustart fährt das System ganz von alleine wieder hoch.

### 3. Manuelle Installation auf Windows

Wenn du lieber einen klassischen Windows Mini-PC im Feuerwehrhaus stehen hast:

1. Lade dir die Datei herunter: [👉 install_windows.bat herunterladen](https://github.com/Jupiter79/alarm_durchsage/blob/main/install_windows.bat)  
2. Mache einen Doppelklick auf die Datei `install_windows.bat`.
3. Das Skript erledigt alles: Es installiert Python, alle Hilfsprogramme und erstellt eine Verknüpfung im Windows-Autostart. Das System läuft danach automatisch unsichtbar im Hintergrund.

---

## ⚙️ Intelligente Textübersetzung

Die Computerstimme liest genau das vor, was sie bekommt. Da die Leitstelle oft mit Abkürzungen arbeitet (z.B. "T VU" oder "BMA"), besitzt das System ein anpassbares Wörterbuch. 
Du kannst auf der Webseite eintragen, dass "T VU" als "Technischer Einsatz, Verkehrsunfall!" und "verm." als "vermutlich" vorgelesen werden soll. So wird aus einem kryptischen Einsatztext eine saubere, verständliche Durchsage.

---

## 🔗 Webhook & Wake on LAN (Smart Home & Einsatz-Monitore)

Das System kann bei einem eingehenden Alarm externe Geräte ansteuern:

* **Webhook URL:** Sobald ein Alarm eingeht, wird eine von dir festgelegte URL aufgerufen. Damit lässt sich z.B. über ein Smart-Home-System (Home Assistant, Loxone) im Feuerwehrhaus automatisch das Licht einschalten oder das Rolltor öffnen.
* **Wake on LAN (WoL):** Trage die MAC-Adresse (z.B. `AA:BB:CC:DD:EE:FF`) eines Computers ein (z.B. dem Einsatz-Monitor an der Wand). Sobald ein Alarm eintrifft, sendet das System ein Aufweck-Signal ("Magic Packet") an diesen PC, wodurch er automatisch hochfährt. Interessant für den PC in der Funkfixstation oder Einsatzmonitore.

---

## 💻 Bedienung & Zugriff (Das Web-Interface)

Du musst kein Netzwerkingenieur sein, um das System zu bedienen!

1. Öffne auf einem beliebigen Gerät im Feuerwehr-Netzwerk den Internetbrowser.
2. Gib folgende Adresse ein: **http://alarmdurchsage.local:8122** (bzw. den gesetzten Hostname bzw. die IP-Adresse)
3. Das Standard-Passwort für den ersten Login lautet: **`122`**

**Funktionen im Überblick:**
* **Manuelle Durchsagen:** Tippe Texte ein und lass sie vorlesen oder spiele einfach nur einen Gong ab.
* **Test-Einsatz:** Löse einen vollständigen Probealarm aus, um Lautstärke und Verständlichkeit in Ruhe zu testen.
* **Historie:** Verfolge alle vergangenen Einsätze und Durchsagen nach.
* **Einstellungen:** Konfiguriere Wiederholungsintervalle, Lautstärke, Stimme und das Abkürzungs-Wörterbuch bequem über den Browser.
