\echo �������� ����� ������������� � �������������
DROP USER reader1;
DROP USER reader2;
DROP USER writer1;
DROP USER writer2;

DROP GROUP readers;
DROP GROUP writers;

CREATE GROUP readers;
CREATE GROUP writers;

CREATE USER reader1 WITH PASSWORD 'reader1' NOCREATEDB NOCREATEUSER;
CREATE USER reader2 WITH PASSWORD 'reader2' NOCREATEDB NOCREATEUSER;

CREATE USER writer1 WITH PASSWORD 'writer1' NOCREATEDB NOCREATEUSER;
CREATE USER writer2 WITH PASSWORD 'writer2' NOCREATEDB NOCREATEUSER;

ALTER GROUP readers ADD USER reader1, reader2;
ALTER GROUP writers ADD USER writer1, writer2;

\echo �������� ������
DROP TABLE AMS;
CREATE TABLE AMS (
    id serial NOT NULL,
    name text NOT NULL,
    max_num_of_targs integer NOT NULL,
    PRIMARY KEY (id)
);

GRANT SELECT ON TABLE AMS TO GROUP readers;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE AMS TO GROUP writers;

DROP TABLE RLS_models;
CREATE TABLE RLS_models (
	id serial NOT NULL,
    name text NOT NULL,
	distance_limit_km integer NOT NULL,
	height_limit_km integer NOT NULL,
	distance_accuracy_m integer NOT NULL,
	PRIMARY KEY (id)
);

GRANT SELECT ON TABLE RLS_models TO GROUP readers;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE RLS_models TO GROUP writers;

DROP TABLE MP_radio_brigade;
CREATE TABLE MP_radio_brigade (
	id serial NOT NULL,
    ams_id integer NOT NULL REFERENCES AMS(id),
    p point NOT NULL CHECK(p >> point'(0,0)' and p >^ point'(0,0)'),
	state integer NOT NULL,
	PRIMARY KEY (id)
);

GRANT SELECT ON TABLE MP_radio_brigade TO GROUP readers;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE MP_radio_brigade TO GROUP writers;

DROP TABLE MP_radio_batallion;
CREATE TABLE MP_radio_batallion (
	id serial NOT NULL,
    ams_id integer NOT NULL REFERENCES AMS(id),
	radio_brigade_id integer NOT NULL REFERENCES MP_radio_brigade(id),
    p point NOT NULL CHECK(p >> point'(0,0)' and p >^ point'(0,0)'),
    UNIQUE(radio_brigade_id),
	PRIMARY KEY (id)
);

GRANT SELECT ON TABLE MP_radio_batallion TO GROUP readers;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE MP_radio_batallion TO GROUP writers;

DROP TABLE MP_radio_rota;
CREATE TABLE MP_radio_rota (
	id serial NOT NULL,
	radio_batallion_id integer NOT NULL REFERENCES MP_radio_batallion(id),
    ams_id integer NOT NULL REFERENCES AMS(id),
    p point NOT NULL CHECK(p >> point'(0,0)' and p >^ point'(0,0)'),
    object BOOLEAN NOT NULL,
	PRIMARY KEY (id)
);

GRANT SELECT ON TABLE MP_radio_rota TO GROUP readers;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE MP_radio_rota TO GROUP writers;

DROP TABLE RLS;
CREATE TABLE RLS (
	id serial NOT NULL,
    model_id integer NOT NULL REFERENCES RLS_models(id),
    radio_batallion_id integer REFERENCES MP_radio_batallion(id),
    radio_rota_id integer REFERENCES MP_radio_rota(id),
	state integer NOT NULL,
    p point NOT NULL CHECK(p >> point'(0,0)' and p >^ point'(0,0)'),
    change integer NOT NULL,
	PRIMARY KEY (id),
    CHECK (radio_batallion_id IS NOT NULL OR radio_rota_id IS NOT NULL),
    CHECK (radio_batallion_id IS     NULL OR radio_rota_id IS     NULL),
    CHECK (change >= 1 AND change <= 2)
);

GRANT SELECT ON TABLE RLS TO GROUP readers;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE RLS TO GROUP writers;

DROP TABLE target;
CREATE TABLE target (
	id serial NOT NULL,
    rls_id integer NOT NULL REFERENCES RLS(id),
    t timestamp NOT NULL,
	p point NOT NULL CHECK(p >> point'(0,0)' and p >^ point'(0,0)'),
	group_t BOOLEAN NOT NULL,
	maneuvering BOOLEAN NOT NULL,
	important BOOLEAN NOT NULL,
	PRIMARY KEY (id)
);

GRANT SELECT ON TABLE target TO GROUP readers;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE target TO GROUP writers;

GRANT SELECT, UPDATE ON TABLE ams_id_seq, mp_radio_batallion_id_seq, mp_radio_brigade_id_seq, mp_radio_rota_id_seq, rls_id_seq, rls_models_id_seq, target_id_seq TO GROUP writers;

DROP TRIGGER target_detection ON target;
DROP FUNCTION target_detection();
CREATE FUNCTION target_detection() RETURNS trigger
    AS '
        DECLARE
            dist double precision := 0.0;
            change integer := 0;
        BEGIN
            RAISE NOTICE ''�������� %'', NEW.p;
            SELECT RLS.change INTO change FROM RLS WHERE RLS.id=NEW.rls_id;
            RAISE NOTICE ''����� %'', change;
            IF change <> 1 THEN
                RAISE EXCEPTION ''�� �� �����'';
            END IF;
            RETURN NEW;
        END;
    '
    LANGUAGE plpgsql;
CREATE TRIGGER target_detection BEFORE INSERT ON target
    FOR EACH ROW EXECUTE PROCEDURE target_detection();

DROP FUNCTION dangerousness(double precision, boolean, boolean, boolean);
CREATE FUNCTION dangerousness(double precision, boolean, boolean, boolean) RETURNS double precision
    AS '
    DECLARE
        a int;
        b int;
        c int;
    BEGIN
        IF $2 THEN
            a := 1;
        ELSE
            a := 0;
        END IF;
        IF $3 THEN
            b := 1;
        ELSE
            b := 0;
        END IF;
        IF $4 THEN
            c := 1;
        ELSE
            c := 0;
        END IF;
        return $1 * (1 + a + b + c);
    END;'
    LANGUAGE 'plpgsql';

\echo ���������� ��������� �������
\echo ��������� ��� writer1
\c - writer1
INSERT INTO AMS VALUES (1, '���������-2�', 200);
INSERT INTO AMS VALUES (2, '���������-1�', 120);
INSERT INTO AMS VALUES (3, '����-�1��', 250);
INSERT INTO AMS VALUES (4, '���������-3�', 300);

INSERT INTO MP_radio_brigade VALUES (1, 4, point(50, 50), 90);

INSERT INTO MP_radio_batallion VALUES (1, 1, 1, point(40, 30));

INSERT INTO MP_radio_rota VALUES (1, 1, 2, point(100, 110), TRUE);
INSERT INTO MP_radio_rota VALUES (2, 1, 3, point(110, 110), FALSE);

INSERT INTO RLS_models VALUES (1, '���������-��', 250, 200, 100);
INSERT INTO RLS_models VALUES (2, '����', 1200, 75, 400);
INSERT INTO RLS_models VALUES (3, '����-��', 400, 70, 120);
INSERT INTO RLS_models VALUES (4, '�����-��', 200, 60, 80);
INSERT INTO RLS_models VALUES (5, '�����-�', 300, 20, 300);
INSERT INTO RLS_models VALUES (6, '�����-2�1', 70, 6, 300);
INSERT INTO RLS_models VALUES (7, '�����-2�2', 70, 6, 100);
INSERT INTO RLS_models VALUES (8, '�����-�1�', 200, 120, 80);
INSERT INTO RLS_models VALUES (9, '�����-�2�', 200, 120, 80);
INSERT INTO RLS_models VALUES (10, '�����-�3�', 200, 120, 80);
INSERT INTO RLS_models VALUES (11, '�����-�1�', 150, 10, 50);
INSERT INTO RLS_models VALUES (12, '��������-��', 400, 100, 300);
INSERT INTO RLS_models VALUES (13, '������', 150, 35, 40);
INSERT INTO RLS_models VALUES (14, '�������', 250, 35, 500);

\echo ����� ������ INSERT �� ��������� ��-�� �������� ���������
INSERT INTO RLS VALUES (nextval('rls_id_seq'), 1, 1, NULL, 100, point(1, 0), 1);
INSERT INTO RLS VALUES (nextval('rls_id_seq'), 1, 1, NULL, 100, point(1, 1), 1);

INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:00.0', point(100, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:10.0', point(95, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:20.0', point(90, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:30.0', point(85, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:40.0', point(80, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:50.0', point(75, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:00.0', point(70, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:10.0', point(65, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:20.0', point(60, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:30.0', point(55, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:40.0', point(50, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:50.0', point(45, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:31:00.0', point(40, 1), TRUE, TRUE, TRUE);

INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:00.0', point(1, 100), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:10.0', point(1, 95), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:20.0', point(1, 90), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:30.0', point(1, 85), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:40.0', point(1, 80), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:50.0', point(1, 75), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:00.0', point(1, 70), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:10.0', point(1, 65), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:20.0', point(1, 60), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:30.0', point(1, 55), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:40.0', point(1, 50), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:50.0', point(1, 45), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:31:00.0', point(1, 40), TRUE, TRUE, TRUE);

INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:00.0', point(1, 50), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:10.0', point(6, 45), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:20.0', point(10, 40), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:30.0', point(15, 35), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:40.0', point(20, 30), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:50.0', point(25, 35), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:00.0', point(20, 40), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:10.0', point(20, 45), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:20.0', point(20, 50), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:30.0', point(20, 55), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:40.0', point(20, 60), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:30.0', point(25, 60), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:31:00.0', point(30, 60), TRUE, TRUE, TRUE);

INSERT INTO RLS VALUES (nextval('rls_id_seq'), 1, 1, NULL, 100, point(1, 100), 2);

INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:00.0', point(100, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:10.0', point(95, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:20.0', point(90, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:30.0', point(85, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:40.0', point(80, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:50.0', point(75, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:00.0', point(70, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:10.0', point(65, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:20.0', point(60, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:30.0', point(55, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:40.0', point(50, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:50.0', point(45, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:31:00.0', point(40, 1), TRUE, TRUE, TRUE);

INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:00.0', point(1, 50), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:10.0', point(6, 45), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:20.0', point(10, 40), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:30.0', point(15, 35), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:40.0', point(20, 30), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:50.0', point(25, 35), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:00.0', point(20, 40), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:10.0', point(20, 45), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:20.0', point(20, 50), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:30.0', point(20, 55), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:40.0', point(20, 60), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:30.0', point(25, 60), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:31:00.0', point(30, 60), TRUE, TRUE, TRUE);

INSERT INTO RLS VALUES (nextval('rls_id_seq'), 1, 1, NULL, 90, point(50, 50), 1);

INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:00.0', point(100, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:10.0', point(95, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:20.0', point(90, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:30.0', point(85, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:40.0', point(80, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:50.0', point(75, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:00.0', point(70, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:10.0', point(65, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:20.0', point(60, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:30.0', point(55, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:40.0', point(50, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:50.0', point(45, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:31:00.0', point(40, 1), TRUE, TRUE, TRUE);

INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:00.0', point(1, 100), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:10.0', point(1, 95), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:20.0', point(1, 90), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:30.0', point(1, 85), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:40.0', point(1, 80), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:50.0', point(1, 75), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:00.0', point(1, 70), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:10.0', point(1, 65), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:20.0', point(1, 60), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:30.0', point(1, 55), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:40.0', point(1, 50), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:50.0', point(1, 45), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:31:00.0', point(1, 40), TRUE, TRUE, TRUE);

INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:00.0', point(1, 50), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:10.0', point(6, 45), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:20.0', point(10, 40), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:30.0', point(15, 35), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:40.0', point(20, 30), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:50.0', point(25, 35), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:00.0', point(20, 40), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:10.0', point(20, 45), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:20.0', point(20, 50), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:30.0', point(20, 55), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:40.0', point(20, 60), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:30.0', point(25, 60), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:31:00.0', point(30, 60), TRUE, TRUE, TRUE);

INSERT INTO RLS VALUES (nextval('rls_id_seq'), 1, 1, NULL, 80, point(30, 30), 2);

INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:00.0', point(100, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:10.0', point(95, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:20.0', point(90, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:30.0', point(85, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:40.0', point(80, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:50.0', point(75, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:00.0', point(70, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:10.0', point(65, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:20.0', point(60, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:30.0', point(55, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:40.0', point(50, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:50.0', point(45, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:31:00.0', point(40, 1), TRUE, TRUE, TRUE);

INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:00.0', point(1, 100), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:10.0', point(1, 95), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:20.0', point(1, 90), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:30.0', point(1, 85), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:40.0', point(1, 80), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:50.0', point(1, 75), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:00.0', point(1, 70), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:10.0', point(1, 65), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:20.0', point(1, 60), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:30.0', point(1, 55), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:40.0', point(1, 50), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:50.0', point(1, 45), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:31:00.0', point(1, 40), TRUE, TRUE, TRUE);

INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:00.0', point(1, 50), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:10.0', point(6, 45), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:20.0', point(10, 40), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:30.0', point(15, 35), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:40.0', point(20, 30), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:50.0', point(25, 35), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:00.0', point(20, 40), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:10.0', point(20, 45), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:20.0', point(20, 50), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:30.0', point(20, 55), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:40.0', point(20, 60), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:30.0', point(25, 60), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:31:00.0', point(30, 60), TRUE, TRUE, TRUE);

INSERT INTO RLS VALUES (nextval('rls_id_seq'), 1, 1, NULL, 70, point(60, 60), 1);

INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:00.0', point(100, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:10.0', point(95, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:20.0', point(90, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:30.0', point(85, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:40.0', point(80, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:50.0', point(75, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:00.0', point(70, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:10.0', point(65, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:20.0', point(60, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:30.0', point(55, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:40.0', point(50, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:50.0', point(45, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:31:00.0', point(40, 1), TRUE, TRUE, TRUE);

INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:40.0', point(20, 30), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:50.0', point(20, 35), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:00.0', point(20, 40), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:10.0', point(20, 45), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:20.0', point(20, 50), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:30.0', point(20, 55), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:40.0', point(20, 60), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:50.0', point(25, 60), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:31:00.0', point(30, 60), TRUE, TRUE, TRUE);

INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:00.0', point(1, 50), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:10.0', point(6, 45), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:20.0', point(10, 40), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:30.0', point(15, 35), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:40.0', point(20, 30), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:50.0', point(25, 35), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:00.0', point(20, 40), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:10.0', point(20, 45), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:20.0', point(20, 50), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:30.0', point(20, 55), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:40.0', point(20, 60), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:30.0', point(25, 60), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:31:00.0', point(30, 60), TRUE, TRUE, TRUE);

INSERT INTO RLS VALUES (nextval('rls_id_seq'), 2, 1, NULL, 100, point(80, 80), 2);

INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:40.0', point(20, 60), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:50.0', point(25, 60), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:31:00.0', point(30, 60), TRUE, TRUE, TRUE);

INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:00.0', point(100, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:10.0', point(95, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:20.0', point(90, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:30.0', point(85, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:40.0', point(80, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:50.0', point(75, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:00.0', point(70, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:10.0', point(65, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:20.0', point(60, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:30.0', point(55, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:40.0', point(50, 1), TRUE, TRUE, TRUE);

INSERT INTO RLS VALUES (nextval('rls_id_seq'), 2, 1, NULL, 100, point(90, 90), 1);

INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:31:00.0', point(30, 60), TRUE, TRUE, TRUE);

INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:00.0', point(100, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:10.0', point(95, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:20.0', point(90, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:30.0', point(85, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:40.0', point(80, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:50.0', point(75, 1), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:00.0', point(70, 1), TRUE, TRUE, TRUE);

INSERT INTO RLS VALUES (nextval('rls_id_seq'), 2, 1, NULL, 100, point(120, 100), 2);

INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:00.0', point(120, 130), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:10.0', point(121, 131), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:20.0', point(122, 132), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:30.0', point(123, 133), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:40.0', point(124, 134), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:50.0', point(125, 135), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:00.0', point(126, 136), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:10.0', point(127, 137), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:20.0', point(128, 138), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:30.0', point(129, 139), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:40.0', point(130, 140), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:50.0', point(131, 141), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:31:00.0', point(132, 142), TRUE, TRUE, TRUE);

INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:00.0', point(90, 90), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:10.0', point(91, 89), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:20.0', point(92, 88), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:30.0', point(93, 87), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:40.0', point(94, 86), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:50.0', point(95, 85), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:00.0', point(96, 84), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:10.0', point(97, 83), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:20.0', point(98, 82), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:30.0', point(99, 81), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:40.0', point(100, 80), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:50.0', point(101, 79), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:31:00.0', point(102, 78), TRUE, TRUE, TRUE);


INSERT INTO RLS VALUES (nextval('rls_id_seq'), 2, 1, NULL, 100, point(140, 100), 1);

INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:00.0', point(120, 130), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:10.0', point(121, 131), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:20.0', point(122, 132), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:30.0', point(123, 133), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:40.0', point(124, 134), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:50.0', point(125, 135), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:00.0', point(126, 136), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:10.0', point(127, 137), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:20.0', point(128, 138), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:30.0', point(129, 139), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:40.0', point(130, 140), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:50.0', point(131, 141), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:31:00.0', point(132, 142), TRUE, TRUE, TRUE);

INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:00.0', point(90, 90), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:10.0', point(91, 89), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:20.0', point(92, 88), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:30.0', point(93, 87), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:40.0', point(94, 86), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:50.0', point(95, 85), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:00.0', point(96, 84), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:10.0', point(97, 83), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:20.0', point(98, 82), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:30.0', point(99, 81), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:40.0', point(100, 80), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:50.0', point(101, 79), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:31:00.0', point(102, 78), TRUE, TRUE, TRUE);

INSERT INTO RLS VALUES (nextval('rls_id_seq'), 2, 1, NULL, 100, point(140, 120), 2);

INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:00.0', point(120, 130), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:10.0', point(121, 131), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:20.0', point(122, 132), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:30.0', point(123, 133), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:40.0', point(124, 134), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:50.0', point(125, 135), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:00.0', point(126, 136), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:10.0', point(127, 137), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:20.0', point(128, 138), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:30.0', point(129, 139), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:40.0', point(130, 140), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:50.0', point(131, 141), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:31:00.0', point(132, 142), TRUE, TRUE, TRUE);

INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:00.0', point(90, 90), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:10.0', point(91, 89), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:20.0', point(92, 88), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:30.0', point(93, 87), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:40.0', point(94, 86), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:50.0', point(95, 85), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:00.0', point(96, 84), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:10.0', point(97, 83), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:20.0', point(98, 82), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:30.0', point(99, 81), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:40.0', point(100, 80), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:50.0', point(101, 79), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:31:00.0', point(102, 78), TRUE, TRUE, TRUE);

INSERT INTO RLS VALUES (nextval('rls_id_seq'), 2, 1, NULL, 70, point(140, 140), 1);

INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:00.0', point(120, 130), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:10.0', point(121, 131), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:20.0', point(122, 132), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:30.0', point(123, 133), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:40.0', point(124, 134), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:50.0', point(125, 135), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:00.0', point(126, 136), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:10.0', point(127, 137), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:20.0', point(128, 138), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:30.0', point(129, 139), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:40.0', point(130, 140), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:50.0', point(131, 141), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:31:00.0', point(132, 142), TRUE, TRUE, TRUE);

INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:00.0', point(90, 90), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:10.0', point(91, 89), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:20.0', point(92, 88), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:30.0', point(93, 87), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:40.0', point(94, 86), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:50.0', point(95, 85), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:00.0', point(96, 84), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:10.0', point(97, 83), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:20.0', point(98, 82), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:30.0', point(99, 81), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:40.0', point(100, 80), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:50.0', point(101, 79), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:31:00.0', point(102, 78), TRUE, TRUE, TRUE);

INSERT INTO RLS VALUES (nextval('rls_id_seq'), 2, 1, NULL, 60, point(80, 85), 2);

INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:40.0', point(20, 60), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:50.0', point(25, 60), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:31:00.0', point(30, 60), TRUE, TRUE, TRUE);

INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:00.0', point(90, 90), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:10.0', point(91, 89), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:20.0', point(92, 88), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:30.0', point(93, 87), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:40.0', point(94, 86), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:50.0', point(95, 85), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:00.0', point(96, 84), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:10.0', point(97, 83), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:20.0', point(98, 82), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:30.0', point(99, 81), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:40.0', point(100, 80), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:50.0', point(101, 79), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:31:00.0', point(102, 78), TRUE, TRUE, TRUE);

INSERT INTO RLS VALUES (nextval('rls_id_seq'), 11, NULL, 1, 100, point(100, 10), 1);

INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:00.0', point(1, 100), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:10.0', point(1, 95), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:20.0', point(1, 90), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:30.0', point(1, 85), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:40.0', point(1, 80), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:50.0', point(1, 75), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:00.0', point(1, 70), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:10.0', point(1, 65), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:20.0', point(1, 60), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:30.0', point(1, 55), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:40.0', point(1, 50), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:50.0', point(1, 45), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:31:00.0', point(1, 40), TRUE, TRUE, TRUE);

INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:00.0', point(1, 50), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:10.0', point(6, 45), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:20.0', point(10, 40), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:30.0', point(15, 35), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:40.0', point(20, 30), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:50.0', point(25, 35), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:00.0', point(20, 40), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:10.0', point(20, 45), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:20.0', point(20, 50), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:30.0', point(20, 55), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:40.0', point(20, 60), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:30.0', point(25, 60), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:31:00.0', point(30, 60), TRUE, TRUE, TRUE);

INSERT INTO RLS VALUES (nextval('rls_id_seq'), 11, NULL, 1, 100, point(100, 20), 2);

INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:00.0', point(1, 100), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:10.0', point(1, 95), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:20.0', point(1, 90), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:30.0', point(1, 85), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:40.0', point(1, 80), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:50.0', point(1, 75), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:00.0', point(1, 70), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:10.0', point(1, 65), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:20.0', point(1, 60), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:30.0', point(1, 55), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:40.0', point(1, 50), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:50.0', point(1, 45), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:31:00.0', point(1, 40), TRUE, TRUE, TRUE);

INSERT INTO RLS VALUES (nextval('rls_id_seq'), 11, NULL, 1, 100, point(90, 20), 1);

INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:00.0', point(1, 100), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:10.0', point(1, 95), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:20.0', point(1, 90), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:30.0', point(1, 85), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:40.0', point(1, 80), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:50.0', point(1, 75), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:00.0', point(1, 70), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:10.0', point(1, 65), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:20.0', point(1, 60), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:30.0', point(1, 55), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:40.0', point(1, 50), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:50.0', point(1, 45), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:31:00.0', point(1, 40), TRUE, TRUE, TRUE);

INSERT INTO RLS VALUES (nextval('rls_id_seq'), 11, NULL, 1, 80, point(90, 30), 2);

INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:40.0', point(20, 60), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:50.0', point(25, 60), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:31:00.0', point(30, 60), TRUE, TRUE, TRUE);

INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:00.0', point(1, 100), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:10.0', point(1, 95), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:20.0', point(1, 90), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:30.0', point(1, 85), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:40.0', point(1, 80), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:50.0', point(1, 75), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:00.0', point(1, 70), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:10.0', point(1, 65), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:20.0', point(1, 60), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:30.0', point(1, 55), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:40.0', point(1, 50), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:50.0', point(1, 45), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:31:00.0', point(1, 40), TRUE, TRUE, TRUE);

INSERT INTO RLS VALUES (nextval('rls_id_seq'), 11, NULL, 1, 80, point(80, 20), 1);

INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:00.0', point(1, 100), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:10.0', point(1, 95), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:20.0', point(1, 90), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:30.0', point(1, 85), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:40.0', point(1, 80), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:50.0', point(1, 75), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:00.0', point(1, 70), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:10.0', point(1, 65), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:20.0', point(1, 60), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:30.0', point(1, 55), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:40.0', point(1, 50), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:50.0', point(1, 45), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:31:00.0', point(1, 40), TRUE, TRUE, TRUE);

INSERT INTO RLS VALUES (nextval('rls_id_seq'), 7, NULL, 2, 100, point(110, 20), 2);

INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:00.0', point(1, 100), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:10.0', point(1, 95), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:20.0', point(1, 90), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:30.0', point(1, 85), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:40.0', point(1, 80), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:50.0', point(1, 75), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:00.0', point(1, 70), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:10.0', point(1, 65), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:20.0', point(1, 60), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:30.0', point(1, 55), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:40.0', point(1, 50), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:50.0', point(1, 45), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:31:00.0', point(1, 40), TRUE, TRUE, TRUE);

INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:00.0', point(90, 90), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:10.0', point(91, 89), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:20.0', point(92, 88), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:30.0', point(93, 87), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:40.0', point(94, 86), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:50.0', point(95, 85), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:00.0', point(96, 84), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:10.0', point(97, 83), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:20.0', point(98, 82), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:30.0', point(99, 81), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:40.0', point(100, 80), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:50.0', point(101, 79), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:31:00.0', point(102, 78), TRUE, TRUE, TRUE);

INSERT INTO RLS VALUES (nextval('rls_id_seq'), 7, NULL, 2, 100, point(90, 40), 1);

INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:00.0', point(1, 100), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:10.0', point(1, 95), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:20.0', point(1, 90), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:30.0', point(1, 85), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:40.0', point(1, 80), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:50.0', point(1, 75), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:00.0', point(1, 70), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:10.0', point(1, 65), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:20.0', point(1, 60), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:30.0', point(1, 55), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:40.0', point(1, 50), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:50.0', point(1, 45), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:31:00.0', point(1, 40), TRUE, TRUE, TRUE);

INSERT INTO RLS VALUES (nextval('rls_id_seq'), 7, NULL, 2, 100, point(70, 30), 2);

INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:00.0', point(1, 100), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:10.0', point(1, 95), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:20.0', point(1, 90), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:30.0', point(1, 85), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:40.0', point(1, 80), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:50.0', point(1, 75), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:00.0', point(1, 70), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:10.0', point(1, 65), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:20.0', point(1, 60), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:30.0', point(1, 55), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:40.0', point(1, 50), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:50.0', point(1, 45), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:31:00.0', point(1, 40), TRUE, TRUE, TRUE);

INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:00.0', point(1, 50), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:20.0', point(10, 40), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:40.0', point(20, 30), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:00.0', point(20, 40), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:20.0', point(20, 50), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:40.0', point(20, 60), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:31:00.0', point(30, 60), TRUE, TRUE, TRUE);

INSERT INTO RLS VALUES (nextval('rls_id_seq'), 7, NULL, 2, 80, point(50, 40), 1);

INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:00.0', point(1, 50), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:10.0', point(6, 45), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:20.0', point(10, 40), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:30.0', point(15, 35), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:40.0', point(20, 30), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:50.0', point(25, 35), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:00.0', point(20, 40), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:10.0', point(20, 45), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:20.0', point(20, 50), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:30.0', point(20, 55), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:40.0', point(20, 60), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:30.0', point(25, 60), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:31:00.0', point(30, 60), TRUE, TRUE, TRUE);

INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:40.0', point(1, 80), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:50.0', point(1, 75), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:00.0', point(1, 70), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:10.0', point(1, 65), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:20.0', point(1, 60), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:30.0', point(1, 55), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:40.0', point(1, 50), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:50.0', point(1, 45), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:31:00.0', point(1, 40), TRUE, TRUE, TRUE);

INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:20.0', point(1, 60), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:30.0', point(1, 55), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:40.0', point(1, 50), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:50.0', point(1, 45), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:31:00.0', point(1, 40), TRUE, TRUE, TRUE);

INSERT INTO RLS VALUES (nextval('rls_id_seq'), 7, NULL, 2, 80, point(20, 20), 2);

INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:00.0', point(1, 50), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:10.0', point(6, 45), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:20.0', point(10, 40), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:30.0', point(15, 35), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:40.0', point(20, 30), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:50.0', point(25, 35), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:00.0', point(20, 40), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:10.0', point(20, 45), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:20.0', point(20, 50), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:30.0', point(20, 55), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:40.0', point(20, 60), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:30.0', point(25, 60), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:31:00.0', point(30, 60), TRUE, TRUE, TRUE);

INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:00.0', point(1, 100), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:10.0', point(1, 95), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:20.0', point(1, 90), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:30.0', point(1, 85), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:40.0', point(1, 80), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:50.0', point(1, 75), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:00.0', point(1, 70), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:10.0', point(1, 65), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:20.0', point(1, 60), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:30.0', point(1, 55), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:40.0', point(1, 50), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:50.0', point(1, 45), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:31:00.0', point(1, 40), TRUE, TRUE, TRUE);

INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:40.0', point(1, 80), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:29:50.0', point(1, 75), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:00.0', point(1, 70), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:10.0', point(1, 65), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:20.0', point(1, 60), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:30.0', point(1, 55), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:40.0', point(1, 50), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:30:50.0', point(1, 45), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (nextval('target_id_seq'), currval('rls_id_seq'), '2018-05-18 14:31:00.0', point(1, 40), TRUE, TRUE, TRUE);

\echo �������
\echo ��������� ��� reader1
\c - reader1
\echo ������� ��� �� ���������������� ����������
DROP VIEW v_radio_batallions;
CREATE VIEW v_radio_batallions AS
SELECT name, p FROM MP_radio_batallion, AMS WHERE MP_radio_batallion.ams_id=AMS.id;
SELECT * FROM v_radio_batallions;
\echo ������� ��� �� ���������������� ���
SELECT name, p FROM MP_radio_rota, AMS WHERE MP_radio_rota.ams_id=AMS.id;
\echo ������� ��� ���
SELECT name, p, state from RLS,RLS_models WHERE RLS.model_id=RLS_models.id;
\echo ������� ��� �� ���������������� ��� � ������������ �� �� ����������������� ���������
SELECT radio_rota_p,
       name as radio_rota_ams_name,
       radio_batallion_p,
       radio_batallion_ams_name,
       radio_rota_p <-> radio_batallion_p as distance FROM AMS
    INNER JOIN
    (SELECT MP_radio_rota.id as radio_rota_id,
           MP_radio_rota.ams_id as radio_rota_ams_id,
           MP_radio_rota.p as radio_rota_p,
           tbl_radio_batallions.radio_batallion_id,
           tbl_radio_batallions.p as radio_batallion_p,
           tbl_radio_batallions.name as radio_batallion_ams_name
           FROM MP_radio_rota,
           (SELECT MP_radio_batallion.id as radio_batallion_id,
                   ams_id,
                   radio_brigade_id,
                   p,
                   name
                   FROM MP_radio_batallion,AMS WHERE MP_radio_batallion.ams_id=AMS.id) as tbl_radio_batallions
            WHERE MP_radio_rota.radio_batallion_id=tbl_radio_batallions.radio_batallion_id) as tbl_rotas_batallion
    ON(AMS.id=tbl_rotas_batallion.radio_rota_ams_id);
\echo ������� ��� �� ���������������� ��� � �������������� ��� ��� � ������������ �� ���
DROP VIEW v_rls_es;
CREATE VIEW v_rls_es AS
SELECT MP_radio_rota.p as rota_p,
       AMS.name as rota_ams_name,
       RLS.p as rls_p,
       RLS_models.name as rls_name,
       MP_radio_rota.p <-> RLS.p as distance
       FROM MP_radio_rota,AMS,RLS,RLS_models
       WHERE MP_radio_rota.ams_id=AMS.id
         AND RLS.radio_rota_id=MP_radio_rota.id
         AND RLS.model_id=RLS_models.id;
SELECT * FROM v_rls_es;
\echo ������� ������������� �������� �� ����������������� ��������� ��� � ������������ �� ���
DROP VIEW v_rls_es_kprtb;
CREATE VIEW v_rls_es_kprtb AS
SELECT rls_p, name as rls_name, radio_batallion_p, radio_batallion_name, rls_p <-> radio_batallion_p as distance FROM RLS_models
    INNER JOIN
    (SELECT model_id, p as rls_p, name as radio_batallion_name, radio_batallion_p FROM RLS
        INNER JOIN
        (SELECT name, p as radio_batallion_p, id as radio_batallion_id2
            FROM MP_radio_batallion
            INNER JOIN
            (SELECT id as ams_id2,name FROM AMS) AS AMS
            ON MP_radio_batallion.ams_id=AMS.ams_id2) AS RAD_BAT
        ON RAD_BAT.radio_batallion_id2=RLS.radio_batallion_id) AS RLSES
    ON RLSES.model_id=RLS_models.id;
SELECT * FROM v_rls_es_kprtb;
\echo ������� ��������� ������������ ���� ������ ���
SELECT *
       FROM target main
       WHERE main.t = (SELECT max(target.t) AS max_data
       FROM target
       WHERE target.rls_id=main.rls_id);
\echo ������� ������������ � ������ ������ ���� � ������������ �� ���
SELECT
    RLS.p AS rls_p,
    tbl_rls_target.p as target_p,
    RLS.p <-> tbl_rls_target.p as distance,
    tbl_rls_target.t,
    tbl_rls_target.group_t,
    tbl_rls_target.maneuvering,
    tbl_rls_target.important
    FROM RLS
    INNER JOIN
    (SELECT *
        FROM target main
        WHERE main.t = (SELECT max(target.t) AS max_data
        FROM target
        WHERE target.rls_id=main.rls_id)) AS tbl_rls_target
    ON (RLS.id=tbl_rls_target.rls_id);
\echo ������� ��� ������ ���� ��������� ��� � ������ ������ �������
CREATE VIEW v_rls_target_dst AS
SELECT
    RLS.p AS rls_p,
    RLS.change,
    tbl_rls_target.p as target_p,
    RLS.p <-> tbl_rls_target.p as distance,
    tbl_rls_target.t,
    tbl_rls_target.group_t,
    tbl_rls_target.maneuvering,
    tbl_rls_target.important
    FROM RLS
    INNER JOIN
    (SELECT *
        FROM target main
        WHERE main.t = (SELECT max(target.t) AS max_data
        FROM target
        WHERE target.rls_id=main.rls_id)) AS tbl_rls_target
    ON (RLS.id=tbl_rls_target.rls_id);
SELECT target_p, rls_p, distance, t, group_t, maneuvering, important, 100*dangerousness(1/distance, group_t, maneuvering, important) as danger
    FROM v_rls_target_dst main
    WHERE main.distance = (SELECT min(v_rls_target_dst.distance) AS min_data
        FROM v_rls_target_dst
        WHERE v_rls_target_dst.target_p~=main.target_p);
