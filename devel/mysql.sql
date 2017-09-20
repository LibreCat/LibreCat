CREATE DATABASE librecat_backup;
CREATE DATABASE librecat_metrics;
GRANT ALL ON librecat_backup.*      TO 'librecat'@'localhost' IDENTIFIED BY 'librecat';
GRANT ALL ON librecat_metrics.*     TO 'librecat'@'localhost' IDENTIFIED BY 'librecat';
FLUSH PRIVILEGES;
