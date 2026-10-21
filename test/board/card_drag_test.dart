import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/board/card_drag.dart';

void main() {
  /// 卡片拖动前左上角在画布上的位置。
  const origin = Offset(100, 200);

  /// 按下的位置（画布坐标），在卡片里面。
  const press = Offset(130, 220);

  /// 移动超过这个距离才算拖动。
  const slop = 18.0;

  CardDragMachine pressed() =>
      CardDragMachine()
        ..down('card-1', origin: origin, pointer: press, slop: slop);

  test('移动超过判定距离就开始拖动，卡片跟着指针走', () {
    final machine = pressed();

    machine.move(press + const Offset(30, 40));

    expect(
      machine.state,
      isA<CardDragging>()
          .having((s) => s.cardId, 'cardId', 'card-1')
          .having((s) => s.position, 'position', const Offset(130, 240)),
    );
  });

  test('拖动中继续移动，卡片位置跟着更新', () {
    final machine = pressed()..move(press + const Offset(30, 40));

    machine.move(press + const Offset(-50, 10));

    expect(
      machine.state,
      isA<CardDragging>().having(
        (s) => s.position,
        'position',
        const Offset(50, 210),
      ),
    );
  });

  test('拖动后松手，给出卡片要移到的位置，回到 idle', () {
    final machine = pressed()..move(press + const Offset(30, 40));

    final drop = machine.up();

    expect(drop, (cardId: 'card-1', position: const Offset(130, 240)));
    expect(machine.state, isA<CardDragIdle>());
  });

  test('卡片不会拖到画布左上角以外，坐标最小是 0', () {
    final machine = pressed();

    machine.move(press + const Offset(-500, -40));

    expect(
      machine.state,
      isA<CardDragging>().having(
        (s) => s.position,
        'position',
        const Offset(0, 160),
      ),
    );
  });

  test('拖动被取消时回到 idle，松手不移动卡片', () {
    final machine = pressed()..move(press + const Offset(30, 40));

    machine.cancel();

    expect(machine.state, isA<CardDragIdle>());
    expect(machine.up(), isNull);
  });
}
