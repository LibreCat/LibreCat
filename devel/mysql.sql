CREATE DATABASE librecat_main CHARACTER SET utf8 COLLATE utf8_unicode_ci;
CREATE USER 'librecat'@'localhost' IDENTIFIED BY 'librecat';
GRANT ALL ON librecat_main.* TO 'librecat'@'localhost';
FLUSH PRIVILEGES;
