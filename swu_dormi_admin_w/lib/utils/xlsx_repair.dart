import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// 공유 문자열 테이블(xl/sharedStrings.xml)에 같은 문자열이 중복 등록된 xlsx를
/// 엑셀이 저장하는 형태(중복 없음)로 바로잡는다. 중복이 없거나 구조를 읽을 수 없으면 null.
///
/// excel 패키지는 중복 문자열을 읽을 때 목록에서 버리고 번호를 당겨버려, 뒤쪽 셀이 참조하는
/// 번호가 범위를 벗어나 "Null check operator" 오류로 파일 전체를 읽지 못한다.
/// 엑셀이 아닌 프로그램(메신저 미리보기, 한컴/WPS, 온라인 변환기 등)으로 저장한 파일에서 생긴다.
///
/// [matchByText]가 true면 서식 없는 문자열은 XML 표기(공백 보존 속성 등)가 달라도 글자가 같으면
/// 같은 문자열로 합친다.
Uint8List? dedupeSharedStrings(Uint8List bytes, {bool matchByText = false}) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final sstFile = archive.findFile('xl/sharedStrings.xml');
  if (sstFile == null) return null;

  final sstDoc = XmlDocument.parse(utf8.decode(sstFile.content as List<int>));
  final items = sstDoc.rootElement.childElements
      .where((e) => e.name.local == 'si')
      .toList();

  String keyOf(XmlElement si) {
    if (!matchByText || si.childElements.any((c) => c.name.local == 'r')) {
      return si.toXmlString();
    }
    return 't:${si.childElements.where((c) => c.name.local == 't').map((c) => c.innerText).join()}';
  }

  // 옛 번호 -> 중복을 합친 뒤의 새 번호
  final newIndexByKey = <String, int>{};
  final newIndex = List<int>.filled(items.length, 0);
  var kept = 0;
  for (var i = 0; i < items.length; i++) {
    final key = keyOf(items[i]);
    final existing = newIndexByKey[key];
    if (existing != null) {
      newIndex[i] = existing;
      items[i].parent!.children.remove(items[i]);
    } else {
      newIndexByKey[key] = kept;
      newIndex[i] = kept++;
    }
  }
  if (kept == items.length) return null;
  sstDoc.rootElement.setAttribute('uniqueCount', '$kept');

  final out = Archive();
  for (final file in archive.files) {
    if (!file.isFile) continue;
    var content = file.content as List<int>;
    if (file.name == 'xl/sharedStrings.xml') {
      content = utf8.encode(sstDoc.toXmlString());
    } else if (file.name.startsWith('xl/worksheets/') &&
        file.name.endsWith('.xml')) {
      final doc = XmlDocument.parse(utf8.decode(content));
      for (final c in doc.findAllElements('c')) {
        if (c.getAttribute('t') != 's') continue;
        final v = c.getElement('v');
        final old = int.tryParse(v?.innerText ?? '');
        if (v == null || old == null || old < 0 || old >= newIndex.length) {
          continue;
        }
        v.children
          ..clear()
          ..add(XmlText('${newIndex[old]}'));
      }
      content = utf8.encode(doc.toXmlString());
    }
    out.addFile(ArchiveFile(file.name, content.length, content));
  }
  final encoded = ZipEncoder().encode(out);
  return encoded == null ? null : Uint8List.fromList(encoded);
}
