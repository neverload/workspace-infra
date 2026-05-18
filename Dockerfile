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

RUN python3.13 -m ensurepip --upgrade

RUN useradd -m -s /bin/bash admin && \
    echo "admin:277127Load" | chpasswd && \
    adduser admin sudo

RUN printf '%s\n' 'export PATH="$HOME/.local/bin:$PATH"' >> /home/admin/.profile && \
    printf '%s\n' 'export PATH="$HOME/.local/bin:$PATH"' >> /home/admin/.bashrc

RUN mkdir /var/run/sshd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

COPY scripts/workspace-bootstrap.sh /usr/local/bin/workspace-bootstrap.sh
COPY scripts/workspace-infra-entrypoint.sh /usr/local/bin/workspace-infra-entrypoint.sh
COPY scripts/workspace-ssh-volume-init.sh /usr/local/bin/workspace-ssh-volume-init.sh
RUN chmod 755 /usr/local/bin/workspace-bootstrap.sh \
    /usr/local/bin/workspace-infra-entrypoint.sh \
    /usr/local/bin/workspace-ssh-volume-init.sh

EXPOSE 22
CMD ["/usr/sbin/sshd", "-D"]
