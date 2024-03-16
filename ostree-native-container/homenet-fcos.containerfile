
FROM quay.io/fedora/fedora-coreos:stable as homenet-fcos-base
RUN date >> /etc/homenet-fcos-build-at.txt
ADD ./rpm-repos/tailscale-stable.repo /etc/yum.repos.d/
RUN rpm-ostree install tailscale && ostree container commit
# Add bits we'd like in our base images /etc or /usr folders (remember ostree-native containers don't suppor other paths like /var)
COPY overlay-base/ /
RUN systemctl enable tailscale-configure.service && systemctl enable tailscaled.service && systemctl enable update.service && ostree container commit


# Build a docker specific image
FROM homenet-fcos-base as homenet-fcos-docker
ADD ./rpm-repos/docker.repo /etc/yum.repos.d/
RUN rpm-ostree install docker-compose-plugin && ostree container commit
RUN systemctl enable docker.service && ostree container commit


# Build a k3s specific image
FROM homenet-fcos-base as homenet-fcos-k3s
ENV INSTALL_K3S_BIN_DIR=/usr/bin
ENV K3S_KUBECONFIG_MODE="644"
ENV INSTALL_K3S_SKIP_ENABLE="true"
COPY overlay-k3s/ /
RUN curl -sfL https://get.k3s.io | sh - && ostree container commit
RUN systemctl enable k3s.service && ostree container commit
# Bring k3s specific config
