# Google·Kakao 로그인 설정

프론트엔드 코드는 Google과 Kakao OAuth를 사용할 준비가 되어 있지만, 공급자 비밀키는 저장소에 넣지 않고 Supabase Dashboard에만 등록해야 합니다.

## 공통

1. Supabase Dashboard → Authentication → URL Configuration
2. Site URL: `https://pulmo11.github.io/travel-checklist/`
3. Redirect URLs에 아래 주소 추가
   - `https://pulmo11.github.io/travel-checklist/`
   - 로컬 확인이 필요하면 `http://127.0.0.1:8000/`
4. Authentication → Providers에서 **Manual Linking** 활성화
5. `SUPABASE_ACCOUNTS.sql`을 SQL Editor에서 실행

## Google

1. Google Auth Platform에서 Web application OAuth client 생성
2. Supabase의 Google provider 화면에 표시되는 callback URL을 Google의 승인된 리디렉션 URI로 등록
3. Google Client ID와 Client Secret을 Supabase Authentication → Providers → Google에 저장

## Kakao

1. Kakao Developers에서 애플리케이션 생성
2. 카카오 로그인을 활성화하고 OpenID Connect를 활성화
3. Supabase의 Kakao provider 화면에 표시되는 callback URL을 Kakao Redirect URI로 등록
4. Kakao REST API 키와 Client Secret을 Supabase Authentication → Providers → Kakao에 저장

## 계정 정책

- 같은 이메일의 검증된 Google·Kakao 계정은 Supabase 자동 연결 정책을 따릅니다.
- 로그인 후 다른 공급자를 명시적으로 연결할 수도 있습니다.
- 익명 그룹 사용자가 소셜 로그인을 시작하면 새 사용자를 만들지 않고 현재 익명 사용자에 OAuth identity를 연결해 그룹 멤버십을 유지합니다.
- 최초 계정 전환 전에 기기 데이터 사본을 `festival_passport_device_backups`에 남긴 뒤 서버 데이터와 합칩니다.
