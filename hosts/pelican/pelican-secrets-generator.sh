# Create the directory
sudo mkdir -p /var/secrets/pelican

# Generate your keys directly into it
sudo sh -c 'echo "base64:$(openssl rand -base64 32)" > /var/secrets/pelican/app.key'
sudo sh -c 'openssl rand -base64 24 > /var/secrets/pelican/dbpassword'
sudo sh -c 'openssl rand -base64 24 > /var/secrets/pelican/redispassword'
sudo sh -c 'openssl rand -base64 24 > /var/secrets/pelican/mailpassword'

# Give ownership to the pelican user so the system can read it securely
sudo chown -R pelican-panel:pelican-panel /var/secrets/pelican
sudo chmod 750 /var/secrets/pelican
sudo chmod 640 /var/secrets/pelican/*
