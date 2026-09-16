/*
============================================================
[2장 1강] 실습문제: 인덱스 구조와 동작 원리
============================================================

[실습 목표]
- B-Tree 인덱스가 검색 범위를 줄여 데이터를 탐색하는 원리를 이해할 수 있다.
- CREATE INDEX와 DROP INDEX를 이용하여 인덱스를 생성하고 삭제할 수 있다.
- EXPLAIN ANALYZE를 이용하여 인덱스 생성 전후의 실행계획을 비교할 수 있다.
- pg_indexes를 이용하여 생성된 인덱스 목록을 확인할 수 있다.
- 인덱스 생성에 따라 INSERT, UPDATE, DELETE 시 추가 작업이 필요한 이유를 설명할 수 있다.

[사용 환경]
- PostgreSQL
- DBeaver

[사용 데이터]
- orders      : 300,000행
- products    : 10,000행

[주의사항]
- 실행 시간과 cost는 PostgreSQL 환경에 따라 달라질 수 있습니다.
- 특정 실행계획 형태를 정답으로 고정하지 않습니다.
- 학생은 자신의 EXPLAIN ANALYZE 결과를 기준으로 작성합니다.
*/


/*
============================================================
실습 준비
============================================================
*/

SELECT COUNT(*) AS order_count
FROM orders;

SELECT COUNT(*) AS product_count
FROM products;


/*
============================================================
필수 1. customer_id 인덱스 생성 전후 비교
============================================================

[문제 1-1]

[문제 설명]
orders에서 특정 고객의 주문을 조회할 때
customer_id 인덱스 생성 전후의 실행계획이 어떻게 달라지는지 확인하세요.

[요구사항]
1. idx_orders_customer_id 인덱스가 있다면 삭제하세요.
2. customer_id = 31428 조건으로 주문을 조회하고 EXPLAIN ANALYZE를 적용하세요.
3. 인덱스 생성 전 실행계획에서 다음 항목을 기록하세요.
   - 스캔 방식
   - cost
   - actual rows
   - Execution Time
4. orders.customer_id에 idx_orders_customer_id 인덱스를 생성하세요.
5. 동일한 SELECT문에 다시 EXPLAIN ANALYZE를 적용하세요.
6. 인덱스 생성 후 실행계획에서 다음 항목을 기록하세요.
   - 스캔 방식
   - cost
   - actual rows
   - Execution Time
7. 인덱스 생성 전후 결과를 비교하세요.
8. 다음 질문에 답하세요.
   Q1. 인덱스 생성 전과 후의 스캔 방식은 어떻게 달라졌나요?
   -> Seq scan에서 index scan으로 바뀜
   
   Q2. B-Tree 인덱스가 customer_id = 31428을 찾을 때
       모든 주문을 처음부터 확인하지 않아도 되는 이유는 무엇인가요?
   -> B-Tree는 키 값을 정렬된 트리 구조로 저장
   따라서 1번부터 순서대로 스캔하지 않고 테이블 행 모두를 한번에 확인하여
   검색 범위를 좁혀서 속도가 빠름
   
   Q3. cost와 Execution Time은 같은 의미인가요?
   -> cost : 옵티마이저가 예상한 상대적인 비용
   -> Execution Time : EXPLAIN ANALYZE에서 실제 실행 후 측정된 시간
   
[제출 결과]
- DROP INDEX 문
- 인덱스 생성 전 EXPLAIN ANALYZE
- 개선 전 기록표
- CREATE INDEX 문
- 인덱스 생성 후 EXPLAIN ANALYZE
- 개선 후 기록표
- 전후 비교
- Q1~Q3 답변
*/

-- [코드 작성란]
--요구사항 1--
drop index if exists idx_orders_customer_id;
--요구사항 2--
EXPLAIN ANALYZE
select *
from orders o 
where customer_id = 31428;
--요구사항 3--
   - 스캔 방식 : parallel seq scan
   - cost : 0.00...4116.88
   - actual rows : 4
   - Execution Time : 79.100ms
4. orders.customer_id에 idx_orders_customer_id
--요구사항 4--
create index idx_orders_customer_id on orders(customer_id);
--요구사항 5--
EXPLAIN ANALYZE
select *
from orders o 
where customer_id = 31428;
--요구사항 6--
   - 스캔 방식 :bitmap index scan
   - cost : 0.00...4.48
   - actual rows : 7
   - Execution Time : 0.108ms
--요구사항 7--
생성후 : index --> 시간이 빨라짐


/*
============================================================
필수 2. 인덱스 생성·확인·삭제와 쓰기 비용 이해
============================================================

[문제 2-1]

[문제 설명]
products 테이블의 category_id와 supplier_id 컬럼에
실습용 B-Tree 인덱스를 생성하고,
PostgreSQL 시스템 뷰에서 생성 결과를 확인한 뒤 삭제하세요.

인덱스 생성과 삭제 문법을 익히고,
테이블의 데이터가 변경될 때 관련 인덱스에도 추가 작업이 필요한 이유를 설명하세요.

[요구사항]
1. 다음 실습용 인덱스가 있다면 삭제하세요.
   - idx_products_category_practice
   - idx_products_supplier_practice
2. products.category_id에 idx_products_category_practice 인덱스를 생성하세요.
3. products.supplier_id에 idx_products_supplier_practice 인덱스를 생성하세요.
4. pg_indexes에서 products 테이블의 인덱스 이름과 정의를 조회하세요.
5. 조회 결과에서 두 실습용 인덱스가 생성되었는지 확인하세요.
6. 두 실습용 인덱스를 삭제하세요.
7. pg_indexes를 다시 조회하여 두 인덱스가 삭제되었는지 확인하세요.
8. 다음 질문에 답하세요.
   Q1. CREATE INDEX와 DROP INDEX는 각각 어떤 작업을 수행하나요?
   -> CREATE INDEX : 지장한 칼럼 값을 기반으로 인덱스 구조를 생성  
   -> DROP INDEX : 해당 인덱스 구조를 삭제
   
   Q2. INSERT 시 테이블 외에 인덱스에도 추가 작업이 필요한 이유는 무엇인가요?
   -> 세 행의 인덱스 대상 칼럼 값과 테이블 위치 정보를 관련 인덱스의 정렬된 구조에도 추가해야하기 때문
   
   Q3. 인덱스 컬럼을 UPDATE하거나 행을 DELETE할 때 인덱스에는 어떤 작업이 필요한가요?
   -> 인덱스 대상 값이 변경되면 새 값과 행 버전에 맞는 인덱스 항목 필요
   

[제출 결과]
- 기존 실습용 인덱스 DROP INDEX 문
- 두 개의 CREATE INDEX 문
- pg_indexes 확인 SQL과 생성 확인 결과
- 두 개의 DROP INDEX 문
- pg_indexes 재확인 SQL과 삭제 확인 결과
- 쓰기 작업 시 인덱스 유지 비용에 대한 설명
- Q1~Q3 답변
*/

-- [코드 작성란]

--요구사항 1--
drop index if exists idx_products_category_practice;
drop index if exists idx_products_supplier_practice;
--요구사항 2--
create index idx_products_category_practice on products(category_id);
--요구사항 3--
create index idx_products_supplier_practice on products(supplier_id);
--요구사항 4~5--
select indexname, indexdef
from pg_indexes
where schemaname = 'public' and tablename ='products'
order by indexname;
--요구사항 6--
drop index if exists idx_products_category_practice;
drop index if exists idx_products_supplier_practice;
--요구사항 7--
select indexname, indexdef
from pg_indexes
where schemaname = 'public' and tablename ='products'
order by indexname;


/*
============================================================
과제. 범위 검색에서 B-Tree 인덱스 확인
============================================================

[문제 3-1]

[문제 설명]
products.price에 B-Tree 인덱스를 생성하고
price가 100 이상 120 미만인 범위 조회의 실행계획을 비교하세요.

※ 필수 문제와 동일한 수준의 독립 실습입니다.

[요구사항]
1. products.price의 최솟값과 최댓값을 확인하세요.
2. idx_products_price 인덱스가 있다면 삭제하세요.
3. price >= 100 AND price < 120 조건에 EXPLAIN ANALYZE를 적용하세요.
4. 인덱스 생성 전 다음 항목을 기록하세요.
   - 스캔 방식
   - cost
   - actual rows
   - Execution Time
5. products.price에 idx_products_price 인덱스를 생성하세요.
6. 동일한 SELECT문에 다시 EXPLAIN ANALYZE를 적용하세요.
7. 인덱스 생성 후 다음 항목을 기록하세요.
   - 스캔 방식
   - cost
   - actual rows
   - Execution Time
8. 인덱스 생성 전후 결과를 비교하세요.
9. 실습이 끝나면 idx_products_price 인덱스를 삭제하세요.
10. 다음 질문에 답하세요.
    Q1. B-Tree 인덱스는 등호 검색 외에 어떤 비교 조건에 활용될 수 있나요?
    -> B-Tree는 =, <, >, BETWEEN 같은 비교와 범위 검색에 폭넓게 활용할 수 있다
    Q2. B-Tree 인덱스가 범위 검색에서 검색 범위를 줄일 수 있는 이유는 무엇인가요?
    -> B-Tree는 키 값이 정렬된 트리 구조로 저장되어 
    -> 전체 테이블을 스캔하지 않고 필요한 범위만 탐색한다.
    Q3. 인덱스를 많이 만들수록 INSERT, UPDATE, DELETE 비용이 커질 수 있는 이유는 무엇인가요?
	-> 행이 추가, 변경, 삭제될때 관련된 인덱스 구조도 함께 영향을 받아
	-> 인덱스가 많을수록 유지비용이 커진다.
	
[제출 결과]
- MIN/MAX 확인 SQL
- DROP INDEX 문
- 인덱스 생성 전 EXPLAIN ANALYZE
- 개선 전 기록표
- CREATE INDEX 문
- 인덱스 생성 후 EXPLAIN ANALYZE
- 개선 후 기록표
- 전후 비교
- 최종 DROP INDEX 문
- Q1~Q3 답변
*/

-- [코드 작성란]
--- MIN/MAX 확인 SQL
--- DROP INDEX 문
--- 인덱스 생성 전 EXPLAIN ANALYZE
--- 개선 전 기록표
--- CREATE INDEX 문
--- 인덱스 생성 후 EXPLAIN ANALYZE
--- 개선 후 기록표
--- 전후 비교
--- 최종 DROP INDEX 문

--1. products.price의 최솟값과 최댓값을 확인하세요.
--2. idx_products_price 인덱스가 있다면 삭제하세요.
--3. price >= 100 AND price < 120 조건에 EXPLAIN ANALYZE를 적용하세요.
--4. 인덱스 생성 전 다음 항목을 기록하세요.
--   - 스캔 방식
--   - cost
--   - actual rows
--   - Execution Time
--5. products.price에 idx_products_price 인덱스를 생성하세요.
--6. 동일한 SELECT문에 다시 EXPLAIN ANALYZE를 적용하세요.
--7. 인덱스 생성 후 다음 항목을 기록하세요.
--   - 스캔 방식
--   - cost
--   - actual rows
--   - Execution Time
--8. 인덱스 생성 전후 결과를 비교하세요.
--9. 실습이 끝나면 idx_products_price 인덱스를 삭제


--요구사항 1
select min(price) as min_price, --100
       max(price) as max_price  --4999
from products;
--요구사항 2
drop index if exists idx_products_price;
--요구사항 3
EXPLAIN ANALYZE
select *
from products
where price >= 100 AND price < 120;
--Seq Scan on products  (cost=0.00..205.00 rows=41 width=16) 
--(actual time=0.014..0.343 rows=35.00 loops=1)
--  Filter: ((price >= 100) AND (price < 120))
--  Rows Removed by Filter: 9965
--  Buffers: shared hit=55
--Planning:
--  Buffers: shared hit=12 dirtied=1
--Planning Time: 0.147 ms
--Execution Time: 0.363 ms

--요구사항 4
--인덱스 생성 전 다음 항목을 기록하세요.
--   - 스캔 방식 : Seq Scan
--   - cost : 0.00..205.00
--   - actual rows : 35.00
--   - Execution Time : 0.363 ms

--요구사항 5
create index idx_products_price on products(price);

--요구사항 6
EXPLAIN ANALYZE
select *
from products
where price >= 100 and price < 120;
--  ->  Bitmap Index Scan on idx_products_price  
--(cost=0.00..4.71 rows=42 width=0) 
--(actual time=0.008..0.008 rows=35.00 loops=1)
--        Index Cond: ((price >= 100) AND (price < 120))
--        Index Searches: 1
--        Buffers: shared hit=2
--Planning:
--  Buffers: shared hit=22 read=3 dirtied=2
--Planning Time: 0.508 ms
--Execution Time: 0.086 ms

--요구사항 7
--인덱스 생성 후 다음 항목을 기록하세요.
--   - 스캔 방식 :  Bitmap Index Scan
--   - cost : 0.00..4.71
--   - actual rows : 35.00
--   - Execution Time : 0.086 ms

--요구사항 8
--> 인덱스 전
--   - 스캔 방식 : Seq Scan
--   - cost : 0.00..205.00
--   - actual rows : 35.00
--   - Execution Time : 0.363 ms

--> 인덱스 후
--   - 스캔 방식 :  Bitmap Index Scan
--   - cost : 0.00..4.71
--   - actual rows : 35.00
--   - Execution Time : 0.086 ms

--요구사항 9
drop index if exists idx_products_price;



/*
============================================================
실습 마무리
============================================================

1. B-Tree 인덱스가 검색 속도를 높일 수 있는 핵심 원리는 무엇인가요?
->  B-Tree : 키를 정렬된 트리구조로 관리하여 전체 데이터를 순서대로 읽지 않고 
검색 범위를 줄일수 있다.

2. B-Tree 인덱스는 등호 검색과 범위 검색에서 각각 어떻게 활용될 수 있나요?
-> 등호 검색에서는 정렬된 트리를 따라 특정 키가 있는 위치로 이동
-> 범위 검색에서는 범위의 시작 위치를 찾은 뒤 해당 구간을 따라 검색

3. 인덱스를 만들 때 조회 성능뿐 아니라 쓰기 성능도 고려해야 하는 이유는 무엇인가요?
-> insert, update, delete시 테이블 뿐만 아니라 
관련 인덱스의 항목 추가 및 유지 그리고 과거 항목 정리가 필요할 수 있다.

*/

