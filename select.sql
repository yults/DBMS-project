-- Текущий состав всех команд
-- todays_teams_participants
SELECT T.Name AS TeamName, P.Name AS PlayerName
FROM TeamMembershipHistory TMH
JOIN Team T ON TMH.TeamID = T.TeamID
JOIN Player P ON TMH.PlayerID = P.PlayerID
WHERE (TMH.LeaveDate IS NULL OR TMH.LeaveDate > CURRENT_DATE)
AND TMH.JoinDate <= CURRENT_DATE
ORDER BY T.Name, P.Name;

-- Очки в турнирной таблице
-- tournaments_score_table
SELECT t.TournamentName, tm.Name AS TeamName, tm.Hometown, SUM(mp.ScoreTeam) AS TotalPoints
FROM MatchParticipation mp
JOIN Team tm ON mp.TeamID = tm.TeamID
JOIN Match m ON mp.MatchID = m.MatchID
JOIN Tournament t ON m.TournamentID = t.TournamentID
GROUP BY t.TournamentName, tm.Name, tm.Hometown
ORDER BY t.TournamentName, TotalPoints DESC;

-- Подсчет побед и поражений каждой команды за ее существование без учета матчей с неизвестным результатом
-- team_total_win_loses
SELECT tm.Name AS TeamName, tm.Hometown,
    COUNT(CASE WHEN COALESCE(mp.ScoreTeam, -1) = 3 THEN 1 END) AS "WinsInMainTime",
    COUNT(CASE WHEN COALESCE(mp.ScoreTeam, -1) = 2 THEN 1 END) AS "WinsInPenalties",
    COUNT(CASE WHEN COALESCE(mp.ScoreTeam, -1) = 1 THEN 1 END) AS "LossesInPenalties",
    COUNT(CASE WHEN COALESCE(mp.ScoreTeam, -1) = 0 THEN 1 END) AS "LossesInMainTime"
FROM MatchParticipation mp
JOIN Team tm ON mp.TeamID = tm.TeamID
GROUP BY tm.Name, tm.Hometown;

-- Количество игр в турнире
-- tournaments_match_cnt
SELECT t.TournamentName, COUNT(*) as CntOfMatches
FROM Match m
JOIN Tournament t ON m.TournamentID = t.TournamentID
GROUP BY t.TournamentName;

-- Процент реализации пенальти
-- player_penalty_percent
SELECT p.Name, ROUND((COUNT(CASE WHEN el.EventType = 'success penalty' THEN 1 END) * 100.0 / COUNT(*)), 1) as PenaltySuccessRate
FROM EventLog el
JOIN Player p ON el.PlayerID = p.PlayerID
WHERE el.EventType IN ('success penalty', 'fail penalty')
GROUP BY p.PlayerID
ORDER BY PenaltySuccessRate DESC;

-- Список игроков с наибольшим количеством карточек
-- player_cards
SELECT p.Name, 
       COUNT(CASE WHEN el.EventType = 'yellow card' THEN 1 END) as YellowCards,
       COUNT(CASE WHEN el.EventType = 'red card' THEN 1 END) as RedCards
FROM EventLog el
JOIN Player p ON el.PlayerID = p.PlayerID
WHERE el.EventType IN ('yellow card', 'red card')
GROUP BY p.PlayerID
ORDER BY YellowCards DESC, RedCards DESC;

-- NOTE: Мало запросов

-- Список игроков, не получавших карточек
-- player_cards_without
SELECT P.Name 
FROM Player P
WHERE P.PlayerID NOT IN (SELECT PlayerID FROM EventLog WHERE EventType IN ('yellow card', 'red card'))
ORDER BY P.Name;

-- Средний возраст игроков команды 
-- avg_team_age
SELECT T.Name AS "Команда", AVG(EXTRACT(YEAR FROM AGE(CURRENT_DATE, P.Birthdate))) AS "Средний Возраст"
FROM Player P
JOIN TeamMembershipHistory TMH ON P.PlayerID = TMH.PlayerID
JOIN Team T ON TMH.TeamID = T.TeamID
GROUP BY T.Name
ORDER BY "Средний Возраст" DESC;

-- Получение по текущему этапу, какой будет следующим
-- tournament_next_stage
SELECT child.TournamentName AS "Турнир", parent.TournamentName AS "Следующий этап"
FROM Tournament child
LEFT JOIN Tournament parent ON child.ParentTournamentID = parent.TournamentID
ORDER BY child.TournamentID;

-- Все матчи команды "Спартак"
-- spartak_matches
SELECT M.MatchID, T.TournamentName, M.DateTime
FROM Match M
JOIN Tournament T ON M.TournamentID = T.TournamentID
JOIN MatchParticipation MP ON M.MatchID = MP.MatchID
WHERE MP.TeamID = (SELECT TeamID FROM Team WHERE Name = 'ПФК "Спартак"')
ORDER BY M.DateTime;

-- Результаты всех матчей в Лиге России
-- russian_leaque_results
SELECT M.MatchID, MP.TeamID, MP.ScoreTeam AS "Очки", T.Name AS "Команда"
FROM MatchParticipation MP
JOIN Match M ON MP.MatchID = M.MatchID
JOIN Team T ON MP.TeamID = T.TeamID
WHERE M.TournamentID = (SELECT TournamentID FROM Tournament WHERE TournamentName = 'Лига России 2024')
ORDER BY M.MatchID, MP.ScoreTeam DESC;

-- Количество матчей, сыгранных каждой командой
-- team_matches_cnt
SELECT T.Name AS "Команда", COUNT(*) AS "Количество Матчей"
FROM MatchParticipation MP
JOIN Team T ON MP.TeamID = T.TeamID
GROUP BY T.Name
ORDER BY "Количество Матчей" DESC;

-- Топ-3 по последней смене состава
-- top_chages_team_membership
SELECT T.Name AS "Команда", 
 COALESCE(MAX(TMH.LeaveDate), MAX(TMH.JoinDate), CURRENT_DATE) AS "Последняя Смена Состава"
FROM TeamMembershipHistory TMH
JOIN Team T ON TMH.TeamID = T.TeamID
GROUP BY T.Name
ORDER BY "Последняя Смена Состава" ASC, T.Name
LIMIT 3;

-- Игроки, которые пришли в команду в текущем году
-- this_year_team_new_players
SELECT P.Name AS "Игрок", T.Name AS "Новая команда", TMH.JoinDate
FROM TeamMembershipHistory TMH
JOIN Team T ON TMH.TeamID = T.TeamID
JOIN Player P ON TMH.PlayerID = P.PlayerID
WHERE EXTRACT(YEAR FROM TMH.JoinDate) = EXTRACT(YEAR FROM CURRENT_DATE)
ORDER BY TMH.JoinDate;

-- Матчи за последний месяц с 1 числа текущего
-- this_month_matches
SELECT M.MatchID, T.TournamentName, M.DateTime
FROM Match M
JOIN Tournament T ON M.TournamentID = T.TournamentID
WHERE M.DateTime >= DATE_TRUNC('month', CURRENT_DATE) AND M.DateTime < DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month'
ORDER BY M.DateTime;

-- Продожительность участия игроков в командах
-- membership_lenght
SELECT P.Name AS "Игрок", T.Name AS "Команда", TMH.JoinDate, TMH.LeaveDate,
       COALESCE(TMH.LeaveDate, CURRENT_DATE) - TMH.JoinDate AS "Продолжительность"
FROM TeamMembershipHistory TMH
JOIN Team T ON TMH.TeamID = T.TeamID
JOIN Player P ON TMH.PlayerID = P.PlayerID
ORDER BY "Продолжительность" DESC;

-- Топ-5 матчей с наибольшим количеством событий
-- eventiest_matches
SELECT M.MatchID, T.TournamentName, COUNT(E.EventID) AS "Количество событий"
FROM EventLog E
JOIN Match M ON E.MatchID = M.MatchID
JOIN Tournament T ON M.TournamentID = T.TournamentID
GROUP BY M.MatchID, T.TournamentName
ORDER BY "Количество событий" DESC
LIMIT 5;

-- Количество голов забитых игроком за матч
CREATE VIEW PlayerGoalsPerMatch AS
SELECT E.PlayerID,P.Name AS PlayerName, E.MatchID, COUNT(E.EventID) AS Goals
FROM EventLog E
JOIN Player P ON E.PlayerID = P.PlayerID
WHERE E.EventType = 'goal'
GROUP BY E.PlayerID, E.MatchID, P.Name;

-- Лучшие бомбардиры определенного турнира
-- tournament_best_players
SELECT PGM.PlayerID, P.Name AS PlayerName, SUM(PGM.Goals) AS TotalGoals
FROM PlayerGoalsPerMatch PGM
JOIN Match M ON PGM.MatchID = M.MatchID
JOIN Player P ON PGM.PlayerID = P.PlayerID
WHERE 
    M.TournamentID = (SELECT TournamentID FROM Tournament WHERE TournamentName = 'Отборочный турнир 1 этап Кубка Мира 2024 в СПб')
GROUP BY PGM.PlayerID, P.Name
ORDER BY TotalGoals DESC
LIMIT 3;

-- Лучшие бомбардиры за все время
-- total_best_players
SELECT P.PlayerID,  P.Name AS PlayerName, SUM(PGM.Goals) AS TotalGoals
FROM PlayerGoalsPerMatch PGM
JOIN Player P ON PGM.PlayerID = P.PlayerID
GROUP BY P.PlayerID, P.Name
ORDER BY TotalGoals DESC
LIMIT 10;

-- Игроки которые забили больше 1 гола за матч
-- multiple_goals_in_match
SELECT MatchID, PlayerName, Goals
FROM PlayerGoalsPerMatch
WHERE Goals >= 2
ORDER BY Goals DESC;