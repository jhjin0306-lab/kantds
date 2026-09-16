/*
============================================================
[5장 2강] 실습문제: 쿼리 재작성 전후 실행계획 비교와 개선 효과 분석
============================================================

[실습 목표]
- 튜닝 전 실행계획과 실행 시간을 기준값으로 기록할 수 있다.
- 인덱스 추가 전후의 실행계획 변화를 비교할 수 있다.
- 쿼리 재작성 전후의 실행계획 변화를 비교할 수 있다.
- cost, 스캔 방식, Execution Time을 근거로 개선 효과를 판단할 수 있다.
- 개선이 항상 발생하는 것은 아니라는 점을 실행계획으로 설명할 수 있다.

[사용 환경]
- PostgreSQL
- DBeaver

[사용 데이터]
이번 과정에서는 아래 12개 CSV로 구성된 동일한 Retail Data Warehouse 데이터셋을 계속 사용합니다.

- customers
- employees
- order_items
- orders
- payments
- products
- promotions
- returns
- shipments
- stores
- suppliers
- categories

[이번 강에서 주로 사용하는 테이블]
- order_items
- orders

[주의사항]
- 실행계획의 cost와 Execution Time은 PostgreSQL 버전, 서버 환경,
  캐시 상태, 통계정보 등에 따라 달라질 수 있습니다.
- 개선 전후에는 비교 대상 SQL의 조건을 동일하게 유지해야 합니다.
- 한 번에 여러 요소를 변경하지 않고 한 가지 변경만 적용하여
  무엇 때문에 실행계획이 달라졌는지 확인합니다.
*/


/*
============================================================
필수 1. 인덱스 추가 전후 실행계획 비교
============================================================

[문제 1-1] 특정 상품 주문상품 조회 성능 비교

[문제 설명]
상품 운영팀에서 특정 product_id가 포함된 주문상품을 자주 조회한다고 가정합니다.

먼저 인덱스가 없는 상태에서 기준 성능을 기록한 뒤,
product_id 인덱스를 추가하고 동일한 쿼리를 다시 측정하세요.

[요구사항]
1. 기존 idx_order_items_product_id 인덱스가 있다면 삭제하세요.
2. product_id = 100인 주문상품을 조회하세요.
3. 다음 컬럼을 조회하세요.
   - order_item_id
   - order_id
   - product_id
   - qty
   - price
4. 인덱스 생성 전 동일 쿼리에 EXPLAIN ANALYZE를 적용하세요.
5. 다음 항목을 기록하세요.
   - 스캔 방식
   - cost
   - estimated rows
   - actual rows
   - Rows Removed by Filter
   - Execution Time
6. order_items.product_id에 idx_order_items_product_id 인덱스를 생성하세요.
7. 동일한 조회 쿼리에 다시 EXPLAIN ANALYZE를 적용하세요.
8. 개선 전후의 스캔 방식, cost, Execution Time을 비교하세요.
9. 다음 질문에 답하세요.
   Q1. 인덱스 추가 후 실제로 인덱스가 사용되었는지는 어디에서 확인할 수 있나요?
   -> index scan, seq scan 부분에서 확인 가능
   
   Q2. 스캔 방식이 Seq Scan에서 Index Scan 또는 Bitmap 계열 스캔으로 바뀌었다면 무엇을 의미하나요?
   ->테이블 전체를 순차적으로 읽는 방식 대신 
   product_id 인덱스를 이용하여 필요한 데이터 위치를 찾는 방식으로 변경
   
   Q3. 인덱스를 생성했는데 Execution Time이 반드시 감소한다고 단정할 수 있나요?
   -> 아니요. 데이터의 상태, 메모리, 서버 등에 따라 영향을 받을 수 있음.
   
10. 실습 종료 후 idx_order_items_product_id 인덱스를 삭제하세요.

[작성 결과]
- 개선 전 EXPLAIN ANALYZE
- CREATE INDEX 문
- 개선 후 EXPLAIN ANALYZE
- 전후 비교
- Q1~Q3 답변
- DROP INDEX 문
*/

-- [코드 작성란]
--1. 기존 idx_order_items_product_id 인덱스가 있다면 삭제하세요.
--2. product_id = 100인 주문상품을 조회하세요.
--3. 다음 컬럼을 조회하세요.
--   - order_item_id
--   - order_id
--   - product_id
--   - qty
--   - price
--4. 인덱스 생성 전 동일 쿼리에 EXPLAIN ANALYZE를 적용하세요.
--5. 다음 항목을 기록하세요.
--   - 스캔 방식
--   - cost
--   - estimated rows
--   - actual rows
--   - Rows Removed by Filter
--   - Execution Time
--6. order_items.product_id에 idx_order_items_product_id 인덱스를 생성하세요.
--7. 동일한 조회 쿼리에 다시 EXPLAIN ANALYZE를

--기존 인덱스 제거
drop index if exists idx_order_items_product_id

--
explain analyze
select  order_item_id, order_id, product_id, qty, price
from order_items
where product_id =100; 
--  ->  Parallel Seq Scan on order_items  
--(cost=0.00..6947.00 rows=25 width=20) (actual time=0.189..6.024 rows=16.00 loops=3)
--        Filter: (product_id = 100)
--        Rows Removed by Filter: 199984
--        Buffers: shared hit=3822
--Planning:
--  Buffers: shared hit=22 dirtied=1
--Planning Time: 0.215 ms
--Execution Time: 110.183 ms

--product_id인덱스 생성
create index idx_order_items_product_id on order_items.product_id

--개선 후 동일 쿼리 재측정
explain analyze
select  order_item_id, order_id, product_id, qty, price
from order_items
where product_id =100; 

--drop
drop index idx_order_items_product_id


/*
============================================================
필수 2. 쿼리 재작성 전후 실행계획 비교
============================================================

[문제 2-1] 인덱스 컬럼 가공 조건 재작성

[문제 설명]
orders.customer_id에 인덱스가 있다고 가정합니다.

다음 두 조건은 논리적으로 같은 고객을 찾습니다.

개선 전
WHERE customer_id + 0 = 31428

개선 후
WHERE customer_id = 31428

일반 B-Tree 인덱스는 원래 customer_id 값을 기준으로 구성되므로,
컬럼을 가공하지 않는 형태로 쿼리를 재작성했을 때
실행계획이 어떻게 달라지는지 확인하세요.

[요구사항]
1. 기존 idx_orders_customer_id 인덱스가 있다면 삭제하세요.
2. orders.customer_id에 idx_orders_customer_id 인덱스를 생성하세요.
3. 개선 전 쿼리에 EXPLAIN ANALYZE를 적용하세요.

   WHERE customer_id + 0 = 31428

4. 개선 후 쿼리에 EXPLAIN ANALYZE를 적용하세요.

   WHERE customer_id = 31428

5. 두 쿼리에서 다음 항목을 비교하세요.
   - 스캔 방식
   - Index Cond 또는 Filter
   - cost
   - actual rows
   - Execution Time
6. 두 쿼리의 조회 결과가 동일한지 확인하세요.
7. 다음 질문에 답하세요.
   Q1. 개선 전 쿼리가 기존 customer_id 인덱스를 직접 활용하기 어려운 이유는 무엇인가요?
   Q2. 개선 후 쿼리에서는 실행계획의 어떤 변화가 나타날 수 있나요?
   Q3. 이번 개선은 인덱스를 새로 추가한 것인가요, 쿼리 구조를 변경한 것인가요?
8. 실습 종료 후 idx_orders_customer_id 인덱스를 삭제하세요.

[작성 결과]
- CREATE INDEX 문
- 개선 전 EXPLAIN ANALYZE
- 개선 후 EXPLAIN ANALYZE
- 결과 동일 여부
- 전후 비교
- Q1~Q3 답변
- DROP INDEX 문
*/

-- [코드 작성란]
--drop index
drop index if exists idx_orders_customer_id;
--create
create index idx_orders_customer_id on orders(customer_id);
--origin
explain analyze
select *
from orders
where customer_id +0 = 31428;


explain analyze
select *
from orders
where customer_id= 31428;

select count(*) as before_count
from orders
where customer_id +0 = 31428;


select count(*) as before_count
from orders
where customer_id = 31428;

drop index idx_orders_customer_id;

/*
============================================================
과제. JOIN 쿼리의 날짜 인덱스 적용 전후 개선 효과 분석
============================================================

[문제 3-1] 고객 도시 정보를 포함한 특정 기간 주문 조회 튜닝 결과 보고

[문제 설명]
운영 리포트에서 2023년 12월 주문과 고객 도시 정보를 함께 조회하고,
최근 주문부터 확인하는 쿼리를 반복적으로 사용한다고 가정합니다.

orders와 customers를 customer_id 기준으로 JOIN한 상태에서
먼저 현재 실행계획을 기준값으로 기록한 뒤,
orders.order_date 인덱스를 추가하여 동일한 JOIN 쿼리를 다시 측정하세요.

마지막에는 Scan → Join → Sort 흐름과 실행계획 변화,
실행시간 개선 효과와 한계를 간단한 비교 보고서 형태로 정리하세요.

※ 과제는 필수 문제와 동일한 수준입니다.

[요구사항]
1. 기존 idx_orders_order_date 인덱스가 있다면 삭제하세요.
2. orders와 customers를 customer_id 기준으로 JOIN하세요.
3. 다음 기간의 주문만 조회하세요.

   orders.order_date >= DATE '2023-12-01'
   orders.order_date <  DATE '2024-01-01'

4. 다음 컬럼을 출력하세요.
   - orders.order_id
   - orders.order_date
   - customers.customer_id
   - customers.city
5. 결과를 orders.order_date DESC로 정렬하세요.
6. 인덱스 생성 전 EXPLAIN ANALYZE 결과에서 다음 항목을 기록하세요.
   - orders 스캔 방식 : Parallel Seq Scan
   - customers 스캔 방식 : Seq Scan
   - Join 방식 : Hash Join
   - JOIN 조건 : Hash Cond: o.customer_id = c.customer_id)
   - Sort 여부 : 있음 (Sort Key: o.order_date DESC, quicksort Memory)
   - total cost : 7304.30..8067.10
   - actual rows : 6344
   - Execution Time : 185.526 ms
7. orders.order_date에 idx_orders_order_date 인덱스를 생성하세요.
8. 동일한 JOIN 쿼리에 다시 EXPLAIN ANALYZE를 적용하세요.
9. 개선 후 동일한 항목을 기록하세요.
   - orders 스캔 방식 : Bitmap Index Scan
   - customers 스캔 방식 : Seq Scan
   - Join 방식 : Hash Join
   - JOIN 조건 :  Hash Join
   - Sort 여부 : 있음 (Sort Key: o.order_date DESC, quicksort Memory)
   - total cost : 4078.74..4095.47
   - actual rows : 6344
   - Execution Time : 9.153 ms
10. Join 노드가 개선 전후에 어떻게 달라졌는지 확인하세요.
    - Join 방식이 변경되었는지 : 변경없음
    - Join 입력 행 수가 달라졌는지 :  orders 쪽 입력 방식이 Parallel Seq Scan → Bitmap Scan으로 바뀜 / 결과 행수는 동일
    - Join 노드의 cost 또는 actual time이 달라졌는지 : Join 노드 cost/actual time 둘다 감소
11. 실행시간 감소율을 다음 식으로 계산하세요.

   (개선 전 Execution Time - 개선 후 Execution Time)
   / 개선 전 Execution Time * 100

12. 다음 형식으로 비교 결과를 정리하세요.

   항목                  개선 전                          개선 후
   ----------------------------------------------------------------------------------
   orders 스캔 방식    Parallel Seq Scan             Bitmap Index Scan
   customers 스캔 방식  Seq Scan                     Seq Sca
   Join 방식           Hash Join                    Hash Join
   JOIN 조건      o.customer_id = c.customer_id     o.customer_id = c.customer_id 
   Sort 여부       있음 (order_date DESC)            있음 (order_date DESC)   
   Join 노드 변화   orders 입력이 전체 스캔               orders 입력이 인덱스 범위 스캔
   total cost    7304.30..8067.10                  4078.74..4095.47
   actual rows      6344                           6344
   Execution Time  185.526 ms                      9.153 ms
   실행시간 감소율       0%                            약 95.07 %

13. 다음 질문에 답하세요.
    Q1. 인덱스 추가 후에도 Sort가 남을 수 있나요?
    -> 그렇다.  Sort 노드는 개선 후에도 그대로 남아 있다.
    
    Q2. 인덱스를 추가했는데 옵티마이저가 Seq Scan을 계속 선택한다면 어떤 의미인가요?
    -> 조회대상 행이 많거나 인덱스를 생성하는 것보다 더 낫다고 옵티마이저가 판단한 것이다.
    
    Q3. Join 방식이 변경되었다고 해서 반드시 성능이 개선되었다고 말할 수 있나요?
    -> 아니다. Join 방식 변화는 입력 행 수·데이터 분포에 따른 옵티마이저의 선택일 뿐이다.
    -> 개선 전후에도 Hash Join으로 동일.
    
    Q4. 이번 결과만으로 모든 날짜 JOIN 조회에 order_date 인덱스가 항상 효과적이라고 결론 내릴 수 있나요?
    -> 알 수 없다.  기간과 데이터 분포에 따라 달라지므로 항상 효과적이라고 단정할 수 없다.
    
14. 실습 종료 후 idx_orders_order_date 인덱스를 삭제하세요.

[제출 결과]
- 전체 JOIN SQL
- 개선 전 EXPLAIN ANALYZE
- CREATE INDEX 문
- 개선 후 EXPLAIN ANALYZE
- Scan / Join / Sort 비교표
- JOIN 조건 확인
- Join 노드 전후 변화 해석
- 실행시간 감소율
- Q1~Q4 답변
- DROP INDEX 문
*/

-- [코드 작성란]

--기존 idx_orders_order_date 인덱스가 있다면 삭제하세요.
--2. orders와 customers를 customer_id 기준으로 JOIN하세요.
--3. 다음 기간의 주문만 조회하세요.
--
--   orders.order_date >= DATE '2023-12-01'
--   orders.order_date <  DATE '2024-01-01'
--
--4. 다음 컬럼을 출력하세요.
--   - orders.order_id
--   - orders.order_date
--   - customers.customer_id
--   - customers.city
--5. 결과를 orders.order_date DESC로 정렬하세요.
--6. 인덱스 생성 전 EXPLAIN ANALYZE 결과에서 다음 항목을 기록


--요구사항 1
drop index if exists idx_orders_order_date;

--요구사항 2~5
select  o.order_id, o.order_date, c.customer_id, c.city
from orders o
join customers c on c.customer_id = o.customer_id 
where o.order_date >= DATE '2023-12-01' and o.order_date <  DATE '2024-01-01'
order by o.order_date desc;

--요규사항 6
EXPLAIN ANALYZE 
select  o.order_id, o.order_date, c.customer_id, c.city
from orders o
join customers c on c.customer_id = o.customer_id 
where o.order_date >= DATE '2023-12-01' and o.order_date <  DATE '2024-01-01'
order by o.order_date desc;

--Gather Merge  (cost=7304.30..8067.10 rows=6693 width=18) 
--(actual time=181.980..184.675 rows=6344.00 loops=1)
--  Workers Planned: 1
--  Workers Launched: 1
--  Buffers: shared hit=2251
--  ->  Sort  (cost=6304.29..6314.13 rows=3937 width=18) 
--				(actual time=7.501..7.712 rows=3172.00 loops=2)
--        Sort Key: o.order_date DESC
--        Sort Method: quicksort  Memory: 440kB
--        Buffers: shared hit=2251
--        Worker 0:  Sort Method: quicksort  Memory: 25kB
--        ->  Hash Join  (cost=1457.00..6069.19 rows=3937 width=18) 
--						(actual time=2.645..7.195 rows=3172.00 loops=2)
--              Hash Cond: (o.customer_id = c.customer_id)
--              Buffers: shared hit=2243
--              ->  Parallel Seq Scan on orders o  (cost=0.00..4558.06 rows=3937 width=12) 
--													(actual time=0.007..3.646 rows=3172.00 loops=2)
--                    Filter: ((order_date >= '2023-12-01'::date) AND (order_date < '2024-01-01'::date))
--                    Rows Removed by Filter: 146828
--                    Buffers: shared hit=1911
--              ->  Hash  (cost=832.00..832.00 rows=50000 width=10) 
--							(actual time=5.089..5.090 rows=50000.00 loops=1)
--                    Buckets: 65536  Batches: 1  Memory Usage: 2612kB
--                    Buffers: shared hit=332
--                    ->  Seq Scan on customers c  (cost=0.00..832.00 rows=50000 width=10) 
--												(actual time=0.008..2.135 rows=50000.00 loops=1)
--                          Buffers: shared hit=332
--Planning Time: 0.159 ms
--Execution Time: 185.526 ms

create index idx_orders_order_date on orders(order_date);

EXPLAIN ANALYZE 
select  o.order_id, o.order_date, c.customer_id, c.city
from orders o
join customers c on c.customer_id = o.customer_id 
where o.order_date >= DATE '2023-12-01' and o.order_date <  DATE '2024-01-01'
order by o.order_date desc;

--Sort  (cost=4078.74..4095.47 rows=6693 width=18) 
--(actual time=8.623..8.778 rows=6344.00 loops=1)
--  Sort Key: o.order_date DESC
--  Sort Method: quicksort  Memory: 440kB
--  Buffers: shared hit=2176 read=5
--  ->  Hash Join  (cost=1550.03..3653.45 rows=6693 width=18) 
--  (actual time=5.176..8.095 rows=6344.00 loops=1)
--        Hash Cond: (o.customer_id = c.customer_id)
--        Buffers: shared hit=2176 read=5
--        ->  Bitmap Heap Scan on orders o  (cost=93.03..2104.42 rows=6693 width=12) 
--        (actual time=0.376..1.832 rows=6344.00 loops=1)
--              Recheck Cond: ((order_date >= '2023-12-01'::date) AND (order_date < '2024-01-01'::date))
--              Heap Blocks: exact=1841
--              Buffers: shared hit=1844 read=5
--              ->  Bitmap Index Scan on idx_orders_order_date  (cost=0.00..91.35 rows=6693 width=0) 
--              (actual time=0.253..0.253 rows=6344.00 loops=1)
--                    Index Cond: ((order_date >= '2023-12-01'::date) AND (order_date < '2024-01-01'::date))
--                    Index Searches: 1
--                    Buffers: shared hit=3 read=5
--        ->  Hash  (cost=832.00..832.00 rows=50000 width=10) 
--        (actual time=4.663..4.663 rows=50000.00 loops=1)
--              Buckets: 65536  Batches: 1  Memory Usage: 2612kB
--              Buffers: shared hit=332
--              ->  Seq Scan on customers c  (cost=0.00..832.00 rows=50000 width=10) 
--              (actual time=0.008..1.873 rows=50000.00 loops=1)
--                    Buffers: shared hit=332
--Planning:
--  Buffers: shared hit=18 read=4
--Planning Time: 0.384 ms
--Execution Time: 9.153 ms

--요구사항 11--
-- 감소율(%) = (185.526 - 9.153) / 185.526 * 100
--          = 176.373 / 185.526 * 100
--          ≒ 95.07 %
-- -> 실행시간이 약 95% 감소


drop index idx_orders_order_date;


/*
============================================================
실습 마무리
============================================================

아래 내용을 한 문단으로 정리하세요.

1. 튜닝 전에 기준 실행계획을 먼저 기록해야 하는 이유는 무엇인가요?
-> 개선 전 스캔, cost, rows, actual time등 실제 변경 전 후를 비교하기 위해

2. 인덱스 추가와 쿼리 재작성 후 무엇을 다시 측정해야 하나요?
-> 동일한 쿼리 조건으로 explain analyze를 다시 실행
-> cost, scan, actual rows 등의 변화 확인 

3. 튜닝 효과를 설명할 때 어떤 지표를 함께 비교해야 하나요?
-> cost, estimated rows, actual rows, execution time 등 비교

4. 실행계획이 바뀌었다는 사실만으로 성능 개선을 확정할 수 없는 이유는 무엇인가요?
-> 실행 방식을 튜닝해도 데이터 분포와 서버 상태에 따라 성능이 반드시 개선되었다고 보기는 어려움
->
*/

