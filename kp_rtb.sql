-- Создание таблиц
DROP TABLE MP_radio_batallion;
CREATE TABLE MP_radio_batallion (
	ID_MP_rb serial NOT NULL,
    ID_AMS integer NOT NULL,
	ID_MP_radio_brigade integer NOT NULL,
    p point NOT NULL,
	PRIMARY KEY (ID_MP_rb)
);

DROP TABLE AMS;
CREATE TABLE AMS (
    ID_AMS serial NOT NULL,
    name text NOT NULL,
    max_num_of_targs integer NOT NULL,
    PRIMARY KEY (ID_AMS)
);

DROP TABLE RLS;
CREATE TABLE RLS (
	ID_RLS serial NOT NULL,
	state integer NOT NULL,
	model_RLS integer NOT NULL,
	ID_MP_rb integer,
	ID_MP_rr integer,
    p point NOT NULL,
	PRIMARY KEY (ID_RLS)
);

DROP TABLE target;
CREATE TABLE target (
	ID_target serial NOT NULL,
    t timestamp NOT NULL,
    ID_RLS integer NOT NULL,
	p point NOT NULL,
	group_t BOOLEAN NOT NULL,
	maneuvering BOOLEAN NOT NULL,
	important BOOLEAN NOT NULL,
	PRIMARY KEY (ID_target)
);

DROP TABLE MP_radio_rota;
CREATE TABLE MP_radio_rota (
	ID_MP_rr serial NOT NULL,
	MP_rb integer NOT NULL,
    p point NOT NULL,
    object BOOLEAN NOT NULL,
    ID_AMS integer NOT NULL,
	PRIMARY KEY (ID_MP_rr)
);

DROP TABLE MP_radio_brigade;
CREATE TABLE MP_radio_brigade (
	ID_MP_radio_brigade serial NOT NULL,
    p point NOT NULL,
    ID_AMS integer NOT NULL,
	state integer NOT NULL,
	PRIMARY KEY (ID_MP_radio_brigade)
);

DROP TABLE RLS_models;
CREATE TABLE RLS_models (
	ID_RLS_model serial NOT NULL,
    name text NOT NULL,
	distance_limit_km integer NOT NULL,
	height_limit_km integer NOT NULL,
	distance_accuracy_m integer NOT NULL,
	PRIMARY KEY (ID_RLS_model)
);

-- Заполнение тестовыми данными
INSERT INTO AMS VALUES (1, 'Фундамент-2Э', 200);
INSERT INTO AMS VALUES (2, 'Фундамент-1Э', 120);
INSERT INTO AMS VALUES (3, 'ПОРИ-П1МЭ', 250);
INSERT INTO AMS VALUES (4, 'Фундамент-3Э', 300);

INSERT INTO MP_radio_brigade VALUES (1, point(50, 50), 4, 90);

INSERT INTO MP_radio_batallion VALUES (1, 1, 1, point(40, 30));

INSERT INTO MP_radio_rota VALUES (1, 1, point(100, 110), TRUE, 2);
INSERT INTO MP_radio_rota VALUES (2, 1, point(110, 110), FALSE, 3);

INSERT INTO RLS_models VALUES (1, 'Противник-ГЕ', 250, 200, 100);
INSERT INTO RLS_models VALUES (2, 'Небо', 1200, 75, 400);
INSERT INTO RLS_models VALUES (3, 'Небо-УЕ', 400, 70, 120);
INSERT INTO RLS_models VALUES (4, 'Гамма-ДЕ', 200, 60, 80);
INSERT INTO RLS_models VALUES (5, 'Десна-М', 300, 20, 300);
INSERT INTO RLS_models VALUES (6, 'Каста-2Е1', 70, 6, 300);
INSERT INTO RLS_models VALUES (7, 'Каста-2Е2', 70, 6, 100);
INSERT INTO RLS_models VALUES (8, 'Гамма-Д1Е', 200, 120, 80);
INSERT INTO RLS_models VALUES (9, 'Гамма-Д2Е', 200, 120, 80);
INSERT INTO RLS_models VALUES (10, 'Гамма-Д3Е', 200, 120, 80);
INSERT INTO RLS_models VALUES (11, 'Гамма-С1Е', 150, 10, 50);
INSERT INTO RLS_models VALUES (12, 'Резонанс-НЭ', 400, 100, 300);
INSERT INTO RLS_models VALUES (13, 'Кольцо', 150, 35, 40);
INSERT INTO RLS_models VALUES (14, 'Валерия', 250, 35, 500);

INSERT INTO RLS VALUES (1, 100, 1, 1, NULL, point(0, 0));
INSERT INTO RLS VALUES (2, 100, 1, 1, NULL, point(0, 100));
INSERT INTO RLS VALUES (3, 90, 1, 1, NULL, point(50, 50));
INSERT INTO RLS VALUES (4, 80, 1, 1, NULL, point(30, 30));
INSERT INTO RLS VALUES (5, 70, 1, 1, NULL, point(60, 60));
INSERT INTO RLS VALUES (6, 100, 2, 1, NULL, point(80, 80));
INSERT INTO RLS VALUES (7, 100, 2, 1, NULL, point(90, 90));
INSERT INTO RLS VALUES (8, 100, 2, 1, NULL, point(120, 100));
INSERT INTO RLS VALUES (9, 100, 2, 1, NULL, point(140, 100));
INSERT INTO RLS VALUES (10, 100, 2, 1, NULL, point(140, 120));
INSERT INTO RLS VALUES (11, 70, 2, 1, NULL, point(140, 140));
INSERT INTO RLS VALUES (12, 60, 2, 1, NULL, point(80, 85));
INSERT INTO RLS VALUES (13, 100, 11, NULL, 1, point(100, 10));
INSERT INTO RLS VALUES (14, 100, 11, NULL, 1, point(100, 20));
INSERT INTO RLS VALUES (15, 100, 11, NULL, 1, point(90, 20));
INSERT INTO RLS VALUES (16, 80, 11, NULL, 1, point(90, 30));
INSERT INTO RLS VALUES (17, 80, 11, NULL, 1, point(80, 20));
INSERT INTO RLS VALUES (18, 100, 7, NULL, 2, point(110, 20));
INSERT INTO RLS VALUES (19, 100, 7, NULL, 2, point(90, 30));
INSERT INTO RLS VALUES (20, 100, 7, NULL, 2, point(70, 30));
INSERT INTO RLS VALUES (21, 80, 7, NULL, 2, point(50, 40));
INSERT INTO RLS VALUES (22, 80, 7, NULL, 2, point(20, 20));

DROP TRIGGER target_detection ON target;
DROP FUNCTION target_detection();
CREATE FUNCTION target_detection() RETURNS trigger
    AS '
        DECLARE
            dist double precision := 0.0;
        BEGIN
            RAISE NOTICE ''Notification %'', dist;
            RETURN NEW;
        END;
    '
    LANGUAGE plpgsql;
CREATE TRIGGER target_detection BEFORE INSERT ON target
    FOR EACH ROW EXECUTE PROCEDURE target_detection();

INSERT INTO target VALUES (1, '2018-05-18 14:29:00.0', 8, point(120, 130), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (2, '2018-05-18 14:29:20.0', 8, point(121, 131), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (3, '2018-05-18 14:29:40.0', 8, point(122, 132), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (4, '2018-05-18 14:30:00.0', 8, point(123, 133), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (5, '2018-05-18 14:30:20.0', 8, point(124, 134), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (6, '2018-05-18 14:30:40.0', 8, point(125, 135), TRUE, TRUE, TRUE);
INSERT INTO target VALUES (7, '2018-05-18 14:31:00.0', 8, point(126, 136), TRUE, TRUE, TRUE);

-- Запросы
SELECT name, p from MP_radio_batallion, AMS WHERE MP_radio_batallion.id_ams=AMS.id_ams;
SELECT name, p FROM MP_radio_rota, AMS WHERE MP_radio_rota.id_ams=AMS.id_ams;
SELECT name, p, state from RLS,RLS_models WHERE RLS.model_rls=RLS_models.id_rls_model;
SELECT MP_radio_batallion.p as batallion_p,
       AMS_PAR.name as battalion_ams_name,
       MP_radio_rota.p as rota_p,
       AMS_CHILD.name as rota_ams_name,
       MP_radio_batallion.p <-> MP_radio_rota.p as distance
       FROM MP_radio_batallion,MP_radio_rota,AMS as AMS_PAR,AMS as AMS_CHILD
       WHERE MP_radio_batallion.ID_MP_rb=MP_radio_rota.mp_rb
         AND AMS_PAR.ID_AMS=MP_radio_batallion.ID_AMS
         AND AMS_CHILD.ID_AMS=MP_radio_rota.ID_AMS;
SELECT MP_radio_rota.p as rota_p,
       AMS.name as rota_ams_name,
       RLS.p as rls_p,
       RLS_models.name as rls_name,
       MP_radio_rota.p <-> RLS.p as distance
       FROM MP_radio_rota,AMS,RLS,RLS_models
       WHERE MP_radio_rota.ID_AMS=AMS.ID_AMS
         AND RLS.ID_MP_rr=MP_radio_rota.ID_MP_rr
         AND RLS.model_rls=RLS_models.ID_RLS_model;
SELECT *
       FROM target;
