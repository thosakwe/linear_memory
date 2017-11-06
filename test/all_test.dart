import 'package:linear_memory/linear_memory.dart';
import 'package:test/test.dart';

main() {
  var memory = new LinearMemory(10);

  tearDown(memory.clear);

  test('finds block with lowest offset', () {
    var block = memory.allocate(4);
    expect(block.offset, 0);
    expect(block.size, 4);
  });

  test('allocates adjacent blocks if possible', () {
    var a = memory.allocate(7);
    var b = memory.allocate(1);
    expect(b.offset, a.size);
  });

  test('blocks cannot exceed total size', () {
    expect(memory.allocate(11), isNull);
  });

  test('cannot exceed total size when not empty', () {
    memory.allocate(5);
    expect(memory.allocate(6), isNull);
  });

  test('between other blocks', () {
    memory.allocate(4);
    var b = memory.allocate(2);
    memory.allocate(4);
    b.release();
    expect(memory.allocate(1).offset, b.offset);
  });

  test('can grow', () {
    expect(memory.grow(255).allocate(200), isNotNull);
  });

  test('grow a block', () {
    expect(memory.allocate(3).grow(7).size, 7);
    expect(memory.allocate(1).offset, 7);
  });

  test('only grow blocks in free space', () {
    var a = memory.allocate(1);
    memory.allocate(2);
    expect(a.grow(3), isNull);
    expect(a.grow(3, greedy: true), isNotNull);
  });

  test('greedy grow block', () {
    var a = memory.allocate(1);
    memory.allocate(2);
    expect(a.grow(3, greedy: true), isNotNull);

    // Next block should overlap the second block
    expect(memory.allocate(3).offset, 3);
  });

  test('optimize shifts blocks down', () {
    memory.allocate(3);
    var a = memory.allocate(2);
    memory.allocate(5);
    a.release();
    expect(memory.optimize(), {5: 3});
  });
}
