import 'package:e1547/shared/shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late PageController pages;
  late GalleryPanController pan;

  Future<void> pump(WidgetTester tester) async {
    pages = PageController();
    addTearDown(pages.dispose);
    pan = GalleryPanController(pages);
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: pan.locked,
          builder: (context, locked, child) => PageView(
            controller: pages,
            physics: locked ? const NeverScrollableScrollPhysics() : null,
            children: [for (int page = 0; page < 3; page++) Text('$page')],
          ),
        ),
      ),
    );
  }

  testWidgets('a push moves the pages by its distance', (tester) async {
    await pump(tester);

    pan.push(-200);
    await tester.pump();

    expect(pages.page, closeTo(0.25, 0.001));
  });

  testWidgets('a release past the middle settles on the next page', (
    tester,
  ) async {
    await pump(tester);

    pan.push(-500);
    await tester.pump();
    pan.release(0);
    await tester.pumpAndSettle();

    expect(pages.page, 1);
  });

  testWidgets('a release short of the middle settles back', (tester) async {
    await pump(tester);

    pan.push(-200);
    await tester.pump();
    pan.release(0);
    await tester.pumpAndSettle();

    expect(pages.page, 0);
  });

  testWidgets('a push still moves pages that are locked against swipes', (
    tester,
  ) async {
    await pump(tester);
    pan.locked.value = true;
    await tester.pump();

    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pump();
    expect(pages.page, 0);

    pan.push(-500);
    await tester.pump();
    pan.release(0);
    await tester.pumpAndSettle();

    expect(pages.page, 1);
  });
}
