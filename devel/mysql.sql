CREATE DATABASE librecat_main CHARACTER SET utf8 COLLATE utf8_unicode_ci;
GRANT ALL ON librecat_main.* TO 'librecat'@'localhost' IDENTIFIED BY 'librecat';
FLUSH PRIVILEGES;
