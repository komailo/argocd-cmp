FROM alpine:3.21.0 AS build

ARG AVP_VERSION=1.16.1
ARG HELM_VERSION=3.16.2

RUN apk add --update --no-cache \
    tar

ADD  https://github.com/argoproj-labs/argocd-vault-plugin/releases/download/v${AVP_VERSION}/argocd-vault-plugin_${AVP_VERSION}_linux_amd64 \
    /argocd-vault-plugin

ADD https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz \
    /helm-linux-amd64.tar.gz

RUN mkdir /helm \
    && cd /helm \
    && tar -xvf /helm-linux-amd64.tar.gz \
    && chmod +x /helm/linux-amd64/helm /argocd-vault-plugin

FROM alpine:3.21.0

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
COPY --from=build /helm/linux-amd64/helm /usr/local/bin/helm

COPY --chmod=755 --chown=root:root \
    root/ \
    /
