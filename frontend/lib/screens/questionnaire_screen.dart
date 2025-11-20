// // screens/questionnaire/questionnaire_screen.dart
// import 'package:flutter/material.dart';
// import '../../services/screening_service.dart'; // ← استخدم الـ service الجديد
// import '../../models/screening_models.dart';
// import '../widgets/question_widget.dart';
// import 'result_screen.dart';
//
// class QuestionnaireScreen extends StatefulWidget {
//   final int childAge;
//   final String? childGender;
//   final List<ScreeningQuestion>? initialQuestions; // 🔥 جديد
//   final Map<String, dynamic>? screeningPlan; // 🔥 جديد
//   final bool isGateway; // 🔥 جديد
//
//   const QuestionnaireScreen({
//     super.key,
//     required this.childAge,
//     this.childGender,
//      this.initialQuestions, // 🔥 جديد
//     this.screeningPlan, // 🔥 جديد
//     this.isGateway = true, // 🔥 جديد
//   });
//
//   @override
//   State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
// }
//
// class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
//   List<ScreeningQuestion> _questions = [];
//   List<ScreeningResponse> _responses = [];
//   int _currentQuestionIndex = 0;
//   bool _isLoading = true;
//   String _currentStep = 'gateway';
//   Map<String, dynamic>? _screeningPlan;
//
//   @override
//   void initState() {
//     super.initState();
//
//     // 🔥 تأكد من أننا نبدأ دائمًا بالبوابة إذا لم توجد أسئلة مسبقة
//     if (widget.isGateway || widget.initialQuestions == null) {
//       _startScreening();
//     } else {
//       // إذا كانت الأسئلة جاهزة (من بوابة سابقة)
//       print('🎯 Using pre-loaded questions from gateway');
//       setState(() {
//         _questions = widget.initialQuestions!;
//         _screeningPlan = widget.screeningPlan;
//         _currentStep = 'primary_screening';
//         _isLoading = false;
//       });
//     }
//   }
//
//   Future<void> _startScreening() async {
//   try {
//     // 🔥 إذا في أسئلة جاهزة (من بوابة)، استخدمهم مباشرة
//     if (widget.initialQuestions != null && !widget.isGateway) {
//       print('🎯 Using pre-loaded questions from gateway');
//       print('📋 Questions count: ${widget.initialQuestions!.length}');
//       print('🎯 Screening plan: ${widget.screeningPlan}');
//
//       setState(() {
//         _questions = widget.initialQuestions!;
//         _screeningPlan = widget.screeningPlan;
//         _currentStep = 'primary_screening'; // 🔥 غير الخطوة
//         _isLoading = false;
//       });
//       return;
//     }
//
//     // 🔥 إذا لا، ابدأ screening جديد (البوابة)
//     print('🎯 Starting new GATEWAY screening for age: ${widget.childAge}');
//
//     final result = await ScreeningService.startScreening(
//       widget.childAge,
//       widget.childGender,
//     );
//
//     if (!mounted) return;
//
//     setState(() {
//       _questions = (result['gateway_questions'] as List)
//           .map((q) => ScreeningQuestion.fromJson(q))
//           .toList();
//       _isLoading = false;
//     });
//
//   } catch (e) {
//     print('❌ Screening start failed: $e');
//     _isLoading = false; // 🔥 أزل حالة التحميل
//     if (!mounted) return;
//
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text('Failed to start screening: $e'),
//         duration: const Duration(seconds: 5),
//       ),
//     );
//
//     Navigator.pop(context);
//   }
// }
//
//
// bool _isSubmitting = false; // 🔥 أضف هذا المتغير
//
//   void _submitAnswer(dynamic answer) {
//     if (_isSubmitting) {
//       print('🚫 Already submitting, ignoring duplicate press');
//       return;
//     }
//
//     _isSubmitting = true;
//
//     final currentQuestion = _questions[_currentQuestionIndex];
//     bool finalAnswer = _convertToBool(answer);
//     int riskScore = finalAnswer ? currentQuestion.riskScore : 0;
//
//     print('🔍 Submitting answer: $answer -> $finalAnswer');
//     print('🔍 Risk: $riskScore, Category: ${currentQuestion.category}');
//     print('🔍 Current position: $_currentQuestionIndex/${_questions.length - 1}');
//     print('🔍 Current step: $_currentStep');
//
//     setState(() {
//       _responses.add(ScreeningResponse(
//         questionId: currentQuestion.id,
//         answer: finalAnswer,
//         riskScore: riskScore,
//         category: currentQuestion.category,
//       ));
//     });
//
//     _nextQuestion().then((_) {
//       _isSubmitting = false;
//     });
//   }
//
// // 🔧 دالة مساعدة لتحويل الإجابة
//   bool _convertToBool(dynamic answer) {
//     if (answer is bool) return answer;
//     if (answer is String) {
//       return answer.toLowerCase() == 'yes' || answer == 'true' || answer == '1';
//     }
//     if (answer is int) return answer == 1;
//     return false;
//   }
//
//   Future<void> _nextQuestion() async {
//     print('🚀 _nextQuestion() started');
//     print('📊 Status: Step=$_currentStep, Index=$_currentQuestionIndex, Total=${_questions.length}');
//
//     // 🔥 تحقق إذا هذا آخر سؤال بوابة
//     if (_currentStep == 'gateway' && _currentQuestionIndex >= _questions.length - 1) {
//       print('🎯 LAST GATEWAY QUESTION DETECTED!');
//       print('📦 Responses collected: ${_responses.length}');
//       print('🔄 Processing gateway results...');
//       await _processGatewayResults();
//       return;
//     }
//
//     // 🔥 تحقق إذا هذا آخر سؤال primary
//     if (_currentStep == 'primary_screening' && _currentQuestionIndex >= _questions.length - 1) {
//       print('🎯 LAST PRIMARY QUESTION DETECTED!');
//       print('🔄 Processing primary results...');
//       await _processPrimaryResults();
//       return;
//     }
//
//     // إذا مو آخر سؤال، اطلع للسؤال الجاي
//     setState(() {
//       _currentQuestionIndex++;
//     });
//
//     print('➡️ Moving to next question: ${_currentQuestionIndex + 1}');
//   }
//
// // 🔥 أصلح دالة _processGatewayResults
//   Future<void> _processGatewayResults() async {
//     try {
//       print('🚀 STARTING _processGatewayResults...');
//
//       final result = await ScreeningService.processGateway(
//         childAge: widget.childAge,
//         childGender: widget.childGender,
//         responses: _responses,
//       ).timeout(const Duration(seconds: 30));
//
//       print('✅ Gateway processing completed on client side');
//       print('📋 Question count: ${result['questions']?.length ?? 0}');
//
//       if (!mounted) {
//         print('❌ Component not mounted');
//         return;
//       }
//
//       // 🔥 تحقق من وجود الأسئلة والخطة
//       final questions = result['questions'] as List?;
//       final screeningPlan = result['screening_plan'] as Map<String, dynamic>?;
//
//       if (questions == null || questions.isEmpty) {
//         throw Exception('No questions received from server');
//       }
//
//       if (screeningPlan == null) {
//         throw Exception('No screening plan received from server');
//       }
//
//       final newQuestions = questions.map((q) => ScreeningQuestion.fromJson(q)).toList();
//
//       print('🎯 Navigating with ${newQuestions.length} questions...');
//       print('📋 Screening plan: $screeningPlan');
//
//       // 🔥 استخدم pushReplacement بدلاً من push
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(
//           builder: (_) => QuestionnaireScreen(
//             childAge: widget.childAge,
//             childGender: widget.childGender,
//             initialQuestions: newQuestions,
//             screeningPlan: screeningPlan,
//             isGateway: false, // 🔥 مهم: هذه ليست بوابة
//           ),
//         ),
//       );
//
//     } catch (e) {
//       print('❌ _processGatewayResults error: $e');
//       _isSubmitting = false;
//
//       if (!mounted) return;
//
//       showDialog(
//         context: context,
//         builder: (context) => AlertDialog(
//           title: const Text('Error'),
//           content: Text('Failed to load questions: $e'),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: const Text('OK'),
//             ),
//           ],
//         ),
//       );
//     }
//   }
//
//
//
//   Future<void> _processPrimaryResults() async {
//     try {
//       // حساب النقاط النهائية
//       final asdScore = _responses
//           .where((r) => r.category.contains('ASD') ||
//                         r.category.contains('social') ||
//                         r.category.contains('communication'))
//           .fold(0, (sum, response) => sum + response.riskScore);
//
//       final adhdScore = _responses
//           .where((r) => r.category.contains('ADHD') ||
//                         r.category.contains('inattention') ||
//                         r.category.contains('hyperactivity'))
//           .fold(0, (sum, response) => sum + response.riskScore);
//
//       final finalScores = {'asd': asdScore, 'adhd': adhdScore};
//
//       // ✅ استخدم الـ service الجديد لحفظ النتائج
//       final result = await ScreeningService.saveResults(
//         childAge: widget.childAge,
//         childGender: widget.childGender,
//         screeningPlan: _screeningPlan!,
//         primaryResponses: _responses,
//         secondaryResponses: null,
//         finalScores: finalScores,
//       );
//
//       if (!mounted) return;
//
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(
//           builder: (_) => ResultsScreen(results: result['results']),
//         ),
//       );
//     } catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error: $e')),
//       );
//     }
//   }
//
//
//   @override
//   Widget build(BuildContext context) {
//     if (_isLoading) {
//       return Scaffold(
//         appBar: AppBar(title: const Text('Screening')),
//         body: const Center(child: CircularProgressIndicator()),
//       );
//     }
//
//     if (_currentQuestionIndex >= _questions.length) {
//       return Scaffold(
//         appBar: AppBar(title: const Text('Screening')),
//         body: const Center(child: CircularProgressIndicator()),
//       );
//     }
//
//     final currentQuestion = _questions[_currentQuestionIndex];
//
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(_currentStep == 'gateway' ? 'Initial Questions' : 'Screening Questions'),
//         backgroundColor: Colors.blue[700],
//         foregroundColor: Colors.white,
//       ),
//       body: Column(
//         children: [
//           // Progress Bar
//           LinearProgressIndicator(
//             value: (_currentQuestionIndex + 1) / _questions.length,
//             backgroundColor: Colors.grey[300],
//             valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
//           ),
//           const SizedBox(height: 10),
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 20),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Text(
//                   'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
//                   style: TextStyle(color: Colors.grey[600]),
//                 ),
//                 Text(
//                   _currentStep == 'gateway' ? 'Gateway' : 'Main Screening',
//                   style: TextStyle(
//                     color: Colors.blue[700],
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           const SizedBox(height: 20),
//
//           // Question Widget
//           Expanded(
//             child: SingleChildScrollView(
//               padding: const EdgeInsets.all(20),
//               child: QuestionWidget(
//                 question: currentQuestion,
//                 onAnswer: _submitAnswer,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }