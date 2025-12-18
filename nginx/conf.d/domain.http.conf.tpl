server {
    listen 80;
    server_name {{DOMAIN}};

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 200 "HTTP OK\n";
    }
}
