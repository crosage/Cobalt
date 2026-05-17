import 'package:flutter_test/flutter_test.dart';
import 'package:paper_reader/models/models.dart';

void main() {
  test('Paper authorsShort summarizes long author lists', () {
    final paper = Paper(
      id: 'p1',
      conference: 'CVPR',
      title: 'Example',
      authors: const ['Alice', 'Bob', 'Carol', 'Dave'],
    );

    expect(paper.authorsShort, 'Alice et al. (4)');
  });
}
