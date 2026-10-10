FROM jlesage/baseimage-gui:alpine-3.24-v4.14.0

ARG PROJECT_URL="https://github.com/maaaaz/bibsnoop"
ARG DOCKER_IMAGE_VERSION=1.1

ARG BROWSER_TO_USE_NAME="LibreWolf"
ARG BROWSER_TO_USE="librewolf"

WORKDIR /tmp

LABEL \
    org.opencontainers.image.title="bibsnoop-${BROWSER_TO_USE}" \
    org.opencontainers.image.description="${BROWSER_TO_USE_NAME} browser with mitmproxy" \
    org.opencontainers.image.version="${DOCKER_IMAGE_VERSION:-unknown}" \
    org.opencontainers.image.documentation="${PROJECT_URL}" \
    org.opencontainers.image.source="${PROJECT_URL}" \
    org.opencontainers.image.url="${PROJECT_URL}"

###############################################################################
# Install packages
###############################################################################
RUN ARCH="$(apk --print-arch)" && \
    if [ "$ARCH" = "x86" ] || [ "$ARCH" = "x86_64" ]; then \
        libva_intel_driver="libva-intel-driver"; \
    fi && \
    add-pkg "$BROWSER_TO_USE" \
            adwaita-icon-theme hicolor-icon-theme \
            mesa-dri-gallium mesa-va-gallium \
            $libva_intel_driver \
            libpulse \
            libnotify \
            font-dejavu \
            xdotool \
            mitmproxy \
            nss-tools \
            ca-certificates \
            socat \
            tor \
            gost \
            && \
    find /usr/share/icons/Adwaita /usr/share/icons/hicolor -type d -mindepth 1 -maxdepth 1 -not -name 16x16 -not -name scalable -exec rm -rf {} ';' && \
    true

###############################################################################
# Add application files
###############################################################################

COPY rootfs/ /
RUN chmod +x /startapp.sh

###############################################################################
# Generate application icon
###############################################################################

COPY assets/icon.png /tmp/icon.png
RUN install_app_icon.sh "/tmp/icon.png"

###############################################################################
# Container environment
###############################################################################

RUN BROWSER_VERSION="$("$BROWSER_TO_USE" -v 2>/dev/null | awk '{print $NF}')" && \
    set-cont-env APP_NAME "$BROWSER_TO_USE_NAME" && \
    set-cont-env APP_VERSION "$BROWSER_VERSION" && \
    set-cont-env DOCKER_IMAGE_VERSION "$DOCKER_IMAGE_VERSION" && \
    true

###############################################################################
# Environment variables
###############################################################################

ENV \
    BROWSER_TO_USE="${BROWSER_TO_USE}" \
    BROWSER_CUSTOM_ARGS="" \
    USE_TOR=0


###############################################################################
# Ports
#
# 5800 = jlesage web interface
# 8081 = mitmweb interface
#
# 8080 stays internal to the container.
###############################################################################

EXPOSE 5800
EXPOSE 8081
