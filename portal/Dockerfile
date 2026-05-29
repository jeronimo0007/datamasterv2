FROM nginx:alpine
COPY portal/index.html portal/banca.html portal/roteiro.html \
  portal/datamaster-01-batch-medallion.png portal/datamaster-02-online-gateway.png \
  portal/datamaster-01-batch-medallion.svg /usr/share/nginx/html/
COPY portal/nginx.conf /etc/nginx/conf.d/default.conf
