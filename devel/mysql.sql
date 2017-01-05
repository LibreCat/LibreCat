CREATE DATABASE librecat_system;
CREATE DATABASE librecat_backup;
CREATE DATABASE librecat_metrics;
CREATE DATABASE librecat_requestcopy;
GRANT ALL ON librecat_system.*      TO 'librecat'@'localhost' IDENTIFIED BY 'librecat';
GRANT ALL ON librecat_backup.*      TO 'librecat'@'localhost' IDENTIFIED BY 'librecat';
GRANT ALL ON librecat_metrics.*     TO 'librecat'@'localhost' IDENTIFIED BY 'librecat';
GRANT ALL ON librecat_requestcopy.* TO 'librecat'@'localhost' IDENTIFIED BY 'librecat';
FLUSH PRIVILEGES;
