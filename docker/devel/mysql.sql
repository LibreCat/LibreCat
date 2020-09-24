CREATE DATABASE IF NOT EXISTS librecat_main CHARACTER SET utf8 COLLATE utf8_unicode_ci;
CREATE USER IF NOT EXISTS 'librecat'@'localhost' IDENTIFIED BY 'librecat';
CREATE USER IF NOT EXISTS 'librecat'@'%' IDENTIFIED BY 'librecat';
GRANT ALL ON librecat_main.* TO 'librecat'@'localhost';
GRANT ALL ON librecat_main.* TO 'librecat'@'%';
FLUSH PRIVILEGES;
