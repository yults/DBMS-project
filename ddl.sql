CREATE TABLE IF NOT EXISTS Tournament (
    TournamentID INT PRIMARY KEY,
    TournamentName VARCHAR(120) NOT NULL,
    ParentTournamentID INT,
    CONSTRAINT check_tournament_name_length CHECK (CHAR_LENGTH(TournamentName) >= 10),
    CONSTRAINT fk_parent_tournament
      FOREIGN KEY (ParentTournamentID) REFERENCES Tournament(TournamentID) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS Match (
    MatchID INT PRIMARY KEY,
    TournamentID INT NOT NULL,
    DateTime TIMESTAMP NOT NULL,
    CONSTRAINT fk_tournament_match
      FOREIGN KEY (TournamentID) REFERENCES Tournament(TournamentID),
    CONSTRAINT check_match_date CHECK (DateTime >= '1992-01-01')
);--первые крупные соревнования в 1992

CREATE TABLE IF NOT EXISTS Team (
    TeamID INT PRIMARY KEY,
    Name VARCHAR(120) NOT NULL,
    Hometown VARCHAR(60) NOT NULL,
    CONSTRAINT unique_team_name_hometown UNIQUE (Name, Hometown)
);

CREATE TABLE IF NOT EXISTS TournamentParticipation (
    TournamentID INT NOT NULL,
    TeamID INT NOT NULL,
    Status VARCHAR(60) CHECK (Status IN ('Участвует', 'В рассмотрении', 'Заявка отклонена')),
    PRIMARY KEY (TournamentID, TeamID),
    CONSTRAINT fk_tournamentparticipation_tournament
      FOREIGN KEY (TournamentID) REFERENCES Tournament(TournamentID),
    CONSTRAINT fk_tournamentparticipation_team
      FOREIGN KEY (TeamID) REFERENCES Team(TeamID)
);

CREATE TABLE IF NOT EXISTS Player (
    PlayerID INT PRIMARY KEY,
    Name VARCHAR(120) NOT NULL,
    Nationality VARCHAR(60) NOT NULL,
    Birthdate DATE NOT NULL,
    CONSTRAINT check_player_birthdate CHECK (Birthdate >= '1900-01-01')
);

CREATE TABLE IF NOT EXISTS MatchParticipation (
    MatchID INT NOT NULL,
    TeamID INT NOT NULL,
    ScoreTeam INT,
    PRIMARY KEY (MatchID, TeamID),
    CONSTRAINT fk_matchparticipation_match
      FOREIGN KEY (MatchID) REFERENCES Match(MatchID),
    CONSTRAINT fk_matchparticipation_team 
      FOREIGN KEY (TeamID) REFERENCES Team(TeamID),
    CONSTRAINT check_score_non_negative CHECK (ScoreTeam IS NULL OR ScoreTeam >= 0)
);

CREATE TABLE IF NOT EXISTS TeamMembershipHistory (
    HistoryMembershipID INT PRIMARY KEY,
    PlayerID INT NOT NULL,
    TeamID INT NOT NULL,
    PlayerNumber INT CHECK (PlayerNumber >= 1 AND PlayerNumber <= 99),
    JoinDate DATE NOT NULL,
    LeaveDate DATE,
    CONSTRAINT fk_teammembershiphistory_player
      FOREIGN KEY (PlayerID) REFERENCES Player(PlayerID),
    CONSTRAINT fk_teammembershiphistory_team 
      FOREIGN KEY (TeamID) REFERENCES Team(TeamID),
    CONSTRAINT check_join_leave_dates CHECK (LeaveDate IS NULL OR JoinDate < LeaveDate)
);

CREATE TABLE IF NOT EXISTS EventLog (
    EventID INT PRIMARY KEY,
    MatchID INT NOT NULL,
    EventType VARCHAR(60) NOT NULL,
    EventTime INT NOT NULL,
    PlayerID INT NOT NULL,
    CONSTRAINT fk_eventlog_match 
      FOREIGN KEY (MatchID) REFERENCES Match(MatchID),
    CONSTRAINT fk_eventlog_player
      FOREIGN KEY (PlayerID) REFERENCES Player(PlayerID),
    CONSTRAINT check_event_type CHECK (EventType IN
      ('goal', 'yellow card', 'red card', 'success penalty', 'fail penalty', 'autogoal')),
    CONSTRAINT check_event_time_in_bounds CHECK (EventTime >= 0 AND EventTime <= 39)
);

-- Индекс на TournamentID в Match
-- Поиск матчей определенного турнира. PK - хеш
CREATE INDEX idx_match_tournament ON Match USING hash (TournamentID);
-- Индекс на PlayerID в EventLog 
-- Поиск событий связанных с определенным игроком. PK - хеш
CREATE INDEX idx_eventlog_player ON EventLog USING hash (PlayerID);
-- Индекс на Name в таблице Player 
-- Сортировка по имени игрока. Строка - btree.
CREATE INDEX idx_player_name ON Player USING btree (Name);
-- Индекс на Name в таблице Team 
-- Сортировка по названию команды. Строка - btree.
CREATE INDEX idx_team_name ON Team USING btree (Name);
-- Индекс на TournamentName в таблице Tournament 
-- Поиск турниров по названию. Строка - btree.
CREATE INDEX idx_tournament_name ON Tournament USING btree (TournamentName);
-- Индекс на ParentTournamentID в таблице Tournament
-- Выборка дочерних турниров для заданного турнира - btree.
CREATE INDEX idx_tournament_parent ON Tournament USING btree (ParentTournamentID);
-- Индекс на DateTime в таблице Match
-- Фильтрация матчей по дате и времени. Дата/время - btree.
CREATE INDEX idx_match_datetime ON Match USING btree (DateTime);
-- Индекс на Status в таблице TournamentParticipation
-- Фильтрация участия в турнирах по статусу. Строка - btree.
CREATE INDEX idx_tournamentparticipation_status ON TournamentParticipation USING btree (Status);
-- Индекс на LeaveDate в таблице TeamMembershipHistory
-- Выборка текущего состава команд. Дата - btree.
CREATE INDEX idx_teammembershiphistory_leavedate ON TeamMembershipHistory USING btree (LeaveDate);
-- Индекс на TournamentID, DateTime, MatchID в таблице Match
-- Ускоряет запросы поиска матчей по ID турнира с сортировкой по дате.
-- Покрывающий индекс - btree.
CREATE INDEX idx_match_tournament_covering ON Match USING btree (TournamentID, DateTime, MatchID);
-- Покрывающий индекс для таблицы MatchParticipation на MatchID, TeamID, ScoreTeam.
-- Ускоряет запросы по результатам матчей для каждой команды.
-- Покрывающий индекс - btree.
CREATE INDEX idx_matchparticipation_covering ON MatchParticipation USING btree (MatchID, TeamID, ScoreTeam);