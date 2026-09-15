// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cloud_sense_webapp/main.dart';
import 'package:provider/provider.dart';
import 'package:cloud_sense_webapp/src/utils/prefix_mapping.dart';
import 'package:cloud_sense_webapp/src/utils/Shared_Add_Device.dart';
import 'package:cloud_sense_webapp/src/widgets/device_action_button.dart';

void main() {

  group('Standard Device Display Names', () {
    final testCases = <String, String>{
      'PJ01': 'ANNAM-01',
      'ANNAM/Punjab/WS_1': 'ANNAM-01',
      'WS_PUNJAB_1': 'ANNAM-01',
      'KR01': 'ANNAM-01',
      'ANNAM/Kerala/WS_1': 'ANNAM-01',
      'WJ201': 'ANNAM-201',
      'ANNAM0126_201': 'ANNAM-201',
      'ANNAM-0126-201': 'ANNAM-201',
      'WF101': 'ANNAM-101',
      'ANNAM0226_101': 'ANNAM-101',
      'WA101': 'ANNAM-101',
      'ANNAM0426_101': 'ANNAM-101',
      'WA007': 'ANNAM-007',
      'ANNAM0426_007': 'ANNAM-007',
      'WM101': 'TESTING-101',
      'TS0526_101': 'TESTING-101',
      'TS-001': 'TESTING-001',
      'TS-01': 'TESTING-001',
      'WT01': 'TESTING-001',
      'TESTING-001': 'TESTING-001',
      'AM01': 'ANNAM-CP-01',
      'ANNAM_CP01': 'ANNAM-CP-01',
      'PS01': 'ANNAM-CPS-01',
      'ANNAM/CPS_1': 'ANNAM-CPS-01',
      'SH001': 'SOBHA-01',
      'WS_Sobha_1': 'SOBHA-01',
      'WS_SHOBHA_1': 'SOBHA-01',
      'AW01': 'ANNAM-01',
      'AWS_1': 'ANNAM-01',
      'AW62': 'ANNAM-62',
      'AWS_62': 'ANNAM-62',
      'AT01': 'AWS-TESTING-01',
      'AWS_TESTING_1': 'AWS-TESTING-01',
      'TH01': 'TH-01',
      'TH_01': 'TH-01',
    };

    testCases.forEach((input, expected) {
      test('Maps $input to $expected', () {
        expect(DevicePrefixUtils.toAnnamDisplayName(input), equals(expected));
      });
    });
  });

  group('Add Device Internal ID Resolution', () {
    test('Resolves ANNAM-PB-01 to PJ', () {
      final candidates = DeviceUtils.getPossibleInternalIDs('ANNAM-PB-01');
      expect(candidates.any((c) => c.startsWith('PJ')), isTrue);
    });

    test('Resolves ANNAM-KL-01 to KR', () {
      final candidates = DeviceUtils.getPossibleInternalIDs('ANNAM-KL-01');
      expect(candidates.any((c) => c.startsWith('KR')), isTrue);
    });

    test('Resolves ANNAM-201 to WJ201', () {
      final candidates = DeviceUtils.getPossibleInternalIDs('ANNAM-201');
      expect(candidates, contains('WJ201'));
    });

    test('Resolves ANNAM-007 to WA007', () {
      final candidates = DeviceUtils.getPossibleInternalIDs('ANNAM-007');
      expect(candidates, contains('WA007'));
    });

    test('Resolves legacy ANNAM-0126-201 to WJ201', () {
      final candidates = DeviceUtils.getPossibleInternalIDs('ANNAM-0126-201');
      expect(candidates, contains('WJ201'));
    });

    test('Resolves legacy ANNAM-0426-101 to WA101', () {
      final candidates = DeviceUtils.getPossibleInternalIDs('ANNAM-0426-101');
      expect(candidates, contains('WA101'));
    });

    test('Resolves SOBHA-01 to SH001', () {
      final candidates = DeviceUtils.getPossibleInternalIDs('SOBHA-01');
      expect(candidates, contains('SH001'));
    });

    test('Resolves TS-101 and TESTING-101 to WM101', () {
      final candidates = DeviceUtils.getPossibleInternalIDs('TS-101');
      expect(candidates, contains('WM101'));
      final candidatesTesting = DeviceUtils.getPossibleInternalIDs('TESTING-101');
      expect(candidatesTesting, contains('WM101'));
    });

    test('Punjab and Kerala have single unambiguous candidate (never repeating)', () {
      final pjCandidates = DeviceUtils.getPossibleInternalIDs('ANNAM-PB-01');
      expect(pjCandidates, equals(['PJ01']));
      expect(pjCandidates.length, equals(1));

      final krCandidates = DeviceUtils.getPossibleInternalIDs('ANNAM-KL-01');
      expect(krCandidates, equals(['KR01']));
      expect(krCandidates.length, equals(1));
    });

    test('Resolves ANNAM-100 candidates with their MQTT topics', () {
      final candidates = DeviceUtils.getPossibleInternalIDs('ANNAM-100');
      expect(candidates, containsAll(['WJ100', 'WA100', 'WF100']));

      final topics = candidates.map((id) => DevicePrefixUtils.buildTopicFromSensorName(id).split('#').last).toList();
      expect(topics, contains('WS/SSMet_0126/100'));
      expect(topics, contains('WS/Annam_0426/100'));
      expect(topics, contains('WS/SSMET_0226/100'));
    });

    test('Correctly distinguishes between ANNAM-CP and ANNAM-CPS sensors', () {
      final cpCandidates = DeviceUtils.getPossibleInternalIDs('ANNAM-CP-01');
      expect(cpCandidates, equals(['AM01']));

      final cpsCandidates = DeviceUtils.getPossibleInternalIDs('ANNAM-CPS-01');
      expect(cpsCandidates, equals(['PS01']));

      expect(DevicePrefixUtils.toAnnamDisplayName('ANNAM-CP-01'), equals('ANNAM-CP-01'));
      expect(DevicePrefixUtils.toAnnamDisplayName('ANNAM-CPS-01'), equals('ANNAM-CPS-01'));
      expect(DevicePrefixUtils.toAnnamDisplayName('AM01'), equals('ANNAM-CP-01'));
      expect(DevicePrefixUtils.toAnnamDisplayName('PS01'), equals('ANNAM-CPS-01'));

      expect(DevicePrefixUtils.getSensorType('AM01'), equals('Annam CP Sensor'));
      expect(DevicePrefixUtils.getSensorType('PS01'), equals('CPS Sensor'));
      expect(DevicePrefixUtils.getSensorType('ANNAM-CP-01'), equals('Annam CP Sensor'));
      expect(DevicePrefixUtils.getSensorType('ANNAM-CPS-01'), equals('CPS Sensor'));
    });

    test('Prioritizes Active ANNAM devices, then Inactive ANNAM, then Non-ANNAM', () {
      int naturalCompare(String a, String b) {
        final regExp = RegExp(r'(\d+|\D+)');
        final matchesA = regExp.allMatches(a).map((m) => m.group(0)!).toList();
        final matchesB = regExp.allMatches(b).map((m) => m.group(0)!).toList();

        final len = matchesA.length < matchesB.length ? matchesA.length : matchesB.length;
        for (int i = 0; i < len; i++) {
          final partA = matchesA[i];
          final partB = matchesB[i];
          final numA = int.tryParse(partA);
          final numB = int.tryParse(partB);

          if (numA != null && numB != null) {
            final cmp = numA.compareTo(numB);
            if (cmp != 0) return cmp;
          } else {
            final cmp = partA.compareTo(partB);
            if (cmp != 0) return cmp;
          }
        }
        return matchesA.length.compareTo(matchesB.length);
      }

      int getSortRank(Map<String, dynamic> d) {
        final deviceId = (d['DeviceId'] ?? "").toString();
        final topic = (d['Topic'] ?? "").toString();
        final sn = DevicePrefixUtils.resolveSensorName(deviceId, topic);
        final dn = DevicePrefixUtils.toAnnamDisplayName(sn).toUpperCase();
        final mapped = DevicePrefixUtils.mapCategoryAndPrefix(topic);
        final isActive = d['isActive'] == true;

        final isKerala = mapped.prefix == 'KR' ||
            sn.startsWith('KR') ||
            topic.toLowerCase().contains('kerala');
        final isPunjab = mapped.prefix == 'PJ' ||
            sn.startsWith('PJ') ||
            topic.toLowerCase().contains('punjab');
        final isAnnam = DevicePrefixUtils.isAnnamCoreSensor(sn) || dn.startsWith('ANNAM');

        // === ACTIVE SENSORS FIRST ===
        if (isAnnam && isKerala && isActive) return 0;
        if (isAnnam && isPunjab && isActive) return 1;
        if (isAnnam && isActive) return 2;
        if (!isAnnam && isActive) return 3;

        // === INACTIVE SENSORS LAST ===
        if (isAnnam && isKerala && !isActive) return 4;
        if (isAnnam && isPunjab && !isActive) return 5;
        if (isAnnam && !isActive) return 6;
        return 7;
      }

      final devices = [
        {'DeviceId': '18', 'Topic': 'WS/Campus/18', 'isActive': true}, // TESTING-018 (Active Non-ANNAM)
        {'DeviceId': '1', 'Topic': 'WS/Campus/1', 'isActive': false},  // ANNAM-001 (Inactive Other ANNAM)
        {'DeviceId': 'WA005', 'Topic': 'WS/Annam_0426/5', 'isActive': true}, // ANNAM-005 (Active Other ANNAM)
        {'DeviceId': 'KR15', 'Topic': 'WS/Kerala/15', 'isActive': true}, // ANNAM-15 (Active Kerala)
        {'DeviceId': 'KR01', 'Topic': 'WS/Kerala/1', 'isActive': true},  // ANNAM-01 (Active Kerala)
        {'DeviceId': 'PJ02', 'Topic': 'WS/Punjab/2', 'isActive': true},  // ANNAM-02 (Active Punjab)
        {'DeviceId': 'KR99', 'Topic': 'WS/Kerala/99', 'isActive': false}, // ANNAM-99 (Inactive Kerala)
        {'DeviceId': 'TS01', 'Topic': 'WS/Testing/1', 'isActive': false}, // TESTING-001 (Inactive Non-ANNAM)
      ];

      devices.sort((a, b) {
        final rankA = getSortRank(a);
        final rankB = getSortRank(b);
        if (rankA != rankB) return rankA.compareTo(rankB);

        final dnA = DevicePrefixUtils.toAnnamDisplayName(DevicePrefixUtils.resolveSensorName(a['DeviceId'] as String, a['Topic'] as String));
        final dnB = DevicePrefixUtils.toAnnamDisplayName(DevicePrefixUtils.resolveSensorName(b['DeviceId'] as String, b['Topic'] as String));

        final cmp = naturalCompare(dnA, dnB);
        if (cmp != 0) return cmp;
        return (a['Topic'] as String).compareTo(b['Topic'] as String);
      });

      final orderedNames = devices.map((d) => DevicePrefixUtils.toAnnamDisplayName(DevicePrefixUtils.resolveSensorName(d['DeviceId'] as String, d['Topic'] as String))).toList();

      // Active Kerala ANNAM should come first: ANNAM-01, ANNAM-15
      expect(orderedNames[0], equals('ANNAM-01'));
      expect(orderedNames[1], equals('ANNAM-15'));

      // Active Punjab ANNAM comes next: ANNAM-02
      expect(orderedNames[2], equals('ANNAM-02'));

      // Active Other ANNAM: ANNAM-005
      expect(orderedNames[3], equals('ANNAM-005'));

      // Active Non-ANNAM (all active devices come before inactive): TESTING-018
      expect(orderedNames[4], equals('TESTING-018'));

      // Inactive Kerala ANNAM: ANNAM-99
      expect(orderedNames[5], equals('ANNAM-99'));

      // Inactive Other ANNAM: ANNAM-001
      expect(orderedNames[6], equals('ANNAM-001'));

      // Inactive Non-ANNAM: TESTING-001
      expect(orderedNames[7], equals('TESTING-001'));
    });
  });

  group('DeviceActionButton Widget Tests', () {
    testWidgets('Renders action button and opens popup menu in Admin mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => UserProvider()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DeviceActionButton(
                deviceId: 'WS_Shobha_1',
                topic: 'WS/Shobha/1',
                sensorName: 'WS_Shobha_1',
                displaySensorName: 'SOBHA-01',
                isAdmin: true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(DeviceActionButton), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);

      // Tap action button to open menu
      await tester.tap(find.byType(DeviceActionButton));
      await tester.pumpAndSettle();

      // Admin menu should show Graph, Parameters, Health Status, Quality Diagnostics
      expect(find.text('Graph'), findsOneWidget);
      expect(find.text('Parameters'), findsOneWidget);
      expect(find.text('Health Status'), findsOneWidget);
      expect(find.text('Quality Diagnostics'), findsOneWidget);
      // Delete Device should NOT be present in admin mode
      expect(find.text('Delete Device'), findsNothing);
    });

    testWidgets('Renders action button and opens popup menu in User mode with delete callback', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => UserProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DeviceActionButton(
                deviceId: 'PJ01',
                topic: 'WS/Punjab/1',
                sensorName: 'PJ01',
                displaySensorName: 'ANNAM-01',
                isAdmin: false,
                onDeleteSuccess: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.byType(DeviceActionButton), findsOneWidget);

      // Tap action button to open menu
      await tester.tap(find.byType(DeviceActionButton));
      await tester.pumpAndSettle();

      // User menu should show Graph, Parameters, Health Status, Delete Device
      expect(find.text('Graph'), findsOneWidget);
      expect(find.text('Parameters'), findsOneWidget);
      expect(find.text('Health Status'), findsOneWidget);
      expect(find.text('Delete Device'), findsOneWidget);
      // Quality Diagnostics should NOT be present in user mode
      expect(find.text('Quality Diagnostics'), findsNothing);
    });

    testWidgets('showDeviceParametersDialog opens and displays parameters correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDeviceParametersDialog(
                    context: context,
                    isDark: true,
                    updateInterval: '15 mins',
                    displayParamNames: ['temperature', 'humidity', 'rain'],
                    topic: 'WS/Shobha/1',
                    deviceName: 'SOBHA-01',
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Parameters'), findsOneWidget);
      expect(find.text('SOBHA-01'), findsNothing);
      expect(find.text('SOBHA-01 (WS/Shobha/1)'), findsNothing);
      expect(find.text('WS/Shobha/1'), findsOneWidget);
      expect(find.text('Data Interval: '), findsOneWidget);
      expect(find.text('15 mins'), findsOneWidget);
      expect(find.text('Temperature'), findsOneWidget);
      expect(find.text('Humidity'), findsOneWidget);
      expect(find.text('Rain'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Parameters'), findsNothing);
    });
  });
}
