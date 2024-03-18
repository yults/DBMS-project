--проверка что нет 2 игроков в команде с одинаковыми футболками
CREATE OR REPLACE FUNCTION check_unique_tshort_number() RETURNS TRIGGER AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM TeamMembershipHistory
        WHERE TeamID = NEW.TeamID
        AND PlayerNumber = NEW.PlayerNumber
        AND PlayerID != NEW.PlayerID
        AND (LeaveDate IS NULL OR LeaveDate > NEW.JoinDate)
    ) THEN
        RAISE EXCEPTION 'В команде % уже есть игрок с номером футболки %', NEW.TeamID, NEW.PlayerNumber;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_unique_tshort_number_before_insert
BEFORE INSERT OR UPDATE ON TeamMembershipHistory
FOR EACH ROW EXECUTE FUNCTION check_unique_tshort_number();

-- Вставка нового игрока в команду 
-- insert_player_in_team
START TRANSACTION ISOLATION LEVEL READ COMMITTED;
INSERT INTO Player (PlayerID, Name, Nationality, Birthdate)
VALUES (101, 'Плеер Плеерович', 'Россия', '2000-01-01');
INSERT INTO TeamMembershipHistory (HistoryMembershipID, PlayerID, TeamID, PlayerNumber, JoinDate)
VALUES (101, 101, 4, 54, '2023-01-01');
COMMIT;

-- Изменение номера игрока на футболке
-- update_player_number_in_team
START TRANSACTION ISOLATION LEVEL READ COMMITTED;
UPDATE TeamMembershipHistory
SET PlayerNumber = 21
WHERE PlayerID = 101 AND TeamID = 4;
COMMIT;

-- проверка при добавлении события, что игрок был членом участующей команды во время матча
CREATE OR REPLACE FUNCTION check_player_team_match() RETURNS TRIGGER AS $$
DECLARE
    match_date TIMESTAMP;
BEGIN
    SELECT DateTime INTO match_date FROM Match WHERE MatchID = NEW.MatchID;
    IF NOT EXISTS (
        SELECT 1
        FROM TeamMembershipHistory tmh
        WHERE tmh.PlayerID = NEW.PlayerID
        AND tmh.JoinDate <= match_date
        AND (tmh.LeaveDate IS NULL OR tmh.LeaveDate > match_date)
        AND EXISTS (
            SELECT 1
            FROM MatchParticipation mp
            WHERE mp.MatchID = NEW.MatchID
            AND mp.TeamID = tmh.TeamID
        )
    ) THEN
        RAISE EXCEPTION 'Игрок с ID % должен быть частью команды, участвующей в матче с ID %', NEW.PlayerID, NEW.MatchID;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_player_team_match_before_insert
BEFORE INSERT ON EventLog
FOR EACH ROW EXECUTE FUNCTION check_player_team_match();

-- Добавление события в матч
-- insert_in_match_event
START TRANSACTION ISOLATION LEVEL SERIALIZABLE;
INSERT INTO EventLog (EventID, MatchID, EventType, EventTime, PlayerID)
VALUES (101, 1, 'goal', 15, 101);
COMMIT;

--проверка что сумма очков поделенна между двумя командами и равна 3
--что одна команда не участовует в матче сама с собой
--и в матче участвует не более 2ух команд
CREATE OR REPLACE FUNCTION check_match_participation() RETURNS TRIGGER AS $$
DECLARE
    existing_scores INT;
BEGIN
    SELECT COUNT(*) INTO existing_scores FROM MatchParticipation WHERE MatchID = NEW.MatchID;
    IF EXISTS (
        SELECT 1 FROM MatchParticipation WHERE MatchID = NEW.MatchID AND TeamID = NEW.TeamID
    ) THEN
        RAISE EXCEPTION 'Команда с ID % уже зарегистрирована в матче с ID %.', NEW.TeamID, NEW.MatchID;
    END IF;
    IF existing_scores >= 2 THEN
        RAISE EXCEPTION 'В матче с ID % уже участвуют две команды.', NEW.MatchID;
    END IF;
    IF NEW.ScoreTeam IS NOT NULL AND existing_scores > 0 THEN
        IF NEW.ScoreTeam + (SELECT COALESCE(SUM(ScoreTeam), 0) FROM MatchParticipation WHERE MatchID = NEW.MatchID) != 3 THEN
            RAISE EXCEPTION 'Общее количество очков в матче с ID % должно равняться 3.', NEW.MatchID;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_match_participation_before_insert
BEFORE INSERT ON MatchParticipation
FOR EACH ROW EXECUTE FUNCTION check_match_participation();

-- Вставка участия команды в матче
-- insert_match_participation
START TRANSACTION ISOLATION LEVEL SERIALIZABLE;
INSERT INTO Match (MatchID, TournamentID, DateTime) 
VALUES (14, 7, '2024-02-17 14:00');
INSERT INTO MatchParticipation (MatchID, TeamID, ScoreTeam)
VALUES (14, 1, 2);
INSERT INTO MatchParticipation (MatchID, TeamID, ScoreTeam)
VALUES (14, 2, 1);
COMMIT;

--проверка что в рамках одного турнира не идут 2 матча в одно и то же время
CREATE OR REPLACE FUNCTION check_match_timing() RETURNS TRIGGER AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM Match
        WHERE TournamentID = NEW.TournamentID
        AND DateTime = NEW.DateTime
        AND MatchID != COALESCE(NEW.MatchID, 0)
    ) THEN
        RAISE EXCEPTION 'В рамках одного турнира не могут проходить два матча в одно и то же время.';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_match_timing_before_insert
BEFORE INSERT ON Match
FOR EACH ROW EXECUTE FUNCTION check_match_timing();

CREATE TRIGGER check_match_timing_before_update
BEFORE UPDATE ON Match
FOR EACH ROW EXECUTE FUNCTION check_match_timing();

-- Обновление времени матча 
-- update_match_datetime
START TRANSACTION ISOLATION LEVEL READ COMMITTED;
UPDATE Match
SET DateTime = '2023-02-02 15:00:00'
WHERE MatchID = 5;
COMMIT;

--проверка на вступление дважды в одну команду одним игроком в один и тот же день
CREATE OR REPLACE FUNCTION check_duplicate_membership() RETURNS TRIGGER AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM TeamMembershipHistory
        WHERE PlayerID = NEW.PlayerID
        AND TeamID = NEW.TeamID
        AND JoinDate = NEW.JoinDate
    ) THEN
        RAISE EXCEPTION 'Игрок не может вступить в одну и ту же команду дважды в один день.';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_duplicate_membership_before_insert
BEFORE INSERT ON TeamMembershipHistory
FOR EACH ROW EXECUTE FUNCTION check_duplicate_membership();

-- Уход игрока из команды сегодня
-- leave_team_today
START TRANSACTION  ISOLATION LEVEL READ COMMITTED;
UPDATE TeamMembershipHistory
SET LeaveDate = CURRENT_DATE
WHERE PlayerID = 101 AND TeamID = 4 AND LeaveDate IS NULL;
COMMIT;

-- Отмена матча
-- cancel_match
START TRANSACTION ISOLATION LEVEL SERIALIZABLE;
DELETE FROM EventLog
WHERE MatchID = 14;
DELETE FROM MatchParticipation
WHERE MatchID = 14;
DELETE FROM Match
WHERE MatchID = 14;
COMMIT;

--Процедура по отклонениям заявок которые подали не участвовшие в отборах или проваливших их(нижняя строчка таблицы)
CREATE OR REPLACE PROCEDURE RejectTournamentApplications(parent_tournament_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    team_record RECORD;
    last_place INT;
BEGIN
    FOR team_record IN
        SELECT TP.TeamID
        FROM TournamentParticipation TP
        WHERE TP.TournamentID = parent_tournament_id AND TP.Status = 'В рассмотрении'
    LOOP
        IF NOT EXISTS (
            SELECT 1 FROM MatchParticipation MP
            JOIN Match M ON MP.MatchID = M.MatchID
            JOIN Tournament T ON M.TournamentID = T.TournamentID
            WHERE T.ParentTournamentID = parent_tournament_id AND MP.TeamID = team_record.TeamID
        ) THEN
            UPDATE TournamentParticipation
            SET Status = 'Заявка отклонена'
            WHERE TournamentID = parent_tournament_id AND TeamID = team_record.TeamID;
        ELSE
            FOR team_record IN
                SELECT MP.TeamID, SUM(MP.ScoreTeam) as TotalPoints
                FROM MatchParticipation MP
                JOIN Match M ON MP.MatchID = M.MatchID
                WHERE M.TournamentID IN (SELECT TournamentID FROM Tournament WHERE ParentTournamentID = parent_tournament_id)
                AND MP.TeamID = team_record.TeamID
                GROUP BY MP.TeamID
            LOOP
                SELECT INTO last_place COUNT(DISTINCT MP.TeamID)
                FROM MatchParticipation MP
                JOIN Match M ON MP.MatchID = M.MatchID
                WHERE M.TournamentID IN (SELECT TournamentID FROM Tournament WHERE ParentTournamentID = parent_tournament_id);

                IF team_record.TotalPoints <= ALL (
                    SELECT SUM(MP.ScoreTeam)
                    FROM MatchParticipation MP
                    JOIN Match M ON MP.MatchID = M.MatchID
                    WHERE M.TournamentID IN (SELECT TournamentID FROM Tournament WHERE ParentTournamentID = parent_tournament_id)
                    GROUP BY MP.TeamID
                    HAVING COUNT(DISTINCT MP.TeamID) = last_place
                ) THEN
                    UPDATE TournamentParticipation
                    SET Status = 'Заявка отклонена'
                    WHERE TournamentID = parent_tournament_id AND TeamID = team_record.TeamID;
                END IF;
            END LOOP;
        END IF;
    END LOOP;
END;
$$;


--отклонить заявки по первому турниру
START TRANSACTION ISOLATION LEVEL REPEATABLE READ;
CALL RejectTournamentApplications(1);
COMMIT;