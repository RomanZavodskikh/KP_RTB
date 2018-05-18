export PATH=/usr/local/pgsql/bin:$PATH
dropdb K
createdb --encoding=KOI8-R K && createlang plpgsql K && psql -f kp_rtb.sql K
