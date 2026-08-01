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
    CheckLocation(3, '중앙 계단, 후게실표 비상 계단', [
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

final kChecklistShalomFloor = ChecklistTemplate(
  id: 'shalom_floor',
  title: '관내점검표 (샬롬 각층)',
  locations: [
    CheckLocation(1, '플로어북, 복도\n계단 중간 벽 하단에 위치', [
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
    CheckLocation(3, '중앙 계단, 후게실표 비상 계단', [
      CheckSubject('계단선서등', [
        CheckItem('1. 불이 켜지는지 확인(넓이는 작동이 안되는 경우도 있음)'),
      ]),
    ]),
    CheckLocation(4, '후게홀', [
      CheckSubject('엘리베이터홀\n콘센트(1), A동 아래(4), B동 아래(8)\n시계(1), 소화기(2)', [
        CheckItem('1. 전등 껐다 켜보기'),
        CheckItem('2. 시계 건전지 교체 여부 및 고장 확인'),
        CheckItem('3. 콘센트 속 먼지/서수 꽂혀있는지/접지 확인'),
        CheckItem('4. 소화기 한 번 뒤집어 보기 (쏴지는 소리가 나야 정상)'),
        CheckItem('5. 소화기 게이지판 바늘이 초록색을 가리키면 정상\n(왼쪽방향 정상, 오른쪽방향 비정상)'),
        CheckItem('6. 전기포트 "켜" 위치 확인, 작동 여부'),
        CheckItem('7. 샤프 상태 확인'),
        CheckItem('8. 정수기 고장 여부 확인, 뒤 밸브에서 물 새거나 고여있나 확인'),
        CheckItem('9. TV 및 리모컨 고장 여부 확인'),
      ]),
    ]),
    CheckLocation(5, '공동화장실', [
      CheckSubject('배수, 콘센트(1)', [
        CheckItem('1. 전등 껐다 켜보기'),
        CheckItem('2. 화장실 세면대 배수 확인'),
        CheckItem('3. 화장실 변기 물 내려보기'),
      ]),
    ]),
    CheckLocation(6, '복도', [
      CheckSubject('사무실쪽 복도\n콘센트(2), 소화기(2), 비상구유도등(1)', [
        CheckItem('1. 전장의 이름 확인 (복도 톡스 누수확인)'),
        CheckItem('2. 콘센트 속 먼지/서수 꽂혀있는지/접지 확인'),
        CheckItem('3. 소화기 한 번 뒤집어 보기 (쏴지는 소리가 나야 정상)'),
        CheckItem('4. 소화기 게이지판 바늘이 초록색을 가리키면 정상\n(왼쪽방향 정상, 오른쪽방향 비정상)'),
      ]),
      CheckSubject('화장실쪽 복도\n콘센트(2), 소화기(1), 비상구유도등(1)', [
        CheckItem('1. 전장의 이름 확인 (복도 톡스 누수확인)'),
        CheckItem('2. 콘센트 속 먼지/서수 꽂혀있는지/접지 확인'),
        CheckItem('3. 소화기 한 번 뒤집어 보기 (쏴지는 소리가 나야 정상)'),
        CheckItem('4. 소화기 게이지판 바늘이 초록색을 가리키면 정상\n(왼쪽방향 정상, 오른쪽방향 비정상)'),
      ]),
    ]),
    CheckLocation(7, '후게실', [
      CheckSubject('복도 끝 시계(1), 콘센트\n전자레인지(1), 소화기(1), 토스터기(1)', [
        CheckItem('1. 전등 켰다 꺼보기'),
        CheckItem('2. 시계 건전지 교체 여부 및 고장 확인'),
        CheckItem('3. 콘센트 속 먼지/서수 꽂혀있는지/접지 확인'),
        CheckItem('4. 소화기 한 번 뒤집어 보기 (쏴지는 소리가 나야 정상)'),
        CheckItem('5. 소화기 게이지판 바늘이 초록색을 가리키면 정상\n(왼쪽방향 정상, 오른쪽방향 비정상)'),
        CheckItem('6. 정전기 청소포, 전자레인지 청소용 물티슈 재고 충분한지 확인'),
        CheckItem('7. 토스터기 정상 작동, 내부 청소 확인'),
        CheckItem('8. 의자 상태 확인'),
      ]),
    ]),
  ],
);

final kChecklistGuksaengFloor = ChecklistTemplate(
  id: 'guksaeng_floor',
  title: '관내점검표 (국생 모든층)',
  locations: [
    CheckLocation(1, '각층 휴게실', [
      CheckSubject('전등, 시계, 전기포트\n프린트기(2개), 정수기', [
        CheckItem('1. 전등 켰다 꺼보기'),
        CheckItem('2. 시계 건전지 교체 여부 및 고장 확인'),
        CheckItem('3. 전기포트 "켜" 위치, 작동 여부'),
        CheckItem('4. 프린트기 2개 비치, 잠금 부품 확인'),
        CheckItem('5. 정수기 고장 여부 확인, 뒤 밸브 물 새는지 확인'),
      ]),
    ]),
    CheckLocation(2, '계단등간 벽 하단에 위치', [
      CheckSubject('통로·복도유도등', [
        CheckItem('1. 등이 어두운지 눈으로 확인(빨아야 함)\n*등그람 점검 스위치를 누르면 불이 꺼졌다 켜짐'),
        CheckItem('2. 초록색 램프가 항상 켜져 있어야 함'),
        CheckItem('3. 적색 램프는 들어와 있으면 안됨'),
      ]),
      CheckSubject('소화기', [
        CheckItem('1. 소화기 게이지판의 바늘이 초록색을 가리키면 정상\n(왼쪽방향 정상, 오른쪽방향 비정상)'),
      ]),
    ]),
    CheckLocation(3, '계단 출입구 상단\n각층 복도 끝 상단에 위치', [
      CheckSubject('비상구유도등', [
        CheckItem('1. 등이 어두운지 눈으로 확인(빨아야 함)'),
        CheckItem('2. 초록색 램프 항상 켜져 있어야 함'),
      ]),
    ]),
    CheckLocation(4, '공용계단, 휴게실표 비상계단', [
      CheckSubject('계단선서등', [
        CheckItem('1. 불이 켜지는지 확인(넓이는 작동이 안되는 경우도 있음)'),
      ]),
    ]),
    CheckLocation(5, '공동화장실', [
      CheckSubject('전등\n배수\n변기', [
        CheckItem('1. 전등 껐다 켜보기'),
        CheckItem('2. 화장실 세면대 배수 확인'),
        CheckItem('3. 화장실 변기 물 내려보기'),
      ]),
    ]),
    CheckLocation(6, '세면실', [
      CheckSubject('콘센트\n유리세면대(1)', [
        CheckItem('1. 콘센트 속 먼지/서수 꽂혀있는지/눕게 한 자국/접지 확인'),
        CheckItem('2. 콘센트가 벽에 붙어 있어야 함'),
        CheckItem('3. 세면대 배수가 잘 되는지 확인'),
      ]),
    ]),
    CheckLocation(7, '복도', [
      CheckSubject('전장\n소화기(4)', [
        CheckItem('1. 전장의 이름 확인 (복도 톡스 누수확인)'),
        CheckItem('2. 소화기 한 번 뒤집어 보기 (쏴지는 소리가 나야 정상)'),
        CheckItem('3. 소화기 게이지판의 바늘이 초록색을 가리키면 정상\n(왼쪽방향 정상, 오른쪽방향 비정상)'),
      ]),
    ]),
    CheckLocation(8, '쓰레기통', [
      CheckSubject('하층', [
        CheckItem('1. 악취가 나는지 확인'),
      ]),
    ]),
    CheckLocation(9, '조리실', [
      CheckSubject('콘센트, 토스터기\n정수기\n전자레인지', [
        CheckItem('1. 전등 껐다 켜보기'),
        CheckItem('2. 콘센트 속 먼지/서수 꽂혀있는지/눕게 한 자국/접지 확인'),
        CheckItem('3. 소화기 한 번 뒤집어 보기 (쏴지는 소리가 나야 정상)'),
        CheckItem('4. 소화기 게이지판의 바늘이 초록색을 가리키면 정상\n(왼쪽방향 정상, 오른쪽방향 비정상)'),
        CheckItem('5. 전자레인지 청소/전자레인지 청소용 물티슈 비치, 재고 충분한지 확인'),
        CheckItem('6. 토스터기 정상 작동, 토스터기 내부 청소'),
        CheckItem('7. 정수기 고장 여부 확인, 정수기 뒤 밸브 물 새거나 고여있나 확인'),
      ]),
    ]),
    CheckLocation(10, '세탁실', [
      CheckSubject('콘센트\n화장건조기(1), 다리미(1)\n세탁기(3)', [
        CheckItem('1. 콘센트 속 먼지/서수 꽂혀있는지/눕게 한 자국/접지 확인'),
        CheckItem('2. 콘센트가 벽에 안 붙어있으면 이상아님'),
        CheckItem('3. 소화기 한 번 뒤집어 보기 (쏴지는 소리가 나야 정상)'),
        CheckItem('4. 소화기 게이지판의 바늘이 초록색을 가리키면 정상\n(왼쪽방향 정상, 오른쪽방향 비정상)'),
      ]),
    ]),
  ],
);

final kChecklistGuksaengSaenghoei = ChecklistTemplate(
  id: 'guksaeng_saenghoei',
  title: '관내점검표 (국생 사생회)',
  locations: [
    CheckLocation(1, '1층 휴게홀', [
      CheckSubject('콘센트\n정수기(1), 자판기(1)\n전화박스(2), TV(1)', [
        CheckItem('1. 전등껐다 켜보기'),
        CheckItem('2. 콘센트 속 먼지/너무 많이 꽂혀있는지/눕혀 탄 자국/접지 확인'),
      ]),
      CheckSubject('제습기(1)', [
        CheckItem('1. 제습기 꺼져있으면 켜두기 (정상작동여부)\n물 조금이라도 있으면 비우기'),
      ]),
    ]),
    CheckLocation(2, '2층 휴게홀\nB동 3층 휴게실', [
      CheckSubject('콘센트\n창문밑(4), 정수기(1)\n테이블(2)', [
        CheckItem('1. 전등껐다 켜보기'),
        CheckItem('2. 콘센트 속 먼지/너무 많이 꽂혀있는지/눕혀 탄 자국/접지 확인'),
      ]),
      CheckSubject('시계', [
        CheckItem('1. 시계 건전지 교체 여부(시간 안맞음) 및 고장 확인'),
      ]),
      CheckSubject('소파', [
        CheckItem('1. 소파상태 확인'),
      ]),
      CheckSubject('정수기(1)', [
        CheckItem('1. 정수기 고장여부 확인'),
      ]),
      CheckSubject('소화기', [
        CheckItem('1. 소화기한번 뒤집어보기(분말소리가나야정상)'),
        CheckItem('2. 소화기 게이지판의 바늘이 초록색을 가리키면 정상\n(왼쪽방향 정상, 오른쪽방향 비정상)'),
      ]),
    ]),
    CheckLocation(3, '운동실', [
      CheckSubject('전등, 시계(1)\n콘센트(20), 소화기(1)', [
        CheckItem('1. 런닝머신 1~9개 작동유무, 비상키 유무 확인\n그 외 운동기구 이상 유무 확인'),
        CheckItem('2. 전등 껐다 켜보기'),
        CheckItem('3. 시계 건전지 교체 여부(시간 안맞음) 및 고장 확인'),
      ]),
      CheckSubject('제습기(1)', [
        CheckItem('1. 제습기 꺼져있으면 켜두기 (정상작동여부)\n물 조금이라도 있으면 비우기'),
      ]),
      CheckSubject('콘센트', [
        CheckItem('1. 콘센트 속 먼지/너무 많이 꽂혀있는지/눕혀 탄 자국/접지 확인'),
      ]),
      CheckSubject('소화기', [
        CheckItem('1. 소화기한번 뒤집어보기(분말소리가나야정상)'),
        CheckItem('2. 소화기 게이지판의 바늘이 초록색을 가리키면 정상\n(왼쪽방향 정상, 오른쪽방향 비정상)'),
      ]),
    ]),
  ],
);

final kChecklistTemplates = [
  kChecklistShalomB1,
  kChecklistShalomFloor,
  kChecklistGuksaengFloor,
  kChecklistGuksaengSaenghoei,
];
