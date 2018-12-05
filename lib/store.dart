import 'package:flutter/widgets.dart';

typedef StoreValueComputer = dynamic Function();
typedef StoreValueSubscriber<T> = T Function();

abstract class StoreSubscriber {
  notify();
}

List<StoreSubscriber> _subscribersStack = [];

T _follow<T>(StoreSubscriber subscriber, StoreValueSubscriber<T> valueSubscriber) {
  if (!_subscribersStack.contains(subscriber)) {
    _subscribersStack.add(subscriber);
  }

  final result = valueSubscriber();

  _subscribersStack.remove(subscriber);

  return result;
}

abstract class _StoreData {
  dynamic get value;

  List<StoreSubscriber> _subscribers = [];

  subscribe() {
    if (_subscribersStack.length > 0 && !_subscribers.contains(_subscribersStack.last)) {
      _subscribers.add(_subscribersStack.last);
    }
  }

  notify() {
    _subscribers.forEach((subscriber) => subscriber.notify());
  }
}

class _StaticData extends _StoreData {
  _StaticData([this.value]);

  dynamic value;
}

class _ComputedData extends _StoreData implements StoreSubscriber {
  _ComputedData(this.computer);

  StoreValueComputer computer;

  bool _needsUpdate = true;
  dynamic _computedValue;

  dynamic get value {
    if (_needsUpdate) {
      _computedValue = _follow(this, computer);
      _needsUpdate = false;
    }
    return _computedValue;
  }

  notify() {
    _needsUpdate = true;
    super.notify();
  }
}

abstract class StoreModel {
  Map<String, _StaticData> _data = {};
  Map<int, _ComputedData> _computedData = {};

  dynamic compute(StoreValueComputer computer) {
    if (!_computedData.containsKey(computer.hashCode)) {
      _computedData[computer.hashCode] = _ComputedData(computer);
    }
    _computedData[computer.hashCode].subscribe();
    return _computedData[computer.hashCode].value;
  }

  get(String name) {
    if (_data[name] == null) {
      _data[name] = _StaticData();
    }
    _data[name].subscribe();
    return _data[name]?.value;
  }

  set(String name, dynamic value) {
    if (_data[name] == null) {
      _data[name] = _StaticData(value);
    } else {
      _data[name].value = value;
    }
    _data[name].notify();
    return value;
  }
}

class StoreBuilder extends StatefulWidget {
  const StoreBuilder({
    Key key,
    @required this.builder
  }) : assert(builder != null),
       super(key: key);

  final WidgetBuilder builder;

  @override
  State<StoreBuilder> createState() => _StoreBuilderState();
}

class _StoreBuilderState extends State<StoreBuilder> implements StoreSubscriber {

  notify() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return _follow<Widget>(this, () => widget.builder(context));
  }
}