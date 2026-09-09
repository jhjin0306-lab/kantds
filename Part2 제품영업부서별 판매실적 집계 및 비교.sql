/*
===============================================================================
SQL & 데이터베이스 통합 개인과제

Part 2. 제품별 및 영업 부서별 판매 실적 집계 및 비교
===============================================================================

[과제 개요]
Part 1과 동일한 2025년 2분기 분석 기간을 적용하되, 분석 범위를
반품을 제외한 전체 정상 거래로 확장하여 제품별·영업 부서별 판매 실적을
집계하고 차이를 비교합니다.

이번 Part에서는 반품 거래를 제외한 정상 판매 데이터를 사용하며,
GROUP BY와 집계 함수를 활용하여 영업기획팀이 활용할 수 있는
판매 실적 요약 결과를 작성합니다.

[실무 시나리오]
제약회사 영업기획팀은 2025년 2분기 판매 실적 회의를 준비하고 있습니다.
회의에서는 어떤 제품과 영업 부서가 높은 실적을 기록했는지 확인하고,
실적 차이가 거래 건수 때문인지 평균 거래금액 때문인지 비교해야 합니다.

Part 1과 동일한 분석 기간을 적용하고, 반품을 제외한 전체 정상 거래를
기준으로 제품과 영업 부서 정보를 판매 데이터와 연결하여 집계 결과를
작성하세요.

[과제 목표]
- 판매 데이터와 제품·영업 부서 테이블을 올바르게 연결할 수 있습니다.
- GROUP BY를 사용하여 제품별·영업 부서별 실적을 집계할 수 있습니다.
- COUNT, SUM, AVG를 사용하여 거래 건수, 판매수량, 총판매금액과
  평균 판매금액을 계산할 수 있습니다.
- 집계 결과를 기준에 맞게 정렬하고 그룹 간 실적 차이를 해석할 수 있습니다.

[사용 환경]
- PostgreSQL
- DBeaver

[데이터베이스 준비 안내]
제공된 CSV는 판매·제품·영업 부서·거래처 정보가 한 파일에 포함된 통합
데이터입니다. 과제 시작 전에 공통 준비 SQL을 실행하여 통합 원본 데이터를
sales, products, sales_departments, customers 등의 관계형 테이블로
분리합니다. 이 준비 과정은 과제의 채점 대상이 아닙니다.

[사용 데이터]
- 원본 파일: 제약회사_제품판매_데이터.csv
- 공통 준비 파일: 제약회사_제품판매데이터_관계형테이블_준비.sql
- 스키마: 제약회사_제품판매_데이터
- 테이블:
  · sales
  · products
  · sales_departments

[주요 컬럼]
- sales:
  sale_id, sale_date, product_id, sales_dept_id,
  sales_type, quantity, sale_amount
- products:
  product_id, product_name
- sales_departments:
  sales_dept_id, sales_dept_name, sales_region

[제출 결과물]
- Part2_제품영업부서별_판매실적집계및비교_실습.sql
- 문제의 SQL 코드와 실행 결과가 확인되는 GitHub 저장소 링크

[실행 전 확인]
===============================================================================
*/

SET search_path TO 제약회사_제품판매_데이터;


/* ============================================================================
문제 1. 제품별 판매 실적 집계
===============================================================================

[업무 요청]
영업기획팀이 제품별 판매 성과를 비교할 수 있도록 2025년 2분기
제품별 판매 실적을 집계하세요.

[필수 요구사항]
1. sales와 products 테이블을 제품 ID를 기준으로 연결하세요.-> 기준으로 연결 from join on // sales s products p
2. 판매일자가 2025년 4월 1일 이상, 2025년 7월 1일 미만인 거래만
   사용하세요.
3. sales_type이 '반품'인 거래는 제외하세요. <>
4. 제품별로 다음 항목을 출력하세요.
   - product_id
   - product_name
   - transaction_count: 거래 건수
   - total_quantity: 총판매수량
   - total_sales_amount: 총판매금액
   - avg_sales_amount: 평균 판매금액
5. 평균 판매금액은 소수점 둘째 자리까지 표시하세요.
 - ROUND(..., 2)는 평균 판매금액을 소수점 둘째 자리까지 표시합니다.
6. 총판매금액이 큰 제품부터 정렬하세요. desc;
===============================================================================
- 테이블:
  · sales
  · products
  · sales_departments

[주요 컬럼]
- sales:
  sale_id, sale_date, product_id, sales_dept_id,
  sales_type, quantity, sale_amount
- products:
  product_id, product_name
- sales_departments:
  sales_dept_id, sales_dept_name, sales_region

*/

select p.product_id, p.product_name,
count(*)as transaction_count,
sum(s.quantity) as total_quantity,
round(avg(s.sale_amount),2) as avg_sales_amount,
sum(s.sale_amount) as total_sales_amount
from sales s  
join products p on s.product_id = p.product_id
where s.sale_date >='2025-04-01'
and s.sale_date <'2025-07-01'
and s.sales_type<>'반품'
group by p.product_id, p.product_name
order by total_sales_amount desc;

/*select 
from
where
group by
having
order by
*/

/* ============================================================================
문제 2. 영업 부서별 판매 실적 집계
===============================================================================

[업무 요청]
같은 기간의 판매 데이터를 영업 부서별로 집계하여 부서 간 실적을
비교할 수 있는 결과를 작성하세요.

[필수 요구사항]
1. sales와 sales_departments 테이블을 영업 부서 ID를 기준으로
   연결하세요.
2. 문제 1과 동일한 기간 조건을 적용하세요.
3. sales_type이 '반품'인 거래는 제외하세요.
4. 영업 부서별로 다음 항목을 출력하세요.
   - sales_dept_id
   - sales_dept_name
   - sales_region
   - transaction_count: 거래 건수
   - total_quantity: 총판매수량
   - total_sales_amount: 총판매금액
   - avg_sales_amount: 평균 판매금액
5. 평균 판매금액은 소수점 둘째 자리까지 표시하세요.
6. 총판매금액이 큰 영업 부서부터 정렬하세요.

- 테이블:
  · sales
  · products
  · sales_departments

[주요 컬럼]
- sales:
  sale_id, sale_date, product_id, sales_dept_id,
  sales_type, quantity, sale_amount
- products:
  product_id, product_name
- sales_departments:
  sales_dept_id, sales_dept_name, sales_region
===============================================================================
*/
select sd.sales_dept_id, sd.sales_dept_name, sd.sales_region,
count(*)as transaction_count,
sum(s.quantity) as total_quantity,
round(avg(s.sale_amount),2) as avg_sales_amount,
sum(s.sale_amount) as total_sales_amount
from sales s
join sales_departments sd on s.sales_dept_id = sd.sales_dept_id
where s.sale_date >='2025-04-01'
and s.sale_date <'2025-07-01'
and s.sales_type<>'반품'
group by sd.sales_dept_id, sd.sales_dept_name, sd.sales_region
order by total_sales_amount desc;



/* ============================================================================
문제 3. 제품·영업 부서별 실적 비교 및 해석
===============================================================================

[업무 요청]
문제 1과 문제 2의 실행 결과를 바탕으로 판매 실적의 차이를 설명하세요.

[필수 요구사항]
아래 내용을 포함하여 SQL 주석으로 3~5문장 작성하세요.

1. 총판매금액이 가장 높은 제품과 영업 부서를 작성하세요.
2. 상위 그룹과 하위 그룹의 실적 차이를 작성하세요.
3. 거래 건수와 평균 판매금액을 함께 확인하여 실적 차이가 발생한
   가능한 이유를 설명하세요.
	
[유의사항]
- 단순히 순위만 나열하지 말고, 집계 지표를 근거로 비교하세요.
- 데이터로 확인할 수 없는 원인을 확정적으로 작성하지 않습니다.

- 테이블:
  · sales
  · products
  · sales_departments

[주요 컬럼]
- sales:
  sale_id, sale_date, product_id, sales_dept_id,
  sales_type, quantity, sale_amount
- products:
  product_id, product_name
- sales_departments:
  sales_dept_id, sales_dept_name, sales_region
===============================================================================
*/
/*1. 총판매금액이 가장 높은 제품과 영업 부서를 작성하세요.
2. 상위 그룹과 하위 그룹의 실적 차이를 작성하세요.
3. 거래 건수와 평균 판매금액을 함께 확인하여 실적 차이가 발생한
   가능한 이유를 설명하세요.*/
/*
1.	product_id : P004 | product_name : 리피다운정 20mg | total_sales_amount	:51,437,100
	sales_dept_name : 호남영업팀 | total_sales_amount : 103,472,901
	
2.  30위인 코프릴시럽은 1,495,707원으로 1위인 리피다운정과는 약 34.38배 차이난다.
	7위인 강원영업팀은 29,685,495원으로 1위인 호남영업팀과는 약 3.48배 차이난다.
	
3.	2위와 3위를 비교하고자 한다.
	인펙트주는 거래횟수가 12건으로 글루코밸런스정의 거래횟수보다 적지만,(글루코밸런스정 거래횟수 : 24회)
	인펙트주의 평균 판매금액이 3,645,260원으로 글루코밸런스정(1,171,758원)보다 높은 순위이다. 
	거래횟수에 비해 평균 판매금액이 높아 실적차이가 발생한 것을 확인할 수 있었다.
	영남영업팀과 온라인사업팀의 거래횟수는 두 팀 모두 75건으로 동일하다. 하지만 	영남영업팀의 평균 판매금액이 1,283,179원으로
	1,085,739원인 온라인사업팀보다 높다. 그래서 영남영업팀이 총 판매금액이 더 높아 순위가 2위이다.
	같은 거래횟수여도 평균 판매금액이 높아 더 높은 순위에 위치한다는 것을 알 수 있었다.
	
*/


/* ============================================================================
선택 심화. 일정 실적 이상인 영업 부서 조회
===============================================================================

아래 심화 문제는 선택사항입니다.
수행하지 않아도 필수 과제 제출에는 영향을 주지 않습니다.

[심화 요구사항]
- 문제 2의 영업 부서별 집계 결과에서 총판매금액이 30000000 이상인
  영업 부서만 조회하세요.
- 집계 결과에 대한 조건은 HAVING을 사용하여 적용하세요.
- 총판매금액이 큰 순서로 정렬하세요.
===============================================================================
*/

select sd.sales_dept_id, sd.sales_dept_name, sd.sales_region,
count(*)as transaction_count,
sum(s.quantity) as total_quantity,
round(avg(s.sale_amount),2) as avg_sales_amount,
sum(s.sale_amount) as total_sales_amount
from sales s
join sales_departments sd on s.sales_dept_id = sd.sales_dept_id
where s.sale_date >='2025-04-01'
and s.sale_date <'2025-07-01'
and s.sales_type<>'반품'
group by sd.sales_dept_id, sd.sales_dept_name, sd.sales_region
having sum(s.sale_amount) >= 30000000
order by total_sales_amount desc;



/* ============================================================================
제출 전 확인
===============================================================================
[ ] 제약회사_제품판매_데이터 스키마를 설정했다.
[ ] 제품별 집계에서 sales와 products를 올바르게 연결했다.
[ ] 영업 부서별 집계에서 sales와 sales_departments를 올바르게 연결했다.
[ ] 두 문제에 동일한 2025년 2분기 조건을 적용했다.
[ ] 반품 거래를 제외했다.
[ ] COUNT, SUM, AVG를 사용했다.
[ ] 비집계 컬럼을 GROUP BY에 포함했다.
[ ] 평균 판매금액을 소수점 둘째 자리까지 표시했다.
[ ] 총판매금액을 기준으로 내림차순 정렬했다.
[ ] 제품과 영업 부서 간 실적 차이를 집계 결과에 근거하여 해석했다.
[ ] 모든 SQL이 PostgreSQL에서 정상 실행된다.
[ ] SQL 파일을 GitHub 저장소에 업로드했다.

※ 선택 심화는 제출 전 필수 확인 항목이 아닙니다.
===============================================================================
*/