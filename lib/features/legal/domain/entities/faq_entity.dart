class FaqEntity {
  final String question;
  final String answer;
  final int sortOrder;

  const FaqEntity({required this.question, required this.answer, this.sortOrder = 0});
}