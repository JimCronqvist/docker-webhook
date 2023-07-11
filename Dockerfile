FROM golang:alpine AS builder
ENV WEBHOOK_VERSION 2.8.1

WORKDIR /go/src/github.com/adnanh/webhook
RUN apk add --update -t build-deps curl libc-dev gcc libgcc
RUN curl -L --silent -o webhook.tar.gz https://github.com/adnanh/webhook/archive/${WEBHOOK_VERSION}.tar.gz \
    && tar -xzf webhook.tar.gz --strip 1
RUN go get -d -v
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o /usr/local/bin/webhook


FROM ubuntu:latest
COPY --from=builder /usr/local/bin/webhook /usr/local/bin/webhook
RUN apt-get update && apt-get install -y curl jq tini git gnupg
EXPOSE 9000
ENTRYPOINT ["/usr/local/bin/webhook"]
CMD ["-hooks", "/etc/webhook/hooks.yaml", "-verbose", "-template", "-hotreload"]

# Install some additional devops tools:

# kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && curl -LO "https://dl.k8s.io/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256" \
    && echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check \
    && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
    && rm kubectl \
    && kubectl version --client --short

# eksctl
RUN curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp \
    && mv /tmp/eksctl /usr/local/bin \
    && eksctl version

# kustomize
RUN curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | bash \
    && install -o root -g root -m 0755 kustomize /usr/local/bin/kustomize \
    && rm kustomize \
    && kustomize version

# argocd
RUN curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64 \
    && install -m 555 argocd-linux-amd64 /usr/local/bin/argocd \
    && rm argocd-linux-amd64 \
    && argocd version --client --short

# helm
RUN curl https://baltocdn.com/helm/signing.asc | apt-key add - \
    && apt install apt-transport-https --yes \
    && echo "deb https://baltocdn.com/helm/stable/debian/ all main" | tee /etc/apt/sources.list.d/helm-stable-debian.list \
    && apt update \
    && apt install helm -y \
    && rm -rf /var/lib/apt/lists/*


