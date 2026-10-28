/// 更新建议：后续邮件对已加入事项的改动提议，她点 [采用] 才写到卡片上
/// （spec 0002"更新建议的规则"）。
library;

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';

import '../planner/planner_exceptions.dart';
import '../planner/planner_service.dart';
import '../planner/task_card.dart';
import '../storage/planner_database.dart';
import 'item_changes.dart';
import 'item_rows.dart';
import 'mail_items.dart';
import 'mail_states.dart';

/// 更新建议的生成、显示、[采用] 和 [不用]。写操作不自己开事务，由
/// `MailService` 在它的事务里调用。
class ItemUpdates {
  ItemUpdates({
    required PlannerService planner,
    required this._clock,
    required this._generateId,
  }) : _planner = planner,
       _db = planner.database;

  final PlannerService _planner;
  final PlannerDatabase _db;
  final Clock _clock;
  final String Function() _generateId;

  /// 后续邮件 [mailId] 把已加入的事项 [target] 改成 [after]：之前的建议
  /// 一律被替代，有改动时新建一条建议。卡片不在画布上或已完成时什么都
  /// 不做，返回 false。
  Future<bool> propose(
    MailItemRow target,
    ItemFields after, {
    required String mailId,
    required int now,
  }) async {
    if (await _openCard(target.cardId) == null) return false;
    // 和卡片上采用过的不一样、也不是她不用过的，才算改动。
    final rejectedToo = ItemChanges.between(await knownFields(target), after);
    final applied = ItemChanges.between(
      await knownFields(target, withRejected: false),
      after,
    );
    final changes = ItemChanges(
      rejectedToo.fields.intersection(applied.fields),
      after,
    );
    // 这封邮件比之前的建议新：之前的建议不管怎样都被替代。
    final updates = _db.mailItemUpdates;
    await (_db.update(updates)..where(
          (u) =>
              u.itemId.equals(target.id) &
              u.status.equalsValue(MailItemUpdateStatus.pending),
        ))
        .write(
          MailItemUpdatesCompanion(
            status: const Value(MailItemUpdateStatus.superseded),
            resolvedAt: Value(now),
          ),
        );
    if (changes.isEmpty) return true;
    await _db
        .into(updates)
        .insert(
          MailItemUpdatesCompanion.insert(
            id: _generateId(),
            itemId: target.id,
            mailId: mailId,
            changes: changes.encode(),
            status: MailItemUpdateStatus.pending,
            createdAt: now,
          ),
        );
    return true;
  }

  /// 事项 [item] 现在已知的可更新字段：事项本身的，再按顺序叠上她采用过
  /// 的更新建议；[withRejected] 时也叠上她不用的，同样的改动以后不再提。
  /// 不叠不用的时候，就是卡片备注里来自邮件的那些内容。
  Future<ItemFields> knownFields(
    MailItemRow item, {
    bool withRejected = true,
  }) async {
    final mail = await (_db.select(
      _db.mails,
    )..where((m) => m.id.equals(item.mailId))).getSingle();
    var fields = item.fields(mail.linkList);
    final resolved =
        await (_db.select(_db.mailItemUpdates)
              ..where(
                (u) =>
                    u.itemId.equals(item.id) &
                    u.status.isInValues([
                      MailItemUpdateStatus.applied,
                      if (withRejected) MailItemUpdateStatus.rejected,
                    ]),
              )
              ..orderBy([(u) => OrderingTerm.asc(u.createdAt)]))
            .get();
    for (final update in resolved) {
      fields = fields.overlay(ItemChanges.decode(update.changes));
    }
    return fields;
  }

  /// 卡片上要显示的更新建议，按卡片 id。只有画布上没完成的卡片；同一张
  /// 卡片只有最新的一条（旧的已经被替代）。
  Stream<Map<String, CardUpdate>> watch() {
    final updates = _db.mailItemUpdates;
    final items = _db.mailItems;
    final cards = _db.taskCards;
    final query =
        _db.select(updates).join([
          innerJoin(items, items.id.equalsExp(updates.itemId)),
          innerJoin(cards, cards.id.equalsExp(items.cardId)),
        ])..where(
          updates.status.equalsValue(MailItemUpdateStatus.pending) &
              cards.status.equalsValue(CardStatus.active) &
              cards.deletedAt.isNull(),
        );
    return query.watch().map((rows) {
      return {
        for (final row in rows)
          row.readTable(cards).id: CardUpdate(
            id: row.readTable(updates).id,
            cardId: row.readTable(cards).id,
            changes: ItemChanges.decode(row.readTable(updates).changes),
            cardTimes: row.readTable(cards).times,
          ),
      };
    });
  }

  /// [采用]：只把建议里列出的字段写到卡片上，她改过的其他内容不变；备注里
  /// 只换掉对应的那一部分，找不到时把新内容加在最后。
  ///
  /// 建议已经处理过或被替代、卡片已经不在画布上时抛出 [InvalidState]。
  Future<void> apply(String updateId) async {
    final update = await _requirePending(updateId);
    final item = await (_db.select(
      _db.mailItems,
    )..where((i) => i.id.equals(update.itemId))).getSingle();
    final card = await _openCard(item.cardId);
    if (card == null) throw const InvalidState('卡片已经不在画布上了');
    final changes = ItemChanges.decode(update.changes);
    final before = (await knownFields(item, withRejected: false)).noteParts;
    final after = changes.values.noteParts;
    var note = card.note ?? '';
    for (final field in after.keys) {
      if (changes.fields.contains(field)) {
        note = _replaceNotePart(note, before[field], after[field]);
      }
    }
    final times = card.times;
    final changed = changes.fields;
    await _planner.updateCardContentInTransaction(
      card.id,
      title: changed.contains(ItemField.title)
          ? truncateCharacters(
              changes.values.title,
              PlannerService.maxTitleLength,
            )
          : card.title,
      note: note.trim().isEmpty
          ? null
          : truncateCharacters(note, PlannerService.maxNoteLength),
      times: (
        event: changed.contains(ItemField.eventTime)
            ? changes.values.eventTime
            : times.event,
        due: changed.contains(ItemField.dueTime)
            ? changes.values.dueTime
            : times.due,
      ),
    );
    await _resolve(updateId, MailItemUpdateStatus.applied);
  }

  /// [不用]：建议不再显示，同样的改动以后也不再提。建议已经处理过或被
  /// 替代时抛出 [InvalidState]。
  Future<void> reject(String updateId) async {
    await _requirePending(updateId);
    await _resolve(updateId, MailItemUpdateStatus.rejected);
  }

  Future<MailItemUpdateRow> _requirePending(String updateId) async {
    final update = await (_db.select(
      _db.mailItemUpdates,
    )..where((u) => u.id.equals(updateId))).getSingleOrNull();
    if (update == null) throw NotFound('找不到更新建议 $updateId');
    if (update.status != MailItemUpdateStatus.pending) {
      throw const InvalidState('这条更新已经处理过了');
    }
    return update;
  }

  Future<void> _resolve(String updateId, MailItemUpdateStatus status) =>
      (_db.update(
        _db.mailItemUpdates,
      )..where((u) => u.id.equals(updateId))).write(
        MailItemUpdatesCompanion(
          status: Value(status),
          resolvedAt: Value(_clock.now().toUtc().millisecondsSinceEpoch),
        ),
      );

  /// 卡片 [cardId]，要在画布上、没完成、不在回收站；否则为 null。
  Future<TaskCardRow?> _openCard(String? cardId) async {
    if (cardId == null) return null;
    final card = await (_db.select(
      _db.taskCards,
    )..where((c) => c.id.equals(cardId))).getSingleOrNull();
    return card?.isOpen ?? false ? card : null;
  }

  /// 在备注 [note] 里把 [before] 换成 [after]：[after] 为 null 时删掉
  /// [before] 那一段；备注里没有 [before] 时把 [after] 加在最后。
  static String _replaceNotePart(String note, String? before, String? after) {
    if (before != null && note.contains(before)) {
      if (after != null) return note.replaceFirst(before, after);
      for (final part in ['$before\n', '\n$before', before]) {
        if (note.contains(part)) return note.replaceFirst(part, '');
      }
    }
    if (after == null) return note;
    return note.isEmpty ? after : '$note\n$after';
  }
}
