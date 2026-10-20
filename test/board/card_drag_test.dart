import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/board/card_drag.dart';

void main() {
  /// 卡片拖动前左上角在画布上的位置。
  const origin = Offset(100, 200);

  /// 按下的位置（画布坐标），在卡片里面。
  const press = Offset(130, 220);

  /// 移动超过这个距离才算拖动。
  const slop = 18.0;

  CardDragMachine pressed({Duration at = Duration.zero}) =>
      CardDragMachine()
        ..down('card-1', origin: origin, pointer: press, at: at, slop: slop);

  test('移动超过判定距离就开始拖动，卡片跟着指针走', () {
    final machine = pressed();

    machine.move(press + const Offset(30, 40), at: _ms(100));

    expect(
      machine.state,
      isA<CardDragging>()
          .having((s) => s.cardId, 'cardId', 'card-1')
          .having((s) => s.position, 'position', const Offset(130, 240)),
    );
  });

  test('拖动中继续移动，卡片位置跟着更新', () {
    final machine = pressed()..move(press + const Offset(30, 40), at: _ms(100));

    machine.move(press + const Offset(-50, 10), at: _ms(200));

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
    final machine = pressed()..move(press + const Offset(30, 40), at: _ms(100));

    final drop = machine.up();

    expect(drop, (cardId: 'card-1', position: const Offset(130, 240)));
    expect(machine.state, isA<CardDragIdle>());
  });

  test('卡片不会拖到画布左上角以外，坐标最小是 0', () {
    final machine = pressed();

    machine.move(press + const Offset(-500, -40), at: _ms(100));

    expect(
      machine.state,
      isA<CardDragging>().having(
        (s) => s.position,
        'position',
        const Offset(0, 160),
      ),
    );
  });

  test('按住 500ms 没有移动就是长按，之后再移动也不拖动', () {
    final machine = pressed(at: _ms(1000));

    machine.move(press + const Offset(5, 5), at: _ms(1300));
    machine.move(press + const Offset(80, 0), at: _ms(1500));

    expect(
      machine.state,
      isA<CardLongPressed>().having((s) => s.cardId, 'cardId', 'card-1'),
    );
    expect(machine.up(), isNull);
    expect(machine.state, isA<CardDragIdle>());
  });

  test('不到 500ms 就移动，是拖动', () {
    final machine = pressed(at: _ms(1000));

    machine.move(press + const Offset(80, 0), at: _ms(1499));

    expect(machine.state, isA<CardDragging>());
  });

  test('拖动被取消时回到 idle，松手不移动卡片', () {
    final machine = pressed()..move(press + const Offset(30, 40), at: _ms(100));

    machine.cancel();

    expect(machine.state, isA<CardDragIdle>());
    expect(machine.up(), isNull);
  });
}

Duration _ms(int milliseconds) => Duration(milliseconds: milliseconds);
