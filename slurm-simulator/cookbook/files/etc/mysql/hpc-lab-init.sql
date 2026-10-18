-- Run by MariaDB at every start (init-file in mariadb.conf.d/90-hpc-lab.cnf), one statement per line.
-- The database user of slurmdbd (StorageUser and StoragePass in slurmdbd.conf). The server listens
-- on localhost only, inside the container, so the password guards nothing and is no secret.
CREATE USER IF NOT EXISTS 'slurm'@'localhost' IDENTIFIED BY 'slurm';
GRANT ALL PRIVILEGES ON *.* TO 'slurm'@'localhost';
