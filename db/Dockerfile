FROM mysql:8
ENV MYSQL_ROOT_PASSWORD=admin123
ENV MYSQL_DATABASE=tienda_semestral
ENV MYSQL_USER=alumno
ENV MYSQL_PASSWORD=alumno123
COPY init.sql /docker-entrypoint-initdb.d/
EXPOSE 3306
