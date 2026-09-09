# Make
FROM alpine:3.24
RUN apk add --no-cache nginx

COPY nginx.conf /etc/nginx/
COPY index.html /usr/share/nginx/html/

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]