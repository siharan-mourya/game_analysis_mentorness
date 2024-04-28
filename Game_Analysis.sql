CREATE DATABASE IF NOT EXISTS game_info;

SELECT * FROM player_details;
SELECT * FROM level_details;

USE game_info;

-- Problem Statement - Game Analysis dataset
-- 1) Players play a game divided into 3-levels (L0,L1 and L2)
-- 2) Each level has 3 difficulty levels (Low,Medium,High)
-- 3) At each level,players have to kill the opponents using guns/physical fight
-- 4) Each level has multiple stages at each difficulty level.
-- 5) A player can only play L1 using its system generated L1_code.
-- 6) Only players who have played Level1 can possibly play Level2 
--    using its system generated L2_code.
-- 7) By default a player can play L0.
-- 8) Each player can login to the game using a Dev_ID.
-- 9) Players can earn extra lives at each stage in a level.

ALTER TABLE player_details MODIFY L1_Status VARCHAR(30);
ALTER TABLE player_details MODIFY L2_Status VARCHAR(30);
ALTER TABLE player_details MODIFY P_ID INT PRIMARY KEY;
ALTER TABLE player_details DROP myunknowncolumn;

ALTER TABLE level_details DROP myunknowncolumn;
ALTER TABLE level_details CHANGE TimeStamp start_datetime DATETIME;
ALTER TABLE level_details MODIFY Dev_Id VARCHAR(10);
ALTER TABLE level_details MODIFY Difficulty VARCHAR(15);
ALTER TABLE level_details ADD PRIMARY KEY (P_ID,Dev_id,start_datetime);
ALTER TABLE level_details ADD FOREIGN KEY (P_ID) REFERENCES player_details(P_ID);


-- player_details (P_ID,PName,L1_status,L2_Status,L1_code,L2_Code)
-- level_details(P_ID,Dev_ID,start_datetime,stages_crossed,level,Difficulty,
-- kill_count,headshots_count,Score,lives_earned)


-- Q1) Extract P_ID,Dev_ID,PName and Difficulty_level of all players 
-- at level 0

SELECT 
	pd.P_ID AS Player_ID, 
    Dev_ID AS Device_ID , 
    pd.PName AS Player_Name, 
    Difficulty AS Difficulty_level
FROM player_details pd
JOIN level_details ld
	ON pd.P_ID = ld.P_ID
WHERE ld.Level = 0;


-- Q2) Find Level1_code wise Avg_Kill_Count where lives_earned is 2 and atleast
-- 3 stages are crossed

SELECT 
	L1_Status,
    ROUND(AVG(ld.kill_count),2) AS Avg_Kill_Count
FROM player_details pd
JOIN level_details ld
	ON pd.P_ID = ld.P_ID
WHERE Lives_Earned = 2 AND
	  Stages_crossed >= 3
GROUP BY L1_Status;


-- Q3) Find the total number of stages crossed at each difficulty level
-- where for Level2 with players use zm_series devices. Arrange the result
-- in decreasing order of total number of stages crossed.

SELECT 
	Difficulty AS difficulty_level,
	SUM(Stages_crossed) AS total_stages_crossed
FROM
	level_details
WHERE Level = 2 AND Dev_ID LIKE 'zm%'
GROUP BY Difficulty 
ORDER BY total_stages_crossed DESC;


-- Q4) Extract P_ID and the total number of unique dates for those players 
-- who have played games on multiple days.

SELECT  
	P_ID AS Player_ID,
	COUNT(DISTINCT DATE(start_datetime)) AS Unique_date_count
FROM level_details
GROUP BY P_ID
HAVING Unique_date_count > 1;


-- Q5) Find P_ID and level wise sum of kill_counts where kill_count
-- is greater than avg kill count for the Medium difficulty.

SELECT 
	P_ID AS Player_ID,
    Level,
    SUM(Kill_Count) total_Kill_count
FROM level_details
WHERE Difficulty = 'Medium' 
GROUP BY P_ID, Level
HAVING total_Kill_count > (SELECT AVG(Kill_Count)
						   FROM level_details)
;


-- Q6) Find Level and its corresponding Level code wise sum of lives earned 
-- excluding level 0. Arrange in ascending order of level.

SELECT 
	Level,
    L1_Code, 
    L2_Code,
    SUM(Lives_Earned) AS total_lives_earned
FROM player_details pd
JOIN level_details ld
	ON pd.P_ID = ld.P_ID
WHERE ld.Level != 0
GROUP BY Level,L1_Code,L2_Code
ORDER BY ld.Level ASC;


-- Q7) Find Top 3 score based on each dev_id and Rank them in increasing order
-- using Row_Number. Display difficulty as well. 

WITH top_scores AS (SELECT DISTINCT
	Dev_ID,
    Score,
    Difficulty,
    ROW_NUMBER() OVER(PARTITION BY Dev_ID ORDER BY Score DESC) AS row_num
FROM level_details)

SELECT DISTINCT
	Dev_ID AS Device_ID,
    Score,
    Difficulty AS Difficulty_Level
FROM 
	top_scores
WHERE
	row_num <= 3
ORDER BY Device_ID, Score ASC;
    

-- Q8) Find first_login datetime for each device id

SELECT 
	Dev_ID AS Device_ID,
    MIN(start_datetime) AS First_login
FROM 
	level_details
GROUP BY
	Device_ID
ORDER BY 
	Device_ID,
    First_login;


-- Q9) Find Top 5 score based on each difficulty level and Rank them in 
-- increasing order using Rank. Display dev_id as well.

WITH ranked_scores AS (SELECT 
	Dev_ID,
	Difficulty,
    Score, 
    RANK() OVER(PARTITION BY Difficulty ORDER BY Score DESC) AS rank_num 
FROM 
	level_details)
    
SELECT DISTINCT
	Dev_ID,
	Difficulty,
    Score
FROM 
	ranked_scores
WHERE rank_num <= 5;
    

-- Q10) Find the device ID that is first logged in(based on start_datetime) 
-- for each player(p_id). Output should contain player id, device id and 
-- first login datetime.

WITH login_details AS (SELECT 
	P_ID,
	Dev_ID,
    start_datetime,
    ROW_NUMBER() OVER(PARTITION BY P_ID ORDER BY start_datetime) AS row_num 
FROM 
	level_details)

SELECT 
	P_ID,
	Dev_ID,
    start_datetime
FROM login_details
WHERE row_num = 1
;


-- Q11) For each player and date, how many kill_count played so far by the player. 
-- That is, the total number of games played by the player until that date.

-- a) window function

SELECT DISTINCT
	P_ID AS Player_ID,
    SUM(Stages_crossed) OVER(PARTITION BY P_ID) AS total_games_played,
    SUM(Kill_Count) OVER(PARTITION BY P_ID) AS total_kill_count 
FROM 
	level_details
ORDER BY
	total_games_played DESC;
    
-- b) without window function

SELECT
	P_ID AS Player_ID,
    SUM(Stages_crossed) AS total_games_played,
    SUM(Kill_Count) AS total_kill_count
FROM 
	level_details
GROUP BY 
	P_ID
ORDER BY
	total_games_played DESC;


-- Q12) Find the cumulative sum of stages crossed over a start_datetime.

SELECT
    start_datetime,
    Stages_crossed,
    SUM(Stages_crossed) OVER(ORDER BY start_datetime) AS cu_sum_stages_crossed
FROM 
	level_details;


-- Q13) Find the cumulative sum of stages crossed over a start_datetime 
-- for each player id but exclude the most recent start_datetime.

WITH sum_of_stages AS (SELECT 
	P_ID,
    start_datetime,
    Stages_crossed,
    SUM(Stages_crossed) OVER(PARTITION BY P_ID ORDER BY start_datetime) AS cu_sum_stages_crossed,
    ROW_NUMBER() OVER(PARTITION BY P_ID ORDER BY start_datetime DESC) AS row_num
FROM 
	level_details
ORDER BY
	P_ID,
	start_datetime)

SELECT 
	P_ID,
    start_datetime,
    Stages_crossed,
    cu_sum_stages_crossed
FROM sum_of_stages
WHERE row_num != 1
;


-- Q14) Extract top 3 highest sum of score for each device id and the corresponding player_id.

WITH numbered as (SELECT
	P_ID,
    Dev_ID,
    SUM(Score) score_total,
    ROW_NUMBER() OVER(PARTITION BY P_ID ORDER BY P_ID, SUM(Score) DESC) AS row_num
FROM 
	level_details
GROUP BY 
	P_ID, 
    Dev_ID)

SELECT
    P_ID,
    Dev_ID,
    score_total
FROM
	numbered
WHERE
	row_num <= 3;
    
    
-- Q15) Find players who scored more than 50% of the avg score, scored by sum of 
-- scores for each player_id

SELECT
	P_ID,
    SUM(Score) AS total_score,
    ROUND(AVG(Score),2) AS avg_score
FROM 
	level_details
GROUP BY
	P_ID
HAVING 
	total_score >= avg_score*(1.50)
;

-- Q16) Create a stored procedure to find top n headshots_count based on each dev_id and 
-- Rank them in increasing order using Row_Number. Display difficulty as well.

DROP PROCEDURE IF EXISTS headshot_count;
DELIMITER ~~
CREATE PROCEDURE headshot_count(top_n INT)
BEGIN
	WITH headshots_total as (SELECT
		Dev_ID,
        DIfficulty,
		SUM(Headshots_count) headshots_total,
		ROW_NUMBER() OVER(PARTITION BY Dev_ID ORDER BY SUM(Headshots_count)) AS row_num
	FROM 
		level_details
	GROUP BY 
		Dev_ID,
        DIfficulty)

	SELECT
		Dev_ID,
        DIfficulty,
        headshots_total
	FROM
		headshots_total
	WHERE
		row_num = top_n;
END~~
DELIMITER ;

CALL headshot_count(1);


-- Q17) Create a function to return sum of Score for a given player_id.

DROP FUNCTION IF EXISTS sum_of_scores;

DELIMITER ~~
CREATE FUNCTION score_total(p_pid INT)
RETURNS INT DETERMINISTIC 
BEGIN
DECLARE total_score INT;
	SELECT
        SUM(Score) INTO total_score
	FROM level_details
	WHERE P_ID = p_pid;
RETURN total_score;
END~~
DELIMITER ;

SELECT score_total(296) AS overall_score;
