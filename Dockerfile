FROM alpine:3.23.3@sha256:25109184c71bdad752c8312a8623239686a9a2071e8825f20acb8f2198c3f659 AS build

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

FROM alpine:3.23.3@sha256:25109184c71bdad752c8312a8623239686a9a2071e8825f20acb8f2198c3f659

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
