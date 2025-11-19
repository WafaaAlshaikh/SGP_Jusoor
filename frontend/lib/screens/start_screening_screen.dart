// screens/questionnaire/start_screening_screen.dart
import 'package:flutter/material.dart';
import 'questionnaire_screen.dart';
class StartScreeningScreen extends StatefulWidget {
  const StartScreeningScreen({Key? key}) : super(key: key);

  @override
  _StartScreeningScreenState createState() => _StartScreeningScreenState();
}

class _StartScreeningScreenState extends State<StartScreeningScreen> {
  final _formKey = GlobalKey<FormState>();
  int? _childAge;
  String? _childGender;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Initial Screening'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Child Information',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Please provide basic information about your child for personalized screening.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 30),
              
              // Age Input
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Child Age (in months)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.cake),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter child age';
                  }
                  final age = int.tryParse(value);
                  if (age == null || age < 16 || age > 120) {
                    return 'Please enter age between 16 and 120 months';
                  }
                  return null;
                },
                onSaved: (value) {
                  _childAge = int.tryParse(value!);
                },
              ),
              const SizedBox(height: 20),
              
              // Gender Selection
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Child Gender (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                value: _childGender,
                items: const [
                  DropdownMenuItem(value: null, child: Text('Select Gender')),
                  DropdownMenuItem(value: 'male', child: Text('Male')),
                  DropdownMenuItem(value: 'female', child: Text('Female')),
                ],
                onChanged: (value) {
                  setState(() {
                    _childGender = value;
                  });
                },
              ),
              const SizedBox(height: 40),
              
              // Start Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _startScreening,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Start Screening',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startScreening() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuestionnaireScreen(
            childAge: _childAge!,
            childGender: _childGender,
          ),
        ),
      );
    }
  }
}