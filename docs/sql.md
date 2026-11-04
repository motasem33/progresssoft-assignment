# مسودة قسم SQL/PLSQL — ProgressSoft

> **نطاق التوافق:** الأمثلة التنفيذية في هذا الملف مكتوبة لـ **Oracle Database 12c أو أحدث** باستخدام Oracle SQL وPL/SQL. صيغ مثل `VARCHAR2`, `NUMBER`, `SYSDATE`, `DBMS_OUTPUT`, و`IDENTITY` خاصة بـ Oracle أو شائعة في بيئته. لم يتم تشغيل السكربت هنا؛ يجب تنفيذه في مخطط Oracle مناسب بعد مراجعة الصلاحيات.
>
> **ملاحظة عن Q3 وQ4:** لم يُرفق نص السؤالين الأصليين في الطلب، لذلك أدرجت صياغة عملية شائعة في اختبارات SQL/PLSQL، ووضحت الافتراضات بحيث يمكن مواءمتها مع ورقة التقييم.

## 1. أساسيات قواعد البيانات

### DDL وDML وDCL

- **DDL (Data Definition Language):** أوامر تعريف بنية قاعدة البيانات، مثل `CREATE`, `ALTER`, `DROP`, `TRUNCATE`, و`RENAME`. مثال: إنشاء جدول أو إضافة قيد.
- **DML (Data Manipulation Language):** أوامر التعامل مع الصفوف، مثل `INSERT`, `UPDATE`, `DELETE`, و`MERGE`. يمكن التراجع عن أوامر DML بـ `ROLLBACK` قبل `COMMIT`.
- **DCL (Data Control Language):** أوامر الصلاحيات، خصوصًا `GRANT` و`REVOKE`.
- **TCL (Transaction Control Language):** أوامر المعاملات مثل `COMMIT`, `ROLLBACK`, و`SAVEPOINT`.

```sql
-- DDL
CREATE TABLE demo_table (
    id NUMBER PRIMARY KEY,
    name VARCHAR2(100) NOT NULL
);

-- DML
INSERT INTO demo_table (id, name) VALUES (1, 'Example');
UPDATE demo_table SET name = 'Updated' WHERE id = 1;
COMMIT;

-- DCL (يتطلب صلاحية مناسبة)
-- GRANT SELECT ON demo_table TO reporting_user;
-- REVOKE SELECT ON demo_table FROM reporting_user;
```

### RDBMS مقابل NoSQL

**RDBMS** يخزن البيانات في جداول ذات مخطط محدد، ويدعم العلاقات والمفاتيح والقيود وSQL والمعاملات المتوافقة مع ACID. يناسب بيانات الموظفين والرواتب حيث التكامل المرجعي مهم. Oracle Database مثال على RDBMS.

**NoSQL** عائلة من نماذج غير علائقية، مثل document, key-value, column-family, وgraph. تميل إلى مخطط مرن وتوسعة أفقية سهلة، لكنها لا تقدم دائمًا نفس نموذج العلاقات والقيود والمعاملات الشاملة الموجود في RDBMS. الاختيار يعتمد على طبيعة الحمل، واتساق البيانات، وحجمها، ونمط الاستعلام، وليس على قاعدة عامة أن أحدهما أفضل دائمًا.

## 2. JOINs

- `INNER JOIN`: يعيد الصفوف ذات المطابقة في الجدولين.
- `LEFT OUTER JOIN`: يعيد كل صفوف الجدول الأيسر والمطابق من الأيمن، ويضع `NULL` عند عدم وجود مطابقة.
- `RIGHT OUTER JOIN`: النظير للـ `LEFT JOIN`.
- `FULL OUTER JOIN`: يعيد كل الصفوف من الطرفين، مع `NULL` للطرف غير المطابق.
- `CROSS JOIN`: حاصل الضرب الديكارتي؛ يجب استخدامه بحذر.
- **Self Join:** ربط الجدول بنفسه، مثل ربط الموظف بمديره.

مثال self join:

```sql
SELECT e.employee_id,
       e.first_name || ' ' || e.last_name AS employee_name,
       m.first_name || ' ' || m.last_name AS manager_name
FROM myemployee e
LEFT JOIN myemployee m ON m.employee_id = e.manager_id;
```

## 3. Aggregation وFunctions

### Aggregation

دوال التجميع تشمل `COUNT`, `SUM`, `AVG`, `MIN`, و`MAX`. تستخدم `GROUP BY` للتجميع، و`HAVING` لتصفية المجموعات بعد التجميع. أما `WHERE` فتُطبق قبل التجميع.

```sql
SELECT department_id,
       COUNT(*) AS employee_count,
       ROUND(AVG(salary), 2) AS average_salary,
       SUM(salary) AS total_salary
FROM myemployee
GROUP BY department_id
HAVING AVG(salary) > 5000;
```

### Date functions في Oracle

- `SYSDATE`: تاريخ ووقت خادم قاعدة البيانات.
- `SYSTIMESTAMP`: طابع زمني مع المنطقة الزمنية.
- `ADD_MONTHS(d, n)`: إضافة أشهر.
- `MONTHS_BETWEEN(d1, d2)`: عدد الأشهر بين تاريخين.
- `TRUNC(d, 'MM')`: بداية الشهر.
- `LAST_DAY(d)`: آخر يوم في الشهر.
- `EXTRACT(YEAR FROM d)`: استخراج السنة.

تواريخ Oracle تُدخل بأمان عبر literal من نوع `DATE` أو `TO_DATE` مع format model:

```sql
SELECT DATE '2024-01-15' AS fixed_date,
       ADD_MONTHS(SYSDATE, 1) AS next_month,
       TRUNC(SYSDATE, 'MM') AS month_start,
       LAST_DAY(SYSDATE) AS month_end
FROM dual;
```

### String functions

`UPPER`, `LOWER`, `INITCAP`, `LENGTH`, `SUBSTR`, `INSTR`, `TRIM`, `REPLACE`, و`REGEXP_LIKE` أمثلة على دوال النصوص. للدمج في Oracle يستخدم `||`.

```sql
SELECT UPPER(last_name) AS upper_name,
       INITCAP(first_name) AS formatted_first_name,
       LENGTH(last_name) AS name_length,
       first_name || ' ' || last_name AS full_name
FROM myemployee;
```

### Null وعمليات التحويل

`NULL` ليس صفرًا ولا نصًا فارغًا. استخدم `NVL`, `NVL2`, `COALESCE`, و`NULLIF` حسب الحاجة. للتحويل استخدم `TO_CHAR`, `TO_DATE`, و`TO_NUMBER` مع format واضح عند الحاجة.

## 4. Constraints وIndexes

- **PRIMARY KEY:** يعرّف الصف بشكل فريد ولا يسمح بـ `NULL`.
- **NOT NULL:** يمنع القيمة الفارغة.
- **UNIQUE:** يمنع تكرار القيمة أو مجموعة القيم؛ في Oracle يمكن أن توجد قيم `NULL` وفق قواعد الفهارس المركبة.
- **FOREIGN KEY:** يضمن أن القيمة تشير إلى مفتاح موجود في جدول أب.
- **CHECK:** يفرض قاعدة مجال أو شرطًا منطقيًا.
- **DEFAULT:** يحدد قيمة افتراضية عند عدم تمرير قيمة.

الفهرس يسرّع البحث والـ join أحيانًا، لكنه يزيد كلفة `INSERT/UPDATE/DELETE` ويستهلك مساحة. غالبًا ينشئ Oracle فهرسًا للمفتاح الأساسي/القيد الفريد، وقد نحتاج فهارس على أعمدة foreign key وأعمدة البحث المتكرر. لا تُفهرس كل الأعمدة بلا قياس.

## 5. Oracle DDL — نموذج الموارد البشرية

### 5.1 حذف اختياري لإعادة تشغيل السكربت

هذا الجزء اختياري، ويُستخدم فقط في بيئة اختبار. لا يُنفذ في بيئة إنتاج دون موافقة.

```sql
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE myemployee CASCADE CONSTRAINTS PURGE';
EXCEPTION WHEN OTHERS THEN
    IF SQLCODE != -942 THEN RAISE; END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE mydepartment CASCADE CONSTRAINTS PURGE';
EXCEPTION WHEN OTHERS THEN
    IF SQLCODE != -942 THEN RAISE; END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE gender CASCADE CONSTRAINTS PURGE';
EXCEPTION WHEN OTHERS THEN
    IF SQLCODE != -942 THEN RAISE; END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE university CASCADE CONSTRAINTS PURGE';
EXCEPTION WHEN OTHERS THEN
    IF SQLCODE != -942 THEN RAISE; END IF;
END;
/
```

### 5.2 إنشاء الجداول

يُنشأ `Gender` و`University` أولًا، ثم `MyDepartment`، ثم `MyEmployee` لأن الموظف يشير إلى القسم والجنس والجامعة، كما يشير إلى موظف آخر كمدير.

```sql
CREATE TABLE gender (
    gender_id   NUMBER(1) CONSTRAINT pk_gender PRIMARY KEY,
    gender_name VARCHAR2(20) CONSTRAINT nn_gender_name NOT NULL,
    CONSTRAINT uq_gender_name UNIQUE (gender_name),
    CONSTRAINT ck_gender_id CHECK (gender_id > 0)
);

CREATE TABLE university (
    university_id   NUMBER(10) CONSTRAINT pk_university PRIMARY KEY,
    university_name VARCHAR2(150) CONSTRAINT nn_university_name NOT NULL,
    country         VARCHAR2(80) DEFAULT 'Jordan' CONSTRAINT nn_university_country NOT NULL,
    CONSTRAINT uq_university_name UNIQUE (university_name),
    CONSTRAINT ck_university_name CHECK (LENGTH(TRIM(university_name)) >= 2)
);

CREATE TABLE mydepartment (
    department_id   NUMBER(10) CONSTRAINT pk_mydepartment PRIMARY KEY,
    department_name VARCHAR2(100) CONSTRAINT nn_department_name NOT NULL,
    location        VARCHAR2(100),
    CONSTRAINT uq_department_name UNIQUE (department_name),
    CONSTRAINT ck_department_name CHECK (LENGTH(TRIM(department_name)) >= 2)
);

CREATE TABLE myemployee (
    employee_id    NUMBER(10) CONSTRAINT pk_myemployee PRIMARY KEY,
    first_name     VARCHAR2(60) CONSTRAINT nn_employee_first_name NOT NULL,
    last_name      VARCHAR2(60) CONSTRAINT nn_employee_last_name NOT NULL,
    salary         NUMBER(12,2) CONSTRAINT nn_employee_salary NOT NULL,
    hire_date      DATE DEFAULT SYSDATE CONSTRAINT nn_employee_hire_date NOT NULL,
    department_id  NUMBER(10) CONSTRAINT nn_employee_department NOT NULL,
    manager_id     NUMBER(10),
    gender_id      NUMBER(1) CONSTRAINT nn_employee_gender NOT NULL,
    university_id  NUMBER(10),
    job_title      VARCHAR2(100) CONSTRAINT nn_employee_job_title NOT NULL,
    email          VARCHAR2(254),
    CONSTRAINT ck_employee_salary CHECK (salary >= 0),
    CONSTRAINT ck_employee_names CHECK (
        LENGTH(TRIM(first_name)) > 0 AND LENGTH(TRIM(last_name)) > 0
    ),
    CONSTRAINT uq_employee_email UNIQUE (email),
    CONSTRAINT fk_employee_department FOREIGN KEY (department_id)
        REFERENCES mydepartment (department_id),
    CONSTRAINT fk_employee_manager FOREIGN KEY (manager_id)
        REFERENCES myemployee (employee_id),
    CONSTRAINT fk_employee_gender FOREIGN KEY (gender_id)
        REFERENCES gender (gender_id),
    CONSTRAINT fk_employee_university FOREIGN KEY (university_id)
        REFERENCES university (university_id),
    CONSTRAINT ck_employee_not_self_manager CHECK (manager_id IS NULL OR manager_id <> employee_id)
);
```

> **ملاحظة Oracle:** القيد الذاتي `fk_employee_manager` يسمح بإدخال المدير أولًا ثم الموظفين التابعين له. كما أن `manager_id` يقبل `NULL` للرئيس الأعلى. منع الدورات المتعددة في شجرة الإدارة يحتاج منطقًا إضافيًا، مثل trigger أو تحقق في التطبيق.

### 5.3 فهارس مفيدة

```sql
CREATE INDEX ix_employee_department ON myemployee (department_id);
CREATE INDEX ix_employee_manager ON myemployee (manager_id);
CREATE INDEX ix_employee_gender ON myemployee (gender_id);
CREATE INDEX ix_employee_university ON myemployee (university_id);
CREATE INDEX ix_employee_last_name ON myemployee (last_name);
```

## 6. بيانات اختبار

```sql
INSERT INTO gender (gender_id, gender_name) VALUES (1, 'Male');
INSERT INTO gender (gender_id, gender_name) VALUES (2, 'Female');

INSERT INTO university (university_id, university_name, country)
VALUES (1, 'University of Jordan', 'Jordan');
INSERT INTO university (university_id, university_name, country)
VALUES (2, 'Jordan University of Science and Technology', 'Jordan');
INSERT INTO university (university_id, university_name, country)
VALUES (3, 'German Jordanian University', 'Jordan');

INSERT INTO mydepartment (department_id, department_name, location)
VALUES (10, 'Human Resources', 'Amman');
INSERT INTO mydepartment (department_id, department_name, location)
VALUES (20, 'Engineering', 'Amman');
INSERT INTO mydepartment (department_id, department_name, location)
VALUES (30, 'Finance', 'Irbid');

-- أدخل المديرين قبل الموظفين الذين يشيرون إليهما.
INSERT INTO myemployee
(employee_id, first_name, last_name, salary, hire_date, department_id, manager_id, gender_id, university_id, job_title, email)
VALUES
(100, 'Lina', 'Haddad', 9000, DATE '2018-03-01', 10, NULL, 2, 1, 'HR Director', 'lina.haddad@example.com');

INSERT INTO myemployee
(employee_id, first_name, last_name, salary, hire_date, department_id, manager_id, gender_id, university_id, job_title, email)
VALUES
(200, 'Omar', 'Saleh', 12000, DATE '2017-06-15', 20, NULL, 1, 2, 'Engineering Director', 'omar.saleh@example.com');

INSERT INTO myemployee
(employee_id, first_name, last_name, salary, hire_date, department_id, manager_id, gender_id, university_id, job_title, email)
VALUES
(300, 'Nour', 'Khalil', 11000, DATE '2019-01-20', 30, NULL, 2, 3, 'Finance Director', 'nour.khalil@example.com');

INSERT INTO myemployee
(employee_id, first_name, last_name, salary, hire_date, department_id, manager_id, gender_id, university_id, job_title, email)
VALUES
(101, 'Ahmad', 'Nasser', 6500, DATE '2021-02-10', 10, 100, 1, 1, 'HR Specialist', 'ahmad.nasser@example.com');

INSERT INTO myemployee
(employee_id, first_name, last_name, salary, hire_date, department_id, manager_id, gender_id, university_id, job_title, email)
VALUES
(201, 'Sara', 'Yousef', 8000, DATE '2020-09-05', 20, 200, 2, 2, 'Senior Developer', 'sara.yousef@example.com');

INSERT INTO myemployee
(employee_id, first_name, last_name, salary, hire_date, department_id, manager_id, gender_id, university_id, job_title, email)
VALUES
(301, 'Tareq', 'Mansour', 7000, DATE '2022-04-12', 30, 300, 1, 3, 'Financial Analyst', 'tareq.mansour@example.com');

COMMIT;
```

## 7. Q2 — اسم الموظف والراتب والقسم والمدير والجنس والجامعة

الاستعلام التالي يعرض الاسم الكامل، الراتب، اسم القسم، المدير، الجنس، والجامعة. استخدمت `LEFT JOIN` حتى يظهر الموظف حتى لو لم تكن الجامعة أو المدير موجودة.

```sql
SELECT e.employee_id,
       e.first_name || ' ' || e.last_name AS employee_name,
       e.salary,
       d.department_name,
       CASE
           WHEN m.employee_id IS NULL THEN NULL
           ELSE m.first_name || ' ' || m.last_name
       END AS manager_name,
       g.gender_name,
       u.university_name,
       e.job_title
FROM myemployee e
JOIN mydepartment d
  ON d.department_id = e.department_id
JOIN gender g
  ON g.gender_id = e.gender_id
LEFT JOIN myemployee m
  ON m.employee_id = e.manager_id
LEFT JOIN university u
  ON u.university_id = e.university_id
ORDER BY d.department_name, e.last_name, e.first_name;
```

## 8. Q3 — مجموع الراتب الشهري حسب المسمى الوظيفي

المطلوب هو عرض كل `job_title` وإجمالي الراتب الشهري، بشرط أن يتجاوز الإجمالي 2500، مع استبعاد موظفي Sales. أضفت `job_title` و`manager_id` إلى نموذج الموظف لأنهما مطلوبان في الأسئلة التالية.

```sql
SELECT e.job_title,
       SUM(e.salary) AS total_monthly_salary
FROM myemployee e
JOIN mydepartment d ON d.dept_id = e.dept_id
WHERE UPPER(d.name) <> 'SALES'
GROUP BY e.job_title
HAVING SUM(e.salary) > 2500
ORDER BY e.job_title;
```

## 9. Q4 — الأخطاء الأربعة في العبارة المعطاة

العبارة هي:

```sql
SELECT empno, ename,
salary x 12 ANNUAL SALARY; FROM emp;
```

الأخطاء المقصودة هي: استخدام `x` بدل عامل الضرب `*`؛ استخدام `salary` بينما جدول Oracle التجريبي `SCOTT.EMP` يستخدم عادةً العمود `SAL`؛ استخدام alias يحتوي مسافة دون اقتباس، ويُفضَّل `annual_salary`؛ ووضع فاصلة منقوطة قبل `FROM` مما ينهي العبارة مبكرًا. التصحيح:

```sql
SELECT empno, ename, sal * 12 AS annual_salary
FROM emp;
```

إذا كان لدى بيئة الاختبار عمود اسمه `salary` فعلًا، تصبح الصيغة `salary * 12 AS annual_salary`.

## 10. Q5 — الدالة `F_HR_QUERY`

لأن عدد الصفوف الناتجة غير ثابت، تعيد الدالة `SYS_REFCURSOR` يحتوي اسم الموظف وتاريخ التعيين لكل من تم تعيينه بعد SCOTT. يبحث الكود عن SCOTT في الاسم الأول أو الأخير، ويصدر خطأ واضحًا إذا لم يوجد.

```sql
CREATE OR REPLACE FUNCTION f_hr_query
  RETURN SYS_REFCURSOR
IS
  l_result SYS_REFCURSOR;
  l_scott_date DATE;
BEGIN
  SELECT MIN(hire_date) INTO l_scott_date
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
```

اختبار SQL*Plus/SQLcl:

```sql
VAR rc REFCURSOR;
EXEC :rc := f_hr_query;
PRINT rc;
```

## 11. Q6 — الإجراء `P_COPY_EMPLOYEE`

الإجراء ينشئ `MyEmployee_update` إذا لم يكن موجودًا، ثم يحذف محتواه السابق وينسخ جميع صفوف `MyEmployee`. لا يضع `COMMIT` داخل الإجراء حتى يبقى قرار المعاملة لدى المستدعي.

```sql
CREATE OR REPLACE PROCEDURE p_copy_employee
IS
BEGIN
  BEGIN
    EXECUTE IMMEDIATE
      'CREATE TABLE myemployee_update AS SELECT * FROM myemployee WHERE 1 = 0';
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
```

النسخة التنفيذية الكاملة، مع DDL وبيانات الاختبار والاستعلامات، موجودة في `sql/hr_assignment.sql`.

## 12. ملاحظات الاختبار

نفّذ أوامر `/` في SQL*Plus أو SQLcl أو أداة Oracle تدعم كتل PL/SQL. فعّل `DBMS_OUTPUT` عند الحاجة، واختبر عدد الصفوف في المصدر والنسخة. لم يتم تشغيل السكربت داخل Oracle في هذه البيئة، لذلك يجب تسجيل نتائج التشغيل من مخطط Oracle مصرح به قبل التسليم.
