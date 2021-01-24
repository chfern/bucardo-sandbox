# Bucardo Sandbox

A sandbox about replicating data from 1 postgres DB to another using [bucardo](https://bucardo.org/).  
This sandbox uses docker-compose for linux package installation and database creation only (this is intentional).

Versions used:  
- PostgreSQL - 11.9
- Bucardo - 5.6.0

## Scenario

We would have 2 databases (source database and destination database). Data in some tables would then be synced from src to dest DB.

Source host: 192.168.99.3  
Source database: booking-db  
Source port: 5432  
Source username: postgres  
Source password: AAAaaa123!@#

Destination host: 192.168.99.3  
Destination database: booking-db  
Destination port: 6432  
Destination username: postgres  
Destination password: AAAaaa123!@#

Tables to-sync from source database:  
- `schema_to_migrate.bookings`
- `schema_to_migrate.booking_histories`

# Running the Sandbox

## Pre-requisites

You need to have these installed in your system beforehand:  
- Docker
- Docker Compose
- Any DB GUI or psql to inspect the database later on

## Sandbox Setup

Setup static IP on host  
`sudo ifconfig lo0 alias 192.168.99.3`

In the root directory, run `docker-compose up`. This spawns the 2 database containers with required linux packages and postgres plugin.

Execute bash in source postgres container. Run `docker ps` to get list of running containers, copy the source database's container ID then run `docker exec -u root -it {containerID} /bin/bash`

### Environment Variables Setup

For convenience purpose, set the informations to env variables
```
export SOURCE_HOST=192.168.99.3
export SOURCE_PORT=5432
export SOURCE_DATABASE=booking-db
export SOURCE_USERNAME=postgres
export SOURCE_PASSWORD='AAAaaa123!@#'

export DEST_HOST=192.168.99.3
export DEST_PORT=6432  
export DEST_DATABASE=booking-db  
export DEST_USERNAME=postgres
export DEST_PASSWORD='AAAaaa123!@#'

export TABLES="schema_to_migrate.bookings schema_to_migrate.booking_histories"
```

### Source Database & Destination Database Setup

Connect to the src database using psql to create tables and optionally seed dummy data.  
```
psql -U $SOURCE_USERNAME -h $SOURCE_HOST $SOURCE_DATABASE

CREATE SCHEMA schema_to_migrate;
CREATE TABLE schema_to_migrate.bookings(booking_id int primary key);
CREATE TABLE schema_to_migrate.booking_histories(booking_history_id int primary key);

INSERT INTO schema_to_migrate.bookings(booking_id) values (1);

\q
```

Because destination database is freshly deployed, dump schema info from source database and update destination database with the schema information
```
cd /tmp && \
pg_dump -U $SOURCE_USERNAME -d $SOURCE_DATABASE --schema-only --no-privileges --no-owner --no-security-labels --no-synchronized-snapshots --no-tablespaces > schema.sql && \
psql -h $DEST_HOST -p $DEST_PORT -d $DEST_DATABASE -U $DEST_USERNAME -f schema.sql
```

### Bucardo Setup

Create a new linux user for bucardo
```
export BUCARDO_USER=bucardo

sudo useradd $BUCARDO_USER -m && \
sudo passwd $BUCARDO_USER
```

Download bucardo distribution in well-known `src` folder
```
cd /usr/local/src && \
wget https://github.com/bucardo/bucardo/archive/5.6.0.tar.gz && \
tar zxvf 5.6.0.tar.gz && \
rm 5.6.0.tar.gz && \
cd bucardo-5.6.0 && \
perl Makefile.PL && \
make && \
make install && \
sudo chown -R $BUCARDO_USER:$BUCARDO_USER /usr/local/src/bucardo-5.6.0
```

Create other folders required by bucardo  
```
sudo mkdir -p /var/log/bucardo /var/run/bucardo && \
sudo chown $BUCARDO_USER:$BUCARDO_USER /var/log/bucardo /var/run/bucardo
```

Switch to `bucardo` user then [re-apply the env variables](#environment-variables-setup)
```
su -l bucardo
```

### Configuring Bucardo's PostgreSQL

Create .pgpass file to connect to local and destination DB, then secure it due to it containing credential information
```
cat > $HOME/.pgpass <<EOL  
$DEST_HOST:$DEST_PORT:$DEST_DATABASE:$DEST_USERNAME:$DEST_PASSWORD
$SOURCE_HOST:$SOURCE_PORT:$SOURCE_DATABASE:$SOURCE_USERNAME:$SOURCE_PASSWORD
EOL

chmod 0600 $HOME/.pgpass
```

In the bucardo directory, trigger bucardo installation. Change the config such that it match the configuration below then proceed with the installation
```
cd /usr/local/src/bucardo-5.6.0 && \
./bucardo install --quiet
```

```
1. Host:           192.168.99.3 
2. Port:           5432  
3. User:           postgres  
4. Database:       booking-db  
5. PID directory:  /var/run/bucardo 
```

### Configuring Bucardo Sync

Add source database
```
./bucardo add db source_db dbhost=$SOURCE_HOST dbport=$SOURCE_PORT dbname=$SOURCE_DATABASE dbuser=$SOURCE_USERNAME dbpass=$SOURCE_PASSWORD
```

Add destination database
```
./bucardo add db dest_db dbhost=$DEST_HOST dbport=$DEST_PORT dbname=$DEST_DATABASE dbuser=$DEST_USERNAME dbpass=$DEST_PASSWORD
```

Add tables to migrate
```
./bucardo add tables $TABLES db=source_db
./bucardo add herd copying_herd $TABLES
```

And build a sync based on the "copying herd"
```
./bucardo add sync booking_sync relgroup=copying_herd dbs=source_db:source,dest_db:target onetimecopy=2
```

Set bucardo's database credential info bucardo's config file
```
cat > $HOME/.bucardorc <<EOL
dbhost=$SOURCE_HOST 
dbname=bucardo
dbport=$SOURCE_PORT
dbuser=bucardo  
EOL
```

Run bucardo to start sync process
```
./bucardo start
```