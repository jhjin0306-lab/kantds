/*
============================================================
[2장 2강] 실습문제: 인덱스가 효과적인 경우와 비효과적인 경우 판단
============================================================

[실습 목표]
- 컬럼의 카디널리티와 조건의 선택도를 확인할 수 있다.
- 인덱스가 효과적인 조건과 비효과적인 조건을 구분할 수 있다.
- 인덱스 컬럼을 그대로 비교하는 조건과 가공한 조건의 실행계획 차이를 확인할 수 있다.
- 테이블 크기와 데이터 분포를 함께 고려하여 인덱스 추가 여부를 판단할 수 있다.

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
- orders     : 300,000행
- shipments  : 300,000행
- stores     : 100행

[주의사항]
- 실행계획의 스캔 방식과 Execution Time은 PostgreSQL 환경에 따라 달라질 수 있습니다.
- 특정 숫자를 맞히는 것이 아니라 데이터 분포와 실행계획을 근거로 인덱스가 효과적인지 판단하는 것이 핵심입니다.
- 이전 강에서 생성한 실습용 인덱스가 남아 있을 수 있으므로 필요한 경우 DROP INDEX IF EXISTS를 먼저 실행합니다.
*/


/*
============================================================
필수 1. 카디널리티와 선택도로 인덱스 효과 판단하기
============================================================

[문제 1-1] customer_id와 status의 인덱스 적합성 비교

[문제 설명]
온라인 리테일 운영팀에서 두 가지 조회 기능을 자주 사용한다고 가정합니다.

① 특정 고객의 주문 조회
② 특정 배송 상태의 배송 정보 조회

두 컬럼 모두 WHERE 절에 사용되지만,
데이터 분포는 서로 크게 다릅니다.

orders.customer_id와 shipments.status의 카디널리티와 선택도를 확인하고,
어느 컬럼에 인덱스를 추가하는 것이 더 효과적일 가능성이 높은지 판단하세요.

[요구사항]
1. orders 테이블의 전체 행 수와 customer_id의 고유값 수를 조회하세요.
2. customer_id = 31428 조건을 만족하는 행 수를 조회하세요.
3. customer_id = 31428의 선택도를 다음 식으로 계산하세요.

   조건 만족 행 수 / 전체 행 수 * 100

4. shipments 테이블의 전체 행 수와 status의 고유값 수를 조회하세요.
5. status별 행 수와 각 상태가 전체에서 차지하는 비율을 조회하세요.
6. customer_id와 status 중 어느 컬럼이 카디널리티가 더 높은지 설명하세요.
-> customer_id가 카디널리티의 수가 높고 선택도가 낮다.
7. 특정 customer_id 조회와 status = 'shipped' 조회 중
   어느 조건의 선택도가 더 낮은지 설명하세요.
-> customer_id : 0.0063 / shipped : 33..43
-> customer_id의 선택도가 더 낮다.
8. 데이터 분포만을 기준으로 보았을 때
   어느 컬럼에 인덱스를 추가하는 것이 더 효과적일 가능성이 높은지 판단하고 이유를 작성하세요.
-> customer_id의 카디널리티의 수가 높고 선택도가 낮아서 인덱스를 추가하는 것이 더 효과적이다.
(customer_id의 distinct : 49886 / status의 distinct : 3)

**선택도 : 특정 조건에 남는 행의 비율
**카디널리티 : 컬럼의 고유값의 수
**인덱스 -> 더 빠르게 찾기 위해서 
(-> customer_id의 distinct : 49886 / status의 distinct : 3)

[작성 결과]
- customer_id 카디널리티
- customer_id = 31428의 선택도
- status 카디널리티
- status별 선택도
- 인덱스 효과 판단 및 근거
*/

-- [코드 작성란]
--요구사항 1--
select count(*) as total_rows, count(distinct customer_id) as customer_id_cardinality
from orders o ;
--요구사항 2,3 : customer_id = 31428 조건을 만족하는 행 수를 조회하세요.--
select count(*) as matched_rows, round(count(*)*100.0/(
select count(*)from orders),6) as selectivity_pct
from orders o 
where customer_id = 31428;
--요구사항 4--
select count(*) as total_rows, count(distinct status) as status_cardinality 
from shipments s;
--요구사항 5 : status별 행 수와 각 상태가 전체에서 차지하는 비율을 조회하세요.--
select status, count(*) as matched_rows, round(count(*)*100.0/(
select count(*)from shipments s),2) as selectivity_pct
from shipments s 
group by status order by status; 


/*
============================================================
필수 2. 인덱스 컬럼을 가공했을 때 실행계획 비교하기
============================================================

[문제 2-1] 같은 값을 찾는 두 WHERE 조건 비교

[문제 설명]
orders.customer_id에 인덱스를 생성한 뒤 다음 두 조건을 비교합니다.

A. customer_id = 31428
B. customer_id + 0 = 31428

두 조건은 사람이 보기에는 같은 customer_id를 찾지만,
일반 B-Tree 인덱스는 원래 customer_id 값을 기준으로 구성되어 있습니다.

EXPLAIN ANALYZE를 이용하여 두 쿼리의 실행계획을 비교하세요.

[요구사항]
1. 기존 idx_orders_customer_id 인덱스가 있다면 삭제하세요.
2. orders.customer_id에 idx_orders_customer_id 인덱스를 생성하세요.
3. 다음 두 쿼리에 각각 EXPLAIN ANALYZE를 적용하세요.

   A. WHERE customer_id = 31428
   B. WHERE customer_id + 0 = 31428

4. 두 실행계획에서 다음 항목을 비교하세요.
   - 스캔 방식
   - 조건이 표시되는 위치(Index Cond 또는 Filter)
   - cost
   - actual rows
   - Execution Time
5. 다음 질문에 답하세요.
   Q1. 두 쿼리는 같은 customer_id를 찾는데도 실행계획이 달라질 수 있는 이유는 무엇인가요?
   -> 일반 B-Tree 인덱스는 customer_id의 원래 값을 기준으로 구성되어있음
   -> customer_id = 31428 는 인덱스의 키를 직접 비교
   -> customer_id + 0 = 31428은 컬럼을 가공한 결과를 기준으로 비교
   -> customer_id + 0은 기존 인덱스의 정렬 구조를 직접 활용하기 어려움
   
   Q2. 일반 B-Tree 인덱스를 효과적으로 사용하려면 WHERE 절을 어떤 형태로 작성하는 것이 좋은가요?
   -> 가능하면 인덱스 칼럼을 함수나 연산으로 가공하지 않고
   원래 칼럼 값을 그대로 비교하는 형태로 작성하는 것이 좋음
6. 실습 종료 후 idx_orders_customer_id 인덱스를 삭제하세요.

[작성 결과]
- CREATE INDEX 문
- 조건 A의 EXPLAIN ANALYZE
- 조건 B의 EXPLAIN ANALYZE
- 실행계획 비교
- Q1~Q2 답변
- DROP INDEX 문
*/

-- [코드 작성란]
--idx_orders_customer_id 인덱스가 있다면 삭제하세요.
--2. orders.customer_id에 idx_orders_customer_id 인덱스를 생성하세요.
--3. 다음 두 쿼리에 각각 EXPLAIN ANALYZE를 적용하세요.
--
--   A. WHERE customer_id = 31428
--   B. WHERE customer_id + 0 = 31428
--요구사항 1--
drop index if exists idx_orders_customer_id;
--요구사항 2--
create index idx_orders_customer_id on orders(customer_id);
--요구사항 3--
explain analyze
select *
from orders
where customer_id = 31428;
--  ->  Parallel Seq Scan on orders  (cost=0.00..4116.88 rows=4 width=20) 
--  (actual time=0.518..3.925 rows=9.50 loops=2)
--      Filter: (customer_id = 31428)
--      Rows Removed by Filter: 149990
--      Buffers: shared hit=1911
--Planning Time: 0.227 ms
--Execution Time: 70.137 ms

explain analyze
select *
from orders
where customer_id + 0 = 31428;
--  ->  Parallel Seq Scan on orders  (cost=0.00..4558.06 rows=882 width=20) 
--  (actual time=0.412..3.166 rows=9.50 loops=2)
--        Filter: ((customer_id + 0) = 31428)
--        Rows Removed by Filter: 149990
--        Buffers: shared hit=1911
--Planning Time: 0.051 ms
--Execution Time: 71.356 ms

--요구사항 4--
--스캔 방식                  |       실행전                실행후
--조건이 표시되는 위치          | Parallel Seq Scan   Parallel Seq Scan       
--(Index Cond 또는 Filter) ||    
--cost                    |   0.00..4116.88        0.00..4558.06 
--actual rows             |        9.50                9.50
--Execution Time          |      70.137 ms           71.356 ms


/*
============================================================
과제. 작은 테이블의 인덱스 추가 여부 판단하기
============================================================

[문제 3-1] stores.city에 인덱스를 추가해야 할까?

[문제 설명]
매장 조회 기능에서 특정 도시의 매장을 검색한다고 가정합니다.

stores 테이블은 전체 데이터가 100행으로 매우 작고,
city 컬럼에는 몇 개의 도시만 반복해서 저장되어 있습니다.

실제 데이터 분포와 실행계획을 확인한 뒤
stores.city에 인덱스를 추가하는 것이 효과적인 선택인지 판단하세요.

※ 과제는 필수 문제와 동일한 수준입니다.
   새로운 인덱스 기법을 사용하는 것이 아니라
   이번 강에서 배운 판단 기준을 스스로 적용하는 문제입니다.

[요구사항]
1. stores 테이블의 전체 행 수를 조회하세요.
2. city의 고유값 수를 조회하세요.
3. city별 행 수와 전체에서 차지하는 비율을 조회하세요.
4. 기존 idx_stores_city 인덱스가 있다면 삭제하세요.
5. city = 'Mumbai' 조건에 EXPLAIN ANALYZE를 적용하세요.
6. stores.city에 idx_stores_city 인덱스를 생성하세요.
7. 같은 조건에 다시 EXPLAIN ANALYZE를 적용하세요.
8. 인덱스 생성 전후의 스캔 방식과 Execution Time을 비교하세요.
9. 다음 네 가지 기준으로 stores.city 인덱스의 적절성을 판단하세요.
   - 카디널리티
   - 선택도
   - 테이블 크기
   - 인덱스 유지 비용
10. 최종적으로 "인덱스 추가를 적극적으로 권장한다 / 우선순위가 낮다" 중 하나를 선택하고 근거를 작성하세요.
--> 인덱스를 추가하지 않는 것이 낫다.
--> city는 카디널리티가 낮고 선택도가 높아 인덱스를 생성 후에도
--> 옵티마이저가 Seq Scan을 선택하므로 인덱스를 추가하지 않는 것이 낫다.
11. 실습 종료 후 idx_stores_city 인덱스를 삭제하세요.

[제출 결과]
- 데이터 분포 확인 SQL
- 인덱스 생성 전 EXPLAIN ANALYZE
- CREATE INDEX 문
- 인덱스 생성 후 EXPLAIN ANALYZE
- 네 가지 기준에 따른 판단
- 최종 결론
- DROP INDEX 문
*/

-- [코드 작성란]
--[요구사항]
--1. stores 테이블의 전체 행 수를 조회하세요.
--2. city의 고유값 수를 조회하세요.
--3. city별 행 수와 전체에서 차지하는 비율을 조회하세요.
--4. 기존 idx_stores_city 인덱스가 있다면 삭제하세요.
--5. city = 'Mumbai' 조건에 EXPLAIN ANALYZE를 적용하세요.
--6. stores.city에 idx_stores_city 인덱스를 생성하세요.
--7. 같은 조건에 다시 EXPLAIN ANALYZE를 적용하세요.
--8. 인덱스 생성 전후의 스캔 방식과 Execution Time을 비교하세요.
--9. 다음 네 가지 기준으로 stores.city 인덱스의 적절성을 판단하세요.
--   - 카디널리티
--   - 선택도
--   - 테이블 크기
--   - 인덱스 유지 비용

--요구사항 1
select count(*) as total_rows
from stores; --100

--요구사항 2
select count(distinct city) as city_cardinality
from stores; --4

--요구사항 3 city별 행 수와 전체에서 차지하는 비율
select city, count(*) as city_count, round(count(*)*100.0/(
select count(*)from stores),2) as selectivity_pct
from stores
group by city order by city; 
--city / city_count / selectivity_pct
--Bangalore	21	21.00
--Delhi	21	21.00
--Mumbai	31	31.00
--Pune	27	27.00

--요구사항 4
drop index if exists idx_stores_city;

--요구사항 5
EXPLAIN analyze
select *
from stores
where city = 'Mumbai';
--Seq Scan on stores  (cost=0.00..2.25 rows=31 width=10) 
--(actual time=0.013..0.017 rows=31.00 loops=1)
--  Filter: ((city)::text = 'Mumbai'::text)
--  Rows Removed by Filter: 69
--  Buffers: shared hit=1
--Planning:
--  Buffers: shared hit=3
--Planning Time: 0.096 ms
--Execution Time: 0.030 ms

--요구사항 6
create index idx_stores_city on stores(city);

--요구사항 7
EXPLAIN analyze
select *
from stores
where city = 'Mumbai';
--Seq Scan on stores  (cost=0.00..2.25 rows=31 width=10) 
--(actual time=0.012..0.015 rows=31.00 loops=1)
--  Filter: ((city)::text = 'Mumbai'::text)
--  Rows Removed by Filter: 69
--  Buffers: shared hit=1
--Planning:
--  Buffers: shared hit=15 read=1
--Planning Time: 0.384 ms
--Execution Time: 0.030 ms

--요구사항 8
--인덱스 생성 전후의 스캔 방식과 Execution Time을 비교
--> 인덱스 생성 전 스캔방식: Seq Scan
--> 인덱스 생성 전 Execution Time : 0.030 ms
--> 인덱스 생성 후 스캔방식 : Seq Scan
--> 인덱스 생성 후 Execution Time : 0.030 ms

--요구사항 9
--다음 네 가지 기준으로 stores.city 인덱스의 적절성을 판단하세요.
--   - 카디널리티 : 낮음(city 고유값 : 4)
--   - 선택도 : 높음 (도시 하나가 전체에서 큰 비율을 차지함 -> 조건에 남는 행이 많음)
--   - 테이블 크기 : 100
--   - 인덱스 유지 비용 : INSERT/UPDATE/DELETE 시 인덱스도 함께 갱신해야 함

--요구사항 10
--10. 최종적으로 "인덱스 추가를 적극적으로 권장한다 
--/ 우선순위가 낮다" 중 하나를 선택하고 근거를 작성하세요.
--> 인덱스를 추가하지 않는 것이 낫다.
--> city는 카디널리티가 낮고 선택도가 높아 인덱스를 생성 후에도
--> 옵티마이저가 Seq Scan을 선택하므로 인덱스를 추가하지 않는 것이 낫다.

--요구사항 11
drop index if exists idx_stores_city; 



/*
============================================================
실습 마무리
============================================================

아래 내용을 한 문단으로 정리하세요.

1. 카디널리티가 높고 선택도가 낮은 조건에서 인덱스가 유리한 이유는 무엇인가요?
-> 서로 다른 값이 많고 조건을 만족하는 행이 적으면
인덱스를 통해 전체 데이블을 읽지 않고 필요한 소수의 행 위치만 빠르게 찾을 수 있음

2. 인덱스가 존재해도 PostgreSQL이 Seq Scan을 선택할 수 있는 이유는 무엇인가요?
-> 옵티마이저는 인덱스 존재 여부만 보는 것이 아니라
조회해야할 행의 비율, 테이블 크기, 통계 정보 등을 이용해 예상 비용을 비교
많은 행을 읽어야 하거나 테이블이 적은 편이라면 Seq Scan의 비용이 더 낮을 수도 있음

3. WHERE 절에서 인덱스 컬럼을 가공하지 않는 것이 좋은 이유는 무엇인가요?
-> 일반 B-Tree인덱스는 원래 칼럼 값을 기준으로 구성됨
-> 함수나 연산을 적용하면 기존 인덱스의 정렬 구조를 직접적 검색 조건으로 활용하기 어려움

4. 인덱스 추가 여부를 판단할 때 확인해야 할 네 가지 기준은 무엇인가요?
-> 4-1. 칼럼의 카디널리티가 충분히 높은가?
-> 4-2. 조건을 적용했을때 선택도가 낮은가?
-> 4-3. 데이블 규모가 충분히 큰가?
-> 4-4. 조회 이득이 insert, update, delete 시 발생하는 인덱스 유지 비용을 감당할 만큼 큰가?
*/

