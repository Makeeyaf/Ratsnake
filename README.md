# Ratsnake
HLS 동영상 스트리밍을 처리하는 iOS 앱 샘플

- 구매 전에는 샘플 영상(`ayc-sample.m3u8`)을 보여준다 
- 샘플 영상을 다 보고 난 뒤에는 구매 페이지를 보여준다 
- 구매 후에는 전체 영상(`ayc.m3u8`)을 이어서 보여준다

## 프로젝트 구조

<image src="https://github.com/Makeeyaf/Ratsnake/blob/e570eed169e2cd93d27db867d800329d6492f75a/assets/diagram.png" width=50%>

## 설치 & 실행
1. HLS, API Service 설정
```shell
cd Service && npm install
```

2. HLS, API Service 실행
```shell
node src/app.js
```
<http://localhost:8000> 으로 접속했을 때 웹 뷰어가 실행되면 👍

3. 앱 빌드 & 실행

시뮬레이터에서만 확인할 수 있음
