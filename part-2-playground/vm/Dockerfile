FROM debian:13.7
RUN apt-get update && apt-get install --no-install-recommends -y \
      ca-certificates curl dbus init openssh-server procps sudo && \
    rm -rf /var/lib/apt/lists/* && \
    useradd -m -s /bin/bash -G sudo,systemd-journal deploy && \
    echo 'deploy ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/deploy && \
    systemctl enable ssh
# The keys and the CA arrive at runtime from the mounted /pg folder.
COPY pg-setup.sh /usr/local/sbin/pg-setup.sh
COPY pg-setup.service /etc/systemd/system/pg-setup.service
RUN chmod +x /usr/local/sbin/pg-setup.sh && systemctl enable pg-setup
CMD ["/sbin/init"]
