import 'package:flutter_app/db/mixin_database.dart';
import 'package:moor/moor.dart';

part 'resend_session_messages_dao.g.dart';

@UseDao(tables: [ResendSessionMessages])
class ResendSessionMessagesDao extends DatabaseAccessor<MixinDatabase>
    with _$ResendSessionMessagesDaoMixin {
  ResendSessionMessagesDao(MixinDatabase db) : super(db);

  Future<int> insert(ResendSessionMessage resendSessionMessage) =>
      into(db.resendSessionMessages).insertOnConflictUpdate(resendSessionMessage);

  Future deleteResendSessionMessage(
          ResendSessionMessage resendSessionMessage) =>
      delete(db.resendSessionMessages).delete(resendSessionMessage);
}
