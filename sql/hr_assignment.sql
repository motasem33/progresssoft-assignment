-- ProgressSoft assignment: Oracle 12c+ example
-- Run only in a disposable/approved schema. No secrets are included.

CREATE TABLE gender (
  gender_id NUMBER(1) CONSTRAINT pk_gender PRIMARY KEY,
  name VARCHAR2(20) CONSTRAINT nn_gender_name NOT NULL,
  CONSTRAINT uq_gender_name UNIQUE (name),
  CONSTRAINT ck_gender_id CHECK (gender_id > 0)
);

CREATE TABLE university (
  university_id NUMBER(10) CONSTRAINT pk_university PRIMARY KEY,
  name VARCHAR2(150) CONSTRAINT nn_university_name NOT NULL,
  CONSTRAINT uq_university_name UNIQUE (name)
);

CREATE TABLE mydepartment (
  dept_id NUMBER(10) CONSTRAINT pk_department PRIMARY KEY,
  name VARCHAR2(100) CONSTRAINT nn_department_name NOT NULL,
  CONSTRAINT uq_department_name UNIQUE (name)
);

CREATE TABLE myemployee (
  id NUMBER(10) CONSTRAINT pk_employee PRIMARY KEY,
  last_name VARCHAR2(60) CONSTRAINT nn_employee_last_name NOT NULL,
  first_name VARCHAR2(60) CONSTRAINT nn_employee_first_name NOT NULL,
  hire_date DATE CONSTRAINT nn_employee_hire_date NOT NULL,
  userid NUMBER(10) CONSTRAINT uq_employee_userid UNIQUE,
  salary NUMBER(12,2) CONSTRAINT nn_employee_salary NOT NULL,
  dept_id NUMBER(10) CONSTRAINT nn_employee_dept NOT NULL,
  gender_id NUMBER(1) CONSTRAINT nn_employee_gender NOT NULL,
  university_id NUMBER(10),
  emp_image BLOB,
  manager_id NUMBER(10),
  job_title VARCHAR2(100) CONSTRAINT nn_employee_job_title NOT NULL,
  CONSTRAINT ck_employee_salary CHECK (salary >= 0),
  CONSTRAINT ck_employee_names CHECK (LENGTH(TRIM(first_name)) > 0 AND LENGTH(TRIM(last_name)) > 0),
  CONSTRAINT fk_employee_dept FOREIGN KEY (dept_id) REFERENCES mydepartment(dept_id),
  CONSTRAINT fk_employee_gender FOREIGN KEY (gender_id) REFERENCES gender(gender_id),
  CONSTRAINT fk_employee_university FOREIGN KEY (university_id) REFERENCES university(university_id),
  CONSTRAINT fk_employee_manager FOREIGN KEY (manager_id) REFERENCES myemployee(id),
  CONSTRAINT ck_employee_not_self_manager CHECK (manager_id IS NULL OR manager_id <> id)
);

CREATE INDEX ix_employee_dept ON myemployee(dept_id);
CREATE INDEX ix_employee_manager ON myemployee(manager_id);

INSERT INTO gender VALUES (1, 'Male');
INSERT INTO gender VALUES (2, 'Female');
INSERT INTO university VALUES (1, 'University of Jordan');
INSERT INTO university VALUES (2, 'Jordan University of Science and Technology');
INSERT INTO mydepartment VALUES (10, 'Human Resources');
INSERT INTO mydepartment VALUES (20, 'Engineering');
INSERT INTO mydepartment VALUES (30, 'Sales');

-- Managers first, because manager_id is a self-referencing foreign key.
INSERT INTO myemployee (id,last_name,first_name,hire_date,userid,salary,dept_id,gender_id,university_id,manager_id,job_title)
VALUES (100,'Scott','SCOTT',DATE '1987-09-09',100,9000,20,1,1,NULL,'Engineering Manager');
INSERT INTO myemployee (id,last_name,first_name,hire_date,userid,salary,dept_id,gender_id,university_id,manager_id,job_title)
VALUES (200,'Ahmad','Ahmad',DATE '1980-10-10',200,3000,10,1,1,NULL,'HR Manager');
INSERT INTO myemployee (id,last_name,first_name,hire_date,userid,salary,dept_id,gender_id,university_id,manager_id,job_title)
VALUES (201,'Rami','Rami',DATE '1986-05-24',201,2600,30,1,2,NULL,'Sales Representative');
INSERT INTO myemployee (id,last_name,first_name,hire_date,userid,salary,dept_id,gender_id,university_id,manager_id,job_title)
VALUES (101,'Khalil','Nour',DATE '1990-01-20',101,3000,20,2,2,100,'Developer');
INSERT INTO myemployee (id,last_name,first_name,hire_date,userid,salary,dept_id,gender_id,university_id,manager_id,job_title)
VALUES (102,'Saleh','Sara',DATE '1992-09-05',102,2800,30,2,1,201,'Sales Representative');
COMMIT;

-- Q2: employee name, salary, department, manager, gender, university.
SELECT e.first_name || ' ' || e.last_name AS employee_name,
       e.salary,
       d.name AS department_name,
       m.first_name || ' ' || m.last_name AS manager_name,
       g.name AS gender_name,
       u.name AS university_name
FROM myemployee e
JOIN mydepartment d ON d.dept_id = e.dept_id
LEFT JOIN myemployee m ON m.id = e.manager_id
JOIN gender g ON g.gender_id = e.gender_id
LEFT JOIN university u ON u.university_id = e.university_id
ORDER BY e.id;

-- Q3: all job titles and total monthly salary; total payroll > 2500,
-- excluding Sales employees. The filter may be represented by department name
-- or by job title; this answer uses department name as the authoritative field.
SELECT e.job_title,
       SUM(e.salary) AS total_monthly_salary
FROM myemployee e
JOIN mydepartment d ON d.dept_id = e.dept_id
WHERE UPPER(d.name) <> 'SALES'
GROUP BY e.job_title
HAVING SUM(e.salary) > 2500
ORDER BY e.job_title;

-- Q4: four errors in the supplied statement:
-- 1) x is not multiplication: use *.
-- 2) Oracle's classic EMP table column is SAL, not SALARY (if using that table).
-- 3) ANNUAL SALARY is not a valid unquoted alias with a space; use annual_salary or quote it.
-- 4) The semicolon before FROM terminates the statement too early.
-- Correct form for the classic SCOTT.EMP table:
SELECT empno, ename, sal * 12 AS annual_salary
FROM emp;

-- Q5: return a cursor containing names and hire dates after SCOTT's hire date.
-- A function is used because a PL/SQL function cannot directly print an arbitrary
-- number of rows as a scalar return value. The caller fetches the returned cursor.
CREATE OR REPLACE FUNCTION f_hr_query
  RETURN SYS_REFCURSOR
IS
  l_result SYS_REFCURSOR;
  l_scott_date DATE;
BEGIN
  SELECT MIN(hire_date)
  INTO l_scott_date
  FROM myemployee
  WHERE UPPER(first_name) = 'SCOTT' OR UPPER(last_name) = 'SCOTT';

  IF l_scott_date IS NULL THEN
    RAISE_APPLICATION_ERROR(-20010, 'SCOTT was not found');
  END IF;

  OPEN l_result FOR
    SELECT first_name || ' ' || last_name AS employee_name, hire_date
    FROM myemployee
    WHERE hire_date > l_scott_date
    ORDER BY hire_date, id;
  RETURN l_result;
END f_hr_query;
/

-- SQL*Plus/SQLcl test:
VAR rc REFCURSOR;
EXEC :rc := f_hr_query;
PRINT rc;

-- Q6: copy all rows and columns from MyEmployee to MyEmployee_update.
CREATE OR REPLACE PROCEDURE p_copy_employee
IS
BEGIN
  EXECUTE IMMEDIATE 'CREATE TABLE myemployee_update AS SELECT * FROM myemployee WHERE 1 = 0';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -955 THEN RAISE; END IF;
END p_copy_employee;
/

-- The procedure above creates the target if absent. This second version performs
-- the requested copy and clears previous contents so repeated tests are deterministic.
CREATE OR REPLACE PROCEDURE p_copy_employee
IS
BEGIN
  BEGIN
    EXECUTE IMMEDIATE 'CREATE TABLE myemployee_update AS SELECT * FROM myemployee WHERE 1 = 0';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE != -955 THEN RAISE; END IF;
  END;

  EXECUTE IMMEDIATE 'DELETE FROM myemployee_update';
  EXECUTE IMMEDIATE 'INSERT INTO myemployee_update SELECT * FROM myemployee';
END p_copy_employee;
/

BEGIN
  p_copy_employee;
  COMMIT;
END;
/

SELECT COUNT(*) AS source_count FROM myemployee;
SELECT COUNT(*) AS copied_count FROM myemployee_update;
