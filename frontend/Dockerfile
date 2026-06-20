FROM node:18-alpine AS builder
WORKDIR /app
ARG VITE_API_VENTAS_URL
ARG VITE_API_DESPACHOS_URL
ENV VITE_API_VENTAS_URL=$VITE_API_VENTAS_URL
ENV VITE_API_DESPACHOS_URL=$VITE_API_DESPACHOS_URL
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build
FROM nginx:alpine
RUN rm -rf /usr/share/nginx/html/*
COPY --from=builder /app/dist /usr/share/nginx/html
COPY default.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
