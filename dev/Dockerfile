FROM ubuntu:24.04

RUN apt update && apt install -y \
    openssh-server \
    sudo \
    curl \
    wget \
    software-properties-common \
    python3-pip \
    && apt clean

# 安装 Python 3.13
RUN add-apt-repository ppa:deadsnakes/ppa -y && \
    apt update && \
    apt install -y python3.13 python3.13-venv python3.13-dev && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.13 1 && \
    update-alternatives --set python3 /usr/bin/python3.13 && \
    ln -s /usr/bin/python3 /usr/bin/python

# 安装 Node.js 22.x
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt install -y nodejs

# 创建用户
RUN useradd -m -s /bin/bash admin && \
    echo "admin:277127Load" | chpasswd && \
    adduser admin sudo

RUN mkdir /var/run/sshd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

EXPOSE 22
CMD ["/usr/sbin/sshd", "-D"]