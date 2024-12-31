FROM alpine:3

ARG AVP_VERSION=1.16.1
ARG HELM_VERSION=3.16.2

# wget https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz -O - | tar xz && mv linux-amd64/helm /custom-tools/helm && chmod +x /custom-tools/helm
# wget https://github.com/stedolan/jq/releases/download/jq-${JQ_VERSION}/jq-linux64 -O /custom-tools/jq && chmod +x /custom-tools/jq
# wget https://github.com/mikefarah/yq/releases/download/v{YQ_VERSION}/yq_linux_amd64 -O /custom-tools/yq && chmod +x /custom-tools/yq

# # wget https://github.com/argoproj-labs/argocd-vault-plugin/releases/download/v${AVP_VERSION}/argocd-vault-plugin_${AVP_VERSION}_linux_amd64 -O /custom-tools/argocd-vault-plugin && chmod +x /custom-tools/argocd-vault-plugin
# /custom-tools/argocd-vault-plugin version

RUN apk add --update --no-cache \
    bash \
    jq \
    libffi \
    libffi-dev \
    openssl \
    py-pip  \
    py3-cryptography \
    py3-jwt \
    py3-requests \
    python3 \
    yq

#RUN wget https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz -O - | tar xz && mv linux-amd64/helm /usr/local/bin/helm && chmod +x /custom-tools/helm /usr/local/bin

ADD  --chmod=755 --chown=root:root \
    https://github.com/argoproj-labs/argocd-vault-plugin/releases/download/v${AVP_VERSION}/argocd-vault-plugin_${AVP_VERSION}_linux_amd64 \
    /usr/local/bin/argocd-vault-plugin

ADD --chmod=755 --chown=root:root \
    https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz \
    /usr/local/bin/helm

COPY --chmod=755 --chown=root:root \
    root/ \
    /
