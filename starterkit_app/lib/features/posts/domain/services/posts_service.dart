import 'package:injectable/injectable.dart';
import 'package:starterkit_app/core/domain/result.dart';
import 'package:starterkit_app/features/posts/data/api/posts_api.dart';
import 'package:starterkit_app/features/posts/data/contracts/post_contract.dart';
import 'package:starterkit_app/features/posts/domain/entities/post_entity.dart';
import 'package:starterkit_app/features/posts/domain/mapping/post_mapper.dart';

abstract interface class PostsService {
  Future<Result<Iterable<PostEntity>>> getPosts();
}

@LazySingleton(as: PostsService)
class PostsServiceImpl implements PostsService {
  final PostsApi _postsApi;
  final PostMapper _postMapper;

  const PostsServiceImpl(this._postsApi, this._postMapper);

  @override
  Future<Result<Iterable<PostEntity>>> getPosts() async {
    try {
      final List<PostContract> contracts = await _postsApi.getPosts();
      final Iterable<PostEntity> posts = contracts.map(_postMapper.convert<PostContract, PostEntity>);

      return Success<Iterable<PostEntity>>(posts);
    } on Exception catch (err, st) {
      return Failure<Iterable<PostEntity>>(err, st);
    }
  }
}
