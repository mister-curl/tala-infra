#----------------------------------------------------------
# DockFile
#----------------------------------------------------------
FROM ubuntu:16.04

ENV USER_NAME admin
ENV USER_PASSWORD test

RUN apt-get update
RUN apt-get -y upgrade

#----------------------------------------------------------
#--- SSH
#t----------------------------------------------------------
RUN apt-get install -y build-essential libssl-dev libreadline-dev zlib1g-dev language-pack-ja
RUN apt install -y sudo passwd openssh-server
RUN sed -ri 's/^#PermitRootLogin yes$/PermitRootLogin no/' /etc/ssh/sshd_config
RUN mkdir /var/run/sshd


#----------------------------------------------------------
#--- LOGIN USER
#----------------------------------------------------------
#--- SSH
RUN useradd $USER_NAME -s /bin/bash -g 0
RUN echo "$USER_NAME:$USER_PASSWORD" | chpasswd
RUN echo "$USER_NAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/$USER_NAME
RUN mkdir -p /home/admin/.ssh; chown admin. /home/admin/.ssh; chmod 700 /home/admin/.ssh
RUN echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC4Uds81NsFT+9q/l88z41rE2XIlp7JsYpGMqWRdQQd3pAjjbk3M0PJeu/jnBM/8PUcRk2XvxPJbbRUtgW+cA84SIT9V2YfTdiCAwu9UsvEMisg+Yr8oTebX5I6/V/K0jKNGCFzNAkm2c8UQZc0Itrq/qyeye0HYJdbRarJN2Ho20SwFlJTXIsXgfevkuDXf+d7r4Nl/M+ogYeGgxvIJJyFBuUn3EQRLM47fd4GUetJSmpdJtG07m1F7ys4Nkby+vFo9mdkeFTVXvDkQIL1vZoeBPQ9ers58FTsMkUSp/fJSLyIv/8hWvQszuPyvoJ6X13ZFd9etFmNhOZ9UClKjNg3 admin@TX120S3-02" > /home/admin/.ssh/authorized_keys
RUN chown admin. /home/admin/.ssh/authorized_keys; chmod 600 /home/admin/.ssh/authorized_keys
