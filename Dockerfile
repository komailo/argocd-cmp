FROM alpine:3.24.3@sha256:1b7232cda4ca3dc20b5d1247bdc9bfb631f2661d15d323bdd6fccc035ed1a9e7 AS build

ARG AVP_VERSION=1.16.1
ARG HELM_VERSION=3.16.2
ARG TARGETARCH

RUN apk add --update --no-cache \
    tar

ADD  https://github.com/argoproj-labs/argocd-vault-plugin/releases/download/v${AVP_VERSION}/argocd-vault-plugin_${AVP_VERSION}_linux_${TARGETARCH} \
    /argocd-vault-plugin

ADD https://get.helm.sh/helm-v${HELM_VERSION}-linux-${TARGETARCH}.tar.gz \
    /helm-linux.tar.gz

RUN mkdir /helm \
    && cd /helm \
    && tar -xvf /helm-linux.tar.gz \
    && chmod +x /helm/linux-${TARGETARCH}/helm /argocd-vault-plugin

FROM alpine:3.24.3@sha256:1b7232cda4ca3dc20b5d1247bdc9bfb631f2661d15d323bdd6fccc035ed1a9e7

ARG TARGETARCH

RUN apk add --update --no-cache \
    bash \
    jq \
    libffi \
    libffi-dev \
    openssl \
    py-pip  \
    py3-cryptography \
    py3-dnspython \
    py3-jwt \
    py3-requests \
    python3 \
    yq

COPY --from=build /argocd-vault-plugin /usr/local/bin/argocd-vault-plugin
COPY --from=build /helm/linux-${TARGETARCH}/helm /usr/local/bin/helm

COPY --chmod=755 --chown=root:root \
    root/ \
    /
