import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'next_screen.dart';

void main() {
  runApp(const MyApp());
}

const Color primaryColor = Color(0xFF00568D);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Onboarding Demo',
      debugShowCheckedModeBanner: false,
      home: FutureBuilder(
        future: Firebase.initializeApp(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return const OnboardingScreen();
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}

enum QuestionType { multipleChoice, textInput }

class OnboardingOption {
  final String title;
  final String? description;

  OnboardingOption({
    required this.title,
    this.description,
  });
}

class OnboardingQuestion {
  final String title;
  final List<OnboardingOption> options;
  final QuestionType questionType;
  final String? placeholder;

  OnboardingQuestion({
    required this.title,
    this.options = const [],
    this.questionType = QuestionType.multipleChoice,
    this.placeholder,
  });
}

List<OnboardingQuestion> questions = [
  OnboardingQuestion(
    title: "What is your level of English?",
    options: [
      OnboardingOption(title: "Beginner A1", description: "I have little to no knowledge of English."),
      OnboardingOption(title: "Lower Intermediate A2", description: "I can communicate in simple tasks."),
      OnboardingOption(title: "Intermediate B1", description: "I can handle everyday conversation."),
      OnboardingOption(title: "Upper Intermediate B2", description: "I am comfortable with more complex language."),
      OnboardingOption(title: "Advanced C", description: "I have a near-native understanding of English."),
    ],
  ),
  OnboardingQuestion(
    title: "What is your current goal?",
    options: [
      OnboardingOption(title: "Get ready for a job interview", description: "Prepare for job interviews in English."),
      OnboardingOption(title: "Test my English Level", description: "Evaluate my current English skills."),
      OnboardingOption(title: "Improve my conversational\nEnglish", description: "Enhance my ability to communicate in daily situations."),
      OnboardingOption(title: "Improve my English for Work", description: "Enhance professional communication skills."),
    ],
  ),
  OnboardingQuestion(
    title: "How often do you prefer to learn?",
    options: [
      OnboardingOption(title: "Watching videos"),
      OnboardingOption(title: "Practicing with conversations"),
      OnboardingOption(title: "Reading and writing exercises"),
      OnboardingOption(title: "A mix of all"),
    ],
  ),
  OnboardingQuestion(
    title: "Which accent do you want to achieve?",
    options: [
      OnboardingOption(title: "Neutral", description: "A clear, accent-free pronunciation."),
      OnboardingOption(title: "American 🇺🇸", description: "Standard American English accent."),
      OnboardingOption(title: "British 🇬🇧", description: "Received Pronunciation (RP) or British English."),
      OnboardingOption(title: "Australian 🇦🇺", description: "General Australian English accent."),
    ],
  ),
  OnboardingQuestion(
    title: "What should I address you?",
    questionType: QuestionType.textInput,
    placeholder: "Enter your name",
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  OnboardingScreenState createState() => OnboardingScreenState();
}

class OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController(initialPage: 0);
  int _currentPage = 0;

  List<int?> selectedOptions = List.filled(questions.length, null);
  Map<int, String> textResponses = {};

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onOptionSelected(int questionIndex, int optionIndex) {
    setState(() {
      selectedOptions[questionIndex] = optionIndex;
    });
  }

  void _onTextChanged(int questionIndex, String value) {
    setState(() {
      textResponses[questionIndex] = value;
    });
  }

  // Check if the current question has a valid response
  bool _isCurrentQuestionAnswered() {
    final currentQuestion = questions[_currentPage];
    if (currentQuestion.questionType == QuestionType.multipleChoice) {
      return selectedOptions[_currentPage] != null;
    } else if (currentQuestion.questionType == QuestionType.textInput) {
      return textResponses[_currentPage]?.isNotEmpty ?? false;
    }
    return false; // Default case, though all questions are covered
  }

  Future<void> _saveOnboardingResponsesAndNavigate() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final Map<String, dynamic> responses = {
        'englishLevel': selectedOptions[0] != null ? questions[0].options[selectedOptions[0]!].title : null,
        'currentGoal': selectedOptions[1] != null ? questions[1].options[selectedOptions[1]!].title : null,
        'learningPreference': selectedOptions[2] != null ? questions[2].options[selectedOptions[2]!].title : null,
        'desiredAccent': selectedOptions[3] != null ? questions[3].options[selectedOptions[3]!].title : null,
        'userName': textResponses[4] ?? '',
        'timestamp': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'onboarding': responses}, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => NextScreen(responses: responses)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving responses: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Before We Start',
          style: TextStyle(fontSize: 20, color: primaryColor),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18.0),
            child: LinearProgressIndicator(
              value: (_currentPage + 1) / questions.length,
              backgroundColor: Colors.grey[300],
              color: primaryColor,
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: PageView.builder(
              physics: const NeverScrollableScrollPhysics(),
              controller: _pageController,
              itemCount: questions.length,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemBuilder: (context, index) {
                final question = questions[index];
                return OnboardingPage(
                  question: question,
                  questionIndex: index,
                  selectedOptionIndex: selectedOptions[index],
                  textResponse: textResponses[index] ?? "",
                  onOptionSelected: (optionIndex) => _onOptionSelected(index, optionIndex),
                  onTextChanged: (value) => _onTextChanged(index, value),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentPage > 0)
                  TextButton(
                    onPressed: () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: const Text(
                      'Previous',
                      style: TextStyle(fontSize: 16, color: primaryColor),
                    ),
                  ),
                ElevatedButton(
                  onPressed: _isCurrentQuestionAnswered()
                      ? () async {
                          if (_currentPage < questions.length - 1) {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          } else {
                            await _saveOnboardingResponsesAndNavigate();
                          }
                        }
                      : null, // Disable button if question isn’t answered
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  child: Text(
                    _currentPage == questions.length - 1 ? 'Finish' : 'Continue',
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingPage extends StatelessWidget {
  final OnboardingQuestion question;
  final int questionIndex;
  final int? selectedOptionIndex;
  final String textResponse;
  final Function(int) onOptionSelected;
  final ValueChanged<String> onTextChanged;

  const OnboardingPage({
    super.key,
    required this.question,
    required this.questionIndex,
    required this.selectedOptionIndex,
    required this.textResponse,
    required this.onOptionSelected,
    required this.onTextChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 20),
          if (question.questionType == QuestionType.multipleChoice)
            Expanded(
              child: ListView.builder(
                itemCount: question.options.length,
                itemBuilder: (context, index) {
                  bool isSelected = selectedOptionIndex == index;
                  final option = question.options[index];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: OutlinedButton(
                      onPressed: () => onOptionSelected(index),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: primaryColor, width: 1.5),
                        backgroundColor: isSelected ? primaryColor : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    option.title,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected ? Colors.white : primaryColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            if (option.description != null)
                              Text(
                                option.description!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isSelected ? Colors.white70 : Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            )
          else if (question.questionType == QuestionType.textInput)
            Padding(
              padding: const EdgeInsets.only(top: 10.0),
              child: TextField(
                onChanged: onTextChanged,
                decoration: InputDecoration(
                  hintText: question.placeholder ?? "",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5),
                    borderSide: const BorderSide(color: primaryColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5),
                    borderSide: const BorderSide(color: primaryColor, width: 2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}