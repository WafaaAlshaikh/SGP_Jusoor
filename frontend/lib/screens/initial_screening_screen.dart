import 'package:flutter/material.dart';

class InitialScreeningScreen extends StatefulWidget {
  const InitialScreeningScreen({Key? key}) : super(key: key);

  @override
  State<InitialScreeningScreen> createState() => _InitialScreeningScreenState();
}

class _InitialScreeningScreenState extends State<InitialScreeningScreen> {
  int currentQuestionIndex = 0;

  final List<Map<String, dynamic>> questions = [
    {
      "text": "هل يواجه طفلك صعوبة في التركيز لفترات طويلة؟",
      "options": ["نعم", "أحيانًا", "لا"],
    },
    {
      "text": "هل يتحرك كثيرًا أثناء الجلوس أو وقت الدراسة؟",
      "options": ["نعم", "أحيانًا", "لا"],
    },
    {
      "text": "هل يجد صعوبة في اتباع التعليمات؟",
      "options": ["نعم", "أحيانًا", "لا"],
    },
    {
      "text": "هل يظهر اهتمامًا محدودًا بالتفاعل مع الآخرين؟",
      "options": ["نعم", "أحيانًا", "لا"],
    },
  ];

  List<String?> answers = [];

  @override
  void initState() {
    super.initState();
    answers = List.filled(questions.length, null);
  }

  void selectAnswer(String option) {
    setState(() {
      answers[currentQuestionIndex] = option;
    });
  }

  void nextQuestion() {
    if (currentQuestionIndex < questions.length - 1) {
      setState(() {
        currentQuestionIndex++;
      });
    } else {
      _showResultsDialog();
    }
  }

  void _showResultsDialog() {
    int score = answers.where((a) => a == "نعم").length;

    String result;
    if (score >= 3) {
      result = "قد تظهر لدى طفلك مؤشرات على اضطراب فرط الحركة (ADHD). يُنصح باستشارة مختص.";
    } else if (score == 2) {
      result = "قد تكون بعض التصرفات بحاجة لمتابعة، يُنصح بمراقبة السلوك بشكل دوري.";
    } else {
      result = "لا توجد مؤشرات مقلقة. استمر بدعم طفلك وتشجيعه.";
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("نتيجة التقييم"),
        content: Text(result, textAlign: TextAlign.right),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("حسنًا"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double progress = (currentQuestionIndex + 1) / questions.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      appBar: AppBar(
        backgroundColor: Colors.teal,
        title: const Text("الاستبيان الذكي"),
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(25)),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // شريط التقدم
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[300],
              color: Colors.teal,
              minHeight: 8,
              borderRadius: BorderRadius.circular(10),
            ),
            const SizedBox(height: 30),

            // السؤال الحالي
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: Card(
                  key: ValueKey(currentQuestionIndex),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 6,
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Text(
                          questions[currentQuestionIndex]["text"],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ...questions[currentQuestionIndex]["options"].map<Widget>(
                              (option) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 55),
                                backgroundColor: answers[currentQuestionIndex] == option
                                    ? Colors.teal
                                    : Colors.teal.shade100,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              onPressed: () => selectAnswer(option),
                              child: Text(
                                option,
                                style: TextStyle(
                                  color: answers[currentQuestionIndex] == option
                                      ? Colors.white
                                      : Colors.teal.shade800,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // الزر التالي
            ElevatedButton(
              onPressed: answers[currentQuestionIndex] != null ? nextQuestion : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: Text(
                currentQuestionIndex == questions.length - 1
                    ? "عرض النتيجة"
                    : "التالي",
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
