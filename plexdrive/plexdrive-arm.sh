#!/bin/sh

echo "Getting the latest version of plexdrive"
latest_version="$(wget -qO- -t1 -T2 "https://api.github.com/repos/plexdrive/plexdrive/releases" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/v//g;s/,//g;s/ //g')"
echo "${latest_version}"
plexdrive_link="https://github.com/plexdrive/plexdrive/releases/download/${latest_version}/plexdrive-linux-arm64"

mkdir -p "/home/gsuite"
mkdir -p "/home/.plexdrive"

cd `mktemp -d`
wget -nv "${plexdrive_link}" -O plexdrive
mv plexdrive /usr/local/bin/plexdrive
chmod +x /usr/local/bin/plexdrive

read -p "请输入config:" config
    [ -z "${config}" ]
read -p "请输入token:" token
    [ -z "${token}" ]

cat > /home/.plexdrive/config.json <<EOF
$config
EOF

cat > /home/.plexdrive/token.json <<EOF
$token
EOF

cat > /etc/systemd/system/plexdrive.service <<EOF
[Unit]
Description=Plexdrive
AssertPathIsDirectory=/home/gsuite
After=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/plexdrive mount \
 -c /home/.plexdrive \
 -o allow_other \
 -v 4 --refresh-interval=1m \
 --chunk-check-threads=4 \
 --chunk-load-threads=4 \
 --chunk-load-ahead=4 \
 --max-chunks=20 \
 /home/gsuite
ExecStop=/bin/fusermount -u /home/gsuite
Restart=on-abort

[Install]
WantedBy=default.target
EOF

systemctl daemon-reload
systemctl reset-failed
systemctl enable plexdrive

echo "plexdrive is installed. use 'systemctl start plexdrive' start plexdrive."
