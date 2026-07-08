FROM rocker/verse:4.4.2

LABEL maintainer="Ghana R Conference 2026 Workshop"
LABEL project="AI-Driven Predictive Analytics for Business Growth Using R"

WORKDIR /home/rstudio/workshop

RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libgit2-dev \
    libfontconfig1-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libfreetype6-dev \
    libpng-dev \
    libtiff5-dev \
    libjpeg-dev \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

COPY scripts/00_setup.R scripts/00_setup.R
RUN Rscript scripts/00_setup.R

COPY . .

EXPOSE 8787

CMD ["/init"]
