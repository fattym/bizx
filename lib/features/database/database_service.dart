import '../../models/task_model.dart';
import '../../models/user_model.dart';
import '../../models/farmer_model.dart';
import '../../models/message_model.dart';
import '../../models/catalog_item_model.dart';
import '../../models/order_item_model.dart';
import '../../models/order_model.dart';
import '../../models/school_sale_model.dart';
import '../../models/pipeline_stage.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class DatabaseService {
  static Future<Box<dynamic>>? _schoolBoxFuture;
  static Future<Box<dynamic>>? _catalogBoxFuture;
  static Future<Box<dynamic>>? _pendingOpsBoxFuture;
  final Future<List<ConnectivityResult>> Function()? _connectivityCheck;
  final Future<Box<dynamic>> Function()? _schoolBoxProvider;
  final Future<Box<dynamic>> Function()? _catalogBoxProvider;
  final Future<Box<dynamic>> Function()? _pendingOpsBoxProvider;
  final Future<void> Function(Map<String, dynamic>)? _upsertSchoolOverride;
  final Future<void> Function(SchoolModel)? _syncEngagementOverride;
  final Future<void> Function(Map<String, dynamic>)? _upsertCatalogOverride;

  DatabaseService({
    Future<List<ConnectivityResult>> Function()? connectivityCheck,
    Future<Box<dynamic>> Function()? schoolBoxProvider,
    Future<Box<dynamic>> Function()? catalogBoxProvider,
    Future<Box<dynamic>> Function()? pendingOpsBoxProvider,
    Future<void> Function(Map<String, dynamic>)? upsertSchoolOverride,
    Future<void> Function(SchoolModel)? syncEngagementOverride,
    Future<void> Function(Map<String, dynamic>)? upsertCatalogOverride,
  }) : _connectivityCheck = connectivityCheck,
       _schoolBoxProvider = schoolBoxProvider,
       _catalogBoxProvider = catalogBoxProvider,
       _pendingOpsBoxProvider = pendingOpsBoxProvider,
       _upsertSchoolOverride = upsertSchoolOverride,
       _syncEngagementOverride = syncEngagementOverride,
       _upsertCatalogOverride = upsertCatalogOverride;

  SupabaseClient get _supabase => Supabase.instance.client;

  Future<Box<dynamic>> get _box async {
    if (_schoolBoxProvider != null) return _schoolBoxProvider();
    _schoolBoxFuture ??= Hive.openBox('school_box');
    return _schoolBoxFuture!;
  }

  Future<Box<dynamic>> get _catalogBox async {
    if (_catalogBoxProvider != null) return _catalogBoxProvider();
    _catalogBoxFuture ??= Hive.openBox('catalog_box');
    return _catalogBoxFuture!;
  }

  Future<Box<dynamic>> get _pendingOpsBox async {
    if (_pendingOpsBoxProvider != null) return _pendingOpsBoxProvider();
    _pendingOpsBoxFuture ??= Hive.openBox('pending_ops_box');
    return _pendingOpsBoxFuture!;
  }

  // User management methods
  Future<void> saveUser(UserModel user) async {
    try {
      await _supabase.from('users').upsert(user.toMap());
      debugPrint("User ${user.email} saved to Supabase.");
    } catch (e) {
      debugPrint("Error saving user to Supabase: $e");
      rethrow;
    }
  }

  Future<UserModel?> getUser(String uid) async {
    try {
      final data =
          await _supabase.from('users').select().eq('id', uid).maybeSingle();
      if (data != null) {
        return UserModel.fromMap(data);
      }
    } catch (e) {
      debugPrint("Error getting user from Supabase: $e");
    }
    return null;
  }

  Future<List<UserModel>> getAllUsers() async {
    try {
      final data = await _supabase.from('users').select().order('created_at');
      return (data as List)
          .map((item) => UserModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      debugPrint("Error getting users from Supabase: $e");
      return <UserModel>[];
    }
  }

  Future<void> updateUserRole(String uid, int role) async {
    try {
      await _supabase.from('users').update({'role': role}).eq('id', uid);
      debugPrint("User $uid role updated to $role.");
    } catch (e) {
      debugPrint("Error updating user role: $e");
      rethrow;
    }
  }

  // 1. Save school contact or lead offline first
  Future<void> saveSchoolProfile(SchoolModel school) async {
    // Save to local Hive box immediately
    final box = await _box;
    await box.put(school.id, school.toMap());

    await syncData();
  }

  Future<SchoolSaveResult> saveSchoolProfileWithStatus(SchoolModel school) async {
    final box = await _box;
    await box.put(school.id, school.toMap());

    final connectivityResult =
        _connectivityCheck != null
            ? await _connectivityCheck()
            : await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return const SchoolSaveResult(
        syncedToDatabase: false,
        message: 'Saved locally. No internet connection.',
      );
    }

    try {
      if (_upsertSchoolOverride != null) {
        await _upsertSchoolOverride(school.toMap());
      } else {
        await _supabase.from('schools').upsert(school.toMap());
      }
      if (_syncEngagementOverride != null) {
        await _syncEngagementOverride(school);
      } else {
        await _syncEngagementToPipeline(school);
      }
      await box.put(school.id, school.copyWithSynced(true).toMap());
      return const SchoolSaveResult(
        syncedToDatabase: true,
        message: 'Saved and synced to database.',
      );
    } catch (e) {
      return SchoolSaveResult(
        syncedToDatabase: false,
        message: 'Saved locally, but database sync failed: $e',
      );
    }
  }

  Future<bool> isSchoolSyncedRemotely(String schoolId) async {
    try {
      final row =
          await _supabase
              .from('schools')
              .select('id')
              .eq('id', schoolId)
              .maybeSingle();
      return row != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> updateSchoolProfile(SchoolModel school) async {
    final updatedSchool = SchoolModel(
      id: school.id,
      name: school.name,
      phone: school.phone,
      county: school.county,
      focusAreas: school.focusAreas,
      bookCategory: school.bookCategory,
      dealerType: school.dealerType,
      shopCategory: school.shopCategory,
      selectedProduct: school.selectedProduct,
      partnerSubtype: school.partnerSubtype,
      latitude: school.latitude,
      longitude: school.longitude,
      photoUrl: school.photoUrl,
      photoPath: school.photoPath,
      capturedBy: school.capturedBy,
      capturedAt: school.capturedAt,
      captureStatus: school.captureStatus,
      contactName: school.contactName,
      contactPhone: school.contactPhone,
      contactTitle: school.contactTitle,
      feedback: school.feedback,
      notes: school.notes,
      samplesLeft: school.samplesLeft,
      sampleBook: school.sampleBook,
      schoolOwnership: school.schoolOwnership,
      schoolOwnershipOther: school.schoolOwnershipOther,
      schoolPopulation: school.schoolPopulation,
      schoolLifecycleStatus: school.schoolLifecycleStatus,
      engagementType: school.engagementType,
      isSynced: false,
      createdAt: school.createdAt,
      updatedAt: DateTime.now(),
    );
    await saveSchoolProfile(updatedSchool);
  }

  Future<void> deleteSchoolProfile(String schoolId) async {
    final box = await _box;
    await box.delete(schoolId);
    try {
      await deleteByIdWithOfflineQueue(table: 'schools', id: schoolId);
    } catch (e) {
      debugPrint("Error deleting school $schoolId from Supabase: $e");
    }
  }

  // 2. Sync pending data to Supabase
  Future<void> syncData() async {
    final connectivityResult =
        _connectivityCheck != null
            ? await _connectivityCheck()
            : await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) return;

    final box = await _box;
    final schools = box.values.map((e) => SchoolModel.fromMap(e)).toList();
    final unsynced = schools.where((f) => !f.isSynced).toList();

    for (var school in unsynced) {
      try {
        if (_upsertSchoolOverride != null) {
          await _upsertSchoolOverride(school.toMap());
        } else {
          await _supabase.from('schools').upsert(school.toMap());
        }
        if (_syncEngagementOverride != null) {
          await _syncEngagementOverride(school);
        } else {
          await _syncEngagementToPipeline(school);
        }

        // Preserve all existing fields and only flip sync state.
        final updatedSchool = school.copyWithSynced(true);
        await box.put(school.id, updatedSchool.toMap());
      } catch (e) {
        debugPrint("Sync Error for ${school.id}: $e");
      }
    }

    // Sync Books (Catalog Items)
    final catalogBox = await _catalogBox;
    final catalogs =
        catalogBox.values
            .map((e) => CatalogItemModel.fromMap(Map<String, dynamic>.from(e)))
            .toList();
    final unsyncedCatalogs = catalogs.where((c) => !c.isSynced).toList();

    for (var catalog in unsyncedCatalogs) {
      try {
        if (_upsertCatalogOverride != null) {
          await _upsertCatalogOverride(catalog.toMap());
        } else {
          await _supabase
              .from('catalog_items')
              .upsert(catalog.toMap(), onConflict: 'sku');
        }

        // Update local status to synced
        final updatedCatalog = CatalogItemModel(
          id: catalog.id,
          name: catalog.name,
          category: catalog.category,
          sku: catalog.sku,
          itemType: catalog.itemType,
          unitPrice: catalog.unitPrice,
          stockQty: catalog.stockQty,
          description: catalog.description,
          isActive: catalog.isActive,
          isSynced: true,
        );
        await catalogBox.put(catalog.sku, updatedCatalog.toMap());
      } catch (e) {
        debugPrint("Sync Error for Catalog ${catalog.sku}: $e");
      }
    }

    await _syncPendingOps();
  }

  // 3. Get all school contacts for UI
  Future<List<SchoolModel>> getAllSchoolProfiles() async {
    final box = await _box;
    return box.values.map((e) => SchoolModel.fromMap(e)).toList();
  }

  Future<List<SchoolModel>> getAllSchools() async {
    // Attempt a sync before read so UI reflects latest server state.
    try {
      await syncData();
    } catch (e) {
      debugPrint("Pre-fetch sync failed: $e");
    }

    final localSchools = await getAllSchoolProfiles();
    try {
      final data = await _supabase.from('schools').select().order('created_at');
      final remoteSchools =
          (data as List)
              .map(
                (item) => SchoolModel.fromMap(
                  Map<String, dynamic>.from(item),
                ).copyWithSynced(true),
              )
              .toList();

      final merged = <String, SchoolModel>{
        for (final school in localSchools) school.id: school,
        for (final school in remoteSchools) school.id: school,
      };

      return merged.values.toList();
    } catch (e) {
      debugPrint("Error getting schools from Supabase: $e");
      return localSchools;
    }
  }

  Future<List<TaskModel>> getAllTasks() async {
    try {
      final data = await _supabase
          .from('tasks')
          .select()
          .order('created_at', ascending: false);
      return (data as List)
          .map((item) => TaskModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      debugPrint("Error getting tasks from Supabase: $e");
      return <TaskModel>[];
    }
  }

  Future<List<TaskModel>> getTasksForRole(int role) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return <TaskModel>[];

      final data = await _supabase
          .from('tasks')
          .select()
          .or('target_role.eq.$role,assigned_to.eq.$currentUserId')
          .order('created_at', ascending: false);
      return (data as List)
          .map((item) => TaskModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      debugPrint("Error getting tasks for role $role from Supabase: $e");
      return <TaskModel>[];
    }
  }

  Future<void> createTask(TaskModel task) async {
    try {
      await _supabase.from('tasks').insert(task.toMap());
      debugPrint("Task ${task.title} saved to Supabase.");
    } catch (e) {
      debugPrint("Error saving task to Supabase: $e");
      rethrow;
    }
  }

  Future<void> deleteTask(String taskId) async {
    try {
      await deleteByIdWithOfflineQueue(table: 'tasks', id: taskId);
      debugPrint("Task $taskId deleted from Supabase.");
    } catch (e) {
      debugPrint("Error deleting task $taskId from Supabase: $e");
      rethrow;
    }
  }

  Future<void> updateTaskStatus(String taskId, String status) async {
    try {
      await updateByIdWithOfflineQueue(
        table: 'tasks',
        id: taskId,
        payload: {'status': status},
      );
      debugPrint("Task $taskId status updated to $status.");
    } catch (e) {
      debugPrint("Error updating task $taskId status: $e");
      rethrow;
    }
  }

  Future<int> getCurrentUserRole() async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return 3; // Default to field agent
    final user = await getUser(currentUser.id);
    return user?.role ?? 3;
  }

  String? getCurrentUserId() {
    return _supabase.auth.currentUser?.id;
  }

  Future<bool> schoolExists(String schoolId) async {
    try {
      final row = await _supabase
          .from('schools')
          .select('id')
          .eq('id', schoolId)
          .maybeSingle();
      return row != null;
    } catch (e) {
      debugPrint("Error checking school existence for $schoolId: $e");
      return false;
    }
  }

  Future<List<MessageModel>> getMessagesForCurrentUser() async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return <MessageModel>[];

      final data = await _supabase
          .from('messages')
          .select()
          .or(
            'sender_id.eq.${currentUser.id},recipient_id.eq.${currentUser.id}',
          )
          .order('created_at', ascending: false);

      return (data as List)
          .map((item) => MessageModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      debugPrint("Error getting messages from Supabase: $e");
      return <MessageModel>[];
    }
  }

  Future<void> sendMessage(MessageModel message) async {
    try {
      await _supabase.from('messages').insert(message.toMap());
      debugPrint("Message ${message.id} saved to Supabase.");
    } catch (e) {
      debugPrint("Error saving message to Supabase: $e");
      rethrow;
    }
  }

  Future<List<CatalogItemModel>> getCatalogItems({
    String? itemType,
    bool activeOnly = true,
  }) async {
    final box = await _catalogBox;
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (!connectivityResult.contains(ConnectivityResult.none)) {
        final response =
            itemType == null
                ? await _supabase
                    .from('catalog_items')
                    .select()
                    .order('category')
                    .order('name')
                : await _supabase
                    .from('catalog_items')
                    .select()
                    .eq('item_type', itemType)
                    .order('category')
                    .order('name');

        final items =
            (response as List)
                .map(
                  (item) => CatalogItemModel.fromMap(
                    Map<String, dynamic>.from(item as Map),
                  ),
                )
                .toList();

        // Cache items locally to ensure offline availability
        for (var item in items) {
          await box.put(item.sku, item.toMap());
        }
      }
    } catch (e) {
      debugPrint("Error fetching catalog items from Supabase: $e");
    }

    // Read from local cache
    var cachedItems =
        box.values
            .map((e) => CatalogItemModel.fromMap(Map<String, dynamic>.from(e)))
            .toList();

    if (itemType != null) {
      cachedItems =
          cachedItems.where((item) => item.itemType == itemType).toList();
    }
    if (activeOnly) {
      cachedItems = cachedItems.where((item) => item.isActive).toList();
    }

    cachedItems.sort((a, b) => a.name.compareTo(b.name));
    return cachedItems;
  }

  Future<List<CatalogItemModel>> getSampleCatalogItemsFromTable() async {
    try {
      final response = await _supabase
          .from('catalog_items')
          .select()
          .order('name', ascending: true);

      final items = List<Map<String, dynamic>>.from(response)
          .where((row) {
            final isActive = (row['is_active'] ?? true) == true;
            final itemType = (row['item_type'] ?? '').toString().toLowerCase();
            return isActive && itemType.contains('sample');
          })
          .map((row) => CatalogItemModel.fromMap(Map<String, dynamic>.from(row)))
          .toList();

      final box = await _catalogBox;
      for (final item in items) {
        await box.put(item.sku, item.toMap());
      }
      return items;
    } catch (e) {
      debugPrint('Error fetching sample catalog items: $e');
      final fallback = await getCatalogItems(itemType: null, activeOnly: true);
      return fallback
          .where((item) => item.itemType.trim().toLowerCase().contains('sample'))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
    }
  }

  Future<void> upsertCatalogItems(List<CatalogItemModel> items) async {
    try {
      if (items.isEmpty) return;
      final box = await _catalogBox;
      for (var item in items) {
        // Force isSynced false until the background sync guarantees successful push
        final localItem = CatalogItemModel(
          id: item.id,
          name: item.name,
          category: item.category,
          sku: item.sku,
          itemType: item.itemType,
          unitPrice: item.unitPrice,
          stockQty: item.stockQty,
          description: item.description,
          isActive: item.isActive,
          isSynced: false,
        );
        await box.put(item.sku, localItem.toMap());
      }
      await syncData(); // Push unsynced data immediately
    } catch (e) {
      debugPrint("Error saving catalog items locally: $e");
      rethrow;
    }
  }

  Future<void> decrementCatalogStock(String itemId, int quantity) async {
    try {
      final current =
          await _supabase
              .from('catalog_items')
              .select('stock_qty')
              .eq('id', itemId)
              .maybeSingle();
      final currentStock = (current?['stock_qty'] as num?)?.toInt() ?? 0;
      final newStock = (currentStock - quantity).clamp(0, 1 << 30);
      await _supabase
          .from('catalog_items')
          .update({'stock_qty': newStock})
          .eq('id', itemId);
    } catch (e) {
      debugPrint("Error updating catalog stock: $e");
      rethrow;
    }
  }

  Future<void> recordSampleDistribution({
    required String schoolId,
    required String sampleName,
    required String sampleCategory,
    String? agentId,
    int quantity = 1,
    String? notes,
    String? stampedReceiptUrl,
    String? stampedReceiptPath,
  }) async {
    try {
      final payload = <String, dynamic>{
        'school_id': schoolId,
        'agent_id': agentId ?? getCurrentUserId(),
        'sample_name': sampleName,
        'sample_category': sampleCategory,
        'quantity': quantity,
        'stamped_receipt_url': stampedReceiptUrl,
        'stamped_receipt_path': stampedReceiptPath,
        'notes': notes,
        'distributed_at': DateTime.now().toIso8601String(),
      };
      await _insertWithOfflineQueue(
        table: 'school_sample_distributions',
        payload: payload,
      );
    } catch (e) {
      debugPrint("Error saving sample distribution record: $e");
      rethrow;
    }
  }

  Future<void> saveDebtCollection({
    required String schoolId,
    required double amount,
    required String paymentMethod,
    String? paymentReference,
    String? notes,
    DateTime? collectedAt,
  }) async {
    final payload = <String, dynamic>{
      'school_id': schoolId,
      'collected_by': getCurrentUserId(),
      'amount': amount,
      'payment_method': paymentMethod,
      'payment_reference': paymentReference,
      'notes': notes,
      'collected_at': (collectedAt ?? DateTime.now()).toIso8601String(),
    };
    await _insertWithOfflineQueue(table: 'debt_collections', payload: payload);
  }

  Future<void> _insertWithOfflineQueue({
    required String table,
    required Map<String, dynamic> payload,
  }) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (!connectivityResult.contains(ConnectivityResult.none)) {
      await _supabase.from(table).insert(payload);
      return;
    }
    final pendingBox = await _pendingOpsBox;
    final op = <String, dynamic>{
      'table': table,
      'payload': payload,
      'created_at': DateTime.now().toIso8601String(),
    };
    await pendingBox.add(op);
  }

  Future<void> insertWithOfflineQueue({
    required String table,
    required Map<String, dynamic> payload,
  }) async {
    await _insertWithOfflineQueue(table: table, payload: payload);
  }

  Future<void> upsertWithOfflineQueue({
    required String table,
    required Map<String, dynamic> payload,
    String? onConflict,
  }) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (!connectivityResult.contains(ConnectivityResult.none)) {
      await _supabase.from(table).upsert(payload, onConflict: onConflict);
      return;
    }
    final pendingBox = await _pendingOpsBox;
    final op = <String, dynamic>{
      'op': 'upsert',
      'table': table,
      'payload': payload,
      'on_conflict': onConflict,
      'created_at': DateTime.now().toIso8601String(),
    };
    await pendingBox.add(op);
  }

  Future<void> updateByIdWithOfflineQueue({
    required String table,
    required String id,
    required Map<String, dynamic> payload,
  }) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (!connectivityResult.contains(ConnectivityResult.none)) {
      await _supabase.from(table).update(payload).eq('id', id);
      return;
    }
    final pendingBox = await _pendingOpsBox;
    await pendingBox.add({
      'op': 'update',
      'table': table,
      'id': id,
      'payload': payload,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteByIdWithOfflineQueue({
    required String table,
    required String id,
  }) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (!connectivityResult.contains(ConnectivityResult.none)) {
      await _supabase.from(table).delete().eq('id', id);
      return;
    }
    final pendingBox = await _pendingOpsBox;
    await pendingBox.add({
      'op': 'delete',
      'table': table,
      'id': id,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _syncPendingOps() async {
    final pendingBox = await _pendingOpsBox;
    final keys = pendingBox.keys.toList();
    for (final key in keys) {
      final raw = pendingBox.get(key);
      if (raw is! Map) continue;
      final table = raw['table']?.toString();
      final opType = raw['op']?.toString() ?? 'insert';
      final rowId = raw['id']?.toString();
      final payloadRaw = raw['payload'];
      if (table == null) {
        await pendingBox.delete(key);
        continue;
      }
      try {
        if (opType == 'upsert') {
          if (payloadRaw is! Map) {
            await pendingBox.delete(key);
            continue;
          }
          final payload = Map<String, dynamic>.from(payloadRaw);
          await _supabase
              .from(table)
              .upsert(payload, onConflict: raw['on_conflict']?.toString());
        } else if (opType == 'update') {
          if (rowId == null || payloadRaw is! Map) {
            await pendingBox.delete(key);
            continue;
          }
          final payload = Map<String, dynamic>.from(payloadRaw);
          await _supabase.from(table).update(payload).eq('id', rowId);
        } else if (opType == 'delete') {
          if (rowId == null) {
            await pendingBox.delete(key);
            continue;
          }
          await _supabase.from(table).delete().eq('id', rowId);
        } else {
          if (payloadRaw is! Map) {
            await pendingBox.delete(key);
            continue;
          }
          final payload = Map<String, dynamic>.from(payloadRaw);
          await _supabase.from(table).insert(payload);
        }
        await pendingBox.delete(key);
      } catch (e) {
        debugPrint("Pending op sync failed for $table: $e");
      }
    }
  }

  Future<List<OrderModel>> getOrdersForCurrentUser() async {
    try {
      final data = await _supabase
          .from('orders')
          .select()
          .order('created_at', ascending: false);
      return (data as List)
          .map((item) => OrderModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      debugPrint("Error getting orders from Supabase: $e");
      return <OrderModel>[];
    }
  }

  Future<List<OrderItemModel>> getOrderItems(String orderId) async {
    try {
      final data = await _supabase
          .from('order_items')
          .select()
          .eq('order_id', orderId)
          .order('created_at', ascending: true);
      return (data as List)
          .map(
            (item) => OrderItemModel.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList();
    } catch (e) {
      debugPrint("Error getting order items from Supabase: $e");
      return <OrderItemModel>[];
    }
  }

  Future<OrderModel> createOrder({
    required OrderModel order,
    required List<OrderItemModel> items,
  }) async {
    OrderModel? savedOrder;
    try {
      final insertedOrder =
          await _supabase
              .from('orders')
              .insert(order.toMap())
              .select()
              .single();
      savedOrder = OrderModel.fromMap(
        Map<String, dynamic>.from(insertedOrder as Map),
      );

      if (items.isNotEmpty) {
        final currentSavedOrder = savedOrder;
        final payload =
            items.map((item) {
              final map = item.toMap();
              map['order_id'] = currentSavedOrder.id;
              return map;
            }).toList();
        await _supabase.from('order_items').insert(payload);
      }

      debugPrint("Order ${savedOrder.orderNumber} saved to Supabase.");
      return savedOrder;
    } catch (e) {
      if (savedOrder != null) {
        try {
          await _supabase.from('orders').delete().eq('id', savedOrder.id);
        } catch (rollbackError) {
          debugPrint(
            "Rollback failed for order ${savedOrder.id}: $rollbackError",
          );
        }
      }
      debugPrint("Error creating order in Supabase: $e");
      rethrow;
    }
  }

  Future<OrderModel> createOrderWithSchoolSale({
    required OrderModel order,
    required List<OrderItemModel> items,
    required SchoolSaleModel sale,
  }) async {
    try {
      final result = await _supabase.rpc(
        'create_school_sale_checkout',
        params: {
          'order_payload': order.toMap(),
          'items_payload': items.map((item) => item.toMap()).toList(),
          'sale_payload': sale.toMap(),
        },
      );

      final response = Map<String, dynamic>.from(result as Map);
      final orderMap = Map<String, dynamic>.from(response['order'] as Map);
      return OrderModel.fromMap(orderMap);
    } catch (e) {
      debugPrint("Error creating atomic checkout transaction: $e");
      rethrow;
    }
  }

  Future<void> markMessageRead(String id) async {
    try {
      await updateByIdWithOfflineQueue(
        table: 'messages',
        id: id,
        payload: {'is_read': true},
      );
    } catch (e) {
      debugPrint("Error marking message read: $e");
      rethrow;
    }
  }

  Future<void> deleteMessage(String id) async {
    try {
      await deleteByIdWithOfflineQueue(table: 'messages', id: id);
    } catch (e) {
      debugPrint("Error deleting message: $e");
      rethrow;
    }
  }

  Future<SchoolSaleModel?> getLatestSchoolSale(String schoolId) async {
    try {
      final data =
          await _supabase
              .from('school_sales')
              .select()
              .eq('school_id', schoolId)
              .order('updated_at', ascending: false)
              .limit(1)
              .maybeSingle();
      if (data == null) return null;
      return SchoolSaleModel.fromMap(Map<String, dynamic>.from(data));
    } catch (e) {
      debugPrint("Error loading latest school sale: $e");
      return null;
    }
  }

  Future<void> saveSchoolSale(SchoolSaleModel sale) async {
    try {
      await _supabase.from('school_sales').upsert(sale.toMap());
    } catch (e) {
      debugPrint("Error saving school sale: $e");
      rethrow;
    }
  }

  Future<void> createSchoolFollowUp({
    required String schoolId,
    required String nextStep,
    required DateTime dueAt,
    String? notes,
  }) async {
    try {
      await _supabase.from('school_follow_ups').insert({
        'school_id': schoolId,
        'agent_id': getCurrentUserId(),
        'next_step': nextStep,
        'due_at': dueAt.toIso8601String(),
        'notes': notes,
        'follow_up_status': 'open',
      });
    } catch (e) {
      debugPrint("Error creating school follow-up: $e");
      rethrow;
    }
  }

  Future<void> _syncEngagementToPipeline(SchoolModel school) async {
    final engagement = (school.engagementType ?? '').trim();
    if (engagement.isEmpty) return;

    final mappedStage = _pipelineStageFromEngagement(engagement);
    final latestSale = await getLatestSchoolSale(school.id);

    if (latestSale == null) {
      final sale = SchoolSaleModel(
        schoolId: school.id,
        agentId: getCurrentUserId(),
        packageName: engagement,
        expectedValue: 0,
        notes: 'Auto-created from onboarding engagement type: $engagement',
        stage: mappedStage,
        stageUpdatedAt: DateTime.now(),
        probability: _probabilityFromStage(mappedStage),
        isSynced: true,
      );
      await saveSchoolSale(sale);
      return;
    }

    final updated = SchoolSaleModel(
      id: latestSale.id,
      schoolId: latestSale.schoolId,
      agentId: latestSale.agentId ?? getCurrentUserId(),
      packageName:
          latestSale.packageName.isNotEmpty
              ? latestSale.packageName
              : engagement,
      expectedValue: latestSale.expectedValue,
      notes: latestSale.notes,
      stage: mappedStage,
      stageUpdatedAt: DateTime.now(),
      expectedCloseDate: latestSale.expectedCloseDate,
      probability: _probabilityFromStage(mappedStage),
      closedAt: latestSale.closedAt,
      isSynced: true,
      createdAt: latestSale.createdAt,
      updatedAt: DateTime.now(),
    );
    await saveSchoolSale(updated);
  }

  PipelineStage _pipelineStageFromEngagement(String engagement) {
    switch (engagement.toLowerCase()) {
      case 'cold lead':
      case 'new prospect':
        return PipelineStage.lead;
      case 'warm lead':
        return PipelineStage.contacted;
      case 'follow-up':
        return PipelineStage.decisionPending;
      case 'existing relationship':
        return PipelineStage.negotiation;
      default:
        return PipelineStage.lead;
    }
  }

  int _probabilityFromStage(PipelineStage stage) {
    switch (stage) {
      case PipelineStage.lead:
        return 10;
      case PipelineStage.contacted:
        return 25;
      case PipelineStage.meetingScheduled:
        return 35;
      case PipelineStage.sampleIssued:
        return 45;
      case PipelineStage.quotationSent:
        return 60;
      case PipelineStage.decisionPending:
        return 70;
      case PipelineStage.negotiation:
        return 80;
      case PipelineStage.won:
        return 100;
      case PipelineStage.lost:
        return 0;
      case PipelineStage.dormant:
        return 5;
    }
  }
}

class SchoolSaveResult {
  const SchoolSaveResult({required this.syncedToDatabase, required this.message});

  final bool syncedToDatabase;
  final String message;
}
