import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:starterkit_app/core/domain/result.dart';
import 'package:starterkit_app/core/infrastructure/navigation/root_auto_router.gr.dart';
import 'package:starterkit_app/core/service_locator.dart';
import 'package:starterkit_app/features/app/presentation/views/app.dart';
import 'package:starterkit_app/features/posts/domain/entities/post_entity.dart';
import 'package:starterkit_app/features/posts/domain/services/posts_service.dart';
import 'package:starterkit_app/features/posts/presentation/views/post_details_view.dart';
import 'package:starterkit_app/features/posts/presentation/views/posts_view.dart';
import 'package:starterkit_app/shared/localization/generated/l10n.dart';

import '../../../../test_utils.dart';
import '../../../../widget_test_utils.dart';
import 'posts_view_test.mocks.dart';

@GenerateNiceMocks(<MockSpec<Object>>[
  MockSpec<PostsService>(),
])
void main() {
  group(PostsView, () {
    late Il8n il8n;
    late MockPostsService mockPostsService;

    setUp(() async {
      await setupWidgetTest();
      il8n = await setupLocale();
      mockPostsService = MockPostsService();

      ServiceLocator.instance.registerSingleton<PostsService>(mockPostsService);
      provideDummy<Result<Iterable<PostEntity>>>(Failure<Iterable<PostEntity>>(Exception()));
    });

    group('AppBar', () {
      testGoldens('should show correct title when shown', (WidgetTester tester) async {
        when(mockPostsService.getPosts()).thenAnswer((_) async => const Success<Iterable<PostEntity>>(<PostEntity>[]));

        await tester.pumpWidget(const App(initialRoute: PostsViewRoute()));
        await tester.pumpAndSettle();

        await tester.matchGolden('posts_view_app_bar_title');
        expect(find.text(il8n.posts), findsOneWidget);
      });
    });

    group('ListView', () {
      testGoldens('should show posts when loaded', (WidgetTester tester) async {
        const PostEntity expectedPost = PostEntity(userId: 0, id: 0, title: 'Lorem Ipsum', body: 'Dolor sit amet');
        when(mockPostsService.getPosts())
            .thenAnswer((_) async => const Success<Iterable<PostEntity>>(<PostEntity>[expectedPost]));

        await tester.pumpWidget(const App(initialRoute: PostsViewRoute()));
        await tester.pumpAndSettle();

        await tester.matchGolden('posts_view_loaded');
        expect(find.byType(ListView), findsOneWidget);
        expect(find.byType(ListTile), findsOneWidget);
        expect(find.text(expectedPost.title), findsOneWidget);
        expect(find.text(expectedPost.body), findsOneWidget);
      });
    });

    group('ListTile', () {
      testGoldens('should navigate to PostDetailsView when post tapped', (WidgetTester tester) async {
        const PostEntity expectedPost = PostEntity(userId: 0, id: 0, title: 'Lorem Ipsum', body: 'Dolor sit amet');
        when(mockPostsService.getPosts())
            .thenAnswer((_) async => const Success<Iterable<PostEntity>>(<PostEntity>[expectedPost]));

        await tester.pumpWidget(const App(initialRoute: PostsViewRoute()));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(Key(expectedPost.id.toString())));
        await tester.pumpAndSettle(const Duration(milliseconds: 500));

        await tester.matchGolden('posts_view_navigate_to_post_details_view');
        expect(find.byType(PostsView), findsNothing);
        expect(find.byType(PostDetailsView), findsOneWidget);
      });
    });
  });
}
