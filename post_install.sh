#!/bin/sh

# Access hoobs using the hostname (e.g. http://hoobs.local)
# Enable avahi to use dbus
sed -i -e 's/#enable-dbus/enable-dbus/' /usr/local/etc/avahi/avahi-daemon.conf
# Enable mdns usage for host resolution
sed -i -e 's/hosts: file dns/hosts: file dns mdns/' /etc/nsswitch.conf
# Enable services
sysrc -f /etc/rc.conf dbus_enable="YES"
sysrc -f /etc/rc.conf avahi_daemon_enable="YES"
# Start services
service dbus start
service avahi-daemon start

# Update npm
npm install -g npm
# Install hoobs
npm install -g --unsafe-perm @hoobs/hoobs@3.1.23

# Run hoobs to create the configuration files and force exit after the timeout
timeout 10 hoobs

# Patch cpu.js to fix a runtime error
patch -u /root/.hoobs/node_modules/@hoobs/systeminfo/lib/cpu.js -i /tmp/cpu.js_workaround.patch
rm /tmp/cpu.js_workaround.patch

# Generate a random pin
PIN=`env LC_ALL=C tr -c -d '0123456789' < /dev/urandom | head -c 8 | sed 's/^\(...\)\(..\)\(...\)/\1-\2-\3/'`
# Generate a random MAC
MAC=`env LC_ALL=C tr -c -d '0123456789abcdef' < /dev/urandom | head -c 12 | sed 's!^M$!!;s!\-!!g;s!\.!!g;s!\(..\)!\1:!g;s!:$!!' | tr [:lower:] [:upper:]`
# Change the UI port to 80
UI_PORT=80
# Update the config file
mkdir -p /root/.hoobs/etc
jq --arg UI_PORT $UI_PORT --arg MAC $MAC --arg PIN $PIN '.server.port = ($UI_PORT  | tonumber) | .bridge.pin = $PIN | .bridge.username = $MAC' /root/.hoobs/default.json > /root/.hoobs/etc/config.json

# Install process manager autostart hoobs
npm install -g pm2
pm2 startup rcd
# enable pm2 service
sysrc -f /etc/rc.conf pm2_enable="YES"
# setup pm2
pm2 start hoobs
pm2 save
