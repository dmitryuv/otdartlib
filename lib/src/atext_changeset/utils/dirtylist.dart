part of otdartlib.atext_changeset;

/**
 * Creates a [List] that implements a property called isDirty. 
 * This property changes every time the list is changed. 
 */
class DirtyList<E> extends DelegatingIterable<E> implements List<E> {
  final List<E> _listBase;
  bool _dirty = false;

  DirtyList() : this._([]);
  
  DirtyList.from(Iterable<E> other, {bool growable: true}) : this._(new List.from(other, growable: growable));
  
  DirtyList._(List<E> list) : _listBase = list, super(list);
  
  bool get isDirty => _dirty;
  
  E operator [](int index) => _listBase[index];

  void operator []=(int index, E value) {
    _listBase[index] = value;
    _dirty = true;
  }

  void add(E value) {
    _listBase.add(value);
    _dirty = true;
  }

  void addAll(Iterable<E> iterable) {
    _listBase.addAll(iterable);
    _dirty = true;
  }

  Map<int, E> asMap() => _listBase.asMap();

  void clear() {
    _listBase.clear();
    _dirty = false;
  }

  void fillRange(int start, int end, [E fillValue]) {
    _listBase.fillRange(start, end, fillValue);
    _dirty = true;
  }

  Iterable<E> getRange(int start, int end) => _listBase.getRange(start, end);

  int indexOf(E element, [int start = 0]) => _listBase.indexOf(element, start);

  void insert(int index, E element) {
    _listBase.insert(index, element);
    _dirty = true;
  }

  void insertAll(int index, Iterable<E> iterable) {
    _listBase.insertAll(index, iterable);
    _dirty = true;
  }

  int lastIndexOf(E element, [int start]) =>
      _listBase.lastIndexOf(element, start);

  void set length(int newLength) {
    _listBase.length = newLength;
    _dirty = true;
  }

  bool remove(Object value) {
    _dirty = true;
    return _listBase.remove(value);
  }

  E removeAt(int index) {
    _dirty = true;
    return _listBase.removeAt(index);
  }

  E removeLast() {
    _dirty = true;
    return _listBase.removeLast();
  }

  void removeRange(int start, int end) {
    _listBase.removeRange(start, end);
    _dirty = true;
  }

  void removeWhere(bool test(E element)) {
    _listBase.removeWhere(test);
    _dirty = true;
  }

  void replaceRange(int start, int end, Iterable<E> iterable) {
    _listBase.replaceRange(start, end, iterable);
    _dirty = true;
  }

  void retainWhere(bool test(E element)) {
    _listBase.retainWhere(test);
  }

  Iterable<E> get reversed => _listBase.reversed;

  void setAll(int index, Iterable<E> iterable) {
    _listBase.setAll(index, iterable);
    _dirty = true;
  }

  void setRange(int start, int end, Iterable<E> iterable, [int skipCount = 0]) {
    _listBase.setRange(start, end, iterable, skipCount);
    _dirty = true;
  }

  void shuffle([Random random]) {
    _listBase.shuffle(random);
    _dirty = true;
  }

  void sort([int compare(E a, E b)]) {
    _listBase.sort(compare);
    _dirty = true;
  }

  List<E> sublist(int start, [int end]) => _listBase.sublist(start, end);
}
