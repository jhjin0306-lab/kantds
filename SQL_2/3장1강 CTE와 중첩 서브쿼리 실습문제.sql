/*
============================================================
[3장 1강] 실습문제: CTE와 중첩 서브쿼리의 구조적 차이와 최적화 특성
============================================================

[실습 목표]
- 중첩 서브쿼리와 CTE로 같은 로직을 각각 작성할 수 있다.
- CTE를 이용해 복잡한 쿼리를 단계별로 나누어 표현할 수 있다.
- EXPLAIN을 이용해 중첩 서브쿼리와 CTE의 실행계획을 비교할 수 있다.
- MATERIALIZED CTE의 실행계획에서 CTE Scan 여부를 확인할 수 있다.
- 성능뿐 아니라 가독성·재사용성·유지보수성 관점에서 적절한 구조를 판단할 수 있다.

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
- orders
- order_items
- customers


CTE : WITH에서 이름을 정의하고 같은 SQL 문장안에서 참조하는 쿼리
MATERIALIZE CTE 구체화 명시, 단 영구 테이블은 아님

항목                  |  쉬운 설명
Parallel Seq Scan    | 여러 작업자가 'orders', 'order_items' 데이터를 나누어 읽습니다.  
Parallel Hash        | 주문번호로 빠르게 연결할 수 있도록 'orders'의 해시 자료구조를 만듭니다.
Parallel Hash Join   | 같은 'order_id'를 가진 주문과 주문 상세를 연결합니다.
Partial HashAggregate| 각 작업자가 담당한 데이터에서 고객별 구매금액을 먼저 합산합니다.
Gather               | 나누어 계산한 부분 합계들을 모읍니다. 최종합산은 다음 단계에서 합니다.
Finalize HashAggregate| 같은 고객의 부분 합계들을 합쳐 최종 구매금액을 계산합니다.
Filter                | 최종 구매금액이 **50000 이상인 고객**만 남깁니다.
Sort                  | 구매금액이 큰 고객부터 정렬합니다.
Workers Planned 2     | 보조 작업자 2명을 사용하도록 계획했다는 뜻입니다.


[주요 관계]
- orders.customer_id = customers.customer_id
- orders.order_id = order_items.order_id

[주의사항]
- 현재 데이터셋의 order_items에는 quantity, list_price, discount 컬럼이 없고
  qty, price 컬럼이 있으므로 구매금액은 qty * price로 계산합니다.
- PostgreSQL 버전과 옵티마이저 판단에 따라 일반 CTE는 본문에 인라인될 수 있습니다.
- 특정 실행계획 모양 자체를 외우는 것이 아니라,
  실제 EXPLAIN 결과를 보고 구조를 해석하는 것이 중요합니다.
*/


/*
============================================================
필수 1. 같은 로직을 중첩 서브쿼리와 CTE로 작성하기
============================================================

[문제 1-1] 고객별 총 구매금액이 50,000 이상인 고객 조회

[문제 설명]
고객별 총 구매금액을 계산한 뒤,
총 구매금액이 50,000 이상인 고객만 조회하려고 합니다.

같은 결과를 중첩 서브쿼리와 CTE 두 가지 방식으로 각각 작성하고,
두 쿼리의 구조적 차이를 비교하세요.

[요구사항]
1. orders와 order_items를 order_id 기준으로 JOIN하세요.
2. 고객별 총 구매금액을 다음 식으로 계산하세요.

   SUM(order_items.qty * order_items.price)

3. 고객별 총 구매금액을 계산한 중간 결과에서
   total_amount가 50,000 이상인 고객만 조회하세요.
4. 결과는 total_amount가 높은 순서대로 정렬하세요.
5. 위 로직을 먼저 중첩 서브쿼리 방식으로 작성하세요.
6. 같은 로직을 customer_totals라는 CTE를 이용하여 다시 작성하세요.
7. 두 결과가 동일한지 확인하세요.
8. 중첩 서브쿼리 쿼리에 EXPLAIN을 적용하세요.
9. 일반 CTE 쿼리에 EXPLAIN을 적용하세요.
10. 두 실행계획을 비교하세요.
11. 다음 질문에 답하세요.
   Q1. 중첩 서브쿼리와 CTE의 결과는 달라야 하나요?
   -> 아니요. 두 쿼리가 같은 테이블, join 등 조건이 같다면 결과는 동일해야 한다.
   
   Q2. 여러 단계의 로직을 읽을 때 CTE가 더 이해하기 쉬울 수 있는 이유는 무엇인가요?
   -> 각 중간 자리 결과에 의미있는 이름을 붙일 수 있다.
   -> ex) customer_totals
   
   Q3. 이번 문제처럼 중간 결과에 이름을 붙이는 것이 유지보수에 어떤 도움이 되나요?
   -> 나중에 쿼리를 수정하거나 다른 개발자가 코드를 확인할 때 
   각 단계가 어떤 역할을 수행했는지 빠르게 파악 가능
   
   Q4. 중첩 서브쿼리와 일반 CTE의 실행계획이 비슷하게 나타난다면,
       어떤 의미로 해석할 수 있나요?
   -> 옵티마이저가 두 SQL을 유사한 실행 구조로 처리하고 있다.

[작성 결과]
- 중첩 서브쿼리 SQL
- CTE SQL
- 두 결과 비교
- 중첩 서브쿼리 EXPLAIN
- 일반 CTE EXPLAIN
- 실행계획 비교
- Q1~Q4 답변
*/

-- [코드 작성란]

--SQL1. 종합 서브쿼리
select customer_id, total_amount
from (
select customer_id, sum(oi.qty * oi.price) as total_amount
from orders o 
join order_items oi on o.order_id = oi.order_id
group by o.customer_id ) as customer_totals
where total_amount >= 50000
order by total_amount desc;

--SQL2. CTE
with customer_totals as(
select customer_id, sum(oi.qty *oi.price) as total_amount
from orders o 
join order_items oi on o.order_id = oi.order_id 
group by customer_id)
select customer_id, total_amount
from customer_totals 
where total_amount >=50000
order by total_amount desc;

--SQL3. 종합서브쿼리에 explain 
explain
select customer_id, total_amount
from (
select customer_id, sum(oi.qty * oi.price) as total_amount
from orders o 
join order_items oi on o.order_id = oi.order_id
group by o.customer_id ) as customer_totals
where total_amount >= 50000
order by total_amount desc;
--CTE에 explain
explain
with customer_totals as(
select customer_id, sum(oi.qty *oi.price) as total_amount
from orders o 
join order_items oi on o.order_id = oi.order_id 
group by customer_id)
select customer_id, total_amount
from customer_totals 
where total_amount >=50000
order by total_amount desc;


/*
============================================================
필수 2. 일반 CTE와 MATERIALIZED CTE 실행계획 비교
============================================================

[문제 2-1] CTE의 구체화 여부 확인하기

[문제 설명]
PostgreSQL에서는 일반 CTE가 항상 별도의 중간 결과로 저장되는 것은 아닙니다.

한 번만 참조되는 일반 CTE는 옵티마이저 판단에 따라
본문 쿼리에 인라인되어 처리될 수 있습니다.

반면 MATERIALIZED를 명시하면
CTE 결과를 먼저 계산한 뒤 그 결과를 읽는 구조를 만들 수 있습니다.

같은 고객별 구매금액 조회를 일반 CTE와 MATERIALIZED CTE로 작성하고,
EXPLAIN을 이용해 실행계획을 비교하세요.

[요구사항]
1. customer_totals CTE에서 고객별 총 구매금액을 계산하세요.
2. total_amount가 50,000 이상인 고객만 조회하세요.
3. 일반 CTE 쿼리에 EXPLAIN을 적용하세요.
4. 같은 CTE에 MATERIALIZED를 명시하고 EXPLAIN을 적용하세요.
5. 두 실행계획에서 다음 내용을 확인하세요.
   - CTE Scan 노드의 존재 여부
   - 고객별 집계 작업이 어느 위치에서 수행되는지
   - 필터 조건이 어느 단계에서 적용되는지
   
6. 다음 질문에 답하세요.
   Q1. 일반 CTE는 항상 CTE Scan으로 나타나나요?
   -> 아니오, PostgreSQL Ver12 이상에서는 조건에 따라 CTE를 본문 쿼리에 인라인 자리 가능 
   -> CTE Scan 이 나타나지 않을 수 있음
   Q2. MATERIALIZED를 사용하면 처리 흐름이 어떻게 달라지나요?
   -> CTE를 본문과 합치치 않고 별도의 결과로 다룸
   -> 본문은 그 결과를 CTE Scan으로 참조하는 구조
   Q3. MATERIALIZED가 항상 더 빠르다고 말할 수 있나요?
   ->중간 결과를 별도로 계산하고 저장한 뒤에 다시 읽는 비용이 발생할 수 있음.
	
[작성 결과]
- 일반 CTE + EXPLAIN
- MATERIALIZED CTE + EXPLAIN
- 실행계획 비교
- Q1~Q3 답변
*/

-- [코드 작성란]

explain
with customer_totals as (
select customer_id, sum(oi.qty * oi.price) as total_amount
from orders o 
join order_items oi on o.order_id = oi.order_id
group by o.customer_id) 
select customer_id, total_amount
from customer_totals
where total_amount >=50000;


explain
with customer_totals as MATERIALIZED(
select customer_id, sum(oi.qty * oi.price) as total_amount
from orders o 
join order_items oi on o.order_id = oi.order_id
group by o.customer_id)
select customer_id, total_amount
from customer_totals 
where total_amount >=50000;




/*
============================================================
과제. 여러 단계 분석을 CTE로 구조화하기
============================================================

[문제 3-1] 우수 고객의 도시별 구매금액 집계

[문제 설명]
운영팀에서 고객별 구매금액을 계산한 뒤,
총 구매금액이 50,000 이상인 우수 고객만 추려
도시별 우수 고객 수와 구매금액을 집계하려고 합니다.

이번 문제에서는 여러 단계의 로직을 CTE로 나누어
쿼리의 흐름을 명확하게 표현하세요.

※ 과제는 필수 문제와 동일한 수준입니다.
   새로운 SQL 문법을 사용하는 것이 아니라,
   이번 강에서 배운 CTE 구조화를 한 번 더 적용하는 문제입니다.

[요구사항]
1. 첫 번째 CTE customer_totals를 작성하세요.
   - orders와 order_items를 order_id 기준으로 JOIN
   - customer_id별 총 구매금액 계산
   - 총 구매금액 컬럼명은 total_amount
2. 두 번째 CTE high_value_customers를 작성하세요.
   - customer_totals에서 total_amount가 50,000 이상인 고객만 선택
3. high_value_customers와 customers를 customer_id 기준으로 JOIN하세요.
4. 도시별로 다음 값을 계산하세요.
   - 우수 고객 수: vip_customer_count
   - 우수 고객 총 구매금액: vip_total_amount
5. vip_total_amount가 높은 순서대로 정렬하세요.
6. 작성한 전체 CTE 쿼리에 EXPLAIN을 적용하여 실행계획을 확인하세요.
7. 실행계획에서 CTE가 본문에 인라인된 형태인지,
   별도의 CTE Scan이 나타나는지 확인하세요.
8. 다음 질문에 답하세요.
   Q1. 이 문제를 하나의 중첩 서브쿼리로 작성하는 것보다 CTE로 나누었을 때 어떤 장점이 있나요?
   -> CTE는 WITH 절에서 중간 결과에 이름을 붙여 본문 쿼리에서 테이블처럼 참조한다. 복잡한 쿼리를 여러 단계로 나누고
   각 단계에 이름을 붙일 수 있어서 쿼리의 흐름을 이해하기 쉽다.
   
   Q2. customer_totals와 high_value_customers라는 이름은 각각 어떤 처리 단계를 의미하나요?
   -> customer_totals : 고객별 총 구매금액
   -> high_value_customers : 총 구매금액이 50000원 이상인 우수 고객
   
   Q3. 성능 차이가 거의 없다면 CTE와 중첩 서브쿼리 중 어떤 기준으로 구조를 선택하는 것이 좋나요?
   -> 성능 차이가 없다면 가독성과 유지 보수를 위해 CTE로 작성하는 것이 이해하기 쉽다.
   
   Q4. 이번 EXPLAIN 결과를 기준으로 CTE가 실제 실행 단계에서
       반드시 별도의 중간 결과로 저장되었다고 말할 수 있나요?
       실행계획을 근거로 설명하세요.
    -> 실행계획에 별도의 CTE scan이 나타나지 않으면 옵티마이저가 CTE를 인라인하여 CTE를 본문 쿼리와 합쳐서 한 번에 처리한 것으로 볼 수 있다.
    CTE를 작성했다고 해서 항상 중간 결과를 따로 저장하는 것은 아니다.

[제출 결과]
- 전체 CTE SQL
- 도시별 집계 결과
- EXPLAIN 실행계획
- CTE 인라인 또는 CTE Scan 여부 확인
- Q1~Q4 답변
*/

-- [코드 작성란]
explain
with customer_totals as (
select o.customer_id, sum(oi.qty*oi.price) as total_amount
from orders o
join order_items oi on oi.order_id  = o.order_id 
group by o.customer_id),
high_value_customers as(
select customer_id, total_amount
from customer_totals
where total_amount >=50000)
select 
	c.city,
	count(hvc.customer_id) as vip_customer_count,
	sum(hvc.total_amount) as vip_total_amount
from high_value_customers hvc
join customers c
on c.customer_id = hvc.customer_id
group by c.city
order by vip_total_amount desc;

--        Group Key: c.city
--        ->  Hash Join  (cost=29856.70..30819.96 rows=14797 width=18)
--              Hash Cond: (c.customer_id = o.customer_id)
--              ->  Seq Scan on customers c  (cost=0.00..832.00 rows=50000 width=10)
--              ->  Hash  (cost=29671.74..29671.74 rows=14797 width=12)
--                    ->  Finalize HashAggregate  (cost=29116.86..29671.74 rows=14797 width=12)
--                          Group Key: o.customer_id
--                          Filter: (sum((oi.qty * oi.price)) >= 50000)
--                          ->  Gather  (cost=17486.68..28584.18 rows=106536 width=12)
--                                Workers Planned: 2
--                                ->  Partial HashAggregate  (cost=16486.68..16930.58 rows=44390 width=12)
--                                      Group Key: o.customer_id
--                                      ->  Parallel Hash Join  (cost=5881.59..14611.68 rows=250000 width=12)
--                                            Hash Cond: (oi.order_id = o.order_id)
--                                            ->  Parallel Seq Scan on order_items oi  
--												(cost=0.00..6322.00 rows=250000 width=12)
--                                            ->  Parallel Hash  
--												(cost=3675.71..3675.71 rows=176471 width=8)
----                                                  ->  Parallel Seq Scan on orders o  
--												(cost=0.00..3675.71 rows=176471 width=8)



/*
============================================================
실습 마무리
============================================================

아래 내용을 한 문단으로 정리하세요.

1. CTE와 중첩 서브쿼리의 가장 큰 구조적 차이는 무엇인가요?
-> 중첩 서브쿼리는 다른 쿼리 내부에 쿼리를 포함하는 구조
-> CTE는 WITH 절에서 중간 결과에 이름을 붙여 본문 쿼리에서 테이블처럼 참조

2. 일반 CTE와 MATERIALIZED CTE의 처리 방식은 어떻게 다를 수 있나요?
-> 일반 CTE는 옵티마이저 판단에 따라 본문에 인라인이 될 수 있음
-> MATERIALIZED CTE는 CTE를 별도 결과로 다루고 본문에서 그 결과를 읽음

3. 실행계획상 성능 차이가 크지 않다면 어떤 기준으로 쿼리 구조를 선택하는 것이 좋나요?
-> 가독성, 유지보수성, 재사용성 
(class에서도 마찬가지)

*/

