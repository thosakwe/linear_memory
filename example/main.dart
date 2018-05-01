import 'package:linear_memory/linear_memory.dart';
import 'package:test/test.dart';

main() {
  var memory = new LinearMemory(10);

  // Mark a continuous number of bytes as in use.
  var block = memory.allocate(4);
  expect(block.offset, 0);
  expect(block.size, 4);

  // Returns `null` is the requested memory is out-of-bounds.
  var exceedsBounds = memory.allocate(7);
  expect(exceedsBounds, isNull);

  // A memory unit can grow in place.
  memory.grow(32);

  // Memory units are generic, and each block can have a value.
  var buffers = new LinearMemory<double>(250);
  var twentyFour = buffers.allocate(45, 24.0);

  // The offset of each memory block is statically computed.
  print(twentyFour.offset);

  // Blocks can grow in size.
  twentyFour.grow(150);

  // Blocks can be released.
  twentyFour.release();
}
