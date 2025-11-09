import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'dart:io';
import '../theme/app_colors.dart';
import '../services/evaluation_service.dart';
import '../services/activity_service.dart';

class AddEvaluationScreen extends StatefulWidget {
  const AddEvaluationScreen({super.key});

  @override
  State<AddEvaluationScreen> createState() => _AddEvaluationScreenState();
}

class _AddEvaluationScreenState extends State<AddEvaluationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _notesController = TextEditingController();

  String? selectedChild;
  int? selectedChildId;
  String evaluationType = 'Initial';
  String notes = '';
  double progressScore = 50;
  DateTime selectedDate = DateTime.now(); // تاريخ اليوم كقيمة افتراضية
  File? selectedFile;

  List<dynamic> childrenList = [];
  bool isLoading = false;
  bool isInitialLoading = true;

  // قائمة بالملاحظات السريعة
  final List<String> quickNotes = [
    'Good progress in communication',
    'Needs more practice with social skills',
    'Excellent participation in activities',
    'Shows improvement in focus and attention',
    'Needs support with emotional regulation',
    'Demonstrated new skills today',
    'Cooperated well with peers',
    'Required minimal prompts',
    'Good eye contact maintained',
    'Responded well to instructions',
    'Showed creativity in problem solving',
    'Needs encouragement to participate',
  ];

  Color getProgressColor(double score) {
    if (score < 40) return Colors.pinkAccent;
    if (score < 70) return Colors.orangeAccent;
    return Colors.greenAccent.shade400;
  }

  @override
  void initState() {
    super.initState();
    loadChildren();
  }

  Future<void> loadChildren() async {
    setState(() {
      isInitialLoading = true;
    });

    try {
      final children = await EvaluationService.getChildrenForCurrentSpecialist();
      setState(() {
        childrenList = children;
      });
    } catch (e) {
      print('Error loading children: $e');
      _showErrorSnackBar('Error loading children: $e');
    } finally {
      setState(() {
        isInitialLoading = false;
      });
    }
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  Future<void> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png', 'txt'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() => selectedFile = File(result.files.single.path!));
    }
  }

  // إضافة ملاحظة سريعة
  void _addQuickNote(String note) {
    setState(() {
      if (notes.isNotEmpty) {
        notes += '\n• $note';
      } else {
        notes = '• $note';
      }
      _notesController.text = notes;
    });
    _showSuccessSnackBar('Note added!');
  }

  void _clearNotes() {
    setState(() {
      notes = '';
      _notesController.clear();
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primary,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void saveEvaluation() async {
    if (_formKey.currentState!.validate() && selectedChildId != null) {
      setState(() {
        isLoading = true;
      });

      try {
        String? attachmentName;

        if (selectedFile != null) {
          final uploadResult = await EvaluationService.uploadFile(selectedFile!);
          attachmentName = uploadResult['filename'];
        }

        final evaluationData = {
          'child_id': selectedChildId,
          'evaluation_type': evaluationType,
          'notes': notes,
          'progress_score': progressScore,
          'attachment': attachmentName,
          'created_at': selectedDate.toIso8601String(), // إرسال التاريخ المختار
        };

        final result = await EvaluationService.addEvaluation(evaluationData);
        _showSuccessSnackBar('✅ ${result['message']}');
        await ActivityService.addActivity(
            'Evaluation added for ${selectedChild}',
            'evaluation'
        );

        // تنظيف الحقول مع الاحتفاظ بالتاريخ الحالي
        _resetForm();

      } catch (e) {
        _showErrorSnackBar('❌ Error: $e');
      } finally {
        setState(() {
          isLoading = false;
        });
      }
    } else if (selectedChildId == null) {
      _showErrorSnackBar('⚠️ Please select a child');
    }
  }

  void _resetForm() {
    _formKey.currentState!.reset();
    setState(() {
      selectedChild = null;
      selectedChildId = null;
      evaluationType = 'Initial';
      notes = '';
      progressScore = 50;
      selectedFile = null;
      // لا نعيد ضبط التاريخ، نبقيه كما هو
    });
    _notesController.clear();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color background = Color(0xFFF6F4FB);

    InputDecoration softInput(String hint) => InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      hintStyle: TextStyle(color: AppColors.primary.withOpacity(0.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text(
          "Add Evaluation",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 20),
        ),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: isInitialLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text(
              'Loading children...',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(18.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _section(
                title: "Select Child",
                child: childrenList.isEmpty
                    ? Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.child_care, size: 48, color: Colors.grey[400]),
                      SizedBox(height: 8),
                      Text(
                        'No children available',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Children with sessions will appear here',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
                    : DropdownSearch<dynamic>(
                  items: (filter, infiniteScrollProps) async => childrenList,
                  selectedItem: selectedChildId != null ?
                  childrenList.firstWhere(
                          (child) => child['id'] == selectedChildId,
                      orElse: () => null
                  ) : null,
                  compareFn: (item1, item2) {
                    if (item1 == null || item2 == null) return false;
                    return item1['id'] == item2['id'];
                  },
                  popupProps: PopupProps.menu(
                    showSearchBox: true,
                    searchFieldProps: TextFieldProps(
                      decoration: softInput("Choose child"),
                    ),
                    itemBuilder: (context, item, isSelected, isFocused) {
                      final childItem = item as Map<String, dynamic>;
                      return ListTile(
                        title: Text(
                          childItem['name'],
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: AppColors.primary,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Parent: ${childItem['parentName']}'),
                            if (childItem['dob'] != null)
                              Text('DOB: ${_formatDate(childItem['dob'])}',
                                  style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      );
                    },
                  ),
                  dropdownBuilder: (context, selectedItem) {
                    if (selectedItem == null) {
                      return Text(
                        'Select a child',
                        style: TextStyle(color: Colors.grey[600]),
                      );
                    }
                    return Text(
                      selectedItem['name'],
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  },
                  validator: (val) => val == null ? 'Please select a child' : null,
                  onChanged: (child) {
                    if (child != null) {
                      setState(() {
                        selectedChildId = child['id'];
                        selectedChild = child['name'];
                      });
                    }
                  },
                ),
              ),

              _section(
                title: "Evaluation Type",
                child: DropdownButtonFormField<String>(
                  decoration: softInput("Select type"),
                  value: evaluationType,
                  items: ['Initial', 'Mid', 'Final', 'Follow-up']
                      .map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(
                      e,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ))
                      .toList(),
                  onChanged: (val) => setState(() => evaluationType = val!),
                ),
              ),

              _section(
                title: "Evaluation Date",
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: pickDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  _getDayName(selectedDate.weekday),
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.calendar_today,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 14, color: Colors.grey[500]),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Default: Today\'s date. Tap to change.',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              _section(
                title: "Notes & Observations",
                child: Column(
                  children: [
                    // الملاحظات السريعة
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue[100]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.lightbulb_outline, size: 20, color: Colors.blue[700]),
                              SizedBox(width: 8),
                              Text(
                                'Quick Notes',
                                style: TextStyle(
                                  color: Colors.blue[700],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Tap to add common observations:',
                            style: TextStyle(
                              color: Colors.blue[600],
                              fontSize: 12,
                            ),
                          ),
                          SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: quickNotes.map((note) {
                              return ActionChip(
                                label: Text(
                                  note.length > 35 ? '${note.substring(0, 35)}...' : note,
                                  style: TextStyle(fontSize: 12),
                                ),
                                onPressed: () => _addQuickNote(note),
                                backgroundColor: Colors.blue[100],
                                labelStyle: TextStyle(color: Colors.blue[900]),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 16),

                    // حقل النص
                    TextFormField(
                      controller: _notesController,
                      maxLines: 6,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 14,
                      ),
                      decoration: softInput("Write detailed notes and observations here..."),
                      onChanged: (val) => setState(() => notes = val),
                    ),

                    SizedBox(height: 12),

                    // أزرار التحكم
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _clearNotes,
                          icon: Icon(Icons.clear, size: 16),
                          label: Text('Clear All'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[300],
                            foregroundColor: Colors.grey[700],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        Spacer(),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: notes.length > 100 ? Colors.green[50] : Colors.orange[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: notes.length > 100 ? Colors.green[100]! : Colors.orange[100]!,
                            ),
                          ),
                          child: Text(
                            '${notes.length} characters',
                            style: TextStyle(
                              color: notes.length > 100 ? Colors.green[800] : Colors.orange[800],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              _section(
                title: "Progress Score - ${progressScore.round()}%",
                child: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: getProgressColor(progressScore).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: getProgressColor(progressScore).withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getProgressIcon(progressScore),
                            color: getProgressColor(progressScore),
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _getProgressText(progressScore),
                              style: TextStyle(
                                color: getProgressColor(progressScore),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
                    Slider(
                      value: progressScore,
                      min: 0,
                      max: 100,
                      divisions: 20,
                      activeColor: AppColors.primary,
                      inactiveColor: Colors.grey[300],
                      onChanged: (val) => setState(() => progressScore = val),
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('0%', style: TextStyle(color: Colors.grey[600])),
                        Text('50%', style: TextStyle(color: Colors.grey[600])),
                        Text('100%', style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  ],
                ),
              ),

              _section(
                title: "Attachment",
                child: Column(
                  children: [
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: pickFile,
                          icon: Icon(Icons.attach_file, size: 18, color: Colors.white),
                          label: const Text('Upload File', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Supports: PDF, DOC, Images, TXT',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (selectedFile != null) ...[
                      SizedBox(height: 12),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green[100]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.attach_file, color: Colors.green, size: 16),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                selectedFile!.path.split('/').last,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.green[800],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close, size: 16, color: Colors.green),
                              onPressed: () => setState(() => selectedFile = null),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: isLoading
                      ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : Icon(Icons.save_rounded, color: Colors.white),
                  label: isLoading
                      ? Text("Saving...", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600))
                      : Text("Save Evaluation", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600)),

                  onPressed: isLoading ? null : saveEvaluation,
                ),
              ),

              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1: return 'Monday';
      case 2: return 'Tuesday';
      case 3: return 'Wednesday';
      case 4: return 'Thursday';
      case 5: return 'Friday';
      case 6: return 'Saturday';
      case 7: return 'Sunday';
      default: return '';
    }
  }

  IconData _getProgressIcon(double score) {
    if (score < 40) return Icons.sentiment_dissatisfied;
    if (score < 70) return Icons.sentiment_neutral;
    return Icons.sentiment_very_satisfied;
  }

  String _getProgressText(double score) {
    if (score < 40) return 'Needs significant improvement';
    if (score < 70) return 'Making good progress';
    return 'Excellent progress and achievement';
  }

  Widget _section({required String title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}