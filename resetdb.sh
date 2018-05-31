#export PATH=/usr/local/pgsql/bin:$PATH
dropdb -Upostgres test
createdb --encoding=KOI8_R -Upostgres test && createlang -Upostgres plpgsql test
psql -Upostgres -f kp_rtb.sql test
