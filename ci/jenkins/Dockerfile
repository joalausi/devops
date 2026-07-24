FROM jenkins/jenkins:lts-jdk21

USER root

RUN apt-get update && \
    apt-get install -y \
      curl \
      git \
      make \
      python3 \
      python3-venv \
      openssh-client \
      docker.io && \
    python3 -m venv /opt/ansible-venv && \
    /opt/ansible-venv/bin/pip install --no-cache-dir ansible && \
    ln -s /opt/ansible-venv/bin/ansible /usr/local/bin/ansible && \
    ln -s /opt/ansible-venv/bin/ansible-playbook /usr/local/bin/ansible-playbook && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

USER jenkins

COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt