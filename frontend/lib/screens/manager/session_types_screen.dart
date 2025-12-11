import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../services/manager_session_type_service.dart';

class SessionTypesScreen extends StatefulWidget {
  @override
  _SessionTypesScreenState createState() => _SessionTypesScreenState();
}

class _SessionTypesScreenState extends State<SessionTypesScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _pendingSessionTypes = [];
  List<Map<String, dynamic>> _allSessionTypes = [];
  Map<String, dynamic> _institution = {};
  int _totalPending = 0;

  int _selectedTab = 0; // 0 = Pending, 1 = All

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load pending session types
      final pendingResponse = await ManagerSessionTypeService.getPendingSessionTypes();
      final pendingData = pendingResponse['data'] ?? {};

      // Load all session types
      final allResponse = await ManagerSessionTypeService.getAllSessionTypes();
      final allData = allResponse['data'] ?? {};

      // معالجة وتحويل البيانات
      List<Map<String, dynamic>> processSessionTypes(List<dynamic> rawList) {
        return List<Map<String, dynamic>>.from(rawList.map((item) {
          final Map<String, dynamic> processed = Map<String, dynamic>.from(item);

          // تحويل السعر إذا كان String
          if (processed['price'] is String) {
            processed['price'] = double.tryParse(processed['price'].toString()) ?? 0.0;
          }

          // تحويل المدة إذا كانت String
          if (processed['duration'] is String) {
            processed['duration'] = int.tryParse(processed['duration'].toString()) ?? 0;
          }

          // معالجة target_conditions إذا كانت List وتحويلها إلى String
          final targetConditions = processed['target_conditions'];
          if (targetConditions != null) {
            if (targetConditions is List) {
              processed['target_conditions'] = targetConditions.join(', ');
            }
          }

          return processed;
        }).toList());
      }

      setState(() {
        _institution = pendingData['institution'] ?? {};
        _totalPending = pendingData['total_pending'] ?? 0;
        _pendingSessionTypes = processSessionTypes(pendingData['session_types'] ?? []);
        _allSessionTypes = processSessionTypes(allData['session_types'] ?? []);
      });
    } catch (e) {
      print('Error loading session types data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load session types data'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateSessionTypeApproval(int sessionTypeId, String status, {double? price}) async {
    try {
      await ManagerSessionTypeService.updateSessionTypeApproval(
        sessionTypeId: sessionTypeId,
        approvalStatus: status,
        price: price,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Session type $status successfully'),
          backgroundColor: status == 'Approved' ? AppColors.success : AppColors.error,
        ),
      );

      await _loadData();
    } catch (e) {
      print('Error updating session type: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update session type: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showApproveDialog(Map<String, dynamic> sessionType) async {
    // تحويل السعر من String إلى double أولاً
    final priceString = sessionType['price']?.toString() ?? '0';
    final priceValue = double.tryParse(priceString) ?? 0.0;

    TextEditingController priceController = TextEditingController(
      text: priceValue.toString(),
    );

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(Icons.price_check_rounded, color: AppColors.success, size: 24),
                SizedBox(width: 12),
                Text(
                  'Approve Session Type',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
            content: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_rounded,
                          size: 20,
                          color: AppColors.success,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Please set the final price for this session type',
                            style: TextStyle(
                              color: AppColors.textGray,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Session Type: ${sessionType['name']}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Duration: ${sessionType['duration']} minutes',
                    style: TextStyle(
                      color: AppColors.textGray,
                    ),
                  ),
                  SizedBox(height: 20),
                  TextField(
                    controller: priceController,
                    decoration: InputDecoration(
                      labelText: 'Final Price (\$)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: EdgeInsets.all(16),
                      prefixText: '\$ ',
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textGray,
                ),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final price = double.tryParse(priceController.text);
                  if (price == null || price <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Please enter a valid price'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  Navigator.pop(context);
                  _updateSessionTypeApproval(sessionType['session_type_id'], 'Approved', price: price);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                ),
                child: Text('Approve'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showAddSessionTypeDialog() async {
    TextEditingController nameController = TextEditingController();
    TextEditingController durationController = TextEditingController(text: '60');
    TextEditingController priceController = TextEditingController(text: '50');
    TextEditingController specializationController = TextEditingController();
    TextEditingController conditionsController = TextEditingController();

    String? selectedCategory;
    final List<String> categories = ['Speech', 'Behavioral', 'Occupational', 'Educational'];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(Icons.add_circle_rounded, color: AppColors.primary, size: 24),
                SizedBox(width: 12),
                Text(
                  'Add New Session Type',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.8,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Session Type Name *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: EdgeInsets.all(16),
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: durationController,
                            decoration: InputDecoration(
                              labelText: 'Duration (minutes) *',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: EdgeInsets.all(16),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: priceController,
                            decoration: InputDecoration(
                              labelText: 'Price (\$) *',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: EdgeInsets.all(16),
                              prefixText: '\$ ',
                            ),
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: InputDecoration(
                        labelText: 'Category *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: EdgeInsets.all(16),
                      ),
                      items: categories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedCategory = value;
                        });
                      },
                      validator: (value) {
                        if (value == null) return 'Please select a category';
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: specializationController,
                      decoration: InputDecoration(
                        labelText: 'Specialist Specialization *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: EdgeInsets.all(16),
                        hintText: 'e.g., Speech Therapy, Behavioral Analysis',
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: conditionsController,
                      decoration: InputDecoration(
                        labelText: 'Target Conditions (Optional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: EdgeInsets.all(16),
                        hintText: 'Comma-separated conditions',
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textGray,
                ),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.isEmpty ||
                      durationController.text.isEmpty ||
                      priceController.text.isEmpty ||
                      selectedCategory == null ||
                      specializationController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Please fill all required fields'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  final duration = int.tryParse(durationController.text);
                  final price = double.tryParse(priceController.text);

                  if (duration == null || duration <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Please enter a valid duration'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  if (price == null || price <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Please enter a valid price'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  try {
                    await ManagerSessionTypeService.addSessionType(
                      name: nameController.text,
                      duration: duration,
                      price: price,
                      category: selectedCategory!,
                      specialistSpecialization: specializationController.text,
                      targetConditions: conditionsController.text.isNotEmpty ? conditionsController.text : null,
                    );

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Session type added successfully'),
                        backgroundColor: AppColors.success,
                      ),
                    );

                    Navigator.pop(context);
                    await _loadData();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to add session type: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: Text('Add Session Type'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showEditSessionTypeDialog(Map<String, dynamic> sessionType) async {
    TextEditingController nameController = TextEditingController(text: sessionType['name']);
    TextEditingController durationController = TextEditingController(text: sessionType['duration'].toString());
    TextEditingController priceController = TextEditingController(text: sessionType['price'].toString());
    TextEditingController specializationController = TextEditingController(text: sessionType['specialist_specialization']);
    TextEditingController conditionsController = TextEditingController(text: sessionType['target_conditions']?.toString() ?? '');

    String? selectedCategory = sessionType['category'];
    final List<String> categories = ['Speech', 'Behavioral', 'Occupational', 'Educational'];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(Icons.edit_rounded, color: AppColors.primary, size: 24),
                SizedBox(width: 12),
                Text(
                  'Edit Session Type',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.8,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Session Type Name *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: EdgeInsets.all(16),
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: durationController,
                            decoration: InputDecoration(
                              labelText: 'Duration (minutes) *',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: EdgeInsets.all(16),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: priceController,
                            decoration: InputDecoration(
                              labelText: 'Price (\$) *',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: EdgeInsets.all(16),
                              prefixText: '\$ ',
                            ),
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: InputDecoration(
                        labelText: 'Category *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: EdgeInsets.all(16),
                      ),
                      items: categories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedCategory = value;
                        });
                      },
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: specializationController,
                      decoration: InputDecoration(
                        labelText: 'Specialist Specialization *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: EdgeInsets.all(16),
                        hintText: 'e.g., Speech Therapy, Behavioral Analysis',
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: conditionsController,
                      decoration: InputDecoration(
                        labelText: 'Target Conditions (Optional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: EdgeInsets.all(16),
                        hintText: 'Comma-separated conditions',
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textGray,
                ),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.isEmpty ||
                      durationController.text.isEmpty ||
                      priceController.text.isEmpty ||
                      selectedCategory == null ||
                      specializationController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Please fill all required fields'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  final duration = int.tryParse(durationController.text);
                  final price = double.tryParse(priceController.text);

                  if (duration == null || duration <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Please enter a valid duration'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  if (price == null || price <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Please enter a valid price'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  try {
                    // TODO: يجب إضافة دالة editSessionType في ManagerSessionTypeService
                    await ManagerSessionTypeService.editSessionType(
                      sessionTypeId: sessionType['session_type_id'],
                      name: nameController.text,
                      duration: duration,
                      price: price,
                      category: selectedCategory!,
                      specialistSpecialization: specializationController.text,
                      targetConditions: conditionsController.text.isNotEmpty ? conditionsController.text : null,
                    );

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Session type updated successfully'),
                        backgroundColor: AppColors.success,
                      ),
                    );

                    Navigator.pop(context);
                    await _loadData();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to update session type: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: Text('Update'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showDeleteConfirmationDialog(Map<String, dynamic> sessionType) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: AppColors.error, size: 24),
            SizedBox(width: 12),
            Text(
              'Delete Session Type',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
        content: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete this session type?',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sessionType['name'],
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.error,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Category: ${sessionType['category']}',
                      style: TextStyle(
                        color: AppColors.textGray,
                      ),
                    ),
                    Text(
                      'Duration: ${sessionType['duration']} min',
                      style: TextStyle(
                        color: AppColors.textGray,
                      ),
                    ),
                    Text(
                      'Price: \$${sessionType['price']}',
                      style: TextStyle(
                        color: AppColors.textGray,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.warning,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_rounded, color: AppColors.warning, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This action cannot be undone. All sessions using this type will need to be reassigned.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textGray,
            ),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteSessionType(sessionType);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }


  Future<void> _deleteSessionType(Map<String, dynamic> sessionType) async {
    try {
      // عرض مؤشر التحميل
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );

      final response = await ManagerSessionTypeService.deleteSessionType(
        sessionTypeId: sessionType['session_type_id'],
      );

      // إغلاق مؤشر التحميل
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['message'] ?? 'Session type deleted successfully'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 3),
        ),
      );

      await _loadData();
    } on Exception catch (e) {
      // إغلاق مؤشر التحميل
      Navigator.pop(context);

      print('Error deleting session type: $e');

      // تحقق إذا كان الخطأ بسبب جلسات مستقبلية
      String errorMessage = e.toString();

      if (errorMessage.contains('future sessions') ||
          errorMessage.contains('Cannot delete') ||
          errorMessage.contains('blocking')) {

        // عرض ديالوج توضيحي للجلسات المانعة
        await _showFutureSessionsBlockingDialog(sessionType, errorMessage);

      } else {
        // عرض رسالة خطأ عادية
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage.replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      // إغلاق مؤشر التحميل
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An unexpected error occurred'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showFutureSessionsBlockingDialog(Map<String, dynamic> sessionType, String errorMessage) async {
    // استخراج عدد الجلسات من الرسالة (إذا وجد)
    int futureSessionsCount = 0;
    final regex = RegExp(r'(\d+)\s*(future|جلسات)');
    final match = regex.firstMatch(errorMessage);
    if (match != null) {
      futureSessionsCount = int.tryParse(match.group(1)!) ?? 0;
    }

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.event_busy_rounded, color: AppColors.warning, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Cannot Delete Session Type',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // اسم نوع الجلسة
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.category_rounded, color: AppColors.primary, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Session Type:',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textLight,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            sessionType['name'],
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20),

              // رسالة الخطأ الرئيسية
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.error_outline_rounded, color: AppColors.warning, size: 22),
                        SizedBox(width: 10),
                        Text(
                          'Cannot Delete',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.warning,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      'There are future sessions scheduled using this session type.',
                      style: TextStyle(
                        color: AppColors.textDark,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    if (futureSessionsCount > 0) ...[
                      SizedBox(height: 8),
                      Text(
                        'Found $futureSessionsCount future session${futureSessionsCount > 1 ? 's' : ''}.',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              SizedBox(height: 20),

              // أسباب المنع
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accent2.withOpacity(0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Why you cannot delete:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 12),
                    _buildReasonItem(
                      icon: Icons.event_available_rounded,
                      iconColor: AppColors.success,
                      text: 'Future sessions are scheduled',
                    ),
                    SizedBox(height: 8),
                    _buildReasonItem(
                      icon: Icons.pending_actions_rounded,
                      iconColor: AppColors.warning,
                      text: 'Sessions have active status (Scheduled, Confirmed, etc.)',
                    ),
                    SizedBox(height: 8),
                    _buildReasonItem(
                      icon: Icons.link_rounded,
                      iconColor: AppColors.primary,
                      text: 'Sessions are linked to appointments with children',
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20),

              // // الحلول الممكنة
              // Container(
              //   padding: EdgeInsets.all(16),
              //   decoration: BoxDecoration(
              //     color: AppColors.success.withOpacity(0.05),
              //     borderRadius: BorderRadius.circular(12),
              //     border: Border.all(color: AppColors.success.withOpacity(0.3)),
              //   ),
              //   child: Column(
              //     crossAxisAlignment: CrossAxisAlignment.start,
              //     children: [
              //       Row(
              //         children: [
              //           Icon(Icons.lightbulb_rounded, color: AppColors.success, size: 22),
              //           SizedBox(width: 10),
              //           Text(
              //             'What you can do:',
              //             style: TextStyle(
              //               fontWeight: FontWeight.w600,
              //               color: AppColors.success,
              //               fontSize: 14,
              //             ),
              //           ),
              //         ],
              //       ),
              //       SizedBox(height: 12),
              //       _buildSolutionItem(
              //         text: 'Cancel all future sessions using this type',
              //       ),
              //       SizedBox(height: 8),
              //       _buildSolutionItem(
              //         text: 'Reschedule sessions to use a different session type',
              //       ),
              //       SizedBox(height: 8),
              //       _buildSolutionItem(
              //         text: 'Wait until all sessions are completed or cancelled',
              //       ),
              //       SizedBox(height: 8),
              //       _buildSolutionItem(
              //         text: 'Mark the session type as "Inactive" instead of deleting',
              //       ),
              //     ],
              //   ),
              // ),

              SizedBox(height: 16),

              // ملاحظة
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accent4.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.accent4.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_rounded, size: 16, color: AppColors.accent4),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'After resolving all future sessions, you can try deleting again.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.accent4,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [

          SizedBox(width: 8),
          // زر إغلاق
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonItem({required IconData icon, required Color iconColor, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: iconColor),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: AppColors.textDark,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSolutionItem({required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check_rounded, size: 12, color: AppColors.success),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: AppColors.textDark,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showSessionsPreview(Map<String, dynamic> sessionType) async {
    // هنا يمكنك إضافة كود لعرض معاينة للجلسات
    // أو الانتقال إلى شاشة الجلسات
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navigate to sessions screen for "${sessionType['name']}"'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Widget _buildPendingSessionTypeCard(Map<String, dynamic> sessionType) {
    final createdBy = sessionType['created_by'];

    // تحويل السعر من String إلى double
    final priceString = sessionType['price']?.toString() ?? '0';
    final priceValue = double.tryParse(priceString) ?? 0.0;
    final formattedPrice = priceValue.toStringAsFixed(2);

    // تعريف targetConditions هنا
    final targetConditions = sessionType['target_conditions'];
    String? conditionsText;

    if (targetConditions != null && targetConditions.isNotEmpty) {
      if (targetConditions is String) {
        conditionsText = targetConditions;
      } else if (targetConditions is List) {
        conditionsText = targetConditions.join(', ');
      }
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.warning.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: AppColors.warning.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Warning Icon for Pending
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.pending_rounded,
                        color: AppColors.warning,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 12),
                    // Title and Category
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sessionType['name'] ?? 'Unnamed Session',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(height: 4),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getCategoryColor(sessionType['category']).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              sessionType['category'] ?? 'General',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _getCategoryColor(sessionType['category']),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Pending Badge
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'PENDING',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 16),

                // Requested By Info
                if (createdBy != null) ...[
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          child: Icon(
                            Icons.person_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Requested by',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textLight,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                createdBy['full_name'] ?? 'Unknown Specialist',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                createdBy['email'] ?? '',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textGray,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                ],
              ],
            ),
          ),

          // Details Section
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.background.withOpacity(0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Duration and Price
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailItem(
                        icon: Icons.timer_rounded,
                        iconColor: AppColors.primary,
                        title: 'Duration',
                        value: '${sessionType['duration']} min',
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: _buildDetailItem(
                        icon: Icons.price_check_rounded,
                        iconColor: AppColors.warning,
                        title: 'Proposed Price',
                        value: '\$$formattedPrice',
                        valueColor: AppColors.warning,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 12),

                // Specialization
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accent1.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.school_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Specialization: ${sessionType['specialist_specialization'] ?? 'General'}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                // Target Conditions if exists
                if (conditionsText != null && conditionsText.isNotEmpty) ...[
                  SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.ment.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.ment.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.medical_services_rounded,
                              size: 16,
                              color: AppColors.ment,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Target Conditions',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textGray,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          conditionsText,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textDark,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Action Buttons
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border(
                top: BorderSide(
                  color: AppColors.accent2.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _updateSessionTypeApproval(sessionType['session_type_id'], 'Rejected'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.error.withOpacity(0.7)),
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.close_rounded, size: 16),
                        SizedBox(width: 8),
                        Text('Reject'),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _showApproveDialog(sessionType),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_rounded, size: 16),
                        SizedBox(width: 8),
                        Text('Approve'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildAllSessionTypeCard(Map<String, dynamic> sessionType) {
    final status = sessionType['approval_status'] as String? ?? 'Pending';

    // تحويل السعر من String إلى double
    final priceString = sessionType['price']?.toString() ?? '0';
    final priceValue = double.tryParse(priceString) ?? 0.0;
    final formattedPrice = priceValue.toStringAsFixed(2);

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status.toLowerCase()) {
      case 'approved':
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle_rounded;
        statusText = 'Approved';
        break;
      case 'rejected':
        statusColor = AppColors.error;
        statusIcon = Icons.cancel_rounded;
        statusText = 'Rejected';
        break;
      default:
        statusColor = AppColors.warning;
        statusIcon = Icons.pending_rounded;
        statusText = 'Pending';
    }

    // تعريف targetConditions هنا
    final targetConditions = sessionType['target_conditions'];
    String? conditionsText;

    if (targetConditions != null && targetConditions.isNotEmpty) {
      if (targetConditions is String) {
        conditionsText = targetConditions;
      } else if (targetConditions is List) {
        conditionsText = targetConditions.join(', ');
      }
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: statusColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Header Section with Actions
          Container(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // First Row: Title and Status
                Row(
                  children: [
                    // Category Icon
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _getCategoryColor(sessionType['category']).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _getCategoryIcon(sessionType['category']),
                        color: _getCategoryColor(sessionType['category']),
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 12),
                    // Title and Category
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  sessionType['name'] ?? 'Unnamed Session',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textDark,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getCategoryColor(sessionType['category']).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              sessionType['category'] ?? 'General',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _getCategoryColor(sessionType['category']),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Status Badge
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 12, color: statusColor),
                          SizedBox(width: 4),
                          Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 16),

                // Action Buttons Row
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.accent2.withOpacity(0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () => _showEditSessionTypeDialog(sessionType),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            padding: EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(12),
                                bottomLeft: Radius.circular(12),
                              ),
                            ),
                          ),
                          icon: Icon(Icons.edit_rounded, size: 16),
                          label: Text(
                            'Edit',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 20,
                        color: AppColors.accent2.withOpacity(0.5),
                      ),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () => _showDeleteConfirmationDialog(sessionType),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.error,
                            padding: EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.only(
                                topRight: Radius.circular(12),
                                bottomRight: Radius.circular(12),
                              ),
                            ),
                          ),
                          icon: Icon(Icons.delete_rounded, size: 16),
                          label: Text(
                            'Delete',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Details Section
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.background.withOpacity(0.5),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Duration and Price
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailItem(
                        icon: Icons.timer_rounded,
                        iconColor: AppColors.primary,
                        title: 'Duration',
                        value: '${sessionType['duration']} min',
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: _buildDetailItem(
                        icon: Icons.attach_money_rounded,
                        iconColor: AppColors.success,
                        title: 'Price',
                        value: '\$$formattedPrice',
                        valueColor: AppColors.success,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 12),

                // Specialization
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accent1.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.school_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Specialization: ${sessionType['specialist_specialization'] ?? 'General'}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                // Target Conditions if exists
                if (conditionsText != null && conditionsText.isNotEmpty) ...[
                  SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.ment.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.ment.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.medical_services_rounded,
                              size: 16,
                              color: AppColors.ment,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Target Conditions',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textGray,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          conditionsText,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textDark,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],

                // Created Info if available
                if (sessionType['created_by'] != null) ...[
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.accent2.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_rounded,
                          size: 14,
                          color: AppColors.textGray,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Created by: ${sessionType['created_by']['full_name'] ?? 'Unknown'}',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textGray,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

// Helper widget for detail items
  Widget _buildDetailItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    Color? valueColor,
  }) {
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.accent2.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: iconColor),
              SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textLight,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addSessionType({
    required String name,
    required int duration,
    required double price,
    required String category,
    required String specialistSpecialization,
    String? targetConditions,
  }) async {
    try {
      await ManagerSessionTypeService.addSessionType(
        name: name,
        duration: duration,
        price: price,
        category: category,
        specialistSpecialization: specialistSpecialization,
        targetConditions: targetConditions,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Session type added successfully'),
          backgroundColor: AppColors.success,
        ),
      );

      await _loadData();
    } catch (e) {
      print('Error adding session type: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add session type: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Color _getCategoryColor(String? category) {
    switch (category?.toLowerCase()) {
      case 'speech':
        return AppColors.primary;
      case 'behavioral':
        return AppColors.ment;
      case 'occupational':
        return AppColors.success;
      case 'educational':
        return AppColors.warning;
      default:
        return AppColors.textGray;
    }
  }

  IconData _getCategoryIcon(String? category) {
    switch (category?.toLowerCase()) {
      case 'speech':
        return Icons.record_voice_over_rounded;
      case 'behavioral':
        return Icons.psychology_rounded;
      case 'occupational':
        return Icons.work_rounded;
      case 'educational':
        return Icons.school_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _selectedTab == 0 ? Icons.pending_actions_rounded : Icons.category_rounded,
            size: 100,
            color: AppColors.accent4,
          ),
          SizedBox(height: 20),
          Text(
            'No session types found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textGray,
            ),
          ),
          SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textLight,
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadData,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: Icon(Icons.refresh_rounded),
            label: Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.05),
            blurRadius: 15,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Institution Info
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.category_rounded,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _institution['name'] ?? 'Institution',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Session Types Management',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textGray,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 20),

          // Pending Requests Info
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.accent2,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.pending_actions_rounded,
                    color: AppColors.warning,
                    size: 22,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pending Approvals',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '$_totalPending request${_totalPending != 1 ? 's' : ''} waiting for review',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_totalPending > 0)
                  IconButton(
                    icon: Icon(Icons.arrow_forward_rounded, color: AppColors.primary),
                    onPressed: () {
                      setState(() {
                        _selectedTab = 0;
                      });
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.accent2,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _selectedTab = 0),
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _selectedTab == 0 ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        children: [
                          Icon(
                            Icons.pending_actions_rounded,
                            size: 18,
                            color: _selectedTab == 0 ? Colors.white : AppColors.textGray,
                          ),
                          if (_totalPending > 0)
                            Positioned(
                              right: -2,
                              top: -2,
                              child: Container(
                                padding: EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: AppColors.error,
                                  shape: BoxShape.circle,
                                ),
                                constraints: BoxConstraints(
                                  minWidth: 14,
                                  minHeight: 14,
                                ),
                                child: Text(
                                  _totalPending > 9 ? '9+' : '$_totalPending',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Pending ($_totalPending)',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _selectedTab == 0 ? Colors.white : AppColors.textGray,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _selectedTab = 1),
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _selectedTab == 1 ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.category_rounded,
                        size: 18,
                        color: _selectedTab == 1 ? Colors.white : AppColors.textGray,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'All Types',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _selectedTab == 1 ? Colors.white : AppColors.textGray,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentList = _selectedTab == 0 ? _pendingSessionTypes : _allSessionTypes;
    final emptyMessage = _selectedTab == 0
        ? 'No pending session type requests'
        : 'No session types available. Add some session types.';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Session Types',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: _loadData,
          ),
          IconButton(
            icon: Icon(Icons.add_rounded, color: AppColors.primary),
            onPressed: _showAddSessionTypeDialog,
            tooltip: 'Add New Session Type',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 20),
            Text(
              'Loading session types...',
              style: TextStyle(
                color: AppColors.textGray,
                fontSize: 16,
              ),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // Header
              _buildHeader(),

              // Tab Bar
              _buildTabBar(),

              // Content
              if (currentList.isNotEmpty)
                Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedTab == 0 ? 'Pending Requests' : 'All Session Types',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${currentList.length} type${currentList.length != 1 ? 's' : ''}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 8),
                    ...currentList.map((sessionType) => _selectedTab == 0
                        ? _buildPendingSessionTypeCard(sessionType)
                        : _buildAllSessionTypeCard(sessionType)).toList(),
                  ],
                )
              else
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: _buildEmptyState(emptyMessage),
                ),

              SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}