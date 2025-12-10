# FBC payload /Dockerfile

FROM registry.access.redhat.com/ubi9/ubi-minimal@sha256:6fc28bcb6776e387d7a35a2056d9d2b985dc4e26031e98a2bd35a7137cd6fd71

WORKDIR /tmp
USER root

# Download jq (not available in default UBI9 minimal repos)
ADD https://github.com/jqlang/jq/releases/latest/download/jq-linux-amd64 .
ADD https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 .

# Install required tools and setup jq
# Note: bash, curl, gawk, sed are already available in UBI9 minimal base image
RUN microdnf install -y \
    git \
    && microdnf clean all && \
    mv jq-linux-amd64 /usr/local/bin/jq && \
    chmod +x /usr/local/bin/jq && \
    mv yq_linux_amd64 /usr/local/bin/yq && \
    chmod +x /usr/local/bin/yq && \
    rm -f /tmp/*

# Create non-root user (UID 1000 following project patterns and GID 0 to allow group permissions for openshfits SCC)
RUN useradd -u 1000 -g 0 -m --home-dir /home/payloads -s /bin/bash payloads

# Set working directory
WORKDIR /workspace

# Copy scripts
COPY payload.yaml /workspace/payload.yaml

# Set PATH to include workspace
ENV PATH="/workspace:${PATH}"

# Switch to non-root user
USER payloads

# Default command
CMD ["/bin/bash", "-c", "yq . /workspace/payload.yaml"]
