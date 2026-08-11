FROM docker/sandbox-templates:shell-docker

USER root

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential ca-certificates curl git jq sudo unzip xz-utils \
    fonts-freefont-ttf fonts-ipafont-gothic fonts-liberation \
    fonts-noto-color-emoji fonts-tlwg-loma-otf fonts-unifont \
    fonts-wqy-zenhei libasound2t64 libatk-bridge2.0-0t64 \
    libatk1.0-0t64 libatspi2.0-0t64 libavcodec62 libcairo-gobject2 \
    libcairo2 libcups2t64 libdbus-1-3 libdrm2 libfontconfig1 \
    libfreetype6 libgbm1 libgdk-pixbuf-2.0-0 libglib2.0-0t64 \
    libgtk-3-0t64 libnspr4 libnss3 libpango-1.0-0 \
    libpangocairo-1.0-0 libx11-6 libx11-xcb1 libxcb-shm0 libxcb1 \
    libxcomposite1 libxcursor1 libxdamage1 libxext6 libxfixes3 \
    libxi6 libxkbcommon0 libxrandr2 libxrender1 xfonts-cyrillic \
    xfonts-scalable xvfb \
  && printf 'agent ALL=(ALL) NOPASSWD:ALL\n' > /etc/sudoers.d/agent \
  && chmod 0440 /etc/sudoers.d/agent \
  && touch /etc/herdr-playwright-deps-v1 \
  && rm -rf /var/lib/apt/lists/*
