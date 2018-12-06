import 'package:flutter/widgets.dart';
import 'dart:collection';

typedef StoreValueComputer = dynamic Function();
typedef _Task<T> = T Function();

abstract class _StoreWatcher {
  _requestUpdate();

  List<_StoreData> _targets = [];

  _watch(_StoreData target) {
    if (!_targets.contains(target)) {
      _targets.add(target);
      target._subscribe(this);
    }
  }

  _unwatch(_StoreData target) {
    if (_targets.contains(target)) {
      _targets.remove(target);
      target._unsubscribe(this);
    }
  }

  _unwatchAll() {
    _targets.forEach((target) => target._unsubscribe(this));
    _targets.clear();
  }
}

List<_StoreWatcher> _watchersStack = [];

T _watchTask<T>(_StoreWatcher watcher, _Task<T> task) {
  if (!_watchersStack.contains(watcher)) {
    _watchersStack.add(watcher);
  }

  final result = task();

  _watchersStack.remove(watcher);

  return result;
}

abstract class _StoreData {
  dynamic get value;

  List<_StoreWatcher> _watchers = [];

  _subscribe(_StoreWatcher watcher) {
    if (!_watchers.contains(watcher)) {
      _watchers.add(watcher);
    }
  }

  _unsubscribe(_StoreWatcher watcher) {
    if (_watchers.contains(watcher)) {
      _watchers.remove(watcher);
    }
  }

  notify() {
    _watchers.forEach((subscriber) => subscriber._requestUpdate());
  }
}

class _StaticData extends _StoreData {
  _StaticData([this.value]);

  dynamic value;
}

class _ComputedData extends _StoreData with _StoreWatcher {
  _ComputedData(this.computer);

  StoreValueComputer computer;

  bool _needsUpdate = true;
  dynamic _computedValue;

  dynamic get value {
    if (_needsUpdate) {
      _unwatchAll();
      _computedValue = _watchTask(this, computer);
      _needsUpdate = false;
    }
    return _computedValue;
  }

  _requestUpdate() {
    _needsUpdate = true;
    super.notify();
  }
}

abstract class StoreModel {
  Map<dynamic, _StaticData> _data = {};
  Map<int, _ComputedData> _computedData = {};

  dynamic compute(StoreValueComputer computer) {
    if (!_computedData.containsKey(computer.hashCode)) {
      _computedData[computer.hashCode] = _ComputedData(computer);
    }
    if (_watchersStack.length > 0) {
      _watchersStack.last._watch(_computedData[computer.hashCode]);
    }
    return _computedData[computer.hashCode].value;
  }

  get(dynamic key) {
    if (_data[key] == null) {
      _data[key] = _StaticData();
    }
    if (_watchersStack.length > 0) {
      _watchersStack.last._watch(_data[key]);
    }
    return _data[key]?.value;
  }

  set(dynamic key, dynamic value) {
    if (_data[key] == null) {
      _data[key] = _StaticData(value);
    } else {
      _data[key].value = value;
    }
    _data[key].notify();
    return value;
  }
}

class StoreListModel<T> extends StoreModel with ListMixin<T> {
  set length(int newLength) => set('length', newLength);

  int get length => get('length') ?? 0;

  T operator [](int index) => get(index); // TODO: validate index

  void operator []=(int index, T value) => set(index, value);
}

class StoreBuilder extends StatefulWidget {
  const StoreBuilder({Key key, @required this.builder})
      : assert(builder != null),
        super(key: key);

  final WidgetBuilder builder;

  @override
  State<StoreBuilder> createState() => _StoreState<StoreBuilder>(builder);
}

abstract class StoreWidget extends StatefulWidget {
  const StoreWidget({Key key}) : super(key: key);

  Widget build(BuildContext context);

  @override
  StatefulElement createElement() => StatefulElement(this);

  @override
  State<StoreWidget> createState() => _StoreState<StoreWidget>(build);
}

class _StoreState<T> extends State<T> with _StoreWatcher {
  _StoreState(this.builder) : assert(builder != null);

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    _unwatchAll();
    return _watchTask<Widget>(this, () => builder(context));
  }

  dispose() {
    _unwatchAll();
    super.dispose();
  }

  _requestUpdate() => setState(() {});
}