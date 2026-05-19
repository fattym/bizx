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

  SupabaseClient get _supabase => Supabase.instance.client;

  Future<Box<dynamic>> get _box async {
    _schoolBoxFuture ??= Hive.openBox('school_box');
    return _schoolBoxFuture!;
  }

  Future<Box<dynamic>> get _catalogBox async {
    _catalogBoxFuture ??= Hive.openBox('catalog_box');
    return _catalogBoxFuture!;
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

  Future<void> updateSchoolProfile(SchoolModel school) async {
    final updatedSchool = SchoolModel(
      id: school.id,
      name: school.name,
      phone: school.phone,
      county: school.county,
      focusAreas: school.focusAreas,
      bookCategory: school.bookCategory,
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
      await _supabase.from('schools').delete().eq('id', schoolId);
    } catch (e) {
      debugPrint("Error deleting school $schoolId from Supabase: $e");
    }
  }

  // 2. Sync pending data to Supabase
  Future<void> syncData() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) return;

    final box = await _box;
    final schools = box.values.map((e) => SchoolModel.fromMap(e)).toList();
    final unsynced = schools.where((f) => !f.isSynced).toList();

    for (var school in unsynced) {
      try {
        await _supabase.from('schools').upsert(school.toMap());
        await _syncEngagementToPipeline(school);

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
        await _supabase
            .from('catalog_items')
            .upsert(catalog.toMap(), onConflict: 'sku');

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
          .or(
            'target_role.eq.$role,assigned_to.eq.$currentUserId',
          )
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

  Future<int> getCurrentUserRole() async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return 3; // Default to field agent
    final user = await getUser(currentUser.id);
    return user?.role ?? 3;
  }

  String? getCurrentUserId() {
    return _supabase.auth.currentUser?.id;
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
      final newStock = (currentStock - quantity).clamp(0, 1 << 30) as int;
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
    int quantity = 1,
    String? notes,
    String? stampedReceiptUrl,
    String? stampedReceiptPath,
  }) async {
    try {
      await _supabase.from('school_sample_distributions').insert({
        'school_id': schoolId,
        'agent_id': getCurrentUserId(),
        'sample_name': sampleName,
        'sample_category': sampleCategory,
        'quantity': quantity,
        'stamped_receipt_url': stampedReceiptUrl,
        'stamped_receipt_path': stampedReceiptPath,
        'notes': notes,
        'distributed_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint("Error saving sample distribution record: $e");
      rethrow;
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
              map['order_id'] = currentSavedOrder!.id;
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

  Future<void> markMessageRead(String id) async {
    try {
      await _supabase.from('messages').update({'is_read': true}).eq('id', id);
    } catch (e) {
      debugPrint("Error marking message read: $e");
      rethrow;
    }
  }

  Future<void> deleteMessage(String id) async {
    try {
      await _supabase.from('messages').delete().eq('id', id);
    } catch (e) {
      debugPrint("Error deleting message: $e");
      rethrow;
    }
  }

  Future<SchoolSaleModel?> getLatestSchoolSale(String schoolId) async {
    try {
      final data = await _supabase
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
      packageName: latestSale.packageName.isNotEmpty
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
