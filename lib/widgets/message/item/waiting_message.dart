import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_app/db/mixin_database.dart' hide Offset, Message;
import 'package:flutter_app/widgets/brightness_observer.dart';
import 'package:flutter_app/generated/l10n.dart';
import 'package:mixin_bot_sdk_dart/mixin_bot_sdk_dart.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../mouse_region_span.dart';
import '../message_bubble.dart';
import '../message_datetime.dart';
import '../message_status.dart';

class WaitingMessage extends StatelessWidget {
  const WaitingMessage({
    Key key,
    @required this.showNip,
    @required this.isCurrentUser,
    @required this.message,
  }) : super(key: key);

  final bool showNip;
  final bool isCurrentUser;
  final MessageItem message;

  @override
  Widget build(BuildContext context) => MessageBubble(
        showNip: showNip,
        isCurrentUser: isCurrentUser,
        child: Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            RichText(
              text: TextSpan(
                text: Localization.of(context).chatWaiting(
                  message.relationship == UserRelationship.me
                      ? Localization.of(context).chatWaitingDesktop
                      : message.userFullName,
                ),
                style: TextStyle(
                  fontSize: 16,
                  color: BrightnessData.themeOf(context).text,
                ),
                children: [
                  MouseRegionSpan(
                    mouseCursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () =>
                          launch(Localization.of(context).chatNotSupportUrl),
                      child: Text(
                        Localization.of(context).chatLearn,
                        style: TextStyle(
                          fontSize: 16,
                          color: BrightnessData.themeOf(context).accent,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                MessageDatetime(dateTime: message.createdAt),
                if (isCurrentUser) MessageStatusWidget(status: message.status),
              ],
            ),
          ],
        ),
      );
}
