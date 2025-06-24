# Sketch to Video POC Demo

스케치 이미지를 업로드하여 AI가 생성하는 영상을 만드는 POC 데모입니다.

데모 영상: https://youtu.be/YPuoNpBu-JU
## 🎯 주요 기능

1. **이미지 업로드**: 웹 인터페이스를 통한 스케치 이미지 업로드
2. **이미지 분석**: Claude 3.5 Sonnet을 이용한 이미지 내용 분석
3. **프롬프트 생성**: 분석 결과와 사용자 입력을 바탕으로 영상 생성용 프롬프트 작성
4. **영상 생성**: Amazon Nova Reel 1.1을 이용한 60초 영상 생성 (MULTI_SHOT_AUTOMATED 모드)
5. **결과 확인**: 생성된 영상 재생 및 다운로드

## 🏗️ 아키텍처

- **Frontend**: HTML/CSS/JavaScript (CloudFront로 배포)
- **Backend**: AWS Lambda (Python 3.11)
- **API**: Amazon API Gateway
- **Storage**: Amazon S3 (Private buckets)
- **AI Services**: 
  - nova pro (이미지 분석)
  - Amazon Nova Reel 1.1 (30초 영상 생성)
- **Infrastructure**: AWS CloudFormation
 

## 📋 사전 요구사항

1. **AWS CLI** 설치 및 구성
   ```bash
   aws configure
   ```

2. **AWS 권한**: 다음 서비스에 대한 권한 필요
   - CloudFormation
   - S3
   - Lambda
   - API Gateway
   - CloudFront
   - IAM
   - Bedrock

3. **Bedrock 모델 액세스**: 다음 모델에 대한 액세스 권한 필요
   - `amazon.nova-pro-v1:0`
   - `amazon.nova-reel-v1:1`

## 🚀 배포 방법

### 1. 프로젝트 클론 또는 다운로드
```bash
cd sketch-video-poc
```

### 2. 배포 실행
```bash
./deploy.sh
```

배포 스크립트는 다음 작업을 수행합니다:
- CloudFormation 스택 배포
- S3 버킷 보안 설정 확인
- 웹사이트 파일 업로드
- CloudFront 캐시 무효화

### 3. 배포 완료 확인
배포가 완료되면 CloudFront URL이 출력됩니다.
```
🌐 Access your application at: https://d1234567890.cloudfront.net
```
### 4. apigateway url & redeploy ###
index.html => const API_BASE_URL 생성된 api gateway url로 대치해서 재배포필요 

## 🧪 사용 방법 
1. **웹사이트 접속**: 배포 완료 후 제공된 CloudFront URL로 접속
2. **이미지 업로드**: JPEG 또는 PNG 파일 업로드 (최대 10MB)
3. **설명 입력**: 원하는 영상의 시놉시스, 배경, 스타일 등을 입력
4. **분석 시작**: 이미지 분석 및 프롬프트 생성
5. **영상 생성**: Nova Reel 1.1을 통한 60초 영상 생성 (약 5-8분 소요)
6. **결과 확인**: 생성된 영상 재생 및 경로 확인

## 🗑️ 리소스 정리

모든 AWS 리소스를 삭제하려면:
```bash
./cleanup.sh
```

## 📊 비용 정보

이 POC는 다음 AWS 서비스를 사용하며 비용이 발생할 수 있습니다:
- **Bedrock**: Claude 3.5 Sonnet 및 Nova Reel 사용량에 따라
- **Lambda**: 함수 실행 시간에 따라
- **S3**: 저장 용량 및 요청 수에 따라
- **CloudFront**: 데이터 전송량에 따라
- **API Gateway**: API 호출 수에 따라

## ⚠️ 제한사항

- **영상 길이**: 60초 (Nova Reel 1.1 MULTI_SHOT_AUTOMATED 모드)
- **이미지 형식**: JPEG, PNG만 지원
- **이미지 크기**: 최대 10MB
- **프롬프트 길이**: 2000-4000자 권장 (60초 영상용)
- **동시 처리**: 한 번에 하나의 영상만 생성 가능

## 🔧 문제 해결

### CloudFront 배포 지연
CloudFront 배포는 10-15분이 소요될 수 있습니다. 웹사이트가 즉시 로드되지 않으면 잠시 기다려주세요.

### Bedrock 모델 액세스 오류
AWS 콘솔에서 Bedrock 서비스로 이동하여 필요한 모델에 대한 액세스를 요청하세요.

### S3 권한 오류
S3 버킷이 public access를 허용하지 않도록 설정되어 있는지 확인하세요.

## 📝 로그 확인

Lambda 함수 로그는 CloudWatch에서 확인할 수 있습니다:
- `/aws/lambda/sketch-video-poc-upload`
- `/aws/lambda/sketch-video-poc-analyze`
- `/aws/lambda/sketch-video-poc-generate-video`
- `/aws/lambda/sketch-video-poc-check-status`

##    

이 프로젝트는 POC 데모용으로 제작되었습니다. 프로덕션 환경에서 사용하려면 추가적인 보안, 모니터링, 오류 처리 등이 필요합니다.
 
이 프로젝트는 데모 목적으로만 제공됩니다.
