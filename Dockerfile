FROM ubuntu:24.04

RUN apt update && apt install -y \
    openssh-server \
    sudo \
    curl \
    wget \
    ca-certificates \
    git \
    software-properties-common \
    python3-pip \
    vim \
    build-essential \
    pkg-config \
    libssl-dev \
    libffi-dev \
    libpq-dev \
    yarn \
    && apt clean

RUN add-apt-repository ppa:deadsnakes/ppa -y && \
    apt update && \
    apt install -y python3.13 python3.13-venv python3.13-dev && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.13 1 && \
    update-alternatives --set python3 /usr/bin/python3.13 && \
    ln -sf /usr/bin/python3 /usr/bin/python

RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt install -y nodejs

# Debian 自带的 Python 3.13 pip 无法用 ensurepip --upgrade（与 apt 安装的 pip 包冲突）。
# venv/bootstrap 会用各仓 .venv 内 pip；系统级 python3.13 -m pip 使用当前 dist-packages 即可。

RUN useradd -m -s /bin/bash admin && \
    echo "admin:277127Load" | chpasswd && \
    adduser admin sudo

RUN printf '%s\n' 'export PATH="$HOME/.local/bin:$PATH"' >> /home/admin/.profile && \
    printf '%s\n' 'export PATH="$HOME/.local/bin:$PATH"' >> /home/admin/.bashrc

RUN mkdir /var/run/sshd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# scripts/ 由 compose 挂载进容器，改脚本不用 rebuild 镜像。

EXPOSE 22
CMD ["/usr/sbin/sshd", "-D"]
