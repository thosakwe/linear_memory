import 'dart:async';

/// Represents a linear memory unit, and manages it efficiently.
class LinearMemory<T> {
  final List<_MemoryBlockImpl<T>> _blocks = [];
  final StreamController<MemoryBlock<T>> _onRelease = new StreamController(sync: true);
  T _defaultValue;
  int _size;

  LinearMemory(this._size, {T defaultValue}) : _defaultValue = defaultValue;

  int get size => _size;

  /// Fires whenever a memory block is released.
  Stream<MemoryBlock<T>> get onRelease => _onRelease.stream;

  void _release(MemoryBlock<T> block) {
    _blocks.remove(block);
    _onRelease.add(block);
  }

  Future close() => _onRelease.close();

  void clear() {
    for (var block in _blocks.toList())
      block.release();
  }

  /// Locates the first free memory block of the given [size].
  ///
  /// Returns `null` if no space is available.
  MemoryBlock<T> allocate(int size, [T value]) {
    if (size < 1)
      throw new ArgumentError('size must be >= 1.');

    // Find first open index
    int offset = 0;

    for (var block in _blocks) {
      // If there is already a block at this offset,
      // jump past it.
      if (offset == block.offset) {
        offset += block.size;
      }
    }

    if (offset >= this.size) {
      // No available memory at all
      return null;
    }

    // Now, find the first free range large enough to store this value
    while (offset > -1) {
      // Find the nearest block
      var closestBlock =
          _blocks.firstWhere((b) => b.offset >= offset, orElse: () => null);

      // See how much space is available
      var available = (closestBlock?.offset ?? this.size) - offset;

      if (available >= size) {
        // Hooray, this space is free!
        break;
      }

      // Otherwise, jump past the block
      else
        offset = (closestBlock?.offset ?? offset) + 1;

      // If we've reached the end of memory, there is no space available.
      if (offset >= this.size) return null;
    }

    // Create a new memory block
    var block = new _MemoryBlockImpl<T>(this, offset, size, _blocks.length)
      .._value = value ?? _defaultValue;
    _blocks.add(block);
    return block;
  }

  /// Copies this memory unit into a new, larger one.
  LinearMemory<T> grow(int newSize) {
    if (newSize < size) return this;
    return this.._size = newSize;
  }

  /// Moves all blocks as far left as possible, getting rid of empty gaps in memory.
  ///
  /// Returns a [Map] of old and new offsets.
  /// If a block was not moved, then its original offset will not appear in the return value.
  /// Thus, if the result is empty, then the memory had no empty gaps present.
  Map<int, int> optimize() {
    Map<int, int> out = {};
    int left = 0;

    for (var block in _blocks) {
      if (block.offset > left) {
        var original = block.offset;
        out[original] = block._offset = left;
        left += block.size;
      } else if (block.offset == left) {
        left += block.size;
      }
    }

    return out;
  }
}

/// A block of memory, optionally with an assigned value.
abstract class MemoryBlock<T> {
  int get offset;
  int get size;
  T get value;

  void release();

  /// Allocates a new memory block in the same spot.
  ///
  /// Returns `null` if no space is available.
  ///
  /// If [greedy] is `true` (default: `false`), then this
  /// operation can erase adjacent blocks if there is overlap.
  MemoryBlock<T> grow(int newSize, {bool greedy});
}

class _MemoryBlockImpl<T> implements MemoryBlock<T> {
  final LinearMemory<T> memory;
  final int size, index;
  int _offset;
  T _value;

  _MemoryBlockImpl(this.memory, this._offset, this.size, this.index);

  @override
  int get offset => _offset;

  @override
  T get value => _value;

  @override
  void release() {
    memory._release(this);
  }

  @override
  MemoryBlock<T> grow(int newSize, {bool greedy}) {
    if (greedy == true) return growGreedy(newSize);

    // Find the nearest block
    var closestBlock = memory._blocks
        .firstWhere((b) => b.offset >= offset && b != this, orElse: () => null);

    // See how much space is available
    int available;

    if (closestBlock != null) {
      available = closestBlock.offset - offset;
    } else {
      available = memory.size - offset;
    }

    if (available >= newSize) {
      // Hooray, this space is free!
      var block = new _MemoryBlockImpl<T>(memory, offset, newSize, index);
      return memory._blocks[index] = block.._value = _value;
    }

    return null;
  }

  MemoryBlock<T> growGreedy(int newSize) {
    // Release any block in the way
    var newEnd = offset + newSize;

    if (newEnd >= memory.size) return null;

    var blocks =
        memory._blocks.where((b) => b.offset >= offset && b != this).toList();

    for (var block in blocks) block.release();

    var block = new _MemoryBlockImpl<T>(memory, offset, newSize, index);
    return memory._blocks[index] = block.._value = _value;
  }
}
