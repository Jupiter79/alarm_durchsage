# Verwende ein offizielles, leichtes Python Image
FROM python:3.11-slim

# System-Abhängigkeiten installieren
# - ffmpeg: zwingend erforderlich für die Audioverarbeitung und TTS
# - alsa-utils, libasound2, libsdl2-*: für die Audio-Ausgabe (pygame)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    alsa-utils \
    libasound2 \
    libsdl2-mixer-2.0-0 \
    libsdl2-image-2.0-0 \
    libsdl2-ttf-2.0-0 \
    git \
    network-manager \
    docker.io \
    && rm -rf /var/lib/apt/lists/*

# Arbeitsverzeichnis im Container setzen
WORKDIR /app

# Requirements kopieren und installieren
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Den gesamten Projektcode in den Container kopieren
COPY . .

# Ordnerstruktur sicherstellen (falls leer und nicht von Git mitkopiert)
RUN mkdir -p gongs default_gongs static

# Port freigeben (der Standardport, den uvicorn in der config.json verwendet, z.B. 80 oder 5000)
# Wichtig: Im Docker-Umfeld solltest du in der config.json idealerweise "host": "0.0.0.0" eingestellt haben
EXPOSE 80

# Das Startskript ausführen
CMD ["python", "durchsage.py"]
