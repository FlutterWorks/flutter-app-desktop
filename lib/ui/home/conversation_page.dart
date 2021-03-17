import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_app/account/account_server.dart';
import 'package:flutter_app/bloc/bloc_converter.dart';
import 'package:flutter_app/constants/resources.dart';
import 'package:flutter_app/db/mixin_database.dart';
import 'package:flutter_app/db/extension/message_category.dart';
import 'package:flutter_app/enum/message_category.dart';
import 'package:flutter_app/enum/message_status.dart';
import 'package:flutter_app/ui/home/bloc/conversation_cubit.dart';
import 'package:flutter_app/ui/home/bloc/conversation_list_bloc.dart';
import 'package:flutter_app/bloc/paging/paging_bloc.dart';
import 'package:flutter_app/ui/home/bloc/multi_auth_cubit.dart';
import 'package:flutter_app/ui/home/bloc/slide_category_cubit.dart';
import 'package:flutter_app/ui/home/route/responsive_navigator_cubit.dart';
import 'package:flutter_app/utils/datetime_format_utils.dart';
import 'package:flutter_app/utils/list_utils.dart';
import 'package:flutter_app/utils/markdown.dart';
import 'package:flutter_app/widgets/avatar_view/avatar_view.dart';
import 'package:flutter_app/widgets/brightness_observer.dart';
import 'package:flutter_app/widgets/interacter_decorated_box.dart';
import 'package:flutter_app/widgets/menu.dart';
import 'package:flutter_app/widgets/message/item/action/action_data.dart';
import 'package:flutter_app/widgets/message/item/action_card/action_card_data.dart';
import 'package:flutter_app/widgets/message_status_icon.dart';
import 'package:flutter_app/widgets/search_bar.dart';
import 'package:flutter_app/widgets/unread_text.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_app/generated/l10n.dart';
import 'package:mixin_bot_sdk_dart/mixin_bot_sdk_dart.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:flutter_app/db/extension/conversation.dart';

class ConversationPage extends StatelessWidget {
  const ConversationPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: BrightnessData.themeOf(context).primary,
      child: Column(
        children: [
          const SearchBar(),
          Expanded(
            child: BlocBuilder<SlideCategoryCubit, SlideCategoryState>(
              builder: (context, state) => _List(
                key: PageStorageKey(state),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dynamicColor = BrightnessData.dynamicColor(
      context,
      const Color.fromRGBO(229, 233, 240, 1),
    );
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SvgPicture.asset(
          Resources.assetsImagesConversationEmptySvg,
          height: 78,
          width: 58,
          color: dynamicColor,
        ),
        const SizedBox(height: 24),
        Text(
          Localization.of(context).noData,
          style: TextStyle(
            color: dynamicColor,
            fontSize: 14,
          ),
        ),
      ]),
    );
  }
}

class _List extends StatelessWidget {
  const _List({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) => BlocBuilder<SlideCategoryCubit,
          SlideCategoryState>(
      builder: (context, slideCategoryState) => BlocConverter<
              ConversationListBloc, PagingState<ConversationItem>, int>(
            converter: (state) => state.count,
            builder: (context, count) {
              if (count <= 0) return const _Empty();
              return ScrollablePositionedList.builder(
                key: PageStorageKey(slideCategoryState),
                itemPositionsListener:
                    BlocProvider.of<ConversationListBloc>(context)
                        .itemPositionsListener,
                itemCount: count,
                itemBuilder: (context, index) => BlocConverter<
                    ConversationListBloc,
                    PagingState<ConversationItem>,
                    ConversationItem?>(
                  converter: (state) => state.map[index],
                  builder: (context, conversation) {
                    if (conversation == null) return const SizedBox(height: 80);
                    return BlocConverter<ConversationCubit, ConversationItem?,
                        bool>(
                      converter: (state) =>
                          conversation.conversationId == state?.conversationId,
                      builder: (context, selected) => ContextMenuPortalEntry(
                        child: _Item(
                          selected: selected,
                          conversation: conversation,
                          onTap: () {
                            BlocProvider.of<ConversationCubit>(context)
                                .emit(conversation);
                            ResponsiveNavigatorCubit.of(context)
                                .pushPage(ResponsiveNavigatorCubit.chatPage);
                          },
                        ),
                        buildMenus: () => [
                          if (conversation.pinTime != null)
                            ContextMenu(
                              title: Localization.of(context).unPin,
                              onTap: () => Provider.of<AccountServer>(
                                context,
                                listen: false,
                              )
                                  .database
                                  .conversationDao
                                  .unpin(conversation.conversationId),
                            ),
                          if (conversation.pinTime == null)
                            ContextMenu(
                              title: Localization.of(context).pin,
                              onTap: () => Provider.of<AccountServer>(
                                context,
                                listen: false,
                              )
                                  .database
                                  .conversationDao
                                  .pin(conversation.conversationId),
                            ),
                          ContextMenu(
                            title: Localization.of(context).unMute,
                          ),
                          ContextMenu(
                            title: Localization.of(context).deleteChat,
                            isDestructiveAction: true,
                            onTap: () => Provider.of<AccountServer>(
                              context,
                              listen: false,
                            ).database.conversationDao.deleteConversation(
                                conversation.conversationId),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ));
}

class _Item extends StatelessWidget {
  const _Item({
    Key? key,
    this.selected = false,
    required this.conversation,
    required this.onTap,
  }) : super(key: key);

  final bool selected;
  final ConversationItem conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final messageColor = BrightnessData.themeOf(context).secondaryText;
    return InteractableDecoratedBox(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: DecoratedBox(
          decoration: selected
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: BrightnessData.themeOf(context).listSelected,
                )
              : const BoxDecoration(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  child: ConversationAvatarWidget(
                    conversation: conversation,
                    size: 50,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      (conversation.groupName
                                                      ?.trim()
                                                      .isNotEmpty ==
                                                  true
                                              ? conversation.groupName
                                              : conversation.name) ??
                                          '',
                                      style: TextStyle(
                                        color: BrightnessData.themeOf(context)
                                            .text,
                                        fontSize: 16,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  VerifiedOrBotWidget(
                                    verified: conversation.ownerVerified == 1,
                                    isBot: conversation.isBotConversation,
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              convertStringTime(
                                  conversation.lastMessageCreatedAt ??
                                      conversation.createdAt),
                              style: TextStyle(
                                color: messageColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(
                          height: 20,
                          child: Row(
                            children: [
                              Expanded(
                                child: _MessagePreview(
                                  messageColor: messageColor,
                                  conversation: conversation,
                                ),
                              ),
                              if ((conversation.unseenMessageCount ?? 0) > 0)
                                _UnreadText(conversation: conversation),
                              if ((conversation.unseenMessageCount ?? 0) <= 0)
                                _StatusRow(conversation: conversation),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class VerifiedOrBotWidget extends StatelessWidget {
  const VerifiedOrBotWidget({
    Key? key,
    required this.verified,
    required this.isBot,
  }) : super(key: key);
  final bool verified;
  final bool isBot;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (verified || isBot) const SizedBox(width: 4),
        if (verified)
          SvgPicture.asset(
            Resources.assetsImagesVerifiedSvg,
            width: 12,
            height: 12,
          ),
        if (isBot)
          SvgPicture.asset(
            Resources.assetsImagesBotFillSvg,
            width: 12,
            height: 12,
          ),
        if (verified || isBot) const SizedBox(width: 4),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    Key? key,
    required this.conversation,
  }) : super(key: key);
  final ConversationItem conversation;

  @override
  Widget build(BuildContext context) {
    final dynamicColor = BrightnessData.dynamicColor(
      context,
      const Color.fromRGBO(229, 231, 235, 1),
      darkColor: const Color.fromRGBO(255, 255, 255, 0.4),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (conversation.muteUntil?.isAfter(DateTime.now()) == true)
          SvgPicture.asset(
            Resources.assetsImagesMuteSvg,
            color: dynamicColor,
          ),
        if (conversation.pinTime != null)
          SvgPicture.asset(
            Resources.assetsImagesPinSvg,
            color: dynamicColor,
          ),
      ].joinList(const SizedBox(width: 4)),
    );
  }
}

class _UnreadText extends StatelessWidget {
  const _UnreadText({
    Key? key,
    required this.conversation,
  }) : super(key: key);

  final ConversationItem conversation;

  @override
  Widget build(BuildContext context) {
    return UnreadText(
      count: conversation.unseenMessageCount ?? 0,
      backgroundColor: conversation.pinTime?.isAfter(DateTime.now()) == true
          ? BrightnessData.themeOf(context).accent
          : BrightnessData.themeOf(context).secondaryText,
      textColor: conversation.pinTime != null
          ? BrightnessData.dynamicColor(
              context,
              const Color.fromRGBO(255, 255, 255, 1),
              darkColor: const Color.fromRGBO(255, 255, 255, 1),
            )
          : BrightnessData.themeOf(context).primary,
    );
  }
}

class _MessagePreview extends StatelessWidget {
  const _MessagePreview({
    Key? key,
    required this.messageColor,
    required this.conversation,
  }) : super(key: key);

  final Color messageColor;
  final ConversationItem conversation;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MessageStatusIcon(conversation: conversation),
          const SizedBox(width: 2),
          Expanded(
            child: _MessageContent(conversation: conversation),
          ),
        ],
      );
}

class _MessageContent extends StatelessWidget {
  const _MessageContent({
    Key? key,
    required this.conversation,
  }) : super(key: key);
  final ConversationItem conversation;

  @override
  Widget build(BuildContext context) {
    final isCurrentUser = UserRelationship.me == conversation.relationship;
    final dynamicColor = BrightnessData.themeOf(context).secondaryText;
    String? icon;
    String? content;

    if (conversation.messageStatus == MessageStatus.failed) {
      icon = Resources.assetsImagesSendingSvg;
      content = Localization.of(context).waitingForThisMessage;
    } else if (conversation.contentType.isText) {
      // todo markdown and mention
      content = conversation.content;
    } else if (conversation.contentType ==
        MessageCategory.systemAccountSnapshot) {
      content = '[${Localization.of(context).transfer}]';
      icon = Resources.assetsImagesTransferSvg;
    } else if (conversation.contentType.isSticker) {
      content = '[${Localization.of(context).sticker}]';
      icon = Resources.assetsImagesStickerSvg;
    } else if (conversation.contentType.isImage) {
      content = '[${Localization.of(context).image}]';
      icon = Resources.assetsImagesImageSvg;
    } else if (conversation.contentType.isVideo) {
      content = '[${Localization.of(context).video}]';
      icon = Resources.assetsImagesVideoSvg;
    } else if (conversation.contentType.isLive) {
      content = '[${Localization.of(context).live}]';
      icon = Resources.assetsImagesLiveSvg;
    } else if (conversation.contentType.isData) {
      content = '[${Localization.of(context).file}]';
      icon = Resources.assetsImagesFileSvg;
    } else if (conversation.contentType.isPost) {
      icon = Resources.assetsImagesFileSvg;
      content = conversation.content!.postOptimizeMarkdown;
    } else if (conversation.contentType.isLocation) {
      content = '[${Localization.of(context).location}]';
      icon = Resources.assetsImagesLocationSvg;
    } else if (conversation.contentType.isAudio) {
      content = '[${Localization.of(context).audio}]';
      icon = Resources.assetsImagesAudioSvg;
    } else if (conversation.contentType == MessageCategory.appButtonGroup) {
      content = 'APP_BUTTON_GROUP';
      if (conversation.content != null)
        content = jsonDecode(conversation.content!)
            .map((e) => ActionData.fromJson(e))
            .map((e) => '[${e.label}]')
            .join();
      icon = Resources.assetsImagesAppButtonSvg;
    } else if (conversation.contentType == MessageCategory.appCard) {
      content = 'APP_CARD';
      if (conversation.content != null)
        content = AppCardData.fromJson(jsonDecode(conversation.content!)).title;
      icon = Resources.assetsImagesAppButtonSvg;
    } else if (conversation.contentType.isContact) {
      content = '[${Localization.of(context).contact}]';
      icon = Resources.assetsImagesContactSvg;
    } else if (conversation.contentType.isCallMessage) {
      content = '[${Localization.of(context).videoCall}]';
      icon = Resources.assetsImagesVideoCallSvg;
    } else if (conversation.contentType.isRecall) {
      content =
          '[${isCurrentUser ? Localization.of(context).chatRecallMe : Localization.of(context).chatRecallDelete}]';
      icon = Resources.assetsImagesRecallSvg;
    } else if (conversation.contentType.isGroupCall) {
// todo
    }

    return Row(
      children: [
        if (icon != null)
          SvgPicture.asset(
            icon,
            color: dynamicColor,
          ),
        if (content != null)
          Expanded(
            child: Text(
              content,
              style: TextStyle(
                color: dynamicColor,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ].joinList(const SizedBox(width: 4)),
    );
  }
}

class _MessageStatusIcon extends StatelessWidget {
  const _MessageStatusIcon({
    Key? key,
    required this.conversation,
  }) : super(key: key);

  final ConversationItem conversation;

  @override
  Widget build(BuildContext context) {
    if (MultiAuthCubit.of(context).state.current?.account.userId ==
            conversation.senderId &&
        conversation.contentType != MessageCategory.systemConversation &&
        conversation.contentType != MessageCategory.systemAccountSnapshot &&
        !conversation.contentType.isCallMessage &&
        !conversation.contentType.isRecall &&
        !conversation.contentType.isGroupCall) {
      return MessageStatusIcon(
        status: conversation.messageStatus,
      );
    }
    return const SizedBox();
  }
}
