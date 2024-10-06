# Case Study Questions and Solutions

### 1. What is the total amount each customer spent at the restaurant?

Question is preety simple but we have to join two tables to get the answer. As sales table have data regarding sales but not price and Menu table consists price for each food item.

Calculating SUM of price and grouping the same by customer ID will lead to the answer we want.

```sql
SELECT
	s.customer_id,
	SUM(m.price) AS total_amt
FROM
	sales s
	JOIN menu m ON m.product_id = s.product_id
GROUP BY
	s.customer_id;
```

| customer_id | total_amt |
|-------------|----------:|
| B | 74 |
| C	| 36 |
| A	| 76 |
|

### 2. How many days has each customer visited the restaurant?

Visits are basically customer went to restaurant and ordered something. Finding unique number of order_date can give us number of visits customer wise. 

```sql
SELECT
	customer_id,
	COUNT(DISTINCT order_date) AS visits
FROM
	sales
GROUP BY
	customer_id;
```
| customer_id |	visits |
|-------------|-------:|
|A|	4|
|B|6|
|C|2|
|

### 3. What was the first item from the menu purchased by each customer?

We will tackle this question step by step

* Find out first order of customer 
using window function where customer wise order dates will be returned.
sort this using order date and assign row number to each row. Yes, I know we might get duplicate date values for customer "A" but if we had date with timestamp instead of only date, this problem will be solved.

* Second thing we will join menu table using product ID to get product name.

* Below is query with common table expression returning indexed table with required data, we will extract only first rows from this data.


```sql
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
```

### 4. What is the most purchased item on the menu and how many times was it purchased by all customers?

* Above question itself is little unclear, but what I understood from this is we need two seperate queries to get desired output.

```sql

--First question asks for which item is ordered most
SELECT
	m.product_name,
	COUNT(s.product_id) AS times_purchased
FROM
	menu m
	JOIN sales s ON m.product_id = s.product_id
GROUP BY
	m.product_name
ORDER BY
	COUNT(s.product_id) DESC
	LIMIT 1;

--Second question is how many times above product is ordered by each customer.

SELECT
	s.customer_id,
	s.product_id,
	COUNT(s.product_id) AS times_ordered,
FROM
	sales s
GROUP BY
	s.customer_id,
	s.product_id
HAVING
	s.product_id = 3;

```
* Output - Query 1

|product_name|times_purchased|
|------------|--------------:|
|ramen|	8|
|

* Output - Query 2

|customer_id| product_id | times_ordered|
|-----------|------------|------------:|
| A | 3 | 3 | 
| B | 3 | 2 |
| C | 3 | 3 |

### 5. Which item was the most popular for each customer?

This question is bit similar to above question as we can find out product which is most ordered by each customer which will be their favourite item.
We will count the product times ordered by each customer and order the count using dense rank to ckeck duplicates in count. We are making this query dynamic by retriving results where dense rank is 1 i.e. most favourite product. And as expected, for customer "B" all 3 products are favourite.

```sql
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
```

|customer_id|product_name|times_ordered|
|-----------|------------|------------:|
|A|ramen|3|
|B|sushi|2|
|B|curry|2|
|B|ramen|2|
|C|ramen|3|

### 6. Which item was purchased first by the customer after they became a member?

Here, we need all three tables joined to get desired output.
* First found out product ordered by customer and order them by order_date from sales table.
* Second join this sales table with member's table and retrive only results where join date is before the order date. i.e. products ordered only after customer become member. as there may be customer who purchased any product before becoming member.

```sql
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
```

|customer_id|product_name|
|-----------|-----------:|
|A|ramen|
|B|sushi|
|

### 7. Which item was purchased just before the customer became a member?

* This question is similar to above question, only difference is retrive product ordered by customer where join date is after the order date.

* As per result below, Customer C did not purchase any item before becoming member.

```sql
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
```

|customer_id|product_name|
|-----------|-----------:|
|A	|sushi|
|A|	curry|
|B|	curry|
|

### 8. What is the total items and amount spent for each member before they became a member?

This question involves two steps
* We will use aggregation functions on produscts and their price to find out number of products ordered and total price spent on these products.
* Then we will retrive data before the join date i.e. before they become member. 

```sql
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
```

|customer_id|number_of_products|amount_spent|
|-----------|------------------|-----------:|
|B|	3|	40|
|A|	2|	25|
|


### 9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?

To obtain ponts gained by each customer, we need to multiply price by multiplier but with a condition as customer who bought "Sushi" will get points twice the price. 

* To get desired points we can use case statement (Similar to if else statement) where there is "Sushi" multiply the price by 20 else by 10.

* Now, group by the result by customer ID and sort by points obtained.

```sql
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
```

|customer_id|points|
|-----|------:|
|B|	940|
|A|	860|
|C|	360|
|

### 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi. How many points do customer A and B have at the end of January?

okay, this question is little tricky. Lets dig in,

* Multiple case statements will be used here, but first understand conditions better.

1. If customer became member, points earned in first week will be doubled.
2. At any point of time, if "Sushi" is purchased, points will be doubled with "Sushi"s price. This implies that, if customer buy's "Sushi" in first weekmof their membership, points will be doubled two times the price.

* We will retrieve the data before first of February. i.e. For the month of January 2021.

```sql
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
```

|customer_id|points|
|-----------|------:|
|A|	1370|
|B|820|
|

*****

## Bonus Questions

### 11. Recreate the following table output using the available data:

|customer_id|order_date|product_name|price|	member|
|-----------|----------|------------|-----|------:|
|A|	2021-01-01|	curry|	15	|N|
|A|	2021-01-01|	sushi|	10	|N|
|A|	2021-01-07|	curry|	15	|Y|
|A|	2021-01-10|	ramen|	12	|Y|
|A|	2021-01-11|	ramen|	12	|Y|
|A|	2021-01-11|	ramen|	12	|Y|
|B|	2021-01-01|	curry|	15	|N|
|B|	2021-01-02|	curry|	15	|N|
|B|	2021-01-04|	sushi|	10	|N|
|B|	2021-01-11|	sushi|	10	|Y|
|B|	2021-01-16|	ramen|	12	|Y|
|B|	2021-02-01|	ramen|	12	|Y|
|C|	2021-01-01|	ramen|	12	|N|
|C|	2021-01-01|	ramen|	12	|N|
|C|	2021-01-07|	ramen|	12	|N|
|

```sql
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
```


### 12. Danny also requires further information about the ranking of customer products,but he purposely does not need the ranking for non-member purchases so he expects null ranking values for the records when customers are not yet part of the loyalty program.

|customer_id|order_date|product_name|price|	member|ranking|
|-----------|----------|------------|-----|------|-------|
|A|	2021-01-01|	curry|	15	|N| null|
|A|	2021-01-01|	sushi|	10	|N| null|
|A|	2021-01-07|	curry|	15	|Y| 1 |
|A|	2021-01-10|	ramen|	12	|Y| 2 |
|A|	2021-01-11|	ramen|	12	|Y| 3 |
|A|	2021-01-11|	ramen|	12	|Y| 3 |
|B|	2021-01-01|	curry|	15	|N| null|
|B|	2021-01-02|	curry|	15	|N| null|
|B|	2021-01-04|	sushi|	10	|N| null|
|B|	2021-01-11|	sushi|	10	|Y| 1|
|B|	2021-01-16|	ramen|	12	|Y| 2|
|B|	2021-02-01|	ramen|	12	|Y| 3|
|C|	2021-01-01|	ramen|	12	|N| null|
|C|	2021-01-01|	ramen|	12	|N| null|
|C|	2021-01-07|	ramen|	12	|N| null|
|

```sql
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
```

