# Домашнее задание к занятию «Индексы»


### Задание 1

Напишите запрос к учебной базе данных, который вернёт процентное отношение общего размера всех индексов к общему размеру всех таблиц.

![00](https://github.com/SeSloup/DB_indexes/blob/main/screens/00.png)


```sql
select  round(sum(index_length)/sum(data_length)*100) '%_index' FROM INFORMATION_SCHEMA.tables
where TABLE_schema = 'sakila'
```
![01](https://github.com/SeSloup/DB_indexes/blob/main/screens/01.png)

### Задание 2

Выполните explain analyze следующего запроса:
```
select distinct concat(c.last_name, ' ', c.first_name), sum(p.amount) over (partition by c.customer_id, f.title)
from payment p, rental r, customer c, inventory i, film f
where date(p.payment_date) = '2005-07-30' and p.payment_date = r.rental_date and r.customer_id = c.customer_id and i.inventory_id = r.inventory_id
```
- перечислите узкие места;
- оптимизируйте запрос: внесите корректировки по использованию операторов, при необходимости добавьте индексы.


```sql
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
	

```

```sql
-- создадим индекс по дате
-- create index idx_payment_date
-- on `sakila`.payment(payment_date);

-- create index idx_rental_date
-- on `sakila`.rental (rental_date);



explain analyze
select distinct concat(last_name, ' ', first_name), sum(p.amount) from payment p
	inner join customer c on p.customer_id = c.customer_id
	inner join rental r on r.customer_id = c.customer_id and p.payment_date = r.rental_date
	inner join inventory i on i.inventory_id = r.inventory_id
	inner join film f on f.film_id=i.film_id
 where payment_date >= '2005-07-30' and payment_date < '2005-07-31'
group by c.customer_id, f.title;

		/*
		-> Sort with duplicate removal: c.full_name, `sum(p.amount)`  (actual time=7.91..7.95 rows=599 loops=1)
		*/
```
![02](https://github.com/SeSloup/DB_indexes/blob/main/screens/02.png)

![03](https://github.com/SeSloup/DB_indexes/blob/main/screens/03.png)
 * Слабые места:
1) неявное указание проведения операций join
2) фильтрация после связывания таблиц, чтото увеличивает обрабатываемый фильтром массив
3) используются все поля таблиц. дешевле сцепить поля имен одной из исходной таблиц до связывания джойнами
4) исходный запрос должен просчитывать сумму с разделением по c.customer_id, f.title внутри функции over, но игнорирует это требование из-за неявных джойнов
-если задачей является получение такого же ответа как и в исходном варианте, то достаточно сделать group by или partition by по полю customer id и исключить соединение с таблицами inventory и film
-если задачей является получение разделения сумм по выбранным полям, то прописываем group by c.customer_id, f.title или partition by c.customer_id, f.title.  в нашем случае действие последнее и не принципиально уменьшать количество строк таблицы.
5) в случае необходимости использования поля f.title для фильтрации на постоянной основе (н.р. bi запрос для ежедневного отчета) стоит присвоить названиям числовые значения или создать отдельную таблицу с индексом. т.к. поиск по маленькому числовому значению будет гораздно быстрее и проще 
6) отсутствие индекса по полю payment.payment_date, rental.rental_date - не ухудшает скорость заливки новых данных, но снижает скорость запроса/поиска
 * 
 */
		
