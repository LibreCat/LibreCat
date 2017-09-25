CREATE DATABASE librecat_main;
CREATE DATABASE librecat_metrics;
GRANT ALL ON librecat_main.*    TO 'librecat'@'localhost' IDENTIFIED BY 'librecat';
GRANT ALL ON librecat_metrics.* TO 'librecat'@'localhost' IDENTIFIED BY 'librecat';
FLUSH PRIVILEGES;
