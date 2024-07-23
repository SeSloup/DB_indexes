--    SQL. Индексы	 ------------------------
-- 1)

select  round(sum(index_length)/sum(data_length)*100) '%_index' FROM INFORMATION_SCHEMA.tables
where TABLE_schema = 'sakila'

-- 2) 
/*
 * Слабые места:
1) неявное указание проведения операций join
2) фильтрация после связывания таблиц, то увеличивает обрабатываемый фильтром массив
3) используются все поля таблиц. дешевле сцепить поля имен одной из исходной таблиц до связывания джойнами
4) исходный запрос должен просчитывать сумму с разделением по c.customer_id, f.title внутри функции over, но игнорирует это требование из-за неявных джойнов
-если задачей является получение такого же ответа как и в исходном варианте, то достаточно сделать group by или partition by по полю customer id и исключить соединение с таблицами inventory и film
-если задачей является получение разделения сумм по выбранным полям, то прописываем group by c.customer_id, fi.title или partition by c.customer_id, fi.title.  в нашем случае действие последнее и не принципиально уменьшать количество строк таблицы.
5) в случае необходимости использования поля f.title для фильтрации на постоянной основе (н.р. bi запрос для ежедневного отчета) стоит присвоить названиям числовые значения или создать отдельную таблицу с индексом. т.к. поиск по маленькому числовому значению будет гораздно быстрее и проще 
 * 
 */

explain analyze
select 
distinct concat(c.last_name, ' ', c.first_name),
sum(p.amount) over (partition by c.customer_id, f.title)
from payment p, rental r, customer c, inventory i, film f
where date(p.payment_date) = '2005-07-30'
		and p.payment_date = r.rental_date
		and r.customer_id = c.customer_id
		and i.inventory_id = r.inventory_id;
		
		/*
		-> Table scan on <temporary>  (cost=2.5..2.5 rows=0) (actual time=14399..14399 rows=391 loops=1)
		*/
	

explain analyze
with p as 
	(select * from payment where date(payment_date) = '2005-07-30'),
	c as 
	(select customer_id, concat(last_name, ' ', first_name) full_name  from customer),
	fi as
	(select inventory_id, title from inventory i left join (select film_id, title from film) f on f.film_id=i.film_id)
select distinct full_name, sum(p.amount) from p
	left join c on p.customer_id = c.customer_id
	left join rental r on r.customer_id = c.customer_id and p.payment_date = r.rental_date
	left join fi on fi.inventory_id = r.inventory_id
group by c.customer_id, fi.title;

		/*
		Sort with duplicate removal: c.full_name, `sum(p.amount)`  (actual time=13..13 rows=599 loops=1)
		*/
