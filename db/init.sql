CREATE DATABASE IF NOT EXISTS tienda_semestral;
USE tienda_semestral;

CREATE TABLE IF NOT EXISTS venta (
    id_venta BIGINT NOT NULL AUTO_INCREMENT,
    direccion_compra VARCHAR(255) NOT NULL,
    valor_compra INT NOT NULL,
    fecha_compra DATE NOT NULL,
    despacho_generado TINYINT(1) NOT NULL DEFAULT 0,
    PRIMARY KEY (id_venta)
);

INSERT INTO venta (id_venta, direccion_compra, valor_compra, fecha_compra, despacho_generado)
VALUES
  (1, 'Av. Providencia 1234, Santiago', 35980, '2024-01-10', 0),
  (2, 'Calle Las Condes 567, Santiago', 17990, '2024-01-11', 0),
  (3, 'Pasaje El Roble 89, Nuñoa', 25990, '2024-01-12', 0)
ON DUPLICATE KEY UPDATE id_venta = id_venta;
