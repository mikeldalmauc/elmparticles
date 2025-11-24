# Usa Debian como imagen base
FROM debian:latest

# Instala dependencias
RUN apt-get update && apt-get install -y --no-install-recommends \
    webp \
    curl \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

# Instala elm y elm-live
RUN npm install -g elm elm-live gulp-cli

# Crea un directorio de trabajo
WORKDIR /app

# Copia package.json antes del código para aprovechar la caché de Docker
COPY package.json package-lock.json ./

# Instala todas las dependencias de Node.js dentro del volumen mapeado
RUN test -f package.json && npm install || echo "No package.json found, skipping npm install"

# Expone el puerto en el que correrá elm-live
EXPOSE 8000

# Comando por defecto para iniciar elm-live en modo watch
CMD ["elm-live", "src/Main.elm", "--open",  "--pushstate", "--start-page=index.html", "--host=0.0.0.0", "--", "--output=main.min.js" ]
#CMD ["sh", "-c", "tail -f /dev/null"]