// 관내 점검표 데이터

class CheckItem {
  final String content;
  CheckItem(this.content);
}

class CheckSubject {
  final String name;
  final List<CheckItem> items;
  CheckSubject(this.name, this.items);
}

class CheckLocation {
  final int no;
  final String location;
  final List<CheckSubject> subjects;
  CheckLocation(this.no, this.location, this.subjects);
}

class ChecklistTemplate {
  final String id;
  final String title;
  final List<CheckLocation> locations;
  ChecklistTemplate({required this.id, required this.title, required this.locations});
}

// ══════════════════════════════════════════
// 샬롬 지하
// ══════════════════════════════════════════
final kChecklistShalomB1 = ChecklistTemplate(
  id: 'shalom_b1',
  title: '관내점검표 (샬롬 지하)',
  locations: [
    CheckLocation(1, '플로어북\n계단 중간 벽 하단에 위치', [
      CheckSubject('유도등', [
        CheckItem('1. 등이 어두웁지 눈으로 확인(빨아야 함)\n*등그람 점검 스위치를 누르면 불이 꺼졌다 켜짐'),
        CheckItem('2. 초록색 램프가 항상 켜져 있어야 함'),
        CheckItem('3. 적색 램프는 들어와 있으면 안됨'),
        CheckItem('4. 점검 스위치 길게 눌렀을 때 적색 램프 켜지면 이상'),
      ]),
    ]),
    CheckLocation(2, '계단 출입구 상단\n각층 복도 끝 상단에 위치', [
      CheckSubject('비상구유도등', [
        CheckItem('1. 등이 어두웁지 눈으로 확인(빨아야 함)'),
        CheckItem('2. 초록색 램프 항상 켜져 있어야 함'),
      ]),
    ]),
    CheckLocation(3, '중앙 계단, 휴게실표 비상 계단', [
      CheckSubject('계단선서등', [
        CheckItem('1. 불이 켜지는지 확인(넓이는 작동이 안되는 경우도 있음)'),
      ]),
    ]),
    CheckLocation(4, '공동화장실', [
      CheckSubject('전등, 배수, 콘센트(1)', [
        CheckItem('1. 전등 켰다 껐다 확인'),
        CheckItem('2. 화장실 세면대 배수 확인'),
        CheckItem('3. 화장실 변기 물 내려보기'),
        CheckItem('4. 콘센트 속 먼지/서수 꽂혀있는지/눕게 한 자국/접지 확인'),
      ]),
    ]),
    CheckLocation(5, '복도', [
      CheckSubject('전장 확인, 소화기', [
        CheckItem('1. 전장의 이름 확인 (복도 톡스 누수확인)'),
        CheckItem('2. 콘센트 속 먼지/서수 꽂혀있는지/접지 확인'),
        CheckItem('3. 소화기 한 번 뒤집어 보기 (쏴지는 소리가 나야 정상)'),
        CheckItem('4. 소화기 게이지판의 바늘이 초록색을 가리키면 정상\n(왼쪽방향 정상, 오른쪽방향 비정상)'),
      ]),
    ]),
    CheckLocation(6, '샤워실', [
      CheckSubject('배수, 콘센트(1)', [
        CheckItem('1. 전등 켰다 껐다 확인'),
        CheckItem('2. 샤워실 바닥 배수 확인'),
        CheckItem('3. 콘센트 속 먼지/서수 꽂혀있는지/접지 확인'),
      ]),
    ]),
    CheckLocation(7, '운동실', [
      CheckSubject('시계(1), 운동시설, 제습기, 콘센트(1), 소화기(1)', [
        CheckItem('1. 전등 켰다 껐다 확인'),
        CheckItem('2. 시계 건전지 교체 여부 및 고장 확인'),
        CheckItem('3. 운동기구 이상 여부 확인'),
        CheckItem('4. 제습기 정상 작동 여부 확인'),
        CheckItem('5. 콘센트 속 먼지/접지 확인'),
        CheckItem('6. 소화기 한 번 뒤집어 보기 (쏴지는 소리가 나야 정상)'),
        CheckItem('7. 소화기 게이지판 바늘 초록색 정상 여부 확인'),
      ]),
    ]),
    CheckLocation(8, '세탁실', [
      CheckSubject('시계(1), 제습기, 콘센트(1), 소화기(1)', [
        CheckItem('1. 전등 켰다 껐다 확인'),
        CheckItem('2. 시계 건전지 교체 여부 및 고장 확인'),
        CheckItem('3. 제습기 정상 작동 여부 확인'),
        CheckItem('4. 콘센트 속 먼지/접지 확인'),
        CheckItem('5. 소화기 한 번 뒤집어 보기 (쏴지는 소리가 나야 정상)'),
        CheckItem('6. 소화기 게이지판 바늘 초록색 정상 여부 확인'),
      ]),
    ]),
    CheckLocation(9, '시청각실', [
      CheckSubject('시계(1), 제습기, 콘센트(1), 소화기(1)', [
        CheckItem('1. 전등 켰다 껐다 확인'),
        CheckItem('2. 시계 건전지 교체 여부 및 고장 확인'),
        CheckItem('3. 제습기 정상 작동 여부 확인'),
        CheckItem('4. 콘센트 속 먼지/접지 확인'),
        CheckItem('5. 소화기 한 번 뒤집어 보기 (쏴지는 소리가 나야 정상)'),
        CheckItem('6. 소화기 게이지판 바늘 초록색 정상 여부 확인'),
      ]),
    ]),
  ],
);

// ══════════════════════════════════════════
// 샬롬 각층
// ══════════════════════════════════════════
final kChecklistShalomFloor = ChecklistTemplate(
  id: 'shalom_floor',
  title: '관내점검표 (샬롬 각층)',
  locations: [
    CheckLocation(1, '통로, 복도, 계단 중간 벽 하단', [
      CheckSubject('유도등', [
        CheckItem('1. 등이 어두운지 눈으로 확인(밝아야 함)\n*동그란 점검 스위치를 누르면 불이 꺼졌다 켜짐'),
        CheckItem('2. 초록색 램프가 항상 켜져 있어야 함'),
        CheckItem('3. 적색 램프는 들어와 있으면 안됨'),
        CheckItem('4. 점검 스위치 길게 눌렀을 때 적색 램프 켜지면 이상'),
      ]),
    ]),
    CheckLocation(2, '계단 출입구 상단, 각층 복도 끝 상단', [
      CheckSubject('유도등', [
        CheckItem('1. 등이 어두운지 눈으로 확인(밝아야 함)'),
        CheckItem('2. 초록색 램프 항상 켜져 있어야 함'),
      ]),
    ]),
    CheckLocation(3, '중앙 계단, 휴게실쪽 비상 계단', [
      CheckSubject('계단 선서등', [
        CheckItem('1. 불이 켜지는지 확인(낮에는 작동이 안 되는 경우도 있음)'),
      ]),
    ]),
    CheckLocation(4, '휴게홀', [
      CheckSubject('전등, 시계, 콘센트, 소화기, 전기모기채동\n살충제(바퀴, 모기, 지네), 소파, 정수기', [
        CheckItem('1. 전등 껐다 켜보기'),
        CheckItem('2. 시계 건전지 교체 여부 및 고장 확인'),
        CheckItem('3. 콘센트 속 먼지 여부/너무 많이 꽂혀있는지/누렇게 탄 자국, 접지(동그란 코드 내부 양쪽 쇠) 하나만 있거나 구부러졌는지 확인'),
        CheckItem('4. 소화기 한 번 뒤집어 보기\n(분말 소리가 나야 정상)'),
        CheckItem('5. 소화기 계기판의 바늘이 초록색을 가리키면 정상, 초록색에서 바늘이 왼쪽 방향이면 정상, 오른쪽 방향이면 비정상임 (범위를 조금 벗아난 것은 정상)'),
        CheckItem('6. 전기모기채 1개 비치, 작동 영부/에프킬라 2개 비치, 잔량 부족 확인'),
        CheckItem('7. 소파 상태 확인'),
        CheckItem('8. 정수기 고장 여부 확인, 정수기 뒤 밸브에서 물 새거나 고여있는지 확인')
      ]),
    ]),
    CheckLocation(5, '공동 화장실', [
      CheckSubject('전등, 배수, 변기, 콘센트', [
        CheckItem('1. 전등 껐다 켜보기'),
        CheckItem('2. 화장실 세면대 배수 확인'),
        CheckItem('3. 화장실 변기 막힌 곳 확인'),
        CheckItem('4. 콘센트 속 먼지 여부/너무 많이 꽂혀있는지/누렇게 탄 자국, 접지(동그란 코드 내부 양쪽 쇠) 하나만 있거나 구부러졌는지 확인'),
      ]),
    ]),
    CheckLocation(6, '복도', [
      CheckSubject(' 천장 얼룩, 콘센트, 소화기', [
        CheckItem('1. 천장의 얼룩 확인 (복도 천장 텍스 누수확인)'),
        CheckItem('2. 콘센트 속 먼지 여부/너무 많이 꽂혀있는지/누렇게 탄 자국, 접지(동그란 코드 내부 양쪽 쇠) 하나만 있거나 구부러졌는지 확인'),
        CheckItem('3. 소화기 한 번 뒤집어 보기\n(분말 소리가 나야 정상)'),
        CheckItem('4. 소화기 계기판의 바늘이 초록색을 가리키면 정상, 초록색에서 바늘이 왼쪽 방향이면 정상, 오른쪽 방향이면 비정상임 (범위를 조금 벗아난 것은 정상)'),
      ]),
    ]),
    CheckLocation(7, '휴게실', [
      CheckSubject('전등, 시계, 콘센트, 소화기, 비품 재고 확인, 의자', [
        CheckItem('1. 전등 켰다 꺼보기'),
        CheckItem('2. 시계 건전지 교체 여부 및 고장 확인'),
        CheckItem('3. 콘센트 속 먼지 여부/너무 많이 꽂혀있는지/누렇게 탄 자국, 접지(동그란 코드 내부 양쪽 쇠) 하나만 있거나 구부러졌는지 확인'),
        CheckItem('4. 소화기 한 번 뒤집어 보기\n(분말 소리가 나야 정상)'),
        CheckItem('5. 소화기 계기판의 바늘이 초록색을 가리키면 정상, 초록색에서 바늘이 왼쪽 방향이면 정상, 오른쪽 방향이면 비정상임 (범위를 조금 벗아난 것은 정상)'),
        CheckItem('6. 정전기 청소포, 전자레인지 청소용 물티슈(청소박사), 바이오크린콜 재고 충분한지 확인'),
        CheckItem('7. 의자 상태 확인'),
      ]),
    ]),
  ],
);

// ══════════════════════════════════════════
// 국생 모든 층
// ══════════════════════════════════════════
final kChecklistGuksaengFloor = ChecklistTemplate(
  id: 'guksaeng_floor',
  title: '관내점검표 (국생 모든층)',
  locations: [
    CheckLocation(1, '각층 휴게실', [
      CheckSubject('전등, 시계, 콘센트, 전기모기채\n살출제(바퀴, 모기, 지네), 비품 재고 확인, 정수기', [
        CheckItem('1. 전등 껐다 켜보기'),
        CheckItem('2. 시계 건전지 교체 여부 및 고장 확인'),
        CheckItem('3. 콘센트 속 먼지 여부/너무 많이 꽂혀있는지/누렇게 탄 자국, 접지(동그란 코드 내부 양쪽 쇠) 하나만 있거나 구부러졌는지 확인'),
        CheckItem('4. 전기모기채 1개 비치, 작동 여부, 에프킬라 2개 비치, 잔량 부족 확인'),
        CheckItem('5. 정전기 청소포 재고 충분한지 확인'),
        CheckItem('6. 정수기 고장 여부 확인, 정수기 뒤 밸브에서 물 새거나 고여있는지 확인'),
      ]),
    ]),
    CheckLocation(2, '계단 중간 벽 하단', [
      CheckSubject('통로/복도 유도등, 소화기', [
        CheckItem('1. 등이 어두운지 눈으로 확인(밝아야 함)\n*동그란 점검 스위치를 누르면 불이 꺼졌다 켜짐'),
        CheckItem('2. 초록색 램프가 항상 켜져 있어야 함'),
        CheckItem('3. 적색 램프는 들어와 있으면 안됨'),
        CheckItem('4. 점검 스우치 길게 눌렀을 때 적색 램프 켜지면 이상'),
        CheckItem('5. 소화기 한 번 뒤집어 보기\n(분말 소리가 나야 정상)'),
        CheckItem('6. 소화기 계기판의 바늘이 초록색을 가리키면 정상, 초록색에서 바늘이 왼쪽 방향이면 정상, 오른쪽 방향이면 비정상임 (범위를 조금 벗아난 것은 정상)'),
      ]),
    ]),
    CheckLocation(3, '계단 출입구 상단, 각층 복도 끝 상단', [
      CheckSubject('유도등', [
        CheckItem('1. 등이 어두운지 눈으로 확인(밝아야 함)'),
        CheckItem('2. 초록색 램프 항상 켜져 있어야 함'),
      ]),
    ]),
    CheckLocation(4, '중앙 계단, 휴게실표 쪽 비상 계단', [
      CheckSubject('계단선서등', [
        CheckItem('1. 불이 켜지는지 확인(낮에는 작동이 안되는 경우도 있음)'),
      ]),
    ]),
    CheckLocation(5, '공동 화장실', [
      CheckSubject('전등, 배수, 변기, 콘센트', [
        CheckItem('1. 전등 껐다 켜보기'),
        CheckItem('2. 화장실 세면대 배수 확인'),
        CheckItem('3. 화장실 변기 막힌 곳 확인'),
        CheckItem('4. 콘센트 속 먼지 여부/너무 많이 꽂혀있는지/누렇게 탄 자국, 접지(동그란 코드 내부 양쪽 쇠) 하나만 있거나 구부러졌는지 확인'),
      ]),
    ]),
    CheckLocation(6, '복도', [
      CheckSubject('천장 얼룩, 소화기(4개)', [
        CheckItem('1. 전장의 얼룩 확인 (복도 천장 텍스 누수 확인)'),
        CheckItem('2. 소화기 한 번 뒤집어 보기\n(분말 소리가 나야 정상)'),
        CheckItem('3. 소화기 계기판의 바늘이 초록색을 가리키면 정상, 초록색에서 바늘이 왼쪽방향이면 정상, 오른쪽 방향이면 비정상\n(* 범위를 조금 벗어난 것은 정상임)'),
      ]),
    ]),
    CheckLocation(7, '세면실', [
      CheckSubject('콘센트(1개), 배수', [
        CheckItem('1. 콘센트 속 먼지 여부/너무 많이 꽂혀있는지/누렇게 탄 자국, 접지(동그란 코드 내부 양쪽 쇠) 하나만 있거나 구부러졌는지 확인'),
        CheckItem('2. 세면대 배수 확인'),
      ]),
    ]),

    CheckLocation(8, '쓰레기통 뒤', [
      CheckSubject('해충', [
        CheckItem('1. 약품 뿌려져 있는지 확인, 벌레 유무'),
      ]),
    ]),
    CheckLocation(9, '조리실', [
      CheckSubject('전등, 콘센트, 소화기\n비품 재고 확인, 정수기', [
        CheckItem('1. 전등 껐다 켜보기'),
        CheckItem('2. 콘센트 속 먼지 여부/너무 많이 꽂혀있는지/누렇게 탄 자국, 접지(동그란 코드 내부 양쪽 쇠) 하나만 있거나 구부러졌는지 확인'),
        CheckItem('3. 소화기 한 번 뒤집어 보기\n(분말 소리가 나야 정상)'),
        CheckItem('4. 소화기 계기판의 바늘이 초록색을 가리키면 정상, 초록색에서 바늘이 왼쪽방향이면 정상, 오른쪽 방향이면 비정상\n(* 범위를 조금 벗어난 것은 정상임)'),
        CheckItem('5. 정전기 청소포, 전자레인지 청소용 물티슈(청소박사), 바이오크린콜 재고 충분한지 확인'),
        CheckItem('6. 정수기 고장 여부 확인, 정수기 뒤 밸브에서 물 새거나 고여있는지 확인'),
      ]),
    ]),
    CheckLocation(10, '세탁실', [
      CheckSubject('전등, 콘센트, 소화기, 위생 상태, 세탁기', [
        CheckItem('1. 전등 껐다 켜보기'),
        CheckItem('2. 콘센트 속 먼지 여부/너무 많이 꽂혀있는지/누렇게 탄 자국, 접지(동그란 코드 내부 양쪽 쇠) 하나만 있거나 구부러졌는지 확인'),
        CheckItem('3. 소화기 한 번 뒤집어 보기\n(분말 소리가 나야 정상)'),
        CheckItem('4. 소화기 계기판의 바늘이 초록색을 가리키면 정상, 초록색에서 바늘이 왼쪽방향이면 정상, 오른쪽 방향이면 비정상\n(* 범위를 조금 벗어난 것은 정상임)'),
        CheckItem('5. 다리미 위와 세탁기 뒤 위생 상태'),
        CheckItem('6. 세탁기 고장 유무'),
      ]),
    ]),
    CheckLocation(11, '컴퓨터실', [
      CheckSubject('전등, 시계, 콘센트(4개), 소화기(1개)', [
        CheckItem('1. 전등 껐다 켜보기'),
        CheckItem('2. 시계 건전지 교체 여부 및 고장 확인'),
        CheckItem('3. 콘센트 속 먼지 여부/너무 많이 꽂혀있는지/누렇게 탄 자국, 접지(동그란 코드 내부 양쪽 쇠) 하나만 있거나 구부러졌는지 확인'),
        CheckItem('4. 소화기 한 번 뒤집어 보기\n(분말 소리가 나야 정상)'),
        CheckItem('5. 소화기 계기판의 바늘이 초록색을 가리키면 정상, 초록색에서 바늘이 왼쪽방향이면 정상, 오른쪽 방향이면 비정상\n(* 범위를 조금 벗어난 것은 정상임)'),
      ]),
    ]),
    CheckLocation(12, '독서실', [
      CheckSubject('전등, 시계, 콘센트(14개), 소화기(1개)', [
        CheckItem('1. 전등 껐다 켜보기'),
        CheckItem('2. 시계 건전지 교체 여부 및 고장 확인'),
        CheckItem('3. 콘센트 속 먼지 여부/너무 많이 꽂혀있는지/누렇게 탄 자국, 접지(동그란 코드 내부 양쪽 쇠) 하나만 있거나 구부러졌는지 확인'),
        CheckItem('4. 소화기 한 번 뒤집어 보기\n(분말 소리가 나야 정상)'),
        CheckItem('5. 소화기 계기판의 바늘이 초록색을 가리키면 정상, 초록색에서 바늘이 왼쪽방향이면 정상, 오른쪽 방향이면 비정상\n(* 범위를 조금 벗어난 것은 정상임)'),
      ]),
    ]),
  ],
);

// ══════════════════════════════════════════
// 국생 사생회
// ══════════════════════════════════════════
final kChecklistGuksaengSaenghoei = ChecklistTemplate(
  id: 'guksaeng_saenghoei',
  title: '관내점검표 (국생 사생회)',
  locations: [
    CheckLocation(1, '1층 휴게홀', [
      CheckSubject('콘센트\n정수기(1), 자판기(1)\n전화박스(2), TV(1)\n시계아래(1), 소화기옆(1)', [
        CheckItem('1. 전등껐다 켜보기'),
        CheckItem('2. 콘센트 속 : 먼지/너무 많이 꽂혀있는지/눕혀 탄 자국/접지(동그란 코드 내부 양쪽 식) 하나만 있거나 구부려졌는지 확인'),
        CheckItem('콘센트가 벽에 붙어있지 않은것은 이상아님'),
      ]),
      CheckSubject('제습기(1)', [
        CheckItem('1. 제습기 꺼져있으면 켜두기 (정상작동여부)\n물 조금이라도 있으면 비우기'),
      ]),
    ]),
    CheckLocation(2, '2층 휴게홀\nB동 3층 휴게실', [
      CheckSubject('콘센트\n창문밑(4), 정수기(1)\n테이블(2)', [
        CheckItem('1. 전등껐다 켜보기'),
        CheckItem('2. 콘센트 속 : 먼지/너무 많이 꽂혀있는지/눕혀 탄 자국/접지(동그란 코드 내부 양쪽 식) 하나만 있거나 구부려졌는지 확인'),
        CheckItem('콘센트가 벽에 붙어있지 않은것은 이상아님'),
      ]),
      CheckSubject('시계', [
        CheckItem('1. 시계 건전지 교체 여부(시간 안맞음) 및 고장 확인'),
      ]),
      CheckSubject('소파', [
        CheckItem('1. 소파상태 확인'),
      ]),
      CheckSubject('정수기(1), 창문밑(1)', [
        CheckItem('1. 정수기 고장여부 확인'),
      ]),
      CheckSubject('소화기 : 휴게홀 TV밑', [
        CheckItem('1. 소화기한번 뒤집어보기\n(분말소리가나야정상)'),
        CheckItem('2. 소화기 게기판의 바늘이 초록색을 가리키면 정상\n초록색에서 바늘이 왼쪽방향이면 정상, 오른쪽방향이면 비정상\n(* 조금 빗나간 것은 이상이 아님)'),
      ]),
    ]),
    CheckLocation(3, '운동실', [
      CheckSubject('전등, 시계(1)\n콘센트(20), 소화기(1)', [
        CheckItem('1. 시설점검\n- 런닝머신 1~9개 작동유무, 비상키 유무 확인\n- 그 외 운동기구(자전거, 볼트마사지기) 이상 유무 확인\n- 요가매트 돌돌말아서 제자리에 정리\n- 아홉 서랍장 잠겨이있는지 확인\n- 쓰레기통 1개가 유통기한 고정대 고정해 두다\n- 사람없는데 냉난방 작동 하고 있으면 끄기'),
        CheckItem('2. 전등 껐다 켜보기'),
        CheckItem('3. 시계 건전지 교체 여부(시간 안맞음) 및 고장 확인'),
      ]),
      CheckSubject('제습기(1)', [
        CheckItem('1. 제습기 꺼져있으면, 켜두기 (정상작동여부)\n물 조금이라도 있으면 비우기'),
      ]),
      CheckSubject('콘센트', [
        CheckItem('1. 콘센트 속 : 먼지/너무 많이 꽂혀있는지/눕혀 탄 자국/접지(동그란 코드 내부 양쪽 식) 하나만 있거나 구부려졌는지 확인'),
        CheckItem('콘센트가 벽에 붙어있지 않은것은 이상아님'),
      ]),
      CheckSubject('소화기', [
        CheckItem('1. 소화기한번 뒤집어보기(분말소리가나야정상)'),
        CheckItem('2. 소화기 게기판의 바늘이 초록색을 가리키면 정상\n초록색에서 바늘이 왼쪽방향이면 정상, 오른쪽방향이면 비정상\n(* 조금 빗나간 것은 이상이 아님)'),
      ]),
    ]),
  ],
);

// 템플릿 목록
final kChecklistTemplates = [
  kChecklistShalomB1,
  kChecklistShalomFloor,
  kChecklistGuksaengFloor,
  kChecklistGuksaengSaenghoei,
];

// 하위 호환용 (기존 코드에서 사용)
List<CheckLocation> get kChecklistData => kChecklistShalomB1.locations;
