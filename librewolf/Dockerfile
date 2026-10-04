FROM jlesage/baseimage-gui:alpine-3.24-v4.14.0

ARG DOCKER_IMAGE_VERSION=

ARG BROWSER_TO_USE_NAME="LibreWolf"
ARG BROWSER_TO_USE="librewolf"

WORKDIR /tmp

LABEL \
    org.label-schema.name="bibsnoop-librewolf" \
    org.label-schema.description="LibreWolf browser with mitmproxy" \
    org.label-schema.version="${DOCKER_IMAGE_VERSION:-unknown}" \
    org.label-schema.vcs-url="https://librewolf.net/" \
    org.label-schema.schema-version="1.0"

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

RUN \
    APP_ICON_URL=https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/librewolf.png && \
    install_app_icon.sh "$APP_ICON_URL"


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
    LIBREWOLF_CUSTOM_ARGS=""


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
