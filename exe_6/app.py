import streamlit as st
import pandas as pd
from statsmodels.tsa.arima.model import ARIMA

st.title("Bike Sharing 시계열 예측")
st.write("월별 자전거 대여량을 확인하고 미래 값을 예측합니다.")

# 1. CSV 파일 업로드
uploaded_file = st.file_uploader(
    "Bike_Sharing_Demand",
    type="csv"
)

# 2. CSV 파일이 업로드되었을 때만 실행
if uploaded_file is not None:

    # 데이터 불러오기
    data = pd.read_csv(uploaded_file)

    st.write("업로드된 CSV 파일의 데이터")
    st.dataframe(data.head())

    # 3. datetime 컬럼을 날짜 형식으로 변환
    data["datetime"] = pd.to_datetime(data["datetime"])

    # 4. 월별 데이터 만들기
    data["month"] = (
        data["datetime"].dt.to_period("M").dt.to_timestamp()
    )

    # 5. 월별 자전거 대여량 합계 계산
    monthly = (
        data.groupby("month", as_index=False)["count"]
        .sum()
    )

    monthly = monthly.set_index("month").sort_index()

    # 6. 월별 대여량 확인
    st.subheader("월별 자전거 대여량")
    st.dataframe(monthly)

    # 7. 시계열 그래프
    st.subheader("시간에 따른 월별 대여량 변화")
    st.line_chart(monthly["count"])

    # 8. 예측 기간 선택
    forecast_period = st.selectbox(
        "예측 기간을 선택하세요:",
        [1, 3, 6]
    )

    # 9. ARIMA 모델 학습
    model = ARIMA(monthly["count"], order=(2, 1, 1))
    model_fit = model.fit()

    # 10. 미래 대여량 예측
    forecast = model_fit.forecast(steps=forecast_period)

    # 11. 예측 결과 출력
    st.subheader("미래 자전거 대여량 예측")
    st.dataframe(forecast.to_frame(name="예측 대여량"))

# import streamlit as st
# import pandas as pd

# from statsmodels.tsa.arima.model import ARIMA

# # 1. 제목과 설명
# st.title("Bike Sharing 시계열 예측")
# st.write("월별 자전거 대여량을 확인하고 미래 값을 예측합니다.")

# # 2. CSV 업로드
# uploaded_file = st.file_uploader("Bike_Sharing_Demand.csv 파일을 올려주세요", type="csv")

# if uploaded_file is not None:
#     # 3. DataFrame으로 불러오기 (한 번만 읽기)
#     data = pd.read_csv(uploaded_file)

#     st.write("업로드한 원본 데이터")
#     st.dataframe(data)

#     # 4. datetime을 날짜/시간 자료형으로 변환
#     data["datetime"] = pd.to_datetime(data["datetime"])

#     # 5. 시간 순서대로 정렬한 뒤 월별 count 합계
#     data = data.sort_values("datetime")
#     data["month"] = data["datetime"].dt.to_period("M").dt.to_timestamp()

#     monthly = data.groupby("month", as_index=False)["count"].sum()
#     monthly = monthly.set_index("month")

#     # 6. 월별 데이터를 표와 선 그래프로 표시
#     st.write("월별 자전거 대여량")
#     st.dataframe(monthly)

#     st.write("시간에 따른 월별 대여량 변화")
#     st.line_chart(monthly["count"])

#     # 7. 예측 기간 선택
#     forecast_period = st.selectbox("예측 기간(개월)을 선택하세요", [1, 3, 6])

#     # 8. 전체 월별 count로 ARIMA(2, 1, 1) 학습
#     model = ARIMA(monthly["count"], order=(2, 1, 1))
#     model_fit = model.fit()

#     # 9. 선택한 기간만큼 예측
#     forecast = model_fit.forecast(steps=forecast_period)

#     # 10. 마지막 관측 월의 다음 달부터 미래 날짜 생성
#     last_month = monthly.index[-1]
#     future_dates = pd.date_range(
#         start=last_month + pd.DateOffset(months=1),
#         periods=forecast_period,
#         freq="MS"
#     )

#     # 11. 미래 날짜와 예측값을 DataFrame으로 만들어 표로 표시
#     forecast_df = pd.DataFrame({"count": forecast.values}, index=future_dates)
#     forecast_df.index.name = "month"

#     st.write("미래 예측 결과")
#     st.dataframe(forecast_df)

#     # 12. 기존 실제값과 미래 예측값을 하나의 선 그래프로 표시
#     chart_df = pd.DataFrame({
#         "실제값": monthly["count"],
#         "예측값": forecast_df["count"]
#     })

#     st.write("실제값과 미래 예측값")
#     st.line_chart(chart_df)