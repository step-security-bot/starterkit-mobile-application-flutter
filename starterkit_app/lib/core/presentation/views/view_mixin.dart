import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart' hide View;
import 'package:reflectable/reflectable.dart';
import 'package:starterkit_app/core/dependency_injection.dart';
import 'package:starterkit_app/core/infrastructure/navigation/navigation_observer.dart';
import 'package:starterkit_app/core/presentation/view_models/app_life_cycle_aware_mixin.dart';
import 'package:starterkit_app/core/presentation/view_models/first_renderable.dart';
import 'package:starterkit_app/core/presentation/view_models/initializable.dart';
import 'package:starterkit_app/core/presentation/view_models/route_aware_mixin.dart';
import 'package:starterkit_app/core/presentation/view_models/view_model.dart';
import 'package:starterkit_app/core/presentation/views/view.dart';
import 'package:starterkit_app/core/reflection.dart';

mixin ViewMixin<TViewModel extends ViewModel> implements View<TViewModel> {
  @override
  @mustCallSuper
  Widget build(BuildContext context) {
    return _ViewModelBuilder<TViewModel>(
      create: () => onCreateViewModel(context),
      dispose: onDisposeViewModel,
      builder: buildView,
    );
  }

  @protected
  @override
  @mustCallSuper
  TViewModel onCreateViewModel(BuildContext context) {
    return _ViewLifeCycleHandler._onCreateViewModel<TViewModel>(context, getNavigationParams: false);
  }

  @protected
  @override
  @mustCallSuper
  void onDisposeViewModel(BuildContext context, TViewModel viewModel) {
    _ViewLifeCycleHandler._onDisposeViewModel(context, viewModel);
  }
}

mixin ViewRouteMixin<TViewModel extends ViewModel> implements View<TViewModel> {
  @override
  @mustCallSuper
  Widget build(BuildContext context) {
    return _ViewModelBuilder<TViewModel>(
      create: () => onCreateViewModel(context),
      dispose: onDisposeViewModel,
      builder: (context, viewModel) {
        _ViewLifeCycleHandler._tryGetNavigationParams(context, viewModel);

        return buildView(context, viewModel);
      },
    );
  }

  @protected
  @override
  @mustCallSuper
  TViewModel onCreateViewModel(BuildContext context) {
    return _ViewLifeCycleHandler._onCreateViewModel<TViewModel>(context, getNavigationParams: true);
  }

  @protected
  @override
  @mustCallSuper
  void onDisposeViewModel(BuildContext context, TViewModel viewModel) {
    _ViewLifeCycleHandler._onDisposeViewModel(context, viewModel);
  }
}

mixin ChildViewMixin<TViewModel extends ViewModel> implements View<TViewModel> {
  @override
  @mustCallSuper
  Widget build(BuildContext context) {
    return _ViewModelBuilder<TViewModel>(
      create: () => onCreateViewModel(context),
      dispose: onDisposeViewModel,
      builder: buildView,
    );
  }

  @protected
  @override
  @mustCallSuper
  TViewModel onCreateViewModel(BuildContext context) => context.viewModel<TViewModel>();

  @protected
  @override
  void onDisposeViewModel(BuildContext context, TViewModel viewModel) {}
}

abstract final class _ViewLifeCycleHandler {
  static TViewModel _onCreateViewModel<TViewModel extends ViewModel>(
    BuildContext context, {
    required bool getNavigationParams,
  }) {
    final viewModel = ServiceLocator.instance<TViewModel>();
    final route = ModalRoute.of(context);

    if (route != null && viewModel is RouteAwareMixin) {
      NavigationObserver.instance.subscribe(viewModel, route);
    }

    if (viewModel is AppLifeCycleAwareMixin) {
      WidgetsBinding.instance.addObserver(viewModel.appLifeCycleObserver);
    }

    _initializeViewModel(context, viewModel, getNavigationParams);

    return viewModel;
  }

  static void _onDisposeViewModel<TViewModel extends ViewModel>(BuildContext context, TViewModel viewModel) {
    viewModel.dispose();

    if (viewModel is RouteAwareMixin) {
      NavigationObserver.instance.unsubscribe(viewModel);
    }

    if (viewModel is AppLifeCycleAwareMixin) {
      WidgetsBinding.instance.removeObserver(viewModel.appLifeCycleObserver);
    }
  }

  static void _initializeViewModel<TViewModel extends ViewModel>(
    BuildContext context,
    TViewModel viewModel,
    bool getNavigationParams,
  ) {
    if (getNavigationParams) {
      _tryGetNavigationParams(context, viewModel);
    }

    if (viewModel is FirstRenderable) {
      final firstRenderable = viewModel as FirstRenderable;
      WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(firstRenderable.onFirstRender()));
    }

    if (viewModel is Initializable) {
      final initializable = viewModel as Initializable;
      unawaited(initializable.onInitialize());
    }
  }

  static void _tryGetNavigationParams<TViewModel extends ViewModel>(BuildContext context, TViewModel viewModel) {
    final routeData = context.routeData;
    final queryParams = Map<String, Object?>.from(routeData.queryParams.rawMap);
    final pathParams = Map<String, Object?>.from(routeData.pathParams.rawMap);
    final hasParams = queryParams.isNotEmpty || pathParams.isNotEmpty;
    final canReflect = navigatable.canReflect(viewModel) || navigatable.canReflectType(TViewModel);

    if (hasParams && !canReflect) {
      throw StateError('ViewModel $TViewModel with navigation parameters must be annotated with @navigatable');
    }

    final instanceMirror = navigatable.reflect(viewModel);
    final typeMirror = navigatable.reflectType(TViewModel) as ClassMirror;

    for (final entry in queryParams.entries) {
      if (entry.value == null) {
        continue;
      }

      bool predicate(DeclarationMirror element) => element.metadata.any((m) => m is QueryParam && m.name == entry.key);
      _setValue(instanceMirror, typeMirror, predicate, entry.value!);
    }

    for (final entry in pathParams.entries) {
      if (entry.value == null) {
        continue;
      }

      bool predicate(DeclarationMirror element) => element.metadata.any((m) => m is PathParam && m.name == entry.key);
      _setValue(instanceMirror, typeMirror, predicate, entry.value!);
    }
  }

  static void _setValue(
    InstanceMirror instanceMirror,
    ClassMirror classMirror,
    bool Function(DeclarationMirror element) predicate,
    Object value,
  ) {
    if (classMirror.declarations.values.any(predicate)) {
      final matchingDeclaration = classMirror.declarations.values.firstWhere(predicate) as VariableMirror;
      instanceMirror.invokeSetter(matchingDeclaration.simpleName, value);
    }
  }
}

class _ViewModelBuilder<TViewModel extends ViewModel> extends StatefulWidget {
  const _ViewModelBuilder({required this.create, required this.builder, this.dispose, super.key});

  final TViewModel Function() create;
  final Widget Function(BuildContext, TViewModel) builder;
  final void Function(BuildContext, TViewModel)? dispose;

  @override
  State<StatefulWidget> createState() => _ViewModelBuilderState<TViewModel>();
}

class _ViewModelBuilderState<TViewModel extends ViewModel> extends State<_ViewModelBuilder<TViewModel>> {
  late final TViewModel _currentViewModel;

  @override
  void initState() {
    super.initState();

    _currentViewModel = widget.create();
  }

  @override
  void dispose() {
    widget.dispose?.call(context, _currentViewModel);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _currentViewModel,
      builder: (context, child) {
        return _ViewModelHolder<TViewModel>(
          viewModel: _currentViewModel,
          child: widget.builder(context, _currentViewModel),
        );
      },
    );
  }
}

class _ViewModelHolder<T extends ViewModel> extends InheritedWidget {
  static _ViewModelHolder<T>? of<T extends ViewModel>(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_ViewModelHolder<T>>();
  }

  final T viewModel;

  const _ViewModelHolder({required super.child, required this.viewModel, super.key});

  @override
  bool updateShouldNotify(_ViewModelHolder<T> oldWidget) {
    return false;
  }
}

extension ViewExtensions on BuildContext {
  T viewModel<T extends ViewModel>() {
    final viewModel = _ViewModelHolder.of<T>(this)?.viewModel;

    if (viewModel == null) {
      throw StateError('Could not locate viewmodel $T');
    }

    return viewModel;
  }
}
