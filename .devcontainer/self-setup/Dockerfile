FROM ubuntu:22.04

# Cài đặt các gói cần thiết
RUN apt-get update && apt-get install --yes \
    curl \
    gpg \
    lsb-release \
    jq \
    vim \
    sudo \
    wget \
    unzip \
    git \
    software-properties-common \
 && rm -rf /var/lib/apt/lists/*

# Tạo non-root user
RUN useradd -m -s /bin/bash vaulttrainee && \
    echo "vaulttrainee ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
