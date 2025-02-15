import 'package:flutter/material.dart';
import 'next_screen.dart';

void main() {
  runApp(const MyApp());
}

// Replace this with your preferred primary color.
const Color primaryColor = Color(0xFF00568D);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Onboarding Demo',
      debugShowCheckedModeBanner: false,
      home: OnboardingScreen(),
    );
  }
}

/// An enum to determine what type of question this is.
enum QuestionType { multipleChoice, textInput }

/// Model for each option including title and (optional) description.
class OnboardingOption {
  final String title;
  final String? description;

  OnboardingOption({
    required this.title,
    this.description,
  });
}

/// Updated Question model with an optional text input type.
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

/// List of onboarding questions with options, descriptions, or text input.
List<OnboardingQuestion> questions = [
  OnboardingQuestion(
    title: "What is your level of English?",
    options: [
      OnboardingOption(
        title: "Beginner A1",
        description: "I have little to no knowledge of English.",
      ),
      OnboardingOption(
        title: "Lower Intermediate A2",
        description: "I can communicate in simple tasks.",
      ),
      OnboardingOption(
        title: "Intermediate B1",
        description: "I can handle everyday conversation.",
      ),
      OnboardingOption(
        title: "Upper Intermediate B2",
        description: "I am comfortable with more complex language.",
      ),
      OnboardingOption(
        title: "Advanced C",
        description: "I have a near-native understanding of English.",
      ),
    ],
  ),
  OnboardingQuestion(
    title: "What is your current goal?",
    options: [
      OnboardingOption(
        title: "Get ready for a job interview",
        description: "Prepare for job interviews in English.",
      ),
      OnboardingOption(
        title: "Test my English Level",
        description: "Evaluate my current English skills.",
      ),
      OnboardingOption(
        title: "Improve my conversational English",
        description: "Enhance my ability to communicate in daily situations.",
      ),
      OnboardingOption(
        title: "Improve my English for Work",
        description: "Enhance professional communication skills.",
      ),
    ],
  ),
  OnboardingQuestion(
    title: "How often do you prefer to learn?",
    options: [
      OnboardingOption(
        title: "Watching videos",
      ),
      OnboardingOption(
        title: "Practicing with conversations",
      ),
      OnboardingOption(
        title: "Reading and writing exercises",
      ),
      OnboardingOption(
        title: "A mix of all",
      ),
    ],
  ),
  // New question: Text Input
  OnboardingQuestion(
    title: "What should I address you?",
    questionType: QuestionType.textInput,
    placeholder: "Enter your name",
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  OnboardingScreenState createState() => OnboardingScreenState(); // Change here
}

class OnboardingScreenState extends State<OnboardingScreen> { // Change here
  final PageController _pageController = PageController(initialPage: 0);
  int _currentPage = 0;

  // For multiple-choice questions, store the selected option index.
  List<int?> selectedOptions = List.filled(questions.length, null);
  // For text input questions, store the response (by question index).
  Map<int, String> textResponses = {};

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Called when an option is tapped.
  void _onOptionSelected(int questionIndex, int optionIndex) {
    setState(() {
      selectedOptions[questionIndex] = optionIndex;
    });
  }

  // Called when text input changes.
  void _onTextChanged(int questionIndex, String value) {
    setState(() {
      textResponses[questionIndex] = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Transparent AppBar matching design.
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
          // Progress Indicator (thin bar below the AppBar)
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
              physics: const NeverScrollableScrollPhysics(), // controlled via buttons
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
                  onOptionSelected: (optionIndex) =>
                      _onOptionSelected(index, optionIndex),
                  onTextChanged: (value) => _onTextChanged(index, value),
                );
              },
            ),
          ),
          // Navigation buttons at the bottom.
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Show Previous button if not on the first page.
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
                  onPressed: () {
                    if (_currentPage < questions.length - 1) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      // On last page, navigate to the next screen.
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const NextScreen()),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  child: Text(
                    _currentPage == questions.length - 1
                        ? 'Finish'
                        : 'Continue',
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

/// The onboarding page that displays either the multiple-choice options or a text field.
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
      // Consistent horizontal padding.
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question Title
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
            // List of option buttons for multiple-choice questions.
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
                        side: const BorderSide(
                          color: primaryColor,
                          width: 1.5,
                        ),
                        backgroundColor:
                            isSelected ? primaryColor : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 15,
                          horizontal: 20,
                        ),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Option Title
                            Text(
                              option.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : primaryColor,
                              ),
                            ),
                            const SizedBox(height: 5),
                            // Conditionally display the description if it exists
                            if (option.description != null)
                              Text(
                                option.description!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isSelected
                                      ? Colors.white70
                                      : Colors.grey[600],
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
            // Text input question
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
