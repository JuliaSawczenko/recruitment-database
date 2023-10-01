-- tabela wymagania - nazwa pozycji, umiejętności, dyplom

CREATE TABLE requirements (
name_of_position varchar(30) PRIMARY KEY,
Skills TEXT NOT NULL,
Degree TEXT);


-- informacje o otwartej roli - id roli, budżet, nazwa pozycji (id może być dużo, -- -- każda poszczególną rola ma własne id, ale nazwa jedna, np. Engineer)

CREATE TABLE position_info (
position_id INT PRIMARY KEY,
budget MONEY NOT NULL,
name_of_position varchar(30),
FOREIGN KEY (name_of_position) REFERENCES requirements (name_of_position) ON UPDATE CASCADE
);

ALTER TABLE position_info
ADD CHECK (budget < 10000000)

--- tabela aplikacje - id kandydata, data aplikacji, źródło (np. LinkedIn), id roli
CREATE TABLE applications (
candidate_id INT PRIMARY KEY,
date_of_application DATE,
source_of_application TEXT NOT NULL,
position_id INT, 
FOREIGN KEY (position_id) REFERENCES position_info (position_id) ON UPDATE CASCADE
);

-- informacje o kandydatach - imię, id, numer telefonu, email
CREATE TABLE candidates_info(
full_name varchar(30) PRIMARY KEY,
candidate_id INT NOT NULL,
FOREIGN KEY (candidate_id) REFERENCES applications (candidate_id) ON UPDATE CASCADE,
phone_number INT,
email TEXT
);

--nowi pracownicy - osoby, które dołączyły do firmy -  id nowego pracownika, imię, data dołączenia, wynagrodzenie, id roli. Nie możemy zatrudnić kandydata którego nie było w tabeli “aplikacje” albo na role której nie istnieje w “position_info”
CREATE TABLE new_hires(
new_joiner_id INT PRIMARY KEY,
full_name varchar(30),
FOREIGN KEY (full_name) REFERENCES candidates_info (full_name) ON UPDATE CASCADE,
date_of_joining DATE,
salary_offered MONEY NOT NULL, 
position_id INT,
FOREIGN KEY (position_id) REFERENCES position_info (position_id)
);

ALTER TABLE new_hires
ADD CHECK (date_of_joining > '2023-01-01');


-- wyzwalacz “czy mamy budżet?”  Nie pozwala zatrudnić kandydata z wynagrodzeniem wyższym niż mamy w budżecie 
CREATE TRIGGER in_budget ON new_hires AFTER INSERT
AS
IF EXISTS(SELECT salary_offered FROM INSERTED 
JOIN position_info ON (position_info.position_id = INSERTED.position_id)
WHERE (INSERTED.salary_offered > position_info.budget))
BEGIN	 
	RAISERROR ('Nie mamy budżetu aby zatrudnić tego kandydata', 16, 1);
	ROLLBACK;
	END

ALTER DATABASE [candidates] SET RECURSIVE_TRIGGERS ON 


-- tabela decyzje po rozmowach: id, pierwsza rozmowa ( 0 - “odrzucamy”, 1 - "dobry ----feedback), druga_rozmowa ( 0 -“odrzucamy”, 1 -“zatrudniamy), hired ( 0 - “oferta --odrzucona”, 1 - “kandydat zatrudniony”)
               
CREATE TABLE feedbacks (
candidate_id INT PRIMARY KEY,
FOREIGN KEY (candidate_id) REFERENCES applications (candidate_id),
first_interview BIT, 
second_interview BIT,
hired BIT);

--  wyzwalacz, sprawdza czy zaproszony na druga rozmowę kandydat dostał dobry feedback po pierwszej rozmowie
               
CREATE TRIGGER second_interview_invite ON feedbacks AFTER INSERT
AS
IF EXISTS(SELECT second_interview FROM INSERTED 
WHERE (INSERTED.first_interview = 0) AND (INSERTED.second_interview = 1))
BEGIN	 
	RAISERROR ('Niepoprawna wartość - feedback po pierwszej rozmowie jest negatywny, kandydat nie moze zostac zaproszony na druga rozmowe', 16, 1);
ROLLBACK;
END

--wyzwalacz, sprawdza czy kandydat którego chcemy zatrudnić przeszedł druga rozmowę
               
CREATE TRIGGER hired_status ON feedbacks AFTER INSERT
AS
IF EXISTS(SELECT hired FROM INSERTED 
WHERE (INSERTED.hired = 1) AND (INSERTED.second_interview = 0))
BEGIN	 
RAISERROR ('Niepoprawna wartość - feedback po drugiej rozmowie jest negatywny, kandydat nie moze zostac zatrudniony', 16, 1);
ROLLBACK;
END

--wyzwalacz, sprawdza czy status “hired” nowego pracownika w tabeli feedback jest prawidłowy 
               
CREATE TRIGGER hired_employee ON new_hires AFTER INSERT
AS
IF EXISTS(SELECT INSERTED.full_name FROM INSERTED
JOIN candidates_info ON (INSERTED.full_name = candidates_info.full_name)
JOIN feedbacks ON (feedbacks.candidate_id = candidates_info.candidate_id)
WHERE (feedbacks.hired = 0))
BEGIN	 
	RAISERROR ('Niepoprawna wartość - w celu zatrudnienia kandydata - proszę zmienić status w tabeli feedbacks', 16, 1);
ROLLBACK;
END


--wprowadzamy dane aby móc testować widoki, funkcje, wyzwalacze

INSERT INTO requirements VALUES ('Software Engineer', 'software engineering', 'masters')
INSERT INTO requirements VALUES ('Accountant', 'finance', 'bachelors')
INSERT INTO requirements VALUES ('Data Analyst', 'SQL', 'bachelors')

INSERT INTO position_info VALUES (1, 200000, 'Software Engineer')
INSERT INTO position_info VALUES (2, 140000, 'Accountant')
INSERT INTO position_info VALUES (3, 160000, 'Data Analyst')

INSERT INTO applications VALUES (45, '2022-02-02', 'LinkedIn', 1)
INSERT INTO applications VALUES (67, '2023-02-03', 'Direct', 1)
INSERT INTO applications VALUES  (98, '2022-03-01', 'Referral', 2)
INSERT INTO applications VALUES (105, '2022-03-04', 'LinkedIn', 2)
INSERT INTO applications VALUES (156, '2022-03-06', 'Internal', 2)
INSERT INTO applications VALUES (203, '2022-04-08', 'Job ad', 3)
INSERT INTO applications VALUES (208, '2022-05-04', 'LinkedIn', 3)


INSERT INTO candidates_info VALUES ('Julia Sawczenko', 45, 6376373, 'j@com')
INSERT INTO candidates_info VALUES ('Julia Sawczenk', 67, 433453, 'ju@com')
INSERT INTO candidates_info VALUES ('Julia Sawczen', 98, 3239329, 'jul@com')
INSERT INTO candidates_info VALUES ('Angelina Jolie', 105, 353353, 'angela@jolie')
INSERT INTO candidates_info VALUES ('Brad Pitt', 156, 42242, 'bit@brad')
INSERT INTO candidates_info VALUES ('Kandydat Kandydat', 203, 43535, 'kandydat@com')
INSERT INTO candidates_info VALUES ('Dummy Duck', 208, 24242, 'dummmm@com')


INSERT INTO feedbacks VALUES (45, 1, 0, 0)
INSERT INTO feedbacks VALUES (156, 1, 1, 0)
INSERT INTO feedbacks VALUES (203, 1, 1, 1)
INSERT INTO feedbacks VALUES (208, 1, 1, 1)
INSERT INTO feedbacks VALUES (105, 1, 1, 0)
INSERT INTO feedbacks VALUES (67, 1, 1, 1)


INSERT INTO new_hires VALUES (208, 'Dummy Duck', '2023-01-02', 120000, 3)
INSERT INTO new_hires VALUES (203, 'Kandydat Kandydat', '2023-02-02', 110000, 3)



-- widok, sprawdza ile kandydatów zaaplikowało w każdym miesiącu, i wyświetla średnią liczbę kandydatów

CREATE VIEW statistics_monthly_applications AS
SELECT MONTH(date_of_application) as month,
SUM(COUNT(*)) OVER (PARTITION BY MONTH(date_of_application)) AS monthly_applicants,
AVG(COUNT(*)) OVER () AS average_monthly
FROM applications
GROUP BY MONTH(date_of_application)


-- widok, sprawdza ile kandydatów zaaplikowało na każdą role, i wyświetla średnią liczbę kandydatów

CREATE VIEW statistics_position_applications AS
SELECT position_id,
SUM(COUNT(*)) OVER (PARTITION BY position_id) AS position_applicants,
AVG(COUNT(*)) OVER () AS average_position
FROM applications
GROUP BY position_id

-- widok, sprawdza ile kandydatów odrzuciło ofertę w każdym miesiącu 

CREATE VIEW rejected_offer_monthly AS
SELECT MONTH(date_of_application) AS month, COUNT(feedbacks.candidate_id) AS candidates_who_rejected_offer
FROM feedbacks
JOIN applications 
ON (applications.candidate_id = feedbacks.candidate_id)
WHERE (second_interview = 1) AND (hired = 0)
GROUP BY MONTH(date_of_application)



--funkcja która zwraca listę kandydatów (id kandydatów) którzy posiadają (albo myślą że posiadają) konkretna umiejętność podana jako parametr (np. ‘Engineering’)

CREATE FUNCTION Find_candidates_by_skill (@skills varchar(30))
RETURNS TABLE
AS
RETURN
(SELECT candidate_id FROM applications 
JOIN position_info ON (position_info.position_id = applications.position_id) 
JOIN requirements ON (requirements.name_of_position = position_info.name_of_position)
WHERE requirements.skills LIKE @skills)

--procedura składowana, służy do dopisywania jednego wiersza do tabeli new_hires. 

--Należy podać imię kandydata, a procedura dopiszę resztę danych - losowo przydzielony new_joiner_id, date_of_joining -  3 miesiące po date_of_application, i tak dalej.

--Jeśli imię kandydata nie istnieje w tabeli candidates_info, to dopisuje również do tej tabeli.

CREATE PROC Add_data_to_new_hires @full_name varchar(30)
AS
DECLARE @new_joiner_id INT
DECLARE @date_of_joining DATE
DECLARE @salary_offered MONEY
DECLARE @position_id INT


SET @new_joiner_id = (rand()*101);

SET @date_of_joining = (SELECT DATEADD(month, 3, a.date_of_application)
FROM applications a JOIN candidates_info c 
ON (c.candidate_id = a.candidate_id)
WHERE @full_name = c.full_name)

SET @position_id = (SELECT position_id FROM applications a JOIN candidates_info c 
ON (c.candidate_id = a.candidate_id)
WHERE @full_name = c.full_name)

SET @salary_offered = (SELECT p.budget FROM position_info p 
WHERE p.position_id = @position_id)


IF NOT EXISTS (SELECT full_name FROM candidates_info WHERE full_name= @full_name)
BEGIN
INSERT INTO candidates_info
SELECT @full_name, a.candidate_id, NULL, NULL
FROM applications a
WHERE a.position_id = @position_id
END


INSERT INTO new_hires
VALUES (@new_joiner_id, @full_name, @date_of_joining, @salary_offered, @position_id)
END
GO


EXEC  Add_data_to_new_hires 'Julia Sawczenk'

SELECT * FROM new_hires