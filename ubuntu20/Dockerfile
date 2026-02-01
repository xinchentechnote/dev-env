FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Shanghai

RUN echo 'Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/99force-ipv4

RUN sed -i 's@http://ports.ubuntu.com@http://mirrors.tuna.tsinghua.edu.cn@g' /etc/apt/sources.list

RUN apt-get update && apt-get install -y ca-certificates

RUN apt-get update && apt-get install -y \
    build-essential \
    clang \
    lldb \
    clang-tidy \
    clang-format \
    cmake \
    ninja-build \
    git \
    pkg-config \
    curl \
    wget \
    vim \
    ca-certificates \
    tzdata \
    openssh-server \
    net-tools \
    iputils-ping \
    zsh \
    sudo \
    && rm -rf /var/lib/apt/lists/*

ENV CC=clang
ENV CXX=clang++

RUN mkdir /var/run/sshd

ARG USERNAME=dev
ARG PASSWORD=dev
ARG UID=1000
ARG GID=1000

RUN groupadd -g ${GID} ${USERNAME} && \
    useradd -m -u ${UID} -g ${GID} -s /bin/bash ${USERNAME} && \
    echo "${USERNAME}:${PASSWORD}" | chpasswd && \
    usermod -aG sudo ${USERNAME}

RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

WORKDIR /workspace

EXPOSE 22

CMD ["/usr/sbin/sshd", "-D"]
