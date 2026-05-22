import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:dehus/features/database/database_service.dart';
import 'package:dehus/models/catalog_item_model.dart';
import 'package:dehus/models/farmer_model.dart';

void main() {
  late Directory tempDir;
  late Box<dynamic> schoolBox;
  late Box<dynamic> catalogBox;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('dehus_sync_test_');
    Hive.init(tempDir.path);
    schoolBox = await Hive.openBox('school_box_test');
    catalogBox = await Hive.openBox('catalog_box_test');
  });

  tearDown(() async {
    await schoolBox.close();
    await catalogBox.close();
    await Hive.deleteBoxFromDisk('school_box_test');
    await Hive.deleteBoxFromDisk('catalog_box_test');
    await tempDir.delete(recursive: true);
  });

  test('syncData marks unsynced records as synced when online', () async {
    var schoolUpserts = 0;
    var catalogUpserts = 0;
    var pipelineSyncCalls = 0;
    final service = DatabaseService(
      connectivityCheck: () async => [ConnectivityResult.wifi],
      schoolBoxProvider: () async => schoolBox,
      catalogBoxProvider: () async => catalogBox,
      upsertSchoolOverride: (_) async => schoolUpserts++,
      upsertCatalogOverride: (_) async => catalogUpserts++,
      syncEngagementOverride: (_) async => pipelineSyncCalls++,
    );

    final school = SchoolModel(
      id: 'school-1',
      name: 'Alpha School',
      phone: '0700000000',
      county: 'Nairobi',
      focusAreas: const ['Math'],
      isSynced: false,
    );
    await schoolBox.put(school.id, school.toMap());
    await schoolBox.put(
      'school-2',
      SchoolModel(
        id: 'school-2',
        name: 'Beta School',
        phone: '0711111111',
        county: 'Kiambu',
        focusAreas: const ['English'],
        isSynced: true,
      ).toMap(),
    );

    final catalog = CatalogItemModel(
      id: 'cat-1',
      name: 'Book A',
      category: 'Primary',
      sku: 'SKU-1',
      itemType: 'sale',
      unitPrice: 100,
      isSynced: false,
    );
    await catalogBox.put(catalog.sku, catalog.toMap());

    await service.syncData();

    expect(schoolUpserts, 1);
    expect(catalogUpserts, 1);
    expect(pipelineSyncCalls, 1);
    expect(SchoolModel.fromMap(schoolBox.get('school-1')).isSynced, isTrue);
    expect(
      CatalogItemModel.fromMap(
        Map<String, dynamic>.from(catalogBox.get('SKU-1')),
      ).isSynced,
      isTrue,
    );
  });

  test('syncData exits without syncing when offline', () async {
    var schoolUpserts = 0;
    var catalogUpserts = 0;
    final service = DatabaseService(
      connectivityCheck: () async => [ConnectivityResult.none],
      schoolBoxProvider: () async => schoolBox,
      catalogBoxProvider: () async => catalogBox,
      upsertSchoolOverride: (_) async => schoolUpserts++,
      upsertCatalogOverride: (_) async => catalogUpserts++,
      syncEngagementOverride: (_) async {},
    );

    final school = SchoolModel(
      id: 'school-offline',
      name: 'Offline School',
      phone: '0722222222',
      county: 'Nakuru',
      focusAreas: const ['Science'],
      isSynced: false,
    );
    await schoolBox.put(school.id, school.toMap());

    await service.syncData();

    expect(schoolUpserts, 0);
    expect(catalogUpserts, 0);
    expect(
      SchoolModel.fromMap(schoolBox.get('school-offline')).isSynced,
      isFalse,
    );
  });
}
