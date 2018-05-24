export PATH=/usr/local/pgsql/bin:$PATH
dropdb test
createdb --encoding=KOI8-R test && createlang plpgsql test && psql -f kp_rtb.sql test
