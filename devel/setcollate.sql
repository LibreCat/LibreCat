/*
 * Set the character set and collation of the database and table.
 * Older installations of Librecat can have the wrong settings. This can 
 * be seen with the MYSQL command:
 *
 * show table status from librecat_main;
 *
 * The Collation column should be 'utf8_unicode_ci'
 *
 * Excute this command: 
 * 
 * mysql -u root -p librecat_main < setcollate.sql
 *
 */
alter database librecat_main character set utf8 collate utf8_unicode_ci;
alter table audit                   convert to character set utf8 collate utf8_unicode_ci;
alter table department_version      convert to character set utf8 collate utf8_unicode_ci;
alter table info                    convert to character set utf8 collate utf8_unicode_ci;
alter table init                    convert to character set utf8 collate utf8_unicode_ci;
alter table project_version         convert to character set utf8 collate utf8_unicode_ci;
alter table publication_version     convert to character set utf8 collate utf8_unicode_ci;
alter table research_group_version  convert to character set utf8 collate utf8_unicode_ci;
alter table user_version            convert to character set utf8 collate utf8_unicode_ci;
