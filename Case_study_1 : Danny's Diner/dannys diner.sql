CREATE SCHEMA dannys_diner;

SET
	search_path = dannys_diner;

DROP TABLE IF EXISTS sales;

CREATE TABLE IF NOT EXISTS sales (
	"customer_id" VARCHAR(1),
	"order_date" date,
	"product_id" INTEGER
);

INSERT INTO
	sales ("customer_id", "order_date", "product_id")
VALUES
	('A', '2021-01-01', '1'),
	('A', '2021-01-01', '2'),
	('A', '2021-01-07', '2'),
	('A', '2021-01-10', '3'),
	('A', '2021-01-11', '3'),
	('A', '2021-01-11', '3'),
	('B', '2021-01-01', '2'),
	('B', '2021-01-02', '2'),
	('B', '2021-01-04', '1'),
	('B', '2021-01-11', '1'),
	('B', '2021-01-16', '3'),
	('B', '2021-02-01', '3'),
	('C', '2021-01-01', '3'),
	('C', '2021-01-01', '3'),
	('C', '2021-01-07', '3');

DROP TABLE IF EXISTS menu;

CREATE TABLE IF NOT EXISTS menu (
	"product_id" INTEGER,
	"product_name" VARCHAR(5),
	"price" INTEGER
);

DROP TABLE IF EXISTS members;

INSERT INTO
	menu ("product_id", "product_name", "price")
VALUES
	('1', 'sushi', '10'),
	('2', 'curry', '15'),
	('3', 'ramen', '12');

CREATE TABLE IF NOT EXISTS members ("customer_id" VARCHAR(1), "join_date" date);

INSERT INTO
	members ("customer_id", "join_date")
VALUES
	('A', '2021-01-07'),
	('B', '2021-01-09');

-- 1. What is the total amount each customer spent at the restaurant?
SELECT
	s.customer_id,
	SUM(m.price)
FROM
	sales s
	JOIN menu m ON m.product_id = s.product_id
GROUP BY
	s.customer_id;

/*
"customer_id"	"sum"
"B"	74
"C"	36
"A"	76
*/
-- 2. How many days has each customer visited the restaurant?
SELECT
	customer_id,
	COUNT(DISTINCT order_date) AS visits
FROM
	sales
GROUP BY
	customer_id;

/*
"customer_id"	"visits"
"A"	4
"B"	6
"C"	2
*/
-- 3. What was the first item from the menu purchased by each customer?
WITH
	cte AS (
		SELECT
			s.customer_id,
			s.order_date,
			m.product_name,
			ROW_NUMBER() OVER (
				PARTITION BY
					s.customer_id
				ORDER BY
					s.order_date
			) AS rk
		FROM
			sales s
			JOIN menu m ON s.product_id = m.product_id
		ORDER BY
			m.product_id
	)
SELECT
	customer_id,
	product_name
FROM
	cte
WHERE
	rk = 1;

/*
"customer_id"	"product_name"
"A"	"sushi"
"B"	"curry"
"C"	"ramen"
*/
-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
SELECT
	m.product_name,
	times_ordered_by_all_customers
FROM
	(
		SELECT
			product_id,
			SUM(times_ordered) AS times_ordered_by_all_customers
			--COUNT(product_id) AS unique_customers_bought
		FROM
			(
				SELECT
					s.customer_id,
					s.product_id,
					COUNT(s.product_id) AS times_ordered,
					DENSE_RANK() OVER (
						PARTITION BY
							s.customer_id
						ORDER BY
							COUNT(s.product_id) DESC
					) AS d_rank
				FROM
					sales s
				GROUP BY
					s.customer_id,
					s.product_id
			) x
			-- x table retrieves how many times each product is ordered by each customer and ranks it by times ordered
		WHERE
			x.d_rank = 1
		GROUP BY
			product_id
		HAVING
			COUNT(product_id) = (
				SELECT
					COUNT(DISTINCT customer_id)
				FROM
					sales
			)
	) a
	-- a table retrieves the product ID which is most ordered and also bought by all customers we have in the table
	JOIN menu m ON m.product_id = a.product_id;

-- finally, the product name is retrieved by joining with a menu table
/*
"product_name"	"times_ordered_by_all_customers"
"ramen"	8
*/
-- 5. Which item was the most popular for each customer?
SELECT
	customer_id,
	product_name,
	times_ordered
FROM
	(
		SELECT
			s.customer_id,
			m.product_name,
			COUNT(s.product_id) AS times_ordered,
			DENSE_RANK() OVER (
				PARTITION BY
					s.customer_id
				ORDER BY
					COUNT(s.product_id) DESC
			) AS d_rank
		FROM
			sales s
			JOIN menu m ON m.product_id = s.product_id
		GROUP BY
			s.customer_id,
			m.product_name
	) x
WHERE
	d_rank = 1;

/*
"customer_id"	"product_name"	"times_ordered"
"A"	"ramen"	3
"B"	"sushi"	2
"B"	"curry"	2
"B"	"ramen"	2
"C"	"ramen"	3
*/
-- 6. Which item was purchased first by the customer after they became a member?
WITH
	cte AS (
		SELECT
			s.customer_id,
			menu.product_name,
			s.order_date,
			mem.join_date,
			DENSE_RANK() OVER (
				PARTITION BY
					s.customer_id
				ORDER BY
					s.order_date
			) AS rk
		FROM
			sales s
			JOIN menu ON menu.product_id = s.product_id
			JOIN members mem ON mem.customer_id = s.customer_id
		WHERE
			s.order_date > mem.join_date
	)
SELECT
	customer_id,
	product_name
FROM
	cte
WHERE
	rk = 1;

/*
"A"	"curry"
"B"	"sushi"

or
"customer_id"	"product_name"
"A"	"ramen"
"B"	"sushi"

*/
-- 7. Which item was purchased just before the customer became a member?
WITH
	cte AS (
		SELECT
			s.customer_id,
			menu.product_name,
			s.order_date,
			mem.join_date,
			DENSE_RANK() OVER (
				PARTITION BY
					s.customer_id
				ORDER BY
					s.order_date
			) AS rk
		FROM
			sales s
			JOIN menu ON menu.product_id = s.product_id
			JOIN members mem ON mem.customer_id = s.customer_id
		WHERE
			s.order_date < mem.join_date
	)
SELECT
	customer_id,
	product_name
FROM
	cte
WHERE
	rk = 1;

/*
"customer_id"	"product_name"
"A"	"sushi"
"A"	"curry"
"B"	"curry"
*/
-- 8. What is the total items and amount spent for each member before they became a member?
SELECT
	s.customer_id,
	COUNT(product_name) AS number_of_products,
	SUM(price) AS amount_spent
FROM
	sales s
	JOIN menu ON menu.product_id = s.product_id
	JOIN members mem ON mem.customer_id = s.customer_id
WHERE
	s.order_date < mem.join_date
GROUP BY
	1;

/*
"customer_id"	"number_of_products"	"amount_spent"
"B"	3	40
"A"	2	25
*/
-- 9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have? 
SELECT
	s.customer_id,
	SUM(
		CASE
			WHEN product_name = 'sushi' THEN price * 20
			ELSE price * 10
		END
	) AS points
FROM
	sales s
	JOIN menu ON menu.product_id = s.product_id
GROUP BY
	1
ORDER BY
	points DESC;

/*
"customer_id"	"points"
"B"	940
"A"	860
"C"	360
*/
-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi -
-- how many points do customer A and B have at the end of January?
SELECT
	s.customer_id, --menu.product_name, s.order_date, mem.join_date,
	SUM(
		CASE
			WHEN menu.product_name = 'sushi' THEN price * 20
			WHEN order_date >= join_date
			AND order_date <= join_date + 6 THEN price * 20
			ELSE price * 10
		END
	) AS points
FROM
	sales s
	JOIN menu ON menu.product_id = s.product_id
	JOIN members mem ON mem.customer_id = s.customer_id
WHERE
	s.order_date < '2021-02-01'::date
GROUP BY
	1;

/*
"customer_id"	"points"
"A"	1370
"B"	820
*/
------------------------BONUS QUESTION----------------------------------
/*
11.
Recreate the following table output using the available data:

customer_id	order_date	product_name	price	member
A	2021-01-01	curry	15	N
A	2021-01-01	sushi	10	N
A	2021-01-07	curry	15	Y
A	2021-01-10	ramen	12	Y
A	2021-01-11	ramen	12	Y
A	2021-01-11	ramen	12	Y
B	2021-01-01	curry	15	N
B	2021-01-02	curry	15	N
B	2021-01-04	sushi	10	N
B	2021-01-11	sushi	10	Y
B	2021-01-16	ramen	12	Y
B	2021-02-01	ramen	12	Y
C	2021-01-01	ramen	12	N
C	2021-01-01	ramen	12	N
C	2021-01-07	ramen	12	N
*/
SELECT
	s.customer_id,
	s.order_date,
	menu.product_name,
	menu.price,
	CASE
		WHEN mem.join_date <= s.order_date THEN 'Y'
		WHEN mem.join_date > s.order_date THEN 'N'
		ELSE 'N'
	END AS membership
FROM
	sales s
	JOIN menu ON menu.product_id = s.product_id
	LEFT JOIN members mem ON mem.customer_id = s.customer_id
ORDER BY
	s.customer_id,
	s.order_date;

/*
12.
Danny also requires further information about the ranking of customer products,
but he purposely does not need the ranking for non-member purchases so he expects null ranking values for the records 
when customers are not yet part of the loyalty program.

customer_id	order_date	product_name	price	member	ranking
A	2021-01-01	curry	15	N	null
A	2021-01-01	sushi	10	N	null
A	2021-01-07	curry	15	Y	1
A	2021-01-10	ramen	12	Y	2
A	2021-01-11	ramen	12	Y	3
A	2021-01-11	ramen	12	Y	3
B	2021-01-01	curry	15	N	null
B	2021-01-02	curry	15	N	null
B	2021-01-04	sushi	10	N	null
B	2021-01-11	sushi	10	Y	1
B	2021-01-16	ramen	12	Y	2
B	2021-02-01	ramen	12	Y	3
C	2021-01-01	ramen	12	N	null
C	2021-01-01	ramen	12	N	null
C	2021-01-07	ramen	12	N	null
*/
WITH
	cte AS (
		SELECT
			s.customer_id,
			s.order_date,
			menu.product_name,
			menu.price,
			CASE
				WHEN mem.join_date <= s.order_date THEN 'Y'
				WHEN mem.join_date > s.order_date THEN 'N'
				ELSE 'N'
			END AS membership
		FROM
			sales s
			JOIN menu ON menu.product_id = s.product_id
			LEFT JOIN members mem ON mem.customer_id = s.customer_id
		ORDER BY
			s.customer_id,
			s.order_date
	)
SELECT
	customer_id,
	order_date,
	product_name,
	price,
	membership,
	CASE
		WHEN membership = 'N' THEN NULL
		ELSE RANK() OVER (
			PARTITION BY
				customer_id,
				membership
			ORDER BY
				order_date
		)
	END AS ranking
FROM
	cte;

-------------------------END--------------------------------------------