# Festival Passport

## 피드백 기능 설정

- Supabase Dashboard의 **SQL Editor**에서 `SUPABASE_FEEDBACK.sql`을 한 번 실행합니다.
- 이 스크립트는 INSERT 전용 `feedback` 테이블과 비공개 `feedback-images` Storage 버킷을 생성합니다.
- 기존 `config.js`의 `supabaseUrl`과 `supabasePublishableKey`만 재사용하며 새 환경변수나 서비스 롤 키는 필요하지 않습니다.
- 일반 사용자는 새 피드백과 이미지를 제출할 수만 있습니다. 목록 조회·수정·삭제와 비공개 이미지 다운로드는 허용되지 않으며, 관리자는 Supabase Dashboard에서 확인합니다.

### 새 피드백 이메일 알림

피드백 저장과 이메일 알림은 `supabase/functions/notify-feedback` Edge Function에서 함께 처리합니다. 알림 주소는 공개 코드에 넣지 않고 Supabase secret으로 설정합니다.

1. [Resend](https://resend.com/)에 `illuvision@naver.com`으로 가입하고 API Key를 발급합니다.
2. Supabase CLI에서 프로젝트를 연결한 뒤 아래 secret을 설정합니다.

```sh
supabase secrets set RESEND_API_KEY=re_발급받은키 FEEDBACK_NOTIFICATION_EMAIL=illuvision@naver.com
```

3. 익명 사용자도 문의를 보낼 수 있도록 Edge Function을 배포합니다.

```sh
supabase functions deploy notify-feedback --no-verify-jwt
```

Resend의 기본 발신 주소 `onboarding@resend.dev`를 사용합니다. Resend 계정 이메일과 알림 수신 주소가 다르거나 자체 발신 주소를 사용하려면 Resend에서 도메인 인증이 필요합니다.

## Trip Engine Phase A

- 모든 기본·사용자 추가 여행은 `#trip/{tripId}` 공통 상세 화면을 사용합니다.
- 공통 탭: 개요, 일정, 교통, 숙소, 짐싸기, 비용
- 기존 `#fuji`, `#sonic` 주소는 같은 여행의 공통 상세 화면으로 연결됩니다.
- 후지록의 기존 개인 일정·숙소·짐싸기 데이터와 localStorage 키는 그대로 유지됩니다.
- 새 여행 데이터는 `festival-passport-trip-{tripId}-*-v1` 형식으로 여행별 분리 저장됩니다.
- Supabase 그룹을 여행별로 분리하려면 `SUPABASE_TRIP_ENGINE.sql`을 한 번 실행합니다. 기존 그룹은 자동으로 `fuji`에 귀속되며 삭제되지 않습니다.
- 하단 메뉴는 홈, 여행, 짐싸기, 환전, 마이페이지로 구성됩니다. 마이페이지에서 로그인·동기화·저장 현황·초기화를 관리합니다.
- 기본 후지록·섬머소닉 도쿄 여행은 목록에서 숨기거나 다시 복원할 수 있으며, 준비도는 남아 있는 가장 가까운 여행으로 자동 전환됩니다.
- 홈의 Festival World Map에서 등록한 여행을 국가·도시별로 확인하고 공통 여행 상세 화면으로 이동할 수 있습니다. 좌표가 없는 여행도 지도 아래 목적지 목록에 유지됩니다.
- World Map은 현재·예정 여행과 과거 페스티벌 기록을 함께 표시하며 지도, 시간순, 연도별, 국가별 보기와 검색·필터를 제공합니다.
- 과거 기록은 직접 추가하거나 완료된 여행에서 변환할 수 있습니다. 변환 시 기존 여행을 유지하거나 상세 데이터까지 삭제하고 기록만 남길 수 있습니다.
- 마이페이지에서 TSV·CSV·JSON 대량 가져오기와 CSV·JSON 내보내기·백업을 사용할 수 있습니다. 가져오기는 저장 전 열 매핑, 오류, 중복, 위치 미등록 항목을 미리 보여줍니다.
- 홈은 가장 가까운 여행의 준비도와 다음 할 일을 한 카드에 보여줍니다.

앞으로 갈 페스티벌 여행의 일정, 준비 상태, 준비물, 환전 및 여행비를 관리하는 반응형 정적 웹앱입니다. 사이트는 공개로 열리며, 개인 일정은 브라우저에 저장하고 친구 일정은 Supabase 그룹코드로 공유합니다.

## 로컬에서 실행

별도 빌드나 패키지 설치가 필요하지 않습니다. 환율 API 요청을 정상적으로 테스트하려면 파일을 직접 열기보다 간단한 로컬 서버를 사용하세요.

```sh
python3 -m http.server 8000
```

브라우저에서 `http://localhost:8000`을 엽니다.

## GitHub Pages 배포

1. 변경 파일을 `main` 브랜치에 반영합니다.
2. 저장소의 **Settings → Pages**에서 Source를 **Deploy from a branch**로 선택합니다.
3. Branch는 `main`, 폴더는 `/(root)`로 설정합니다.
4. 배포가 끝나면 `https://pulmo11.github.io/travel-checklist/`에서 확인합니다.

앱은 `index.html`을 진입점으로 사용하며 상대 경로로 `config.js`와 Supabase 라이브러리를 불러옵니다.

## 데이터 저장

- 준비물 체크 상태와 사용자 수정 금액은 브라우저 `localStorage`에 저장됩니다.
- 후지록과 섬머소닉 체크 상태는 각각 `travel-companion-fuji-checks`, `travel-companion-sonic-checks` 키를 계속 사용합니다.
- 개인 항공·교통 일정은 `travel-companion-personal-itinerary-v1` 키에 저장됩니다.
- 여행별 통합 준비 상태는 `festival-passport-readiness-v1` 키에 저장됩니다.
- 홈 준비도는 개인 교통 일정, 숙박 계획, 준비물 체크 상태를 읽어 자동으로 갱신됩니다.
- 사용자가 추가한 국내외 페스티벌 여행은 `festival-passport-custom-trips-v1` 키에 저장됩니다.
- 과거 페스티벌 여행은 현재 여행과 분리된 `festival-passport-past-festivals-v1` 키에 저장됩니다.
- 마이페이지의 초기화 버튼은 확인 후 개인 일정·숙소·준비도·짐싸기·환전·여행비·추가 여행을 초기 상태로 되돌립니다. 로그인 중이면 초기화 상태도 클라우드에 동기화됩니다.
- 환율 기능 사용 여부는 `festival-passport-exchange-settings-v1` 키에 저장되며 기본값은 OFF입니다.
- 환전 화면은 JPY·USD·GBP·EUR를 지원하며 선택 통화와 통화별 트래블월렛·현금 값을 각각 저장합니다. 기존 엔화 데이터는 JPY 항목으로 자동 이전됩니다.
- 로그인하지 않은 개인 일정은 브라우저 데이터를 삭제하면 함께 삭제됩니다.
- 환율 기능을 켠 경우에만 Frankfurter v2의 선택 통화/원화 공개 기준환율을 요청하며, 조회 실패 시 마지막 정상 조회값을 표시합니다.

## Supabase 기기 간 동기화

1. Supabase Dashboard의 **SQL Editor**에서 `SUPABASE_SETUP.sql`을 실행합니다.
2. 이어서 `SUPABASE_GROUPS.sql`을 실행합니다.
3. **Authentication → Providers → Anonymous Sign-Ins**를 활성화합니다.
4. **Authentication → URL Configuration**에서 Site URL을 실제 GitHub Pages 주소로 설정합니다.
5. Redirect URLs에 실제 GitHub Pages 주소와 필요한 로컬 테스트 주소를 추가합니다.
6. `config.js`에는 Project URL과 publishable key만 둡니다. secret 또는 service role key는 프론트엔드에 추가하지 않습니다.

같은 이메일의 로그인 링크로 인증한 기기끼리 준비물, 보유 엔화, 여행비 데이터가 동기화됩니다. 최초 로그인 시 서버 데이터가 없으면 기존 localStorage 데이터를 서버로 이전하며, 이후에도 오프라인 표시를 위해 localStorage를 유지합니다.

그룹 일정은 추측하기 어려운 자동 생성 코드를 사용합니다. 코드 확인은 Supabase 함수에서 처리하며, RLS가 가입한 그룹의 데이터만 읽도록 제한합니다. 기존 `private_data`는 로그인한 소유자가 첫 그룹을 만들 때 해당 그룹 일정으로 복사됩니다.
