-- Database: spa_db

-- DROP DATABASE spa_db;
/*
CREATE DATABASE spa_db
    WITH 
    OWNER = postgres
    ENCODING = 'UTF8'
    LC_COLLATE = 'ru_RU.UTF-8'
    LC_CTYPE = 'ru_RU.UTF-8'
    TABLESPACE = pg_default
    CONNECTION LIMIT = -1;
	*/
	
	
	
	
	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- OPERATION_TYPES
	
	CREATE TYPE OPERATION_TYPE AS ENUM ('debt', 'transfer', 'expense', 'income', 'deposit', 'credit');
	
	CREATE TYPE CREDIT_PAYMENTS_TYPE AS ENUM ('annuities', 'differentiated');

	CREATE TYPE INTEREST_PAYMENTS_TYPE AS ENUM ('monthly', 'end_of_term');

	CREATE TYPE CATEGORY_TYPE AS ENUM ('expense', 'income');
	
	CREATE TYPE debt_type AS ENUM ('lent', 'borrowed');
	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--	TABLES
	
	CREATE TABLE users(
		id SERIAL PRIMARY KEY,
		email VARCHAR(64),
		password VARCHAR(256)
	);

	CREATE TABLE accounts(
		id SERIAL PRIMARY KEY,
		account_name VARCHAR(32) NOT NULL,
		balance real NOT NULL,
		currency VARCHAR(16) NOT NULL,
		user_id integer REFERENCES users (id) NOT NULL
	);

	CREATE TABLE operations_queue(
		operation_id SERIAL PRIMARY KEY,
		user_id INT,
		operation_type OPERATION_TYPE,
		FOREIGN KEY (user_id) REFERENCES users (id)
	);
	ALTER TABLE operations_queue ADD date_time DATE;

	CREATE TABLE debt(
		amount REAL,
		currency VARCHAR(32),
		source_account INT REFERENCES accounts (id),
		person VARCHAR(32),
		user_comment VARCHAR(255),
		date_time DATE
	);
	ALTER TABLE debt ADD outer_row_id INT REFERENCES operations_queue (operation_id);
	ALTER TABLE debt ADD debt_mode debt_type NOT NULL;
		
	
	CREATE TABLE transfer(
		outer_row_id INT REFERENCES operations_queue (operation_id),
		amount REAL,
		currency VARCHAR(32),
		source_account INT REFERENCES accounts (id),
		target_account INT REFERENCES accounts (id)
	);

	CREATE TABLE expense(
		outer_row_id INT REFERENCES operations_queue (operation_id),
		amount REAL,
		currency VARCHAR(32),
		account_id INT REFERENCES accounts (id)
	);

	CREATE TABLE income(
		outer_row_id INT REFERENCES operations_queue (operation_id),
		amount REAL,
		currency VARCHAR(32),
		account_id INT REFERENCES accounts (id)
	);

	CREATE TABLE deposit(
		deposit_name VARCHAR(16),
		amount REAL,
		currency VARCHAR(32),
		begin_date DATE,
		end_date DATE,
		interest_rate REAL,
		source_account INT REFERENCES accounts (id),
		interest_payments INTEREST_PAYMENTS_TYPE
	);
	ALTER TABLE deposit ADD outer_row_id INT REFERENCES operations_queue (operation_id);
	
	CREATE TABLE credit(
		credit_name VARCHAR(16),
		amount REAL,
		currency VARCHAR(32),
		begin_date DATE,
		end_date DATE,
		interest_rate REAL,
		target_account INT REFERENCES accounts (id),
		credit_payments CREDIT_PAYMENTS_TYPE
	);
	ALTER TABLE credit ADD outer_row_id INT REFERENCES operations_queue (operation_id);

	CREATE TABLE categories(
		id SERIAL PRIMARY KEY,
		category_name VARCHAR(32),
		category_type CATEGORY_TYPE,
		category_icon VARCHAR(32),
		user_id integer
	);

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--	FUNCTIONS


	
	CREATE OR REPLACE FUNCTION get_last_operation_id(usr_id integer) 
	RETURNS integer 
	AS $$
	BEGIN
		RETURN (SELECT max(operation_id)
		FROM operations_queue 
		WHERE user_id = usr_id);
	END; 
	$$ LANGUAGE 'plpgsql';
	
	CREATE OR REPLACE FUNCTION get_accounts(usr_id integer) 
	RETURNS TABLE (account_id INT, account_name varchar, balance real, currency varchar) 
	AS $$
	BEGIN
		RETURN QUERY SELECT accounts.id, accounts.account_name, accounts.balance, accounts.currency
			FROM accounts 
			WHERE user_id = usr_id;
	END; 
	$$ LANGUAGE 'plpgsql';
	
	CREATE OR REPLACE FUNCTION get_deposit(usr_id integer) 
	RETURNS TABLE (operation_id INT, operation_type operation_type, deposit_name varchar, amount real,
				    currency varchar, date_time date, end_date date, interest_rate real, 
				    interest_payments interest_payments_type, source_account INT) 
	AS $$
	BEGIN
		RETURN QUERY SELECT operations_queue.operation_id, operations_queue.operation_type, deposit.deposit_name, deposit.amount, 
		deposit.currency, operations_queue.date_time, deposit.end_date, deposit.interest_rate, deposit.interest_payments, deposit.source_account
			FROM operations_queue 
			INNER JOIN deposit
			ON operations_queue.operation_id = deposit.outer_row_id 
			WHERE operations_queue.user_id = usr_id;
	END; 
	$$ LANGUAGE 'plpgsql';

	CREATE OR REPLACE FUNCTION get_debts(usr_id integer) 
	RETURNS TABLE (operation_id INT, operation_type operation_type, date_time date, amount real,
				    source_account INT, person varchar, user_comment varchar, debt_mode debt_type, closed boolean) 
	AS $$
	BEGIN
		RETURN QUERY SELECT operations_queue.operation_id, operations_queue.operation_type, operations_queue.date_time, 
							debt.amount, debt.source_account, debt.person, debt.user_comment, debt.debt_mode, debt.closed
			FROM operations_queue 
			INNER JOIN debt 
			ON operations_queue.operation_id = debt.outer_row_id 
			WHERE operations_queue.user_id = usr_id;
	END; 
	$$ LANGUAGE 'plpgsql';
	

	ALTER TABLE credit ADD closed BOOL;


CREATE OR REPLACE FUNCTION get_income(usr_id integer) 
	RETURNS TABLE (operation_id INT, operation_type operation_type, date_time date, 
				   amount real, account_id INT, category_id INT, category_name varchar, category_icon varchar) 
	AS $$
	BEGIN
		RETURN QUERY SELECT operations_queue.operation_id, operations_queue.operation_type, operations_queue.date_time, 
			income.amount, income.account_id, income.category_id, categories.category_name, categories.category_icon
			FROM operations_queue 
			INNER JOIN income 
			ON operations_queue.operation_id = income.outer_row_id 
			INNER JOIN categories 
			ON income.category_id = categories.id 
			WHERE operations_queue.user_id = usr_id;
	END; 
	$$ LANGUAGE 'plpgsql';

	
	CREATE OR REPLACE FUNCTION get_expenses(usr_id integer) 
	RETURNS TABLE (operation_id INT, operation_type operation_type, date_time date, 
				   amount real, account_id INT, category_id INT, category_name varchar, category_icon varchar) 
	AS $$
	BEGIN
		RETURN QUERY SELECT operations_queue.operation_id, operations_queue.operation_type, operations_queue.date_time, 
			expense.amount, expense.account_id, expense.category_id, categories.category_name, categories.category_icon
			FROM operations_queue 
			INNER JOIN expense 
			ON operations_queue.operation_id = expense.outer_row_id 
			INNER JOIN categories 
			ON expense.category_id = categories.id 
			WHERE operations_queue.user_id = usr_id;
	END; 
	$$ LANGUAGE 'plpgsql';

drop FUNCTION get_credits;

	CREATE OR REPLACE FUNCTION get_credits(usr_id integer) 
	RETURNS TABLE (operation_id INT, operation_type operation_type, credit_name varchar, amount real,
				    date_time date, end_date date, interest_rate real, target_account INT,
				  	credit_payments credit_payments_type, closed boolean) 
	AS $$
	BEGIN
		RETURN QUERY SELECT operations_queue.operation_id, operations_queue.operation_type, credit.credit_name, 
		credit.amount, operations_queue.date_time, credit.end_date, credit.interest_rate, credit.target_account, 
		credit.credit_payments, credit.closed
			FROM operations_queue 
			INNER JOIN credit 
			ON operations_queue.operation_id = credit.outer_row_id 
			WHERE operations_queue.user_id = usr_id;
	END; 
	$$ LANGUAGE 'plpgsql';
	
CREATE OR REPLACE PROCEDURE delete_credit(oper_id integer) 								   
LANGUAGE SQL
AS $$
	update accounts set balance = balance - (select amount from credit where outer_row_id = oper_id) 
		where id = (select target_account from credit where outer_row_id = oper_id);
			
	delete from credit where outer_row_id = oper_id;
	delete from operations_queue where operation_id = oper_id;
$$;

	
	Select * from get_income(12);
	Select * from get_expenses(12);
	

	CREATE OR REPLACE FUNCTION get_credits(usr_id integer) 
	RETURNS TABLE (operation_id INT, operation_type operation_type, credit_name varchar, amount real,
				    date_time timestamp, end_date date, interest_rate real, target_account INT,
				  	credit_payments credit_payments_type, closed boolean) 
	AS $$
	BEGIN
		RETURN QUERY SELECT operations_queue.operation_id, operations_queue.operation_type, credit.credit_name, 
		credit.amount, operations_queue.date_time, credit.end_date, credit.interest_rate, credit.target_account, 
		credit.credit_payments, credit.closed
			FROM operations_queue 
			INNER JOIN credit 
			ON operations_queue.operation_id = credit.outer_row_id 
			WHERE operations_queue.user_id = usr_id;
	END; 
	$$ LANGUAGE 'plpgsql';

drop function get_debts;


	CREATE OR REPLACE FUNCTION get_transfer(usr_id integer) 
	RETURNS TABLE (operation_id INT, operation_type operation_type, date_time date, amount real,
				    source_account INT, target_account INT) 
	AS $$
	BEGIN
		RETURN QUERY SELECT operations_queue.operation_id, operations_queue.operation_type, operations_queue.date_time, 
							transfer.amount, transfer.source_account, transfer.target_account
			FROM operations_queue 
			INNER JOIN transfer 
			ON operations_queue.operation_id = transfer.outer_row_id 
			WHERE operations_queue.user_id = usr_id;
	END; 
	$$ LANGUAGE 'plpgsql';

		CREATE OR REPLACE FUNCTION get_deposit(usr_id integer) 
	RETURNS TABLE (operation_id INT, operation_type operation_type, deposit_name varchar, amount real,
				    currency varchar, date_time timestamp, end_date timestamp, interest_rate real, 
				    interest_payments interest_payments_type, source_account INT) 
	AS $$
	BEGIN
		RETURN QUERY SELECT operations_queue.operation_id, operations_queue.operation_type, deposit.deposit_name, deposit.amount, 
		deposit.currency, operations_queue.date_time, deposit.end_date, deposit.interest_rate, deposit.interest_payments, deposit.source_account
			FROM operations_queue 
			INNER JOIN deposit
			ON operations_queue.operation_id = deposit.outer_row_id 
			WHERE operations_queue.user_id = usr_id;
	END; 
	$$ LANGUAGE 'plpgsql';

	CREATE OR REPLACE FUNCTION get_accounts(usr_id integer) 
	RETURNS TABLE (account_id INT, account_name varchar, balance real, currency varchar) 
	AS $$
	BEGIN
		RETURN QUERY SELECT accounts.id, accounts.account_name, accounts.balance, accounts.currency
			FROM accounts 
			WHERE user_id = usr_id;
	END; 
	$$ LANGUAGE 'plpgsql';


------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--	PROCEDURES

CREATE OR REPLACE PROCEDURE delete_credit(oper_id integer) 								   
LANGUAGE SQL
AS $$
	update accounts set balance = balance - (select amount from credit where outer_row_id = oper_id) 
		where id = (select target_account from credit where outer_row_id = oper_id);
			
	delete from credit where outer_row_id = oper_id;
	delete from operations_queue where operation_id = oper_id;

CREATE OR REPLACE PROCEDURE new_income(usr_id integer, date_time DATE, amount real, account_id integer)
LANGUAGE SQL
AS $$
		WITH row_id AS (INSERT INTO operations_queue(user_id, operation_type, date_time) VALUES(usr_id, 'income', date_time) RETURNING operation_id)
        	INSERT INTO income(outer_row_id, amount, account_id)
            	VALUES((SELECT operation_id FROM row_id), amount, account_id);
        UPDATE accounts SET balance = balance + amount WHERE id = account_id;
$$;
	
drop PROCEDURE new_income


CREATE OR REPLACE PROCEDURE new_expense(usr_id integer, date_time DATE, amount real, account_id integer)
LANGUAGE SQL
AS $$
	WITH row_id AS (INSERT INTO operations_queue(user_id, operation_type, date_time) VALUES(usr_id, 'expense', date_time) RETURNING operation_id)
		INSERT INTO expense(outer_row_id, amount, account_id)
			VALUES((SELECT operation_id FROM row_id), amount, account_id);
		UPDATE accounts SET balance = balance - amount WHERE id = account_id;
$$;
 

CREATE OR REPLACE PROCEDURE new_transfer(usr_id integer, date_time DATE, amount real, source_account_id integer, target_account_id integer)
LANGUAGE SQL
AS $$
	WITH row_id AS (INSERT INTO operations_queue(user_id, operation_type, date_time) VALUES(usr_id, 'transfer', date_time) RETURNING operation_id)
		INSERT INTO transfer(outer_row_id, amount, source_account, target_account)
			VALUES((SELECT operation_id FROM row_id), amount, source_account_id, target_account_id);
                    
	UPDATE accounts SET balance = balance - amount WHERE id = source_account_id;
    UPDATE accounts SET balance = balance + amount WHERE id = target_account_id;
$$;


CREATE OR REPLACE PROCEDURE new_debt(usr_id integer, date_time DATE, amount real, debt_mode debt_type, person text, user_comment text, source_account_id integer)
LANGUAGE SQL
AS $$
	WITH row_id AS (INSERT INTO operations_queue(user_id, operation_type, date_time) VALUES(usr_id, 'debt', date_time) RETURNING operation_id)
		INSERT INTO debt(outer_row_id, amount, source_account, person, user_comment, date_time)
			VALUES((SELECT operation_id FROM row_id), amount, source_account_id, person, user_comment, date_time);

	update accounts set balance = balance - amount where id = source_account_id and debt_mode = 'lent';
	update accounts set balance = balance + amount where id = source_account_id and debt_mode = 'borrowed';
$$;





CREATE OR REPLACE PROCEDURE new_deposit(user_id integer, deposit_name text, amount real, interest_rate real,
		source_account_id integer, interest_payments interest_payments_type, date_time date, end_date date)                                    
LANGUAGE SQL
AS $$
	WITH row_id AS (INSERT INTO operations_queue(user_id, operation_type, date_time) VALUES(user_id, 'deposit', date_time) RETURNING operation_id)
		INSERT INTO deposit(outer_row_id, deposit_name, amount, currency, begin_date, end_date, interest_rate, interest_payments)
			VALUES((SELECT operation_id FROM row_id), deposit_name, amount, (SELECT currency FROM accounts WHERE id=source_account_id),
				date_time, end_date, interest_rate, interest_payments);
                    
	UPDATE accounts SET balance = balance - amount WHERE id = source_account_id;
$$;

						
CREATE OR REPLACE PROCEDURE new_credit(user_id integer, date_time date, end_date date, amount real, 
		interest_rate real, credit_name text, target_account_id integer, credit_payments CREDIT_PAYMENTS_TYPE)                             
LANGUAGE SQL
AS $$										
	WITH row_id AS (INSERT INTO operations_queue(user_id, operation_type, date_time) VALUES(user_id, 'credit', date_time) RETURNING operation_id)
		INSERT INTO credit(outer_row_id, credit_name, amount, currency, begin_date, end_date, interest_rate, target_account, credit_payments)
			VALUES((SELECT operation_id FROM row_id), credit_name, amount, (SELECT currency FROM accounts WHERE id=target_account_id),
				date_time, end_date, interest_rate, target_account_id, credit_payments);
										 														
	UPDATE accounts SET balance = balance + amount WHERE id = target_account_id;
$$;

CREATE OR REPLACE PROCEDURE delete_debt(operation_id integer)
LANGUAGE SQL
AS $$
	update accounts set balance = balance + (select amount from debt where outer_row_id = operation_id) 
			where id = (select source_account from debt where outer_row_id = operation_id) 
				and (select debt_mode from debt where outer_row_id = operation_id) = 'lent';
	
	update accounts set balance = balance - (select amount from debt where outer_row_id = operation_id) 
			where id = (select source_account from debt where outer_row_id = operation_id) 
				and (select debt_mode from debt where outer_row_id = operation_id) = 'borrowed';	
			
	delete from debt where outer_row_id = operation_id;
	delete from operations_queue where operation_id = operation_id;
$$;

CREATE OR REPLACE PROCEDURE delete_deposit(oper_id integer) 								   
LANGUAGE SQL
AS $$
	update accounts set balance = balance + (select amount from deposit where outer_row_id = oper_id) 
		where id = (select source_account from deposit where outer_row_id = oper_id);
			
	delete from deposit where outer_row_id = oper_id;
	delete from operations_queue where operation_id = oper_id;
$$;

CREATE OR REPLACE PROCEDURE delete_credit(oper_id integer) 								   
LANGUAGE SQL
AS $$
	update accounts set balance = balance - (select amount from credit where outer_row_id = oper_id) 
		where id = (select target_account from credit where outer_row_id = oper_id);
			
	delete from credit where outer_row_id = oper_id;
	delete from operations_queue where operation_id = oper_id;
$$;

CREATE OR REPLACE PROCEDURE close_credit(oper_id integer) 								   
LANGUAGE SQL
AS $$
	update accounts set balance = balance - (select amount from credit where outer_row_id = oper_id) 
		where id = (select target_account from credit where outer_row_id = oper_id);
			
	delete from credit where outer_row_id = oper_id;
	delete from operations_queue where operation_id = oper_id;
$$;
						
CREATE OR REPLACE PROCEDURE delete_expense(oper_id integer) 									   
LANGUAGE SQL
	AS $$
	update accounts set balance = balance + (select amount from expense where outer_row_id = oper_id) 
			where id = (select account_id from expense where outer_row_id = oper_id);
		delete from expense where outer_row_id = oper_id;
		delete from operations_queue where operation_id = oper_id;
$$;

CREATE OR REPLACE PROCEDURE delete_income(oper_id integer) 								   
LANGUAGE SQL
	AS $$
		update accounts set balance = balance - (select amount from income where outer_row_id = oper_id) 
			where id = (select account_id from income where outer_row_id = oper_id);
		delete from income where outer_row_id = oper_id;
		delete from operations_queue where operation_id = oper_id;
$$;

CREATE OR REPLACE PROCEDURE delete_transfer(oper_id integer) 								   
LANGUAGE SQL
AS $$
	update accounts set balance = balance + (select amount from transfer where outer_row_id = oper_id) 
		where id = (select source_account from transfer where outer_row_id = oper_id);
			
	update accounts set balance = balance - (select amount from transfer where outer_row_id = oper_id)
		where id = (select target_account from transfer where outer_row_id = oper_id);
			
	delete from transfer where outer_row_id = oper_id;
	delete from operations_queue where operation_id = oper_id;
$$;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--	DEFAULT INSERTIONS

	insert into categories(category_name, category_type, category_icon, user_id)
		values('Продукты', 'expense','products.png', null), 
				('Алкоголь', 'expense', 'alcohol.png', null), 
				('Подарки', 'expense', 'gift.png', null),
				('Кафе и рестораны', 'expense', 'cafe.png', null),
				('Одежда', 'expense', 'clothes.png', null),
				('Образование', 'expense', 'education.png', null),
				('Здоровье', 'expense', 'health.png', null),
				('Дом', 'expense', 'home.png', null),
				('Транспорт', 'expense', 'transport.png', null),
				('Оклад', 'income', 'salary.png', null),
				('Аксессуары', 'expense', 'accessories.png', null);
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			