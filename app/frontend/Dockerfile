FROM nginx:1.27-alpine

COPY index.html /usr/share/nginx/html/index.html
COPY style.css /usr/share/nginx/html/style.css
COPY app.js /usr/share/nginx/html/app.js
COPY nginx.conf /etc/nginx/conf.d/default.conf

COPY docker-entrypoint.d/40-generate-server-info.sh /docker-entrypoint.d/40-generate-server-info.sh
RUN chmod +x /docker-entrypoint.d/40-generate-server-info.sh

EXPOSE 80