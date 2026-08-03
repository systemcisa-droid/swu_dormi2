import 'package:fluent_ui/fluent_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:swu_dormi_admin/models/excel_student_row.dart';
import 'package:swu_dormi_admin/screens/windows/windows_cleaning_inspection_screen.dart';
import 'dart:io';

// ──────────────────────────────────────────────────────────────
// 호실별 청소점검 이력 탭
// ──────────────────────────────────────────────────────────────
class RoomInspectionHistoryContent extends StatefulWidget {
  final String? fixedType; // 'monthly', 'move_out', null=전체
  const RoomInspectionHistoryContent({super.key, this.fixedType});

  @override
  State<RoomInspectionHistoryContent> createState() =>
      _RoomInspectionHistoryContentState();
}

class _RoomInspectionHistoryContentState
    extends State<RoomInspectionHistoryContent> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, Map<String, dynamic>> _scheduleMap = {};
  bool _isLoading = true;

  // requestId -> inspectionType (scheduleMap 조인 결과 캐시)
  Map<String, String> _requestInspectionType = {};

  // roomNumber -> 해당 호실의 request 목록 (createdAt 역순)
  Map<String, List<QueryDocumentSnapshot>> _grouped = {};
  List<String> _sortedRooms = [];
  Map<String, String> _userFloorLabels = {}; // 호실별 정확한 층 정보
  // 그룹 키('건물|호실|uid') → {name, seatNumber} : 퇴사검사 대상 학생 정보
  Map<String, Map<String, String>> _personInfoByKey = {};
  // 거주 학생이 없어 인위적으로 추가한 호실 카드('건물|호실')
  Set<String> _vacantRoomKeys = {};
  // 호실 키('건물|호실') → 현재 거주 인원 수
  Map<String, int> _residentCountByRoom = {};

  String _searchQuery = '';
  String? _selectedRoom;
  String? _floorFilter;
  // 스케줄 필터 값: 'sid:신청' 또는 'sid:미신청'
  String? _scheduleFilter;

  // 퇴사검사 이력: 선택된 호실의 학생 목록 캐시 (roomKey → List<Map>)
  final Map<String, List<Map<String, dynamic>>> _roomStudentsCache = {};
  // 사생 기본 정보 엑셀 전체 명단 (미가입 학생 표시용)
  // null = 아직 미로드, 로드 시도 완료 후에는 항상 non-null (실패 시 빈 리스트)
  List<ExcelStudentRow>? _excelStudentRows;
  // fixedType이 있으면 탭 필터는 고정, 없으면 탭 UI로 변경 가능
  String? get _typeFilter => widget.fixedType ?? _typeFilterOverride;
  String? _typeFilterOverride;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 퇴사검사 모드에서는 _loadData가 엑셀 명단을 직접 await 하므로 여기서 중복 호출하지 않는다.
    // (그 외 모드는 _loadRoomStudents보다 먼저 끝나도록 가장 먼저 시작)
    if (widget.fixedType != 'move_out') _loadExcelStudentRows();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _errorMessage = '';

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      print('===== [호실별 이력] _loadData 시작 =====');

      // orderBy 없이 전체 로드 후 메모리 정렬 (인덱스 미생성 문제 회피)
      final requestsSnap = await _firestore
          .collection('cleaning_requests')
          .get();
      print('[호실별 이력] cleaning_requests 문서 수: ${requestsSnap.docs.length}');

      final schedulesSnap = await _firestore
          .collection('cleaning_schedules')
          .get();
      print('[호실별 이력] cleaning_schedules 문서 수: ${schedulesSnap.docs.length}');

      final usersSnap = await _firestore.collection('users').get();
      print('[호실별 이력] users 문서 수: ${usersSnap.docs.length}');

      // 퇴사검사 이력에서만 엑셀 명단(미가입 학생)을 카드로 추가한다.
      final excelRows = widget.fixedType == 'move_out'
          ? await _loadExcelStudentRows()
          : const <ExcelStudentRow>[];

      final Map<String, String> userFloorLabels = {};
      // uid → seatNumber : cleaning_requests 문서엔 자리번호가 저장되지 않으므로 users에서 조회
      final Map<String, String> userSeatNumbers = {};
      // uid → residentStatus : 퇴사검사 카드에 재실상태 배지를 표시하기 위함
      final Map<String, String> userResidentStatuses = {};
      // 퇴사검사 이력: 신청/검사 여부와 무관하게 등록된 학생 전체를 표시하기 위함
      final allStudentUsers = <QueryDocumentSnapshot>[];
      // 재실중인 학생이 있는 '건물|호실' 키 집합 (거주학생 없음 판정용)
      final occupiedRoomKeys = <String>{};
      final residentCountByRoom = <String, int>{};
      for (final doc in usersSnap.docs) {
        final data = doc.data();
        final seatNumber = data['seatNumber']?.toString();
        if (seatNumber != null && seatNumber.isNotEmpty) {
          userSeatNumbers[doc.id] = seatNumber;
        }
        final dormBuilding = data['dormBuilding']?.toString();
        final roomNumber = data['roomNumber']?.toString();
        final residentStatus = data['residentStatus']?.toString() ?? '재실중';
        if (data['role']?.toString() == 'student') {
          allStudentUsers.add(doc);
          userResidentStatuses[doc.id] = residentStatus;
        }
        if (dormBuilding == null || roomNumber == null || roomNumber.isEmpty)
          continue;

        if (residentStatus == '재실중') {
          final roomKey = '$dormBuilding|$roomNumber';
          occupiedRoomKeys.add(roomKey);
          residentCountByRoom[roomKey] = (residentCountByRoom[roomKey] ?? 0) + 1;
        }

        final String floorNum;
        if (roomNumber.length == 3)
          floorNum = roomNumber[0];
        else if (roomNumber.length >= 4)
          floorNum = roomNumber.substring(0, 2);
        else
          continue;

        if (dormBuilding == '바롬인성교육관') {
          userFloorLabels['$dormBuilding|$roomNumber'] =
              '$dormBuilding ${floorNum}층';
        } else {
          final roomNum = int.tryParse(roomNumber) ?? 0;
          final wing = _computeBuilding(dormBuilding, roomNum);
          if (wing != null) {
            userFloorLabels['$dormBuilding|$roomNumber'] =
                '$dormBuilding $wing ${floorNum}층';
          } else if (dormBuilding == '샬롬하우스(겨울방학)') {
            userFloorLabels['$dormBuilding|$roomNumber'] =
                '$dormBuilding A동 ${floorNum}층';
          }
        }
      }
      print('[호실별 이력] userFloorLabels 수: ${userFloorLabels.length}');

      final scheduleMap = <String, Map<String, dynamic>>{};
      for (final doc in schedulesSnap.docs) {
        scheduleMap[doc.id] = doc.data();
      }

      final grouped = <String, List<QueryDocumentSnapshot>>{};
      final personInfoByKey = <String, Map<String, String>>{};
      final moveOutKeysByUid = <String, String>{};
      for (final req in requestsSnap.docs) {
        final data = req.data();
        final room = data['roomNumber']?.toString() ?? '';
        if (room.isEmpty) {
          print(
            '[호실별 이력] ⚠️ roomNumber 비어있는 문서: ${req.id}, data keys: ${data.keys.toList()}',
          );
          continue;
        }
        // 건물 정보 결정: request의 dormBuilding → schedule의 floor → null
        final sid = data['scheduleId']?.toString();
        String? dorm = data['dormBuilding']?.toString();
        if (dorm == null || dorm.isEmpty) {
          dorm = null;
          if (sid != null) {
            final floor = scheduleMap[sid]?['floor']?.toString() ?? '';
            dorm = _buildingFromFloor(floor);
          }
        }
        // 이 요청의 검사유형 판별: 스케줄 우선, 없으면 request 자체 필드
        String? reqType;
        if (sid != null) reqType = scheduleMap[sid]?['inspectionType'] as String?;
        reqType ??= data['inspectionType'] as String?;

        final String groupKey;
        if (reqType == 'move_out') {
          // 퇴사검사 이력: 사람(학생) 기준으로 그룹핑
          final uid = data['userId']?.toString() ?? '';
          groupKey = dorm != null ? '$dorm|$room|$uid' : '|$room|$uid';
          if (uid.isNotEmpty) moveOutKeysByUid[uid] = groupKey;
          personInfoByKey[groupKey] = {
            'name': data['userName']?.toString() ?? '',
            'seatNumber':
                userSeatNumbers[uid] ?? data['seatNumber']?.toString() ?? '',
            'residentStatus': userResidentStatuses[uid] ?? '재실중',
          };
        } else {
          // 월검사 이력: 호실 기준으로 그룹핑 (기존 동작 유지)
          groupKey = dorm != null ? '$dorm|$room' : room;
        }
        grouped.putIfAbsent(groupKey, () => []).add(req);
      }

      // 등록된 학생 전체 중 아직 퇴사검사 이력이 없는 학생도 빈 카드로 추가
      for (final userDoc in allStudentUsers) {
        final uid = userDoc.id;
        if (moveOutKeysByUid.containsKey(uid)) continue;
        final data = userDoc.data() as Map<String, dynamic>;
        final room = data['roomNumber']?.toString() ?? '';
        if (room.isEmpty) continue;
        final dorm = data['dormBuilding']?.toString();
        final groupKey = dorm != null ? '$dorm|$room|$uid' : '|$room|$uid';
        grouped.putIfAbsent(groupKey, () => []);
        personInfoByKey[groupKey] = {
          'name': data['name']?.toString() ?? '',
          'seatNumber': userSeatNumbers[uid] ?? '',
          'residentStatus': userResidentStatuses[uid] ?? '재실중',
        };
      }

      // 퇴사검사 이력: 엑셀 명단에만 있고 아직 앱에 가입하지 않은 학생도 빈 카드로 추가.
      // 가입 여부 판단은 이메일만 기준으로 한다(학번은 기준으로 쓰지 않는다).
      if (excelRows.isNotEmpty) {
        final registeredEmails = usersSnap.docs
            .map((d) => (d.data()['email']?.toString() ?? '').trim().toLowerCase())
            .where((v) => v.isNotEmpty)
            .toSet();

        for (final row in excelRows) {
          if (!row.hasMatchKey) continue;
          final rowEmail = row.normalizedEmail;
          if (rowEmail != null && registeredEmails.contains(rowEmail)) continue;
          final room = _normalize(row.roomNumber);
          if (room.isEmpty) continue;
          final dorm = _normalize(row.dormBuilding);
          final excelId = rowEmail ?? _normalize(row.studentId);
          if (excelId.isEmpty) continue;
          final groupKey = dorm.isNotEmpty
              ? '$dorm|$room|excel:$excelId'
              : '|$room|excel:$excelId';
          grouped.putIfAbsent(groupKey, () => []);
          personInfoByKey[groupKey] = {
            'name': row.name ?? '',
            'seatNumber': _normalize(row.seatNumber),
            'residentStatus': '재실중',
            'isUnregistered': 'true',
          };
        }
      }

      // 월검사 이력: 재실 학생이 있는 호실 전체를 빈 카드로 추가 (신청/검사 여부 무관)
      for (final roomKey in userFloorLabels.keys) {
        grouped.putIfAbsent(roomKey, () => []);
      }

      // 샬롬하우스/국제생활관: 거주 학생이 없는 호실도 빈 카드로 추가 ('거주학생 없음' 표시용)
      final vacantRoomKeys = <String>{};
      for (final floor in kFloorOptions) {
        final dorm = _buildingFromFloor(floor);
        if (dorm != '샬롬하우스' && dorm != '국제생활관' && dorm != '샬롬하우스(겨울방학)') continue;
        final wing = floor.contains('A동')
            ? 'A동'
            : floor.contains('B동')
            ? 'B동'
            : null;
        if (wing == null) continue;
        final floorNumMatch = RegExp(r'(\d+)층').firstMatch(floor);
        if (floorNumMatch == null) continue;
        final floorNum = int.parse(floorNumMatch.group(1)!);

        final List<int> roomNumbers;
        if (dorm == '국제생활관') {
          if (wing == 'A동' && floorNum == 1)
            roomNumbers = [for (var i = 101; i <= 132; i++) i];
          else if (wing == 'A동' && floorNum == 2)
            roomNumbers = [for (var i = 201; i <= 229; i++) i];
          else if (wing == 'B동' && floorNum == 2)
            roomNumbers = [for (var i = 233; i <= 260; i++) i];
          else if (wing == 'B동' && floorNum == 3)
            roomNumbers = [for (var i = 301; i <= 329; i++) i];
          else
            roomNumbers = [];
        } else if (dorm == '샬롬하우스(겨울방학)') {
          // A동만 존재: 201~220, 301~320, 401~420
          final base = floorNum * 100;
          roomNumbers = [for (var i = base + 1; i <= base + 20; i++) i];
        } else {
          final base = floorNum * 100;
          roomNumbers = wing == 'A동'
              ? [for (var i = base + 1; i <= base + 20; i++) i]
              : [for (var i = base + 21; i <= base + 35; i++) i];
        }

        for (final roomNum in roomNumbers) {
          final roomKey = '$dorm|$roomNum';
          if (!grouped.containsKey(roomKey)) {
            grouped[roomKey] = [];
            userFloorLabels.putIfAbsent(roomKey, () => floor);
          }
          // 재실중인 학생이 없는 호실은 이력 존재 여부와 무관하게 '거주학생 없음'으로 표시
          if (!occupiedRoomKeys.contains(roomKey)) {
            vacantRoomKeys.add(roomKey);
          }
        }
      }

      // 바롬인성교육관 10층: 1001-A~C, 1002-A~C, 1003-A~C 9개 호실
      const barumRooms = [
        '1001-A', '1001-B', '1001-C',
        '1002-A', '1002-B', '1002-C',
        '1003-A', '1003-B', '1003-C',
      ];
      for (final roomStr in barumRooms) {
        final roomKey = '바롬인성교육관|$roomStr';
        if (!grouped.containsKey(roomKey)) {
          grouped[roomKey] = [];
          userFloorLabels.putIfAbsent(roomKey, () => '바롬인성교육관 10층');
        }
        if (!occupiedRoomKeys.contains(roomKey)) {
          vacantRoomKeys.add(roomKey);
        }
      }
      print(
        '[호실별 이력] grouped 호실 수: ${grouped.length}, 호실 목록: ${grouped.keys.toList()}',
      );

      // 각 호실의 이력을 createdAt 역순 정렬
      for (final list in grouped.values) {
        list.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTs = aData['createdAt'] as Timestamp?;
          final bTs = bData['createdAt'] as Timestamp?;
          if (aTs == null && bTs == null) return 0;
          if (aTs == null) return 1;
          if (bTs == null) return -1;
          return bTs.compareTo(aTs);
        });
      }

      int buildingOrder(String key) {
        if (key.startsWith('샬롬하우스(겨울방학)')) return 3;
        if (key.startsWith('샬롬하우스')) return 0;
        if (key.startsWith('국제생활관')) return 1;
        if (key.startsWith('바롬인성교육관')) return 2;
        return 4;
      }

      final sortedRooms = grouped.keys.toList()
        ..sort((a, b) {
          final bo = buildingOrder(a).compareTo(buildingOrder(b));
          if (bo != 0) return bo;
          final numA = int.tryParse(_keyRoom(a)) ?? 0;
          final numB = int.tryParse(_keyRoom(b)) ?? 0;
          if (numA != 0 && numB != 0) return numA.compareTo(numB);
          return a.compareTo(b);
        });

      print('[호실별 이력] sortedRooms: $sortedRooms');
      print('===== [호실별 이력] _loadData 완료 =====');

      // requestId → inspectionType 조인 캐시 구성
      // 스케줄의 inspectionType을 우선 사용(원본 데이터), request 자체 필드는 스케줄 조회 실패 시에만 fallback
      final requestInspectionType = <String, String>{};
      for (final req in requestsSnap.docs) {
        final d = req.data();
        final sid = d['scheduleId'] as String?;
        String? t;
        if (sid != null) {
          t = scheduleMap[sid]?['inspectionType'] as String?;
        }
        t ??= d['inspectionType'] as String?;
        if (t != null) requestInspectionType[req.id] = t;
      }

      if (mounted) {
        setState(() {
          _scheduleMap = scheduleMap;
          _grouped = grouped;
          _sortedRooms = sortedRooms;
          _userFloorLabels = userFloorLabels;
          _requestInspectionType = requestInspectionType;
          _personInfoByKey = personInfoByKey;
          _vacantRoomKeys = vacantRoomKeys;
          _residentCountByRoom = residentCountByRoom;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      print('===== [호실별 이력] _loadData 에러 =====');
      print('에러: $e');
      print('스택: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  // 현재 화면(월검사/퇴사검사)에 표시된 이력 전체를 엑셀로 저장한다.
  Future<void> _exportHistoryToExcel() async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ContentDialog(
        title: Text('엑셀 생성 중'),
        content: SizedBox(height: 80, child: Center(child: ProgressRing())),
      ),
    );

    try {
      final excel = Excel.createExcel();
      final isMoveOutTab = widget.fixedType == 'move_out';
      final sheet = excel[isMoveOutTab ? '퇴사검사이력' : '월검사이력'];

      final headers = [
        '건물',
        '구역',
        '호실',
        '이름',
        '자리번호',
        '점검일',
        '상태',
        if (!isMoveOutTab) '평균점수',
        if (isMoveOutTab) '재검사필요',
        '층장의견',
        '평가자',
      ];
      for (int c = 0; c < headers.length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0)).value =
            TextCellValue(headers[c]);
      }

      int rowIdx = 1;
      for (final key in _sortedRooms) {
        final requests = _grouped[key] ?? [];
        if (requests.isEmpty) continue;
        final roomNumber = _keyRoom(key);
        final buildingLabel = _keyBuilding(key) ?? '';
        final personUid = _keyUserId(key);
        final personInfo = personUid != null ? _personInfoByKey[key] : null;
        final floorLabel = _getRoomFloorOption(key) ?? '';

        for (final req in requests) {
          final data = req.data() as Map<String, dynamic>;
          final reqType = _requestInspectionType[req.id] ?? 'monthly';
          if (isMoveOutTab && reqType != 'move_out') continue;
          if (!isMoveOutTab && reqType != 'monthly') continue;

          final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
          final scoreAvg = (data['scoreAvg'] as num?)?.toDouble();
          final needsRecheck = data['needsRecheck'] == true;
          final comment = (data['inspectionComment'] as String?) ?? '';
          final evaluatedByEmail = (data['evaluatedByEmail'] as String?) ?? '';
          final name = personInfo?['name'] ?? (data['userName'] as String? ?? '');
          final seatNumber = personInfo?['seatNumber'] ?? '';

          final values = [
            buildingLabel,
            floorLabel,
            roomNumber,
            name,
            seatNumber,
            createdAt != null ? DateFormat('yyyy.MM.dd').format(createdAt) : '',
            _statusLabel((data['status'] as String?) ?? 'pending'),
            if (!isMoveOutTab) (scoreAvg != null ? scoreAvg.toStringAsFixed(1) : ''),
            if (isMoveOutTab) (needsRecheck ? 'Y' : 'N'),
            comment,
            evaluatedByEmail,
          ];
          for (int c = 0; c < values.length; c++) {
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIdx)).value =
                TextCellValue(values[c]);
          }
          rowIdx++;
        }
      }

      if (excel.sheets.containsKey('Sheet1')) excel.delete('Sheet1');

      final bytes = excel.encode();
      if (bytes == null) throw Exception('엑셀 파일 생성 실패');

      if (!mounted) return;
      Navigator.pop(context);

      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: isMoveOutTab ? '퇴사검사 이력 저장' : '월검사 이력 저장',
        fileName:
            '${isMoveOutTab ? '퇴사검사이력' : '월검사이력'}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );
      if (savePath == null) return;
      await File(savePath).writeAsBytes(bytes);

      if (!mounted) return;
      await displayInfoBar(
        context,
        builder: (c, close) => InfoBar(
          title: Text('저장 완료: $savePath'),
          severity: InfoBarSeverity.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      await displayInfoBar(
        context,
        builder: (c, close) => InfoBar(
          title: Text('오류: $e'),
          severity: InfoBarSeverity.error,
        ),
      );
    }
  }

  List<String> get _filteredRooms {
    print(
      '[호실별 이력] _filteredRooms 호출됨: _sortedRooms.length=${_sortedRooms.length}, _searchQuery="$_searchQuery", _floorFilter=$_floorFilter, _typeFilter=$_typeFilter',
    );
    final result = _sortedRooms.where((r) {
      if (_searchQuery.isNotEmpty && !_keyRoom(r).contains(_searchQuery.trim()))
        return false;
      if (_floorFilter != null) {
        final roomFloor = _getRoomFloorOption(r);
        if (roomFloor == null) return false;
        if (roomFloor != _floorFilter) return false;
      }
      if (_typeFilter != null) {
        final requests = _grouped[r] ?? [];
        if (requests.isEmpty) {
          // 이력이 없는(미신청) 카드: 그룹 키가 사람 기준(3파트)이면 move_out 전용,
          // 호실 기준(2파트)이면 monthly 전용으로 취급
          final isPersonKey = _keyUserId(r) != null;
          final impliedType = isPersonKey ? 'move_out' : 'monthly';
          if (impliedType != _typeFilter) return false;
        } else {
          final isPersonKey = _keyUserId(r) != null;
          final fallbackType = isPersonKey ? 'move_out' : 'monthly';
          final hasType = requests.any((req) {
            final t = _requestInspectionType[req.id] ?? fallbackType;
            return t == _typeFilter;
          });
          if (!hasType) return false;
        }
      }
      // 신청 스케줄 필터: 'sid:신청' 또는 '__unapplied__'(전체 미신청)
      if (_scheduleFilter != null) {
        if (_scheduleFilter == '__unapplied__') {
          // 현재 유형(월검사/퇴사검사)의 어떤 스케줄에도 신청 이력이 없는 학생만 표시
          final requests = _grouped[r] ?? [];
          final scheduleType = _typeFilter ?? 'monthly';
          final hasAnySchedule = requests.any((req) {
            final data = req.data() as Map<String, dynamic>;
            final sid = data['scheduleId']?.toString();
            return sid != null && _scheduleMap[sid]?['inspectionType'] == scheduleType;
          });
          if (hasAnySchedule) return false;
        } else {
          final parts = _scheduleFilter!.split(':');
          if (parts.length == 2) {
            final sid = parts[0];
            final requests = _grouped[r] ?? [];
            final hasSchedule = requests.any((req) {
              final data = req.data() as Map<String, dynamic>;
              return data['scheduleId'] == sid;
            });
            if (!hasSchedule) return false;
          }
        }
      }
      return true;
    }).toList();
    print('[호실별 이력] _filteredRooms 결과: ${result.length}개, $result');
    return result;
  }

  // 그룹 키('건물|호실' 또는 '호실')에서 점검 구역 문자열 반환
  String? _getRoomFloorOption(String key) {
    final requests = _grouped[key] ?? [];
    for (final req in requests) {
      final data = req.data() as Map<String, dynamic>;
      final scheduleId = data['scheduleId'] as String?;
      if (scheduleId != null) {
        final floor = _scheduleMap[scheduleId]?['floor'] as String?;
        if (floor != null && floor.isNotEmpty) return floor;
      }
    }
    // DB의 users 컬렉션 정보로 층 추론
    if (_userFloorLabels.containsKey(key)) {
      return _userFloorLabels[key];
    }
    // 사람 기준(3파트) 키는 '건물|호실' 형태로 변환해서 재조회
    final building = _keyBuilding(key);
    final room = _keyRoom(key);
    final roomKey = building != null ? '$building|$room' : room;
    if (roomKey != key && _userFloorLabels.containsKey(roomKey)) {
      return _userFloorLabels[roomKey];
    }
    // 최종 폴백: users 데이터의 roomNumber 표기가 미세하게 달라(공백, 0패딩 등)
    // userFloorLabels에서 조회되지 않는 경우, 건물명+호실번호로 직접 층을 계산한다.
    return _computeFloorOptionFromRoom(building, room);
  }

  // 건물명 + 호실번호로부터 kFloorOptions 표기의 층 라벨을 직접 계산한다.
  String? _computeFloorOptionFromRoom(String? building, String room) {
    if (building == null) return null;
    final roomNum = int.tryParse(room.trim());
    if (roomNum == null) return null;

    if (building == '바롬인성교육관') return '바롬인성교육관 10층';

    if (building == '국제생활관') {
      final wing = _computeBuilding(building, roomNum);
      if (wing == null) return null;
      final floorNum = roomNum ~/ 100;
      return '국제생활관 $wing ${floorNum}층';
    }

    if (building == '샬롬하우스(겨울방학)') {
      final floorNum = roomNum ~/ 100;
      return '샬롬하우스(겨울방학) A동 ${floorNum}층';
    }

    if (building == '샬롬하우스') {
      final wing = _computeBuilding(building, roomNum);
      if (wing == null) return null;
      final floorNum = roomNum ~/ 100;
      return '샬롬하우스 $wing ${floorNum}층';
    }

    return null;
  }

  // 그룹 키에서 호실 번호 추출
  // 사람 기준(퇴사검사): '샬롬하우스|202|uid' → '202' / 호실 기준(월검사): '샬롬하우스|202' → '202', '202' → '202'
  static String _keyRoom(String key) {
    final parts = key.split('|');
    if (parts.length >= 3) return parts[1];
    return parts.length == 2 ? parts[1] : key;
  }

  // 그룹 키에서 건물명 추출 ('샬롬하우스|202' → '샬롬하우스', '샬롬하우스|202|uid' → '샬롬하우스', '202' → null)
  static String? _keyBuilding(String key) {
    final parts = key.split('|');
    if (parts.length < 2) return null;
    return parts.first.isEmpty ? null : parts.first;
  }

  // 그룹 키에서 userId 추출 (사람 기준일 때만 존재): '샬롬하우스|202|uid' → 'uid'
  static String? _keyUserId(String key) {
    final parts = key.split('|');
    return parts.length >= 3 ? parts[2] : null;
  }

  // dormBuilding + 호실번호에서 동(A동/B동) 계산
  // 국제생활관: 101~132, 201~229=A동 / 233~260, 301~329=B동
  // 샬롬하우스: 마지막 두자리 01~20=A동, 21~35=B동
  static String? _computeBuilding(String dormBuilding, int roomNum) {
    if (dormBuilding == '국제생활관') {
      if ((roomNum >= 101 && roomNum <= 132) ||
          (roomNum >= 201 && roomNum <= 229))
        return 'A동';
      if ((roomNum >= 233 && roomNum <= 260) ||
          (roomNum >= 301 && roomNum <= 329))
        return 'B동';
      return null;
    }
    if (dormBuilding == '샬롬하우스(겨울방학)') return 'A동'; // 201~220, 301~320, 401~420 모두 A동
    // 샬롬하우스
    final lastTwo = roomNum % 100;
    if (lastTwo >= 1 && lastTwo <= 20) return 'A동';
    if (lastTwo >= 21 && lastTwo <= 35) return 'B동';
    return null;
  }

  // floor 문자열에서 건물명 추출
  static String? _buildingFromFloor(String? floor) {
    if (floor == null || floor.isEmpty) return null;
    if (floor.startsWith('샬롬하우스(겨울방학)')) return '샬롬하우스(겨울방학)';
    if (floor.startsWith('샬롬하우스')) return '샬롬하우스';
    if (floor.startsWith('국제생활관')) return '국제생활관';
    if (floor.startsWith('바롬인성교육관')) return '바롬인성교육관';
    return null;
  }

  // 사생 기본 정보 엑셀 전체 명단을 한 번만 로드해서 캐싱한다.
  // 미가입 학생 표시용 부가 기능이므로 실패해도 조용히 빈 리스트로 처리한다.
  Future<List<ExcelStudentRow>> _loadExcelStudentRows() async {
    try {
      final settingsDoc = await _firestore
          .collection('settings')
          .doc('home')
          .get();
      final excelUrl = settingsDoc.data()?['studentInfoExcelUrl'] as String?;
      if (excelUrl == null || excelUrl.trim().isEmpty) {
        return _applyExcelStudentRows([]);
      }

      final response = await http.get(Uri.parse(excelUrl));
      if (response.statusCode != 200) {
        return _applyExcelStudentRows([]);
      }
      final excel = Excel.decodeBytes(response.bodyBytes);
      final sheet = excel.sheets.values.first;
      final rows = sheet.rows
          .map((row) => row.map((cell) => cell?.value?.toString() ?? '').toList())
          .toList();
      if (rows.isEmpty) {
        return _applyExcelStudentRows([]);
      }

      final header = rows.first;
      return _applyExcelStudentRows(
        rows.skip(1).map((row) => ExcelStudentRow.fromRow(header, row)).toList(),
      );
    } catch (_) {
      return _applyExcelStudentRows([]);
    }
  }

  // 엑셀 로드 결과 반영. 엑셀 로드 전에 만들어진 호실 캐시는 미가입자가 빠져
  // 있으므로 비우고, 현재 선택된 호실만 다시 로드한다.
  List<ExcelStudentRow> _applyExcelStudentRows(List<ExcelStudentRow> rows) {
    if (!mounted) return rows;
    final hadCache = _roomStudentsCache.isNotEmpty;
    setState(() {
      _excelStudentRows = rows;
      if (hadCache) _roomStudentsCache.clear();
    });
    final selected = _selectedRoom;
    if (hadCache && selected != null) _loadRoomStudents(selected);
    return rows;
  }

  // 엑셀 값 정규화 (공백 제거)
  static String _normalize(String? v) => (v ?? '').trim();

  Future<void> _loadRoomStudents(String roomKey) async {
    if (_roomStudentsCache.containsKey(roomKey)) return;
    final roomNumber = _keyRoom(roomKey);
    final building = _keyBuilding(roomKey);
    try {
      var query = _firestore
          .collection('users')
          .where('roomNumber', isEqualTo: roomNumber)
          .where('role', isEqualTo: 'student');
      if (building != null) {
        query = query.where('dormBuilding', isEqualTo: building);
      }
      final snap = await query.get();
      // 재실중인 학생만 표시 (퇴사/바롬인성교육관 상태는 제외)
      final students = snap.docs
          .map((d) => d.data())
          .where((data) {
            final status = data['residentStatus']?.toString() ?? '재실중';
            return status == '재실중';
          })
          .toList();

      // 엑셀 명단에는 있으나 아직 앱에 가입하지 않은 학생을 덧붙인다.
      // 가입 여부 판단 기준은 이메일뿐이다(학번은 기준으로 쓰지 않는다).
      final excelRows = _excelStudentRows;
      if (excelRows != null && excelRows.isNotEmpty) {
        final registeredEmails = students
            .map((s) => _normalize(s['email']?.toString()).toLowerCase())
            .where((v) => v.isNotEmpty)
            .toSet();

        for (final row in excelRows) {
          if (!row.hasMatchKey) continue;
          if (_normalize(row.roomNumber) != roomNumber) continue;
          // 엑셀에 기숙사 정보가 있고 호실 키에도 건물이 있으면 함께 대조한다.
          final rowBuilding = _normalize(row.dormBuilding);
          if (building != null &&
              rowBuilding.isNotEmpty &&
              rowBuilding != building) {
            continue;
          }
          final rowEmail = row.normalizedEmail;
          if (rowEmail != null && registeredEmails.contains(rowEmail)) continue;

          students.add({
            'name': row.name ?? '',
            'studentId': _normalize(row.studentId),
            'seatNumber': _normalize(row.seatNumber),
            'isUnregistered': true,
          });
        }
      }

      if (mounted) setState(() => _roomStudentsCache[roomKey] = students);
    } catch (_) {}
  }

  // 점검 구역 문자열 → 건물 색상

  List<QueryDocumentSnapshot> get _selectedRoomRequests {
    if (_selectedRoom == null) return [];
    return _grouped[_selectedRoom!] ?? [];
  }

  // ──────────── status 헬퍼 ────────────
  static String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return '점검 대기중';
      case 'in_progress':
        return '점검중';
      case 'completed':
        return '완료';
      case 'rejected':
        return '반려됨';
      default:
        return '알 수 없음';
    }
  }

  Widget _buildTypeTab(String? value, String label) {
    final isSelected = _typeFilter == value;
    final Color color = value == 'move_out'
        ? Colors.orange
        : value == 'monthly'
        ? Colors.teal
        : Colors.blue;
    return GestureDetector(
      onTap: () => setState(() {
        _typeFilterOverride = value;
        _selectedRoom = null;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? color : Colors.grey.withValues(alpha: 0.3),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? color : null,
          ),
        ),
      ),
    );
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFF87CEEB);
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    print(
      '[호실별 이력] build() 호출됨: _isLoading=$_isLoading, _errorMessage="$_errorMessage", _sortedRooms.length=${_sortedRooms.length}',
    );
    if (_isLoading) {
      return const Center(child: ProgressRing());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(FluentIcons.error, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            const Text(
              '데이터를 불러오는 중 오류가 발생했습니다',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              style: TextStyle(fontSize: 12, color: Colors.grey[100]),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _loadData, child: const Text('다시 시도')),
          ],
        ),
      );
    }

    return Row(
      children: [
        // 왼쪽 패널 (flex 2)
        Expanded(
          flex: 2,
          child: Container(
            decoration: BoxDecoration(
              color: FluentTheme.of(context).micaBackgroundColor,
              border: Border(
                right: BorderSide(
                  color: FluentTheme.of(
                    context,
                  ).resources.dividerStrokeColorDefault,
                ),
              ),
            ),
            child: Column(
              children: [
                _buildLeftHeader(),
                _buildSearchBox(),
                _buildFilterRow(),
                Expanded(child: _buildRoomList()),
              ],
            ),
          ),
        ),
        // 오른쪽 패널 (flex 3)
        Expanded(flex: 3, child: _buildDetailPanel()),
      ],
    );
  }

  // ──────────── 왼쪽 헤더 ────────────
  Widget _buildLeftHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FluentTheme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(
            color: FluentTheme.of(context).resources.dividerStrokeColorDefault,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            widget.fixedType == 'move_out'
                ? '퇴사검사이력'
                : widget.fixedType == 'monthly'
                ? '월검사이력'
                : '호실별 이력',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          Button(
            onPressed: _exportHistoryToExcel,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(FluentIcons.excel_document, size: 13),
                const SizedBox(width: 6),
                const Text('엑셀 다운로드', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ──────────── 검색창 ────────────
  Widget _buildSearchBox() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: TextBox(
        controller: _searchController,
        placeholder: '호실 번호 검색',
        prefix: const Padding(
          padding: EdgeInsets.only(left: 8),
          child: Icon(FluentIcons.search, size: 14),
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  // 현재 필터(fixedType 또는 탭 선택)가 퇴사검사인지 여부
  // 현재 유형(월검사/퇴사검사)의 스케줄 목록 (scheduleId -> 표시 라벨), 날짜 내림차순
  List<MapEntry<String, String>> get _scheduleFilterOptions {
    final scheduleType = _typeFilter ?? 'monthly';
    final entries = <({String id, String label, DateTime? date})>[];
    _scheduleMap.forEach((id, data) {
      if (data['inspectionType'] != scheduleType) return;
      final ts = data['date'] as Timestamp?;
      final floor = data['floor']?.toString() ?? '';
      final dateLabel = ts != null
          ? DateFormat('yyyy.MM.dd').format(ts.toDate())
          : '날짜 미상';
      entries.add((id: id, label: '$dateLabel $floor', date: ts?.toDate()));
    });
    entries.sort((a, b) {
      if (a.date == null && b.date == null) return 0;
      if (a.date == null) return 1;
      if (b.date == null) return -1;
      return b.date!.compareTo(a.date!);
    });
    final result = <MapEntry<String, String>>[
      for (final e in entries) MapEntry('${e.id}:신청', '${e.label} 신청'),
      const MapEntry('__unapplied__', '미신청'),
    ];
    return result;
  }

  // ──────────── 점검 구역 필터 ────────────
  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Column(
        children: [
          Row(
            children: [
              // 검사 유형 탭 (fixedType이 있으면 숨김)
              if (widget.fixedType == null) ...[
                _buildTypeTab(null, '전체'),
                const SizedBox(width: 4),
                _buildTypeTab('monthly', '월검사'),
                const SizedBox(width: 4),
                _buildTypeTab('move_out', '퇴사검사'),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: ComboBox<String>(
                  value: _floorFilter ?? '전체',
                  isExpanded: true,
                  placeholder: const Text('구역 필터'),
                  items: [
                    const ComboBoxItem(value: '전체', child: Text('전체 구역')),
                    for (final floor in kFloorOptions)
                      ComboBoxItem(
                        value: floor,
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: buildingColor(floor),
                                shape: BoxShape.circle,
                              ),
                            ),
                            Text(floor, style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _floorFilter = v == '전체' ? null : v;
                      _selectedRoom = null;
                    });
                  },
                ),
              ),
            ],
          ),
          if (_typeFilter != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ComboBox<String>(
                    value: _scheduleFilter ?? '전체',
                    isExpanded: true,
                    placeholder: const Text('신청 스케줄 필터'),
                    items: [
                      const ComboBoxItem(value: '전체', child: Text('전체')),
                      for (final entry in _scheduleFilterOptions)
                        ComboBoxItem(value: entry.key, child: Text(entry.value)),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _scheduleFilter = v == '전체' ? null : v;
                        _selectedRoom = null;
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ──────────── 호실 목록 ────────────
  Widget _buildRoomList() {
    final rooms = _filteredRooms;
    print('[호실별 이력] _buildRoomList: rooms.length=${rooms.length}');

    if (rooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(FluentIcons.history, size: 48, color: Colors.grey[60]),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isEmpty ? '이력이 없습니다' : '검색 결과가 없습니다',
              style: const TextStyle(fontSize: 15),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      itemCount: rooms.length,
      itemBuilder: (context, index) {
        final room = rooms[index];
        try {
          print('[호실별 이력] _buildRoomCard 시작: $room');
          final widget = _buildRoomCard(room);
          print('[호실별 이력] _buildRoomCard 성공: $room');
          return widget;
        } catch (e, st) {
          print('[호실별 이력] ⚠️ _buildRoomCard 에러: $e');
          print('[호실별 이력] 스택: $st');
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.red),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$room호 렌더링 에러: $e',
              style: TextStyle(color: Colors.red),
            ),
          );
        }
      },
    );
  }

  Widget _buildRoomCard(String key) {
    final roomNumber = _keyRoom(key);
    final buildingLabel = _keyBuilding(key);
    final personUid = _keyUserId(key);
    final isVacant = _vacantRoomKeys.contains(key);
    final residentStatus = _personInfoByKey[key]?['residentStatus'];
    // 엑셀 명단에만 있는 미가입 학생 카드 (uid가 없으므로 대리신청 불가)
    final isUnregisteredStudent =
        _personInfoByKey[key]?['isUnregistered'] == 'true';
    var requests = _grouped[key] ?? [];
    if (_typeFilter != null) {
      final fallbackType = personUid != null ? 'move_out' : 'monthly';
      requests = requests.where((req) {
        final typeStr = _requestInspectionType[req.id] ?? fallbackType;
        return typeStr == _typeFilter;
      }).toList();
    }
    // 월청소 전용: 활성 스케줄에 연결된 request 여부
    final isMonthlyCard = _requestInspectionType[requests.isNotEmpty ? requests.first.id : ''] == 'monthly'
        || (personUid == null && _typeFilter == 'monthly');
    final hasActiveScheduleRequest = isMonthlyCard && requests.any((r) {
      final d = r.data() as Map<String, dynamic>;
      final sid = d['scheduleId']?.toString();
      return sid != null && _scheduleMap.containsKey(sid);
    });

    final isSelected = _selectedRoom == key;
    final accentColor = FluentTheme.of(context).accentColor;
    final bldColor = buildingColor(_getRoomFloorOption(key));

    // 최근 점수, 최근 상태
    double? latestScore;
    String? latestStatus;
    bool latestIsMoveOut = false;
    bool latestNeedsRecheck = false;
    if (requests.isNotEmpty) {
      final latestData = requests.first.data() as Map<String, dynamic>;
      latestScore = (latestData['scoreAvg'] as num?)?.toDouble();
      latestStatus = latestData['status'] as String?;
      // inspectionType: 로드 시 조인된 캐시에서 조회
      final latestType = _requestInspectionType[requests.first.id];
      latestIsMoveOut = latestType == 'move_out';
      latestNeedsRecheck = latestData['needsRecheck'] == true;
    }

    // 점검 대기중인 활성 스케줄의 날짜/시간 찾기
    String? scheduleDateTime;
    if (hasActiveScheduleRequest && latestStatus != 'completed') {
      final activeRequest = requests.firstWhere((r) {
        final d = r.data() as Map<String, dynamic>;
        final sid = d['scheduleId']?.toString();
        return sid != null && _scheduleMap.containsKey(sid);
      }, orElse: () => requests.first);
      final sid = (activeRequest.data() as Map<String, dynamic>)['scheduleId']?.toString();
      if (sid != null && _scheduleMap.containsKey(sid)) {
        final sch = _scheduleMap[sid]!;
        final ts = (sch['date'] as Timestamp?)?.toDate();
        final startTime = (sch['startTime'] as String?) ?? '';
        if (ts != null) {
          scheduleDateTime = DateFormat('MM/dd').format(ts);
          if (startTime.isNotEmpty) scheduleDateTime = '$scheduleDateTime $startTime';
        }
      }
    }

    return GestureDetector(
      onTap: () {
        setState(() => _selectedRoom = key);
        _loadRoomStudents(key);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 왼쪽 건물 색상 스트라이프
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: bldColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    bottomLeft: Radius.circular(6),
                  ),
                ),
              ),
              // 메인 카드 콘텐츠
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? accentColor.withValues(alpha: 0.12)
                        : null,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(6),
                      bottomRight: Radius.circular(6),
                    ),
                    border: Border.all(
                      color: isSelected
                          ? accentColor
                          : FluentTheme.of(
                              context,
                            ).resources.dividerStrokeColorDefault,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // 정보
                      Expanded(
                        child: () {
                          final isMonthly = _typeFilter == 'monthly';
                          if (isMonthly && personUid == null) {
                            // 월청소: 호실·거주인원/인실 / 건물이름 점검N회
                            final roomKey = buildingLabel != null
                                ? '$buildingLabel|$roomNumber'
                                : roomNumber;
                            final residentCount =
                                _residentCountByRoom[roomKey] ?? 0;
                            final capLabel = buildingLabel == '샬롬하우스' ||
                                    buildingLabel == '샬롬하우스(겨울방학)'
                                ? roomCapacityLabel(roomNumber)
                                : '';
                            final capNum = int.tryParse(
                                capLabel.replaceAll(RegExp(r'[^0-9]'), ''));
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 6,
                                  children: [
                                    Text(
                                      capNum != null
                                          ? '$roomNumber호 · $residentCount/${capNum}인'
                                          : '$roomNumber호',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1A1A1A),
                                      ),
                                    ),
                                    if (scheduleDateTime != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2196F3).withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: const Color(0xFF2196F3).withValues(alpha: 0.3)),
                                        ),
                                        child: Text(
                                          scheduleDateTime,
                                          style: const TextStyle(fontSize: 10, color: Color(0xFF2196F3), fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${buildingLabel ?? ''} · 점검 ${requests.length}회',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF666666),
                                  ),
                                ),
                              ],
                            );
                          }
                          // 퇴사검사 / 전체 탭
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1행: 이름 호수(자리번호) [미가입 배지]
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 6,
                                children: [
                                  Text(
                                    () {
                                      if (personUid != null) {
                                        final info = _personInfoByKey[key];
                                        final name = info?['name'] ?? '';
                                        final seat = info?['seatNumber'] ?? '';
                                        final namePart = name.isNotEmpty ? '$name ' : '';
                                        final roomPart = seat.isNotEmpty
                                            ? '$roomNumber호($seat)'
                                            : '$roomNumber호';
                                        return '$namePart$roomPart';
                                      }
                                      return '$roomNumber호';
                                    }(),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                  ),
                                  if (isUnregisteredStudent)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: Colors.orange.withValues(alpha: 0.6),
                                        ),
                                      ),
                                      child: Text(
                                        '미가입',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.orange,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              // 2행: 건물이름 점검N회
                              Text(
                                '${buildingLabel ?? ''}  점검 ${requests.length}회',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF666666),
                                ),
                              ),
                            ],
                          );
                        }(),
                      ),
                      // 뱃지: 퇴사검사는 request 이력 자체로 판단, 월청소는 활성 스케줄 기준
                      if (personUid != null && residentStatus != null && residentStatus != '재실중')
                        // 퇴사/미거주 상태
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            residentStatus,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.red),
                          ),
                        )
                      else if (isVacant)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey[40].withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.grey[80]),
                          ),
                          child: Text(
                            '거주학생 없음',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[130]),
                          ),
                        )
                      else if (requests.isEmpty)
                        // 이력 없음 → 미신청
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                '미신청',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.orange),
                              ),
                            ),
                            // 미가입 학생은 uid가 없어 대리신청이 불가하므로 버튼을 숨긴다
                            if (personUid != null && !isUnregisteredStudent) ...[
                              const SizedBox(width: 6),
                              Button(
                                style: ButtonStyle(
                                  padding: WidgetStateProperty.all(
                                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  ),
                                ),
                                onPressed: () => _showApplyScheduleDialog(key, personUid),
                                child: const Text('관리자신청', style: TextStyle(fontSize: 11)),
                              ),
                            ],
                          ],
                        )
                      else if (latestStatus != null)
                        // 이력 있음 → status/score 뱃지
                        if (latestStatus == 'pending' || latestStatus == 'in_progress')
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _statusColor(latestStatus).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: _statusColor(latestStatus).withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              _statusLabel(latestStatus),
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _statusColor(latestStatus)),
                            ),
                          )
                        else
                          _buildScoreBadge(
                            latestScore,
                            isMoveOut: latestIsMoveOut,
                            needsRecheck: latestNeedsRecheck,
                          ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 관리자 대리 신청 ──
  Future<void> _showApplyScheduleDialog(String key, String? uid) async {
    if (uid == null) return;

    final roomFloor = _getRoomFloorOption(key);
    final schedules = _scheduleMap.entries
        .where((e) =>
            e.value['inspectionType'] == 'move_out' &&
            (roomFloor == null || e.value['floor'] == roomFloor))
        .toList()
      ..sort((a, b) {
        final ta = (a.value['date'] as Timestamp?)?.toDate();
        final tb = (b.value['date'] as Timestamp?)?.toDate();
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return tb.compareTo(ta);
      });

    if (!mounted) return;
    if (schedules.isEmpty) {
      await showDialog(
        context: context,
        builder: (ctx) => ContentDialog(
          title: const Text('알림'),
          content: Text(
            roomFloor != null
                ? '$roomFloor 구역에 등록된 퇴사검사 스케줄이 없습니다'
                : '등록된 퇴사검사 스케줄이 없습니다',
          ),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('확인')),
          ],
        ),
      );
      return;
    }

    String? selectedId;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => ContentDialog(
          title: const Text('스케줄 선택'),
          content: SizedBox(
            width: 400,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: schedules.length,
              itemBuilder: (_, i) {
                final sid = schedules[i].key;
                final data = schedules[i].value;
                final floor = data['floor']?.toString() ?? '';
                final ts = data['date'] as Timestamp?;
                final dateLabel = ts != null
                    ? DateFormat('yyyy.MM.dd').format(ts.toDate())
                    : '날짜 미상';
                final start = data['startTime']?.toString() ?? '';
                final end = data['endTime']?.toString() ?? '';
                final isSelected = selectedId == sid;
                return ListTile(
                  title: Text('$dateLabel $floor'),
                  subtitle: start.isNotEmpty ? Text('$start ~ $end') : null,
                  tileColor: isSelected ? WidgetStateProperty.all(FluentTheme.of(context).accentColor.withValues(alpha: 0.15)) : null,
                  onPressed: () => setDialogState(() => selectedId = sid),
                );
              },
            ),
          ),
          actions: [
            Button(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            FilledButton(
              onPressed: selectedId == null ? null : () => Navigator.pop(ctx),
              child: const Text('신청'),
            ),
          ],
        ),
      ),
    );

    if (selectedId == null || !mounted) return;
    await _submitApplyByAdmin(key, uid, selectedId!);
  }

  Future<void> _submitApplyByAdmin(String key, String uid, String scheduleId) async {
    try {
      final scheduleData = _scheduleMap[scheduleId];
      if (scheduleData == null) throw Exception('스케줄 정보 없음');

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final userData = userDoc.data();
      if (userData == null) throw Exception('학생 정보 없음');

      final scheduleDate = (scheduleData['date'] as Timestamp).toDate();
      final startTime = (scheduleData['startTime'] ?? '') as String;
      final endTime = (scheduleData['endTime'] ?? '') as String;

      final rawDorm = userData['dormBuilding']?.toString() ?? '';
      final dormBuilding = rawDorm.isNotEmpty
          ? rawDorm
          : _buildingFromFloor(scheduleData['floor']?.toString()) ?? '';

      final adminUser = FirebaseAuth.instance.currentUser;
      String? adminName;
      if (adminUser != null) {
        try {
          final adminDoc = await FirebaseFirestore.instance.collection('users').doc(adminUser.uid).get();
          adminName = adminDoc.data()?['name'] as String?;
        } catch (_) {}
      }
      final batch = FirebaseFirestore.instance.batch();
      final requestRef = FirebaseFirestore.instance.collection('cleaning_requests').doc();
      batch.set(requestRef, {
        'userId': uid,
        'userName': userData['name'] ?? '',
        'roomNumber': userData['roomNumber'] ?? '',
        'dormBuilding': dormBuilding,
        'scheduleId': scheduleId,
        'inspectionType': 'move_out',
        'availableDates': [Timestamp.fromDate(scheduleDate)],
        'availableTimeSlot': '$startTime~$endTime',
        'availableTimeSlotLabel': '${DateFormat('MM/dd').format(scheduleDate)} $startTime~$endTime',
        'status': 'pending',
        'createdByAdmin': true,
        'adminId': adminUser?.uid,
        'adminEmail': adminUser?.email,
        'adminName': adminName ?? adminUser?.email,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });
      batch.update(
        FirebaseFirestore.instance.collection('cleaning_schedules').doc(scheduleId),
        {'currentCount': FieldValue.increment(1)},
      );
      await batch.commit();

      if (mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => ContentDialog(
            title: const Text('완료'),
            content: const Text('신청이 완료되었습니다'),
            actions: [
              FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('확인')),
            ],
          ),
        );
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => ContentDialog(
            title: const Text('오류'),
            content: Text('$e'),
            actions: [
              FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('확인')),
            ],
          ),
        );
      }
    }
  }

  Widget _buildScoreBadge(
    double? score, {
    bool isMoveOut = false,
    bool needsRecheck = false,
  }) {
    final Color color;
    final String label;
    if (isMoveOut) {
      color = needsRecheck ? Colors.red : Colors.green;
      label = needsRecheck ? 'Fail' : 'Pass';
    } else {
      color = scoreColor(score);
      label = scoreLabel(score);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  // ──────────── 오른쪽 상세 패널 ────────────
  Widget _buildDetailPanel() {
    if (_selectedRoom == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(FluentIcons.history, size: 64, color: Colors.grey[60]),
            const SizedBox(height: 16),
            const Text('호실을 선택해주세요', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              '왼쪽에서 호실을 선택하면\n해당 호실의 점검 이력이 표시됩니다',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[100]),
            ),
          ],
        ),
      );
    }

    var requests = _grouped[_selectedRoom!] ?? [];
    if (_typeFilter != null) {
      final isPersonKey = _keyUserId(_selectedRoom!) != null;
      final fallbackType = isPersonKey ? 'move_out' : 'monthly';
      requests = requests.where((req) {
        final t = _requestInspectionType[req.id] ?? fallbackType;
        return t == _typeFilter;
      }).toList();
    }
    // 통계
    String studentName = '';
    final List<double> completedScores = [];

    for (final req in requests) {
      final data = req.data() as Map<String, dynamic>;
      if (studentName.isEmpty) studentName = (data['userName'] ?? '') as String;
      final s = (data['scoreAvg'] as num?)?.toDouble();
      if (s != null) completedScores.add(s);
    }
    final personInfo = _personInfoByKey[_selectedRoom!];
    if (studentName.isEmpty) studentName = personInfo?['name'] ?? '';
    final studentSeat = personInfo?['seatNumber'] ?? '';
    final overallAvg = completedScores.isEmpty
        ? null
        : completedScores.reduce((a, b) => a + b) / completedScores.length;

    return Container(
      color: FluentTheme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          _buildDetailHeader(
            requests.length,
            studentName,
            overallAvg,
            studentSeat: studentSeat,
            roomStudents: _roomStudentsCache[_selectedRoom!],
          ),
          Expanded(
            child: requests.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          FluentIcons.clipboard_list,
                          size: 48,
                          color: Colors.grey[60],
                        ),
                        const SizedBox(height: 12),
                        const Text('점검 이력이 없습니다'),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      final doc = requests[index];
                      final data = doc.data() as Map<String, dynamic>;
                      return _buildHistoryCard(data);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailHeader(
    int total,
    String studentName,
    double? overallAvg, {
    String studentSeat = '',
    List<Map<String, dynamic>>? roomStudents,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FluentTheme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(
            color: FluentTheme.of(context).resources.dividerStrokeColorDefault,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: FluentTheme.of(
                    context,
                  ).accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  FluentIcons.history,
                  color: FluentTheme.of(context).accentColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      () {
                        final room = _keyRoom(_selectedRoom!);
                        final building =
                            _keyBuilding(_selectedRoom!) ??
                            _buildingFromFloor(
                              _getRoomFloorOption(_selectedRoom!) ?? '',
                            );
                        final cap = building == '샬롬하우스'
                            ? roomCapacityLabel(room)
                            : '';
                        final roomLabel = cap.isNotEmpty ? '$room호 ($cap)' : '$room호';
                        final isPerson = _keyUserId(_selectedRoom!) != null;
                        if (isPerson && studentName.isNotEmpty) {
                          final roomPart = studentSeat.isNotEmpty
                              ? '$roomLabel($studentSeat)'
                              : roomLabel;
                          return '$studentName $roomPart';
                        }
                        return roomLabel;
                      }(),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_keyBuilding(_selectedRoom!) != null)
                      Text(
                        _keyBuilding(_selectedRoom!)!,
                        style: TextStyle(
                          fontSize: 12,
                          color: buildingColor(
                            _getRoomFloorOption(_selectedRoom!),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '총 $total회',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
              ),
            ],
          ),
          if (_keyUserId(_selectedRoom!) == null &&
              roomStudents != null &&
              roomStudents.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: roomStudents.map((s) {
                final name = (s['name'] as String?) ?? '';
                final studentId = (s['studentId'] as String?) ?? '';
                final seatNumber = (s['seatNumber'] as String?) ?? '';
                final isUnregistered = s['isUnregistered'] == true;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: FluentTheme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isUnregistered
                          ? Colors.orange.withValues(alpha: 0.6)
                          : FluentTheme.of(
                              context,
                            ).resources.dividerStrokeColorDefault,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (isUnregistered) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.orange.withValues(alpha: 0.6),
                                ),
                              ),
                              child: Text(
                                '미가입',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (studentId.isNotEmpty)
                        Text(
                          studentId,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[100],
                          ),
                        ),
                      if (seatNumber.isNotEmpty)
                        Text(
                          '자리 $seatNumber',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[100],
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ] else if (_keyUserId(_selectedRoom!) == null &&
              roomStudents != null) ...[
            const SizedBox(height: 8),
            Text(
              '호실 학생 정보 없음',
              style: TextStyle(fontSize: 12, color: Colors.grey[80]),
            ),
          ],
          if (overallAvg != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  '누적 평균 점수',
                  style: TextStyle(fontSize: 12, color: Colors.grey[100]),
                ),
                const SizedBox(width: 10),
                Text(
                  '${overallAvg.toStringAsFixed(1)}점 / 4점',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: scoreColor(overallAvg),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ──────────── 이력 카드 ────────────
  // requestId로 원본 신청 데이터 조회 (호실별 그룹 전체에서 검색)
  Map<String, dynamic>? _findRequestDataById(String? requestId) {
    if (requestId == null || requestId.isEmpty) return null;
    for (final list in _grouped.values) {
      for (final doc in list) {
        if (doc.id == requestId) return doc.data() as Map<String, dynamic>;
      }
    }
    return null;
  }

  Widget _buildHistoryCard(Map<String, dynamic> data) {
    final scheduleId = data['scheduleId'] as String?;
    final status = (data['status'] ?? 'pending') as String;
    final scoreAvg = (data['scoreAvg'] as num?)?.toDouble();
    final needsRecheck = data['needsRecheck'] == true;
    final isRecheckSubmission = data['isRecheck'] == true;
    final originalRequestData = _findRequestDataById(data['recheckOfRequestId'] as String?);
    final comment = data['comment'] as String?;
    final inspectionComment = data['inspectionComment'] as String?;
    final memo = data['memo'] as String?;
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final evaluatedAt = (data['evaluatedAt'] as Timestamp?)?.toDate();
    final evaluatedByEmail = data['evaluatedByEmail'] as String?;

    // 개인/공동 점수 데이터
    final rawCommunal = data['scoresCommunal'] as Map<String, dynamic>?;
    final rawPersonal = data['scoresPersonal'] as Map<String, dynamic>?;

    final communalScores = rawCommunal?.map(
      (k, v) => MapEntry(k, (v as num).toInt()),
    );
    final personalScores = rawPersonal?.map(
      (student, items) => MapEntry(
        student,
        (items as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, (v as num).toInt()),
        ),
      ),
    );

    final hasScores =
        (communalScores?.isNotEmpty ?? false) ||
        (personalScores?.isNotEmpty ?? false);
    final userName = (data['userName'] ?? '') as String;

    // 스케줄 정보 조회 (스케줄이 삭제된 경우 요청 문서에 저장된 값으로 폴백)
    final scheduleData = (scheduleId != null) ? _scheduleMap[scheduleId] : null;
    final floor = (scheduleData?['floor'] ?? data['floor'] ?? '') as String;
    final inspectionType =
        (scheduleData?['inspectionType'] ??
                data['inspectionType'] ??
                'monthly')
            as String;
    final scheduleDate = (scheduleData?['date'] as Timestamp?)?.toDate();
    final scheduleStartTime = scheduleData?['startTime'] as String?;
    final scheduleEndTime = scheduleData?['endTime'] as String?;

    final isMoveOut = inspectionType == 'move_out';
    final inspectionTypeLabel = isMoveOut ? '퇴사검사' : '월검사';

    final statusColor = _statusColor(status);
    final statusLabel = _statusLabel(status);
    final sColor = scoreColor(scoreAvg);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 날짜/시간 + 상태 뱃지
            Row(
              children: [
                Icon(
                  FluentIcons.calendar_settings,
                  size: 14,
                  color: Colors.grey[90],
                ),
                const SizedBox(width: 6),
                Text(
                  scheduleDate != null
                      ? '${DateFormat('yyyy.MM.dd').format(scheduleDate)}${scheduleStartTime != null ? ' $scheduleStartTime' : ''}${scheduleEndTime != null ? '~$scheduleEndTime' : ''}'
                      : (createdAt != null ? DateFormat('yyyy.MM.dd HH:mm').format(createdAt) : '-'),
                  style: TextStyle(fontSize: 13, color: Colors.grey[120]),
                ),
                const Spacer(),
                // 상태 뱃지
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
                if (isMoveOut || scoreAvg != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (isMoveOut
                                  ? (needsRecheck ? Colors.red : Colors.green)
                                  : sColor)
                              .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color:
                            (isMoveOut
                                    ? (needsRecheck ? Colors.red : Colors.green)
                                    : sColor)
                                .withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      isMoveOut
                          ? (needsRecheck ? 'Fail' : 'Pass')
                          : '${scoreAvg!.toStringAsFixed(1)}점',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isMoveOut
                            ? (needsRecheck ? Colors.red : Colors.green)
                            : sColor,
                      ),
                    ),
                  ),
                ],
                if (needsRecheck) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      '재검사 필요',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                if (isRecheckSubmission) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: Colors.purple.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      '재검사 신청',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.purple,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            // 구역 + 점검 유형 + 신청자
            Row(
              children: [
                if (floor.isNotEmpty) ...[
                  Icon(
                    FluentIcons.map_layers,
                    size: 13,
                    color: Colors.grey[80],
                  ),
                  const SizedBox(width: 5),
                  Text(
                    floor,
                    style: TextStyle(fontSize: 13, color: Colors.grey[120]),
                  ),
                  const SizedBox(width: 12),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Colors.teal.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    inspectionTypeLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.teal,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (scheduleDate != null) ...[
                  const SizedBox(width: 10),
                  Text(
                    DateFormat('yyyy.MM.dd').format(scheduleDate),
                    style: TextStyle(fontSize: 11, color: Colors.grey[90]),
                  ),
                ],
                if (userName.isNotEmpty) ...[
                  const Spacer(),
                  Icon(FluentIcons.contact, size: 13, color: Colors.grey[80]),
                  const SizedBox(width: 4),
                  Text(
                    userName,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[120],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
            // 평가일시
            if (evaluatedAt != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(FluentIcons.check_mark, size: 13, color: Colors.green),
                  const SizedBox(width: 5),
                  Text(
                    '평가일시: ${DateFormat('yyyy.MM.dd HH:mm').format(evaluatedAt)}'
                    '${evaluatedByEmail != null ? ' · $evaluatedByEmail' : ''}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[120]),
                  ),
                ],
              ),
            ],
            if (isMoveOut) ...[
              () {
                final raw = data['commonAreas'];
                List<String> areas = [];
                if (raw is List) {
                  areas = raw.map((e) => e.toString()).toList();
                } else if (raw is String && raw.isNotEmpty) {
                  areas = [raw];
                }
                if (areas.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Icon(FluentIcons.home, size: 13, color: const Color(0xFF00BCD4)),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          '공동구역: ${areas.join(' · ')}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF00BCD4),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }(),
            ],
            if (comment != null && comment.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(FluentIcons.comment, size: 13, color: Colors.grey[80]),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      '코멘트: $comment',
                      style: TextStyle(fontSize: 12, color: Colors.grey[120]),
                    ),
                  ),
                ],
              ),
            ],
            if (inspectionComment != null && inspectionComment.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(FluentIcons.comment_add, size: 13, color: Colors.teal),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      '점검자 코멘트: $inspectionComment',
                      style: TextStyle(fontSize: 12, color: Colors.grey[120]),
                    ),
                  ),
                ],
              ),
            ],
            if (memo != null && memo.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(FluentIcons.edit_note, size: 13, color: Colors.grey[80]),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      '메모: $memo',
                      style: TextStyle(fontSize: 12, color: Colors.grey[120]),
                    ),
                  ),
                ],
              ),
            ],
            // 점수/OX 상세 (평가 완료된 경우)
            if (hasScores) ...[
              const SizedBox(height: 10),
              Expander(
                header: Row(
                  children: [
                    Icon(
                      FluentIcons.clipboard_list,
                      size: 13,
                      color: Colors.grey[90],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isMoveOut ? 'O/X 상세' : '점수 상세',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[120],
                      ),
                    ),
                  ],
                ),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (personalScores != null && personalScores.isNotEmpty)
                      ...personalScores.entries.map((studentEntry) {
                        final structures =
                            getCheckStructures(
                              floor,
                              inspectionType,
                            );
                        final ordered = <MapEntry<String, int>>[];
                        for (final cat in structures.personal.entries) {
                          for (final sub in cat.value) {
                            final key = '${cat.key}_$sub';
                            if (studentEntry.value.containsKey(key)) {
                              ordered.add(
                                MapEntry(key, studentEntry.value[key]!),
                              );
                            }
                          }
                        }
                        // isMoveOut: X(실패)를 앞으로
                        final sortedEntries = isMoveOut
                            ? [
                                ...ordered.where((e) => e.value == 0),
                                ...ordered.where((e) => e.value != 0),
                              ]
                            : ordered;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '개인 — ${studentEntry.key}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: sortedEntries
                                    .map(
                                      (e) => _buildScoreChip(
                                        e.key,
                                        e.value,
                                        isMoveOut: isMoveOut,
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ),
                        );
                      }),
                    if (communalScores != null &&
                        communalScores.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isMoveOut
                              ? Colors.purple.withValues(alpha: 0.08)
                              : Colors.teal.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isMoveOut ? '공동 구역' : '점검 항목',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isMoveOut ? Colors.purple : Colors.teal,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: () {
                          final structures =
                              getCheckStructures(
                                floor,
                                inspectionType,
                              );
                          final ordered = <MapEntry<String, int>>[];
                          for (final cat in structures.communal.entries) {
                            for (final sub in cat.value) {
                              final key = '${cat.key}_$sub';
                              if (communalScores.containsKey(key)) {
                                ordered.add(
                                  MapEntry(key, communalScores[key]!),
                                );
                              }
                            }
                          }
                          final sortedEntries = isMoveOut
                              ? [
                                  ...ordered.where((e) => e.value == 0),
                                  ...ordered.where((e) => e.value != 0),
                                ]
                              : ordered;
                          return sortedEntries
                              .map(
                                (e) => _buildScoreChip(
                                  e.key,
                                  e.value,
                                  isMoveOut: isMoveOut,
                                ),
                              )
                              .toList();
                        }(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (isRecheckSubmission && originalRequestData != null) ...[
              const SizedBox(height: 10),
              buildEvaluationHistorySection([originalRequestData]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScoreChip(String key, int score, {bool isMoveOut = false}) {
    final parts = key.split('_');
    final label = parts.length >= 2 ? '${parts[0]} ${parts[1]}' : key;

    if (isMoveOut) {
      final isPassed = score == 1;
      final Color color = isPassed ? Colors.green : Colors.red;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPassed ? FluentIcons.check_mark : FluentIcons.cancel,
              size: 10,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              '$label: ${isPassed ? 'O' : 'X'}',
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: isPassed ? FontWeight.normal : FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    final Color color = score == 4
        ? Colors.green
        : score == 3
        ? Colors.blue
        : score == 2
        ? Colors.orange
        : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$label  $score점',
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
