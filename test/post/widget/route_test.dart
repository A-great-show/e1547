import 'package:drift/native.dart';
import 'package:e1547/app/app.dart';
import 'package:e1547/client/client.dart';
import 'package:e1547/identity/identity.dart';
import 'package:e1547/post/post.dart';
import 'package:e1547/query/query.dart';
import 'package:e1547/settings/settings.dart';
import 'package:e1547/shared/shared.dart';
import 'package:e1547/traits/traits.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notified_preferences/notified_preferences.dart';

import '../../_support/fake_e621.dart';
import '../../_support/harness.dart';
import '../../_support/images.dart';
import '../../_support/posts.dart';
import '../../_support/video.dart';

void main() {
  late FakeE621 fake;
  late Client client;
  late ValueNotifier<Traits> traits;
  late AppDatabase sqlite;
  late Settings settings;
  late VideoService videos;

  setUpAll(() async {
    await initializeTestApp();
    sqlite = AppDatabase(NativeDatabase.memory());
  });

  tearDownAll(() => sqlite.close());

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fake = await FakeE621.start();
    settings = Settings(await SharedPreferences.getInstance());
    videos = fakeVideoService();
    traits = ValueNotifier(
      const Traits(
        id: 1,
        userId: null,
        denylist: [],
        homeTags: '',
        avatar: null,
        perPage: null,
      ),
    );
    client = Client(
      identity: Identity(id: 1, host: fake.url, username: null, headers: null),
      traits: traits,
      storage: AppStorage(
        preferences: await SharedPreferences.getInstance(),
        temporaryFiles: '.',
        queryCache: CachedQuery.asNewInstance()
          ..config(
            config: const GlobalQueryConfig(
              cacheDuration: Duration(milliseconds: 1),
            ),
          ),
        sqlite: sqlite,
      ),
    );
  });

  tearDown(() async {
    traits.dispose();
    videos.dispose();
    await fake.stop();
  });

  /// Opens a post detail route from a tree layered like the app, where the
  /// client sits above the [Navigator] and the post list below it, so the route
  /// sees only what it was handed.
  Future<void> pushDetail(
    WidgetTester tester,
    PostFilter filter, {
    Post? post,
  }) async {
    final routeObserver = AnyRouteObserver();
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<Client>.value(value: client),
            Provider<BaseCacheManager>.value(
              value: const NoImageCacheManager(),
            ),
            Provider<AnyRouteObserver>.value(value: routeObserver),
            Provider<Settings>.value(value: settings),
            ChangeNotifierProvider<VideoService>.value(value: videos),
          ],
          child: MaterialApp(
            navigatorObservers: [routeObserver],
            home: FilterControllerProvider<PostFilter, Post>.value(
              value: filter,
              child: ChangeNotifierProvider(
                create: (_) => PostParamsController(),
                child: ImageCacheSizeProvider(
                  size: null,
                  child: Builder(
                    builder: (context) => TextButton(
                      onPressed: () =>
                          defaultPushPostDetail(context, post ?? samplePost()),
                      child: const Text('open'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pump();
      // The gallery queries as it opens, so that request has to land before
      // the tree is torn down.
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
  }

  displayTest('a pushed gallery keeps the filter of its list', (tester) async {
    final filter = PostFilter(client);
    addTearDown(filter.dispose);

    await pushDetail(tester, filter);

    final gallery = tester.element(find.byType(PostDetailGallery));
    expect(gallery.read<FilterController<Post>?>(), same(filter));
  });

  displayTest('a pushed gallery drops the posts its list denies', (
    tester,
  ) async {
    traits.value = traits.value.copyWith(denylist: ['tag_47']);
    final filter = PostFilter(client);
    addTearDown(filter.dispose);

    await pushDetail(tester, filter, post: samplePost(id: 1000));

    final view = tester.widget<PagedPageView<int, Post>>(
      find.byType(PagedPageView<int, Post>),
    );
    expect(view.state.items?.map((post) => post.id), [1000]);
  });

  void seedDeniedChild() {
    traits.value = traits.value.copyWith(denylist: ['bad_tag']);
    client.posts.postCache.set(
      samplePost(
        id: 1049,
        tags: const {
          'general': ['bad_tag'],
        },
        file: 'http://example.invalid/1049.jpg',
        preview: 'http://example.invalid/1049.jpg',
      ),
    );
  }

  Future<void> openFirstRelation(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.byType(RelationshipDisplay),
      200,
      scrollable: find
          .descendant(
            of: find.byType(PostDetail),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await Scrollable.ensureVisible(
      tester.element(find.byType(PostRelationPreview).first),
      alignment: 0.5,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(() async {
      await tester.tap(find.byType(PostRelationPreview).first);
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump(const Duration(seconds: 1));
  }

  displayTest('a blacklisted post offers show', (tester) async {
    seedDeniedChild();
    final filter = PostFilter(client);
    addTearDown(filter.dispose);

    await pushDetail(tester, filter, post: samplePost(id: 1042));
    await tester.pump(const Duration(seconds: 1));
    await openFirstRelation(tester);
    expect(find.text('Post is blacklisted'), findsOneWidget);
    expect(find.text('show'), findsOneWidget);

    await tester.tap(find.text('show'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Post is blacklisted'), findsNothing);
    expect(find.text('hide'), findsOneWidget);
  });

  displayTest('the hide button leaves with the blacklist off', (tester) async {
    traits.value = traits.value.copyWith(denylist: ['tag_2']);
    final filter = PostFilter(client)..denying = false;
    addTearDown(filter.dispose);

    await pushDetail(tester, filter, post: samplePost(id: 1000));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(PostDetailImageDisplay), findsOneWidget);
    expect(find.text('Post is blacklisted'), findsNothing);
    expect(find.text('hide'), findsNothing);
  });

  displayTest('a child opened from a relation keeps the filter', (
    tester,
  ) async {
    seedDeniedChild();
    final filter = PostFilter(client)..denying = false;
    addTearDown(filter.dispose);

    await pushDetail(tester, filter, post: samplePost(id: 1042));
    await tester.pump(const Duration(seconds: 1));
    await openFirstRelation(tester);

    final child = tester.element(
      find.descendant(
        of: find.byType(PostLoadingPage),
        matching: find.byType(PostDetail),
      ),
    );
    expect(child.read<PostFilter?>(), same(filter));
    expect(find.text('Post is blacklisted'), findsNothing);
  });
}
