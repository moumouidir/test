# Stage 1: Build Stage
FROM alpine:3.20 AS builder

WORKDIR /tmp

# Variable de version pour faciliter les mises à jour
ARG DOLIBARR_VERSION=19.0.0

# Téléchargement de la version stable officielle
# ADD vérifie automatiquement le checksum si on le configure, mais ici on prend la release officielle
ADD https://github.com/Dolibarr/dolibarr/archive/refs/tags/${DOLIBARR_VERSION}.tar.gz .

# Extraction et nettoyage
RUN tar -xzf ${DOLIBARR_VERSION}.tar.gz && \
    # On renomme le dossier extrait pour simplifier la copie
    mv dolibarr-${DOLIBARR_VERSION}/htdocs /htdocs && \
    mv dolibarr-${DOLIBARR_VERSION}/scripts /scripts && \
    # On supprime l'archive et le dossier source pour être propre
    rm -rf dolibarr-${DOLIBARR_VERSION} ${DOLIBARR_VERSION}.tar.gz

# Stage 2: Image Finale Sécurisée (Runtime)
FROM php:8.2-apache-bookworm

# Installation des dépendances système requises par Dolibarr
# On nettoie le cache apt immédiatement pour réduire la surface d'attaque et la taille
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpng-dev \
    libjpeg-dev \
    libldap2-dev \
    libxml2-dev \
    libzip-dev \
    libicu-dev \
    mariadb-client \
    unzip \
    && docker-php-ext-configure gd --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        calendar \
        gd \
        intl \
        mysqli \
        pdo_mysql \
        soap \
        zip \
        xml \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*


# --- RECUPERATION DEPUIS LE STAGE BUILDER ---

# On copie uniquement le résultat propre du stage précédent
COPY --from=builder --chown=www-data:www-data /htdocs /var/www/html
COPY --from=builder --chown=www-data:www-data /scripts /var/www/scripts

# Création des dossiers nécessaires et verrouillage des permissions
RUN mkdir -p /var/www/documents && \
    chown -R www-data:www-data /var/www/documents && \
    chown -R www-data:www-data /var/www/html/conf && \
    # Sécurité : on retire les droits d'écriture sur le code source pour le serveur web
    # Seul root peut modifier le code, www-data peut seulement le lire (sauf conf et documents)
    chmod -R 550 /var/www/html && \
    chmod -R 750 /var/www/html/conf && \
    chmod -R 750 /var/www/documents

# VOLUME pour la persistance des données critiques
VOLUME ["/var/www/documents", "/var/www/html/conf"]

EXPOSE 80


CMD ["apache2-foreground"]