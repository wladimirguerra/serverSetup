#!/bin/dash

USER_NAME="$1"
# This script aims Ubuntu 18.04
#
# It should be run as a root user.
#
# The purpose of this script is to secure a raw
# Ubuntu VM machine with only a root user and
# ssh access using password.

## Validations ##

if [ ! -f ./pub-key ]; then
  echo "pub-key file must exists."
  exit 1
fi

## Initial Setup ##
# This step was written following the tutorial:
# https://www.digitalocean.com/community/tutorials/initial-server-setup-with-ubuntu-18-04

if ! id "$1" >/dev/null 2>&1; then
  echo "User doesn't exists. Creating user..."
  adduser "$USER_NAME" || exit 1
  echo "User created."
fi

usermod -aG sudo "$USER_NAME" || exit 1

echo "Configuring ufw to allow SSH"
ufw allow OpenSSH || exit 1

echo "ufw Configured! You must enable it manually."

echo "Making root .ssh folder"
mkdir -p ~/.ssh || exit 1

echo "Copying authorized_keys to .ssh root folder"
cp ./pub-key ~/.ssh/authorized_keys || exit 1

echo "Copying authorized_keys to $USER_NAME folder"
rsync --archive --chown="$USER_NAME":"$USER_NAME" ~/.ssh /home/"$USER_NAME" || exit 1

echo "Hardening sshd"
echo "Making a backup copy to sshd_config.bak."

## Hardening ssh ##
# From tutorial
# https://www.digitalocean.com/community/tutorials/how-to-harden-openssh-on-ubuntu-18-04
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

echo "Reconfiguring sshd_config..."
sed 's/#\?\(PermitRootLogin\s*\).*$/\1 no/' /etc/ssh/sshd_config > .sshd_config_temp.txt

if [ ! -f ./.sshd_config_temp.txt ]; then
  echo "Couldn't reconfigure sshd. 'sed' was unable to create .sshd_config_temp.txt file."
  exit 1
fi

sed -i 's/#\?\(MaxAuthTries\s*\).*$/\1 3/' ./.sshd_config_temp.txt || exit 1
# LoginGraceTime
# Lower values prevent certain denial-of-service attacks
sed -i 's/#\?\(LoginGraceTime\s*\).*$/\1 20/' ./.sshd_config_temp.txt || exit 1
sed -i 's/#\?\(PasswordAuthentication\s*\).*$/\1 no/' ./.sshd_config_temp.txt || exit 1
sed -i 's/#\?\(PermitEmptyPasswords\s*\).*$/\1 no/' ./.sshd_config_temp.txt || exit 1
sed -i 's/#\?\(ChallengeResponseAuthentication\s*\).*$/\1 no/' ./.sshd_config_temp.txt || exit 1
sed -i 's/#\?\(GSSAPIAuthentication\s*\).*$/\1 no/' ./.sshd_config_temp.txt || exit 1
sed -i 's/#\?\(X11Forwarding\s*\).*$/\1 no/' ./.sshd_config_temp.txt || exit 1
#sed -i 's/#\?\(PermitUserEnvironment\s*\).*$/\1 no/' ./.sshd_config_temp.txt || exit 1
sed -i 's/#\?\(AllowAgentForwarding\s*\).*$/\1 no/' ./.sshd_config_temp.txt || exit 1
sed -i 's/#\?\(AllowTcpForwarding\s*\).*$/\1 no/' ./.sshd_config_temp.txt || exit 1
sed -i 's/#\?\(PermitTunnel\s*\).*$/\1 no/' ./.sshd_config_temp.txt || exit 1
sed -i 's/#\?\(DebianBanner\s*\).*$/\1 no/' ./.sshd_config_temp.txt || exit 1

echo "Overwriting sshd_config file"
mv -f .sshd_config_temp.txt /etc/ssh/sshd_config || (rm .sshd_config_temp.txt && exit 1)
echo "Successfully reconfigured sshd"

echo "Testing configuration"

if ! sshd -t; then
  echo "Test failed. Rolling back configuration."
  cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config
fi

echo "Test Succeeded"

echo "Reloading sshd"
service sshd reload
echo "Reload Succeeded"

