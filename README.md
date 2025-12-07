<img width="100" src="https://github.com/user-attachments/assets/6d4f1c3e-bc14-48c3-b894-9eb22e15c374" />

# 축꾸미
축꾸미는 K리그 팬들을 위한 사진·영상 기반 커뮤니티 앱입니다.  
게시글을 나만의 스타일로 꾸밀 수 있는 이미지/영상 편집 기능과  
실시간 채팅을 통해 팬들끼리 소통할 수 있는 공간을 제공합니다.

<br>

## 앱 미리보기
<p align="center">
  <img src="https://github.com/user-attachments/assets/11caac78-4573-4545-875e-ff29811c28ae" width="150"/> 
  <img src="https://github.com/user-attachments/assets/658aa8ec-c847-4a2e-8362-6429a0167d32" width="150"/> 
  <img src="https://github.com/user-attachments/assets/bb2e949e-ffab-4b49-aeac-46340ff42ada" width="150"/> 
  <img src="https://github.com/user-attachments/assets/59ff8352-8006-4331-bec3-8eb6c0e023d5" width="150"/> 
  <img src="https://github.com/user-attachments/assets/c3787a33-f570-4d7d-8913-f667bf59a4d7" width="150"/>
</p>

<br>

## 프로젝트 개요

이 프로젝트는 iOS 개발자 3명이 함께 진행한 3주간의 팀 프로젝트입니다.

- 개발 기간: 2024년 11월 ~ 2024년 12월
- 지원 OS: iOS 17.0 이상
- 개발 환경: Swift 6, SwiftUI, Xcode 16, Swift Package Manager

<br>

## 주요 기능

### 인증
- Apple / Kakao 소셜 로그인  
- 이메일 회원가입 및 로그인  
- Keychain 기반 토큰 보안 저장  

<br>

### 게시글 및 피드
- 무한 스크롤 피드  
- 좋아요, 댓글, 북마크  
- 응원팀 카테고리별 게시글 작성  
- 해시태그 검색  

<br>

### 이미지 편집
- CoreML 기반 AI 필터  
- 흑백, 빈티지 등 기본 필터  
- 텍스트 오버레이  
- 스티커 편집  
- 자유 드로잉   
- 다양한 비율 자르기  
- Undo / Redo 기능 지원  

<br>

### 영상 편집
- 구간 자르기  
- 자막 추가  
- 배경 음악 삽입  
- 필터 적용  

<br>

### 실시간 채팅
- Socket.IO 기반 WebSocket 통신  
- 텍스트, 이미지, 영상 메시지  
- 게시글 공유  
- 읽음 표시  
- 채팅방 배경 테마 변경  

<br>

### 결제
- PortOne 기반 AI 필터 구매  
- 서버 검증 기반 결제 처리  
- 구매 이력 로컬 캐싱  

<br>

## 기술 스택

### 아키텍처
- SwiftUI  
- TCA (The Composable Architecture)  
- MVVM + Coordinator  

<br>

### 네트워킹
- URLSession (Async/Await)  
- Router 패턴  
- Multipart Form-data 업로드  
- URLSessionDelegate 업로드 진행률 추적  
- Actor 기반 TaskStorage  

<br>

### 토큰 관리
- Keychain 보안 저장  
- Actor 기반 자동 토큰 갱신  
- 동시 갱신 문제를 대기열 패턴으로 해결  
- CheckedContinuation 기반 Race Condition 방지  

<br>

### 캐싱
- 이미지 필터용 LRU 캐싱  
- 썸네일/원본 이미지 캐시 분리  
- Undo/Redo 메타데이터 기반 메모리 절감  
- Lazy regeneration 최적화  

<br>

### 실시간 통신
- Socket.IO 기반 WebSocket  
- 자동 재연결  
- Namespace 분리로 방 관리  

<br>

### 미디어 처리
- CoreImage + Metal 필터  
- CoreML 스타일 변환 모델  
- PencilKit 드로잉  
- AVFoundation 영상 편집  

<br>

### 결제 처리
- PortOne WebView 연동  
- Deep Link 처리  
- 서버 기반 결제 검증  
