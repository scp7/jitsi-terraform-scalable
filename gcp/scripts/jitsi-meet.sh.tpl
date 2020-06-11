echo "Starting to install Jitsi Meet (prosody, jicofo, meet)"

# Include shared preparations above this line.
apt-get -y install \
  nginx \
  prosody jicofo jitsi-meet-web jitsi-meet-prosody jitsi-meet-web-config \
  google-cloud-sdk

# https://github.com/jitsi/jitsi-meet/blob/4080/doc/manual-install.md
cat << EOF > /etc/nginx/sites-available/${jitsi_hostname}.conf
server_names_hash_bucket_size 64;

server {
    listen 0.0.0.0:443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ${jitsi_hostname};
    # auto-updated from here https://github.com/jitsi/jitsi-meet/blob/8758c222c6f4ffa6f2403ff1a4b097d3437b52a5/resources/install-letsencrypt-cert.sh#L68-L76
    ssl_certificate     /etc/jitsi/meet/${jitsi_hostname}.crt;
    ssl_certificate_key /etc/jitsi/meet/${jitsi_hostname}.key;
    # set the root
    root /usr/share/jitsi-meet;
    index index.html;
    location ~ ^/([a-zA-Z0-9=\?]+)$ {
        rewrite ^/(.*)$ / break;
    }
    location / {
        ssi on;
    }
    # BOSH, Bidirectional-streams Over Synchronous HTTP
    # https://en.wikipedia.org/wiki/BOSH_(protocol)
    location /http-bind {
        proxy_pass      http://localhost:5280/http-bind;
        proxy_set_header X-Forwarded-For \$remote_addr;
        proxy_set_header Host \$http_host;
    }
    # external_api.js must be accessible from the root of the
    # installation for the electron version of Jitsi Meet to work
    # https://github.com/jitsi/jitsi-meet-electron
    location /external_api.js {
        alias /usr/share/jitsi-meet/libs/external_api.min.js;
    }
}
EOF

cd /etc/nginx/sites-enabled
ln -s ../sites-available/${jitsi_hostname}.conf ${jitsi_hostname}.conf
nginx -s reload

# Enable CORS for BOSH in Prosody Lua config
sed -i "s|cross_domain_bosh = false|cross_domain_bosh = true|g" /etc/prosody/conf.avail/${jitsi_hostname}.cfg.lua
/etc/init.d/prosody restart
/etc/init.d/jicofo restart

# LetsEncrypt
# See script: https://github.com/jitsi/jitsi-meet/blob/8758c222c6f4ffa6f2403ff1a4b097d3437b52a5/resources/install-letsencrypt-cert.sh
echo "${lets_encrypt_email}" | /usr/share/jitsi-meet/scripts/install-letsencrypt-cert.sh

nginx -s reload