/*
============================================================
[4장 1강] 실습문제: 윈도우 함수 구조와 집계 함수 비교
============================================================
윈도우 함수 : 각 결과 행을 유지하며 관련 행들을 참조한 계산값을 붙인다.
-> 각 행을 그대로 유지하면서 관련된 여러 행을 대상으로 순위, 합계, 평균 등을 계산하는 함수

employees 테이블
|이름|부서|급여|
|지훈|개발|400|
|범조|개발|600|
|강혁|영업|300|
|영준|영업|500|

group by 부서(department)에 급여 평균
-> 개발 500, 영업 400

윈도우 함수는 직원별 행을 유지하면서 부서평균을 표시하고자 할 때 쓴다.
|이름|부서|급여|급여평균|
|지훈|개발|400|500|
|범조|개발|600|500|
|강혁|영업|300|400|
|영준|영업|500|400|

over : 앞에 함수를 어떤 행들을 대상으로 어떤 순서로 계산할지 지정한다.
AVG(급여)OVER() : 전체 직원의 평균 급여 계산
AVG(급여)OVER(partition by 부서) : 각 직원이 속한 부서의 평균 급여 계산
-> 계산 결과는 테이블의 오른쪽에 붙는다.

PARTITION BY : 계산을 독립적으로 수행할 그룹을 나눈다.
PARTITION BY 부서 : 개발 부서와 영업 부서를 나누어 각각 계산한다.
-> 부서별 급여 순위를 정한다면, 개발 부서도 1등, 영업부서도 1등부터 순위를 매긴다.

윈도우 ORDER BY: 파티션 내부에서 계산에 사용할 행 순서를 지정한다.
순위 계산에서 ORDER BY salary desc : 급여가 높은 직원부터 순위를 매긴다.
누락 매출 계산에서는 ORDER BY sales_date : 날짜가 이른 행부터 순서대로 매출을 더한다.
윈도우의 ORDER By는 계산 순서를 지정하는 것
출력 순서는 쿼리 마지막의 ORDER BY로 지정


[실습 목표]
- GROUP BY 집계 함수와 윈도우 함수의 결과 구조 차이를 설명할 수 있다.
- PARTITION BY를 이용해 그룹별 계산을 수행할 수 있다.
- ORDER BY와 프레임을 이용해 윈도우 계산 범위를 이해할 수 있다.
- 실행계획에서 WindowAgg와 Sort 노드를 확인할 수 있다.

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
- employees
- orders
- order_items

[주요 컬럼]
employees
- employee_id
- store_id
- salary

orders
- order_id
- customer_id
- store_id
- order_date

order_items
- order_item_id
- order_id
- product_id
- qty
- price
*/

/*
============================================================
필수 1. GROUP BY와 윈도우 함수 결과 비교하기
============================================================

[문제 1-1] 매장별 평균 급여를 두 방식으로 계산하기

[문제 설명]
인사팀에서 매장별 평균 급여를 확인하려고 합니다.

먼저 GROUP BY를 이용해 매장별 평균 급여만 조회하고,
다음에는 윈도우 함수를 이용해 직원별 급여 행을 유지하면서
같은 매장의 평균 급여를 함께 표시하세요.

[요구사항]
1. employees 테이블에서 store_id별 평균 salary를 계산하세요.
2. GROUP BY를 사용하고 평균 급여 컬럼명은 store_avg_salary로 지정하세요.
3. 같은 계산을 AVG(salary) OVER (PARTITION BY store_id) 형태의 윈도우 함수로 다시 작성하세요.
4. 윈도우 함수 결과에서는 다음 컬럼을 조회하세요.
   - employee_id
   - store_id
   - salary
   - store_avg_salary
5. 두 쿼리의 결과 행 수를 각각 확인하세요.
6. 다음 질문에 답하세요.
   Q1. GROUP BY 결과에서 개별 employee_id가 사라지는 이유는 무엇인가요?
   -> GROUP BY는 같은 그룹에 속한 여러 행을 하나의 결과 행으로 압축
   -> store_id로 그룹화하면 직원 개별행이 아니라 매장별 집계 결과가 나옴
   
   Q2. 윈도우 함수는 평균을 계산하면서도 직원별 행을 유지할 수 있는 이유는 무엇인가요?
   -> partition by는 계산 범위를 나누지만
   -> group by처럼 행을 하나로 합치지 않음
   -> 원본 테이블은 유지하고 집계값을 오른쪽 칼럼에 추가적으로 붙임
   
   Q3. "매장별 평균만 필요한 경우"와 "직원별 급여와 매장 평균을 함께 봐야 하는 경우"에는 각각 어떤 방식을 사용하는 것이 적절한가요?
   -> 매장별 평균만 필요한 경우 GROUP BY가 적절
   -> 직원별 급여와 해당 매장의 평균을 같은 결과에서 비교해야 한다면 윈도우 함수가 적절
   
   
[작성 결과]
- GROUP BY SQL
- 윈도우 함수 SQL
- 두 결과 행 수 비교
- Q1~Q3 답변
*/

-- [코드 작성란]
select store_id, avg(salary) as store_avg_salary
from employees
group by store_id 
order by store_id ;

--===========================================

--윈도우 함수
--Window 함수의 기본형
--함수(칼럼) over partition by 그룹을 나눌 칼럼 order by 계산 순서를 정할 칼럼 as 결과 칼럼명
select store_id, salary, employee_id, avg(salary)
over(partition by store_id)as store_avg_salary
from employees
order by store_id, employee_id ;

--===========================================
--Group by 결과 행 수 
select count(*)as grouped_row_count
from (
select store_id, avg(salary) as store_avg_salary
from employees
group by store_id)

--===========================================

--윈도우 함수 결과 행수 --> 원본 행을 유지한 채
select count(*) as window_row_count
from(
select store_id, salary, employee_id, avg(salary)
over(partition by store_id)as store_avg_salary
from employees)


/*
============================================================
필수 2. PARTITION BY, ORDER BY, 프레임 구조 확인하기
============================================================

[문제 2-1] 매장별 급여 순서에 따른 누적 평균 계산하기

[문제 설명]
각 매장에서 급여가 낮은 직원부터 높은 직원 순서로 정렬한 뒤,
현재 직원까지의 누적 평균 급여를 계산하려고 합니다.

윈도우 함수의 PARTITION BY, ORDER BY, 프레임을 모두 사용하여
각 요소가 어떤 역할을 하는지 확인하세요.

[요구사항]
1. employees 테이블을 사용하세요.
2. store_id별로 파티션을 나누세요.
3. 각 파티션 안에서 salary 오름차순, employee_id 오름차순으로 정렬하세요.
4. AVG(salary) 윈도우 함수를 사용하세요.
5. 프레임은 다음과 같이 지정하세요.

   ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW

6. 결과 컬럼은 다음과 같이 조회하세요.
   - employee_id
   - store_id
   - salary
   - running_avg_salary
7. 같은 쿼리에 EXPLAIN을 적용하고 WindowAgg와 Sort 노드가 있는지 확인하세요.
8. 다음 질문에 답하세요.
   Q1. PARTITION BY store_id는 어떤 역할을 하나요?
   -> 전체 직원 테이블을 store_id별 계산 그룹으로 나눕니다.
   -> 한 매장의 직원은 같은 파티션에서 계산되고 다른 매장 직원과 섞이지 않음
   
   Q2. 윈도우 함수 안의 ORDER BY는 어떤 역할을 하나요?
   -> 각 파티션 안에서 행의 계산 순서를 정한다.
   -> 문제 2번에서는 salary 오름차순으로 급여가 낮은 직원부터 높은 직원 순으로 계산하고,
   -> 급여가 같은 경우에는 직원 id별로 오름차순으로 계산순서를 주기로 부여.
   
   Q3. ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW는 어떤 범위를 계산하나요?
   -> 현재 파티션의 첫 행부터 현재 행까지를 계산 범위로 지정
   -> 현재 행까지 누적 평균 계산
   
   Q4. 실행계획의 WindowAgg와 Sort는 각각 어떤 작업을 의미하나요?
   -> sort는 윈도우 함수 계산에 필요한 순서로 데이터를 정렬하는 작업
   -> windowAgg는 정렬된 데이터를 이용하여 윈도우 함수 결과를 계산하는 작업


[작성 결과]
- 누적 평균 SQL
- EXPLAIN SQL
- 실행계획 확인
- Q1~Q4 답변
*/

-- [코드 작성란]
--1. employees 테이블을 사용하세요.
--2. store_id별로 파티션을 나누세요.
--3. 각 파티션 안에서 salary 오름차순, employee_id 오름차순으로 정렬하세요.
--4. AVG(salary) 윈도우 함수를 사용하세요.
--5. 프레임은 다음과 같이 지정하세요.
--   ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT row
--   
--   ROWS : 행 단위 계산
--   BETWEEN A AND B : 계산 범위를 A부터 B까지
--   UNBOUNDED preceding : 앞쪽 끝 현재 파티션의 첫번째 행부터 시작
--   CURRENT row : 현재 계산 중인 행 포함
--   
--6. 결과 컬럼은 다음과 같이 조회하세요.
--   - employee_id
--   - store_id
--   - salary
--   - running_avg_salary
   
  select employee_id, store_id, salary, avg(salary) 
  over(partition by store_id order by salary asc, employee_id asc
  ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT row) as running_avg_salary
  from employees
  order by store_id, salary, employee_id asc;
  
  --explain
  explain
  select employee_id, store_id, salary, avg(salary)
  over(partition by store_id order by salary asc, employee_id asc
  ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT row) as running_avg_salary
  from employees
  order by employee_id, salary, store_id asc;

/*
============================================================
과제. 주문 상세 행을 유지하면서 고객별 구매금액 계산하기
============================================================

[문제 3-1] 고객별 총 구매금액을 윈도우 함수로 표시하기

[문제 설명]
고객별 총 구매금액을 계산하되,
각 주문 상품 행도 그대로 유지해야 합니다.

GROUP BY로 고객별 합계를 만들면 주문별·상품별 상세 행이 사라집니다.
이번에는 윈도우 함수를 이용해 상세 행을 유지하면서
고객별 총 구매금액을 같은 결과에서 확인하세요.

※ 과제는 필수 문제와 동일한 수준입니다.

[요구사항]
1. orders와 order_items를 order_id 기준으로 JOIN하세요.
2. 주문상품별 구매금액은 qty * price로 계산하세요.
3. 다음 컬럼을 조회하세요.
   - orders.order_id
   - orders.customer_id
   - order_items.product_id
   - order_items.qty
   - order_items.price
   - item_amount
4. SUM(qty * price) OVER (PARTITION BY customer_id)를 사용하여
   customer_total_amount를 계산하세요.
5. 결과를 customer_id, order_id, product_id 순으로 정렬하세요.
6. 다음 질문에 답하세요.
   Q1. customer_total_amount가 같은 고객의 여러 행에서 반복되는 이유는 무엇인가요?
   -> 윈도우 함수는 행을 합치지 않고 원본 상세 행을 그대로 유지함.
   -> PARTITION BY로 나눈 그룹합계를 행 오른쪽에 붙이고 같은 고객의 모든 행에는 동일한 합계값이 반복 표시된다.
   
   Q2. GROUP BY로 같은 고객별 합계를 계산했다면 어떤 상세 정보가 사라지나요?
   -> GROUP BY로 customer_id 그룹화하면 고객 당 한 행으로 압축되고
   -> order_id, product_id, oi.qty, oi.price는 사라진다.
   
   Q3. 개별 주문상품과 고객별 총 구매금액을 동시에 봐야 하는 분석에서 윈도우 함수가 적합한 이유는 무엇인가요?
   -> 윈도우 함수는 행을 합치지 않고 원본 상세 행을 그대로 유지해서
   -> 주문상품 정보와 구매금액 합계를 한번에 볼 수 있다.
   
   Q4. 윈도우 함수에서 PARTITION BY, ORDER BY, 프레임은 각각 어떤 역할을 하나요?
   -> PARTITION BY : 독립적으로 계산할 내용을 나눔.
   -> ORDER BY : 파티션 안에서 계산할 행 순서를 정함.
   -> 프레임 : 계산에 포함할 행의 범위를 지정함.

[제출 결과]
- 전체 SQL
- 결과 확인
- Q1~Q4 답변
*/

-- [코드 작성란]
select o.order_id, o.customer_id, oi.product_id, oi.qty, oi.price, oi.qty*oi.price as item_amount,
sum(oi.qty*oi.price)over(partition by customer_id)as customer_total_amount
from orders o
join order_items oi on oi.order_id = o.order_id 
order by o.order_id, o.customer_id, oi.product_id;


/*
============================================================
실습 마무리
============================================================

아래 내용을 한 문단으로 정리하세요.

1. GROUP BY와 윈도우 함수의 가장 큰 차이는 무엇인가요?
-> GROUP BY는 여러 행을 하나로 압축해 집계 결과만 남기지만,
-> 윈도우 함수는 원본 상세 행을 그대로 유지하면서 집계값을 옆에 붙인다.

2. PARTITION BY, ORDER BY, 프레임은 각각 어떤 역할을 하나요?
-> PARTITION BY는 계산 그룹을 나누고, 
-> ORDER BY는 그룹 내 계산 순서를 정하며,
-> 프레임은 각 행에서 계산에 포함할 행의 범위를 지정한다.

3. 윈도우 함수 실행계획에서 WindowAgg와 Sort를 확인하는 이유는 무엇인가요?
-> Sort는 윈도우 계산에 필요한 순서로 데이터를 정렬하는 작업이고,
-> WindowAgg는 그 정렬된 데이터로 윈도우 함수 결과를 계산한다.

*/

