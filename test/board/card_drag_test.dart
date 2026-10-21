import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/board/card_drag.dart';
import 'package:my_personal_use_app/planner/link_geometry.dart';

void main() {
  /// 卡片拖动前左上角在画布上的位置。
  const origin = Offset(100, 200);

  /// 按下的位置（画布坐标），在卡片里面。
  const press = Offset(130, 220);

  /// 移动超过这个距离才算拖动。
  const slop = 18.0;

  /// 画布上另一张卡片，拖动时可以碰到它。
  const target = (x: 400.0, y: 200.0, width: 180.0, height: 88.0);
  const cards = <String, CardBox>{'card-2': target};

  /// 在目标卡片里面的一个指针位置。
  const onTarget = Offset(450, 230);

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

    final release = machine.up();

    expect(
      release,
      isA<CardMoved>().having((r) => r.drop, 'drop', (
        cardId: 'card-1',
        position: const Offset(130, 240),
      )),
    );
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

  test('指针进入另一张卡片就开始悬停，卡片仍然跟着指针走', () {
    final machine = pressed()..move(press + const Offset(30, 40));

    machine.move(onTarget, cards: cards, now: Duration.zero);

    expect(
      machine.state,
      isA<CardHovering>()
          .having((s) => s.targetId, 'targetId', 'card-2')
          .having((s) => s.position, 'position', onTarget - press + origin),
    );
  });

  /// 已经拖到目标卡片上、在 [Duration.zero] 开始悬停。
  CardDragMachine hovering() => pressed()
    ..move(press + const Offset(30, 40))
    ..move(onTarget, cards: cards, now: Duration.zero);

  test('在同一张卡片上移动不重新计时，停满 400ms 进入 armed', () {
    final machine = hovering()
      ..move(
        onTarget + const Offset(20, 10),
        cards: cards,
        now: const Duration(milliseconds: 200),
      );

    machine.tick(const Duration(milliseconds: 399));
    expect(machine.state, isA<CardHovering>());

    machine.tick(const Duration(milliseconds: 400));
    expect(
      machine.state,
      isA<CardArmed>()
          .having((s) => s.targetId, 'targetId', 'card-2')
          .having(
            (s) => s.position,
            'position',
            onTarget + const Offset(20, 10) - press + origin,
          ),
    );
  });

  /// 目标卡片外面的空白处。
  const offTarget = Offset(300, 400);

  test('不到 400ms 就离开回到普通拖动，再进入重新计时', () {
    final machine = hovering()
      ..move(offTarget, cards: cards, now: const Duration(milliseconds: 300));
    expect(machine.state, isNot(isA<CardHovering>()));
    expect(machine.state, isA<CardDragging>());

    machine
      ..move(onTarget, cards: cards, now: const Duration(milliseconds: 350))
      ..tick(const Duration(milliseconds: 700));
    expect(machine.state, isA<CardHovering>());

    machine.tick(const Duration(milliseconds: 750));
    expect(machine.state, isA<CardArmed>());
  });

  test('armed 后移开就取消，回到普通拖动', () {
    final machine = hovering()..tick(CardDragMachine.armDelay);

    machine.move(offTarget, cards: cards, now: const Duration(seconds: 1));

    expect(machine.state, isNot(isA<CardArmed>()));
    expect(machine.state, isA<CardDragging>());
  });

  test('停在被拖卡片自己下面不算碰到卡片', () {
    final machine = pressed()..move(press + const Offset(30, 40));

    machine.move(
      press + const Offset(40, 40),
      cards: {'card-1': (x: 0, y: 0, width: 600, height: 600), ...cards},
      now: Duration.zero,
    );

    expect(machine.state, isNot(isA<CardHovering>()));
  });

  test('悬停不到 400ms 就松手，当作普通移动', () {
    final machine = hovering();

    final release = machine.up();

    expect(
      release,
      isA<CardMoved>().having((r) => r.drop, 'drop', (
        cardId: 'card-1',
        position: onTarget - press + origin,
      )),
    );
    expect(machine.state, isA<CardDragIdle>());
  });

  test('armed 时松手，给出要连线的两张卡片，以及被拖卡片松手的位置和起点', () {
    final machine = hovering()..tick(CardDragMachine.armDelay);

    final release = machine.up();

    expect(
      release,
      isA<CardLinkToggled>()
          .having((r) => r.cardId, 'cardId', 'card-1')
          .having((r) => r.targetId, 'targetId', 'card-2')
          .having((r) => r.releasedAt, 'releasedAt', onTarget - press + origin)
          .having((r) => r.origin, 'origin', origin),
    );
    expect(machine.state, isA<CardDragIdle>());
  });
}
