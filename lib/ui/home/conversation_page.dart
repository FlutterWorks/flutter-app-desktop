import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_app/account/account_server.dart';
import 'package:flutter_app/bloc/bloc_converter.dart';
import 'package:flutter_app/bloc/search_cubit.dart';
import 'package:flutter_app/constants/resources.dart';
import 'package:flutter_app/db/mixin_database.dart';
import 'package:flutter_app/db/extension/message_category.dart';
import 'package:flutter_app/enum/message_category.dart';
import 'package:flutter_app/ui/home/bloc/conversation_cubit.dart';
import 'package:flutter_app/ui/home/bloc/conversation_list_bloc.dart';
import 'package:flutter_app/bloc/paging/paging_bloc.dart';
import 'package:flutter_app/ui/home/bloc/multi_auth_cubit.dart';
import 'package:flutter_app/ui/home/bloc/slide_category_cubit.dart';
import 'package:flutter_app/ui/home/route/responsive_navigator_cubit.dart';
import 'package:flutter_app/utils/datetime_format_utils.dart';
import 'package:flutter_app/utils/hook.dart';
import 'package:flutter_app/utils/list_utils.dart';
import 'package:flutter_app/utils/message_optimize.dart';
import 'package:flutter_app/widgets/avatar_view/avatar_view.dart';
import 'package:flutter_app/widgets/brightness_observer.dart';
import 'package:flutter_app/widgets/high_light_text.dart';
import 'package:flutter_app/widgets/interacter_decorated_box.dart';
import 'package:flutter_app/widgets/menu.dart';
import 'package:flutter_app/widgets/message_status_icon.dart';
import 'package:flutter_app/widgets/search_bar.dart';
import 'package:flutter_app/widgets/unread_text.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_app/generated/l10n.dart';
import 'package:mixin_bot_sdk_dart/mixin_bot_sdk_dart.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:flutter_app/db/extension/conversation.dart';
import 'package:tuple/tuple.dart';

const _defaultLimit = 3;

class ConversationPage extends HookWidget {
  const ConversationPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hasKeyword = useBlocState<SearchCubit, SearchState>(
            bloc: context.read<SearchCubit>())
        .keyword
        .trim()
        .isNotEmpty;

    final textEditingController = useTextEditingController();
    final focusNode = useFocusNode();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<TextEditingController>.value(
          value: textEditingController,
        ),
        ChangeNotifierProvider<FocusNode>.value(
          value: focusNode,
        ),
      ],
      child: ColoredBox(
        color: BrightnessData.themeOf(context).background,
        child: Column(
          children: [
            const SearchBar(),
            if (!hasKeyword)
              Expanded(
                child: BlocBuilder<SlideCategoryCubit, SlideCategoryState>(
                  builder: (context, state) => _List(
                    key: PageStorageKey(state),
                  ),
                ),
              ),
            if (hasKeyword)
              const Expanded(
                child: _SearchList(),
              ),
          ],
        ),
      ),
    );
  }
}

enum _ShowMoreType {
  contact,
  conversation,
  message,
}

class _SearchList extends HookWidget {
  const _SearchList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final searchState = useBlocState<SearchCubit, SearchState>(
        bloc: context.read<SearchCubit>());
    final type = useState<_ShowMoreType?>(null);
    if (searchState.isEmpty)
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 43,
          vertical: 86,
        ),
        width: double.infinity,
        color: BrightnessData.themeOf(context).primary,
        child: Text(
          Localization.of(context).searchEmpty,
          style: TextStyle(
            fontSize: 14,
            color: BrightnessData.themeOf(context).secondaryText,
          ),
        ),
      );
    return CustomScrollView(
      slivers: [
        if (searchState.users.isNotEmpty)
          _SearchHeader(
            title: Localization.of(context).contact,
            showMore: searchState.users.length > _defaultLimit,
            more: type.value != _ShowMoreType.contact,
            onTap: () => type.value = _ShowMoreType.contact,
          ),
        if (searchState.users.isNotEmpty)
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (BuildContext context, int index) {
                final user = searchState.users[index];
                return _SearchItem(
                  avatar: AvatarWidget(
                    name: user.fullName!,
                    userId: user.userId,
                    size: 50,
                    avatarUrl: user.avatarUrl,
                  ),
                  name: user.fullName!,
                  keyword: searchState.keyword,
                  onTap: () async {
                    _clear(context);

                    context.read<ConversationCubit>().emit(
                          await context
                              .read<AccountServer>()
                              .database
                              .conversationDao
                              .conversationByUserId(user.userId),
                        );
                    ResponsiveNavigatorCubit.of(context)
                        .pushPage(ResponsiveNavigatorCubit.chatPage);
                  },
                );
              },
              childCount: type.value == _ShowMoreType.contact
                  ? searchState.users.length
                  : min(searchState.users.length, _defaultLimit),
            ),
          ),
        if (searchState.users.isNotEmpty)
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
        if (searchState.conversations.isNotEmpty)
          _SearchHeader(
            title: Localization.of(context).group,
            showMore: searchState.conversations.length > _defaultLimit,
            more: type.value != _ShowMoreType.conversation,
            onTap: () => type.value = _ShowMoreType.conversation,
          ),
        if (searchState.conversations.isNotEmpty)
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (BuildContext context, int index) {
                final conversation = searchState.conversations[index];
                return _SearchItem(
                  avatar: ConversationAvatarWidget(
                    conversationId: conversation.conversationId,
                    fullName: conversation.groupName ?? conversation.fullName,
                    groupIconUrl: conversation.groupIconUrl,
                    avatarUrl: conversation.avatarUrl,
                    category: conversation.category,
                    size: 50,
                  ),
                  name: (conversation.groupName?.trim().isNotEmpty == true
                          ? conversation.groupName
                          : conversation.fullName) ??
                      '',
                  keyword: searchState.keyword,
                  onTap: () async {
                    _clear(context);

                    context.read<ConversationCubit>().emit(
                          await context
                              .read<AccountServer>()
                              .database
                              .conversationDao
                              .conversationItem(conversation.conversationId),
                        );
                    ResponsiveNavigatorCubit.of(context)
                        .pushPage(ResponsiveNavigatorCubit.chatPage);
                  },
                );
              },
              childCount: type.value == _ShowMoreType.conversation
                  ? searchState.conversations.length
                  : min(searchState.conversations.length, _defaultLimit),
            ),
          ),
        if (searchState.conversations.isNotEmpty)
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
        if (searchState.messages.isNotEmpty)
          _SearchHeader(
            title: Localization.of(context).group,
            showMore: searchState.messages.length > _defaultLimit,
            more: type.value != _ShowMoreType.message,
            onTap: () => type.value = _ShowMoreType.message,
          ),
        if (searchState.messages.isNotEmpty)
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (BuildContext context, int index) {
                final message = searchState.messages[index];
                String? icon;
                late String description;
                if (message.type == MessageCategory.signalData ||
                    message.type == MessageCategory.plainData) {
                  icon = Resources.assetsImagesFileSvg;
                  description = message.mediaName!;
                } else if (message.type == MessageCategory.signalContact ||
                    message.type == MessageCategory.plainContact) {
                  icon = Resources.assetsImagesContactSvg;
                  description = message.mediaName!;
                } else {
                  description = message.content!;
                }

                return _SearchItem(
                  avatar: ConversationAvatarWidget(
                    conversationId: message.conversationId,
                    fullName: message.groupName ?? message.userFullName,
                    groupIconUrl: message.groupIconUrl,
                    avatarUrl: message.userAvatarUrl,
                    category: message.category,
                    size: 50,
                  ),
                  name: (message.groupName?.trim().isNotEmpty == true
                          ? message.groupName
                          : message.userFullName) ??
                      '',
                  nameHighlight: false,
                  keyword: searchState.keyword,
                  descriptionIcon: icon,
                  description: description,
                  date: message.createdAt,
                  onTap: () async {
                    _clear(context);

                    final conversation = await context
                        .read<AccountServer>()
                        .database
                        .conversationDao
                        .conversationItem(message.conversationId);

                    final index = await context
                        .read<AccountServer>()
                        .database
                        .messagesDao
                        .messageIndex(message.conversationId, message.messageId)
                        .getSingleOrNull();
                    context.read<ConversationCubit>().initIndex = index;
                    context.read<ConversationCubit>().emit(conversation);
                    ResponsiveNavigatorCubit.of(context)
                        .pushPage(ResponsiveNavigatorCubit.chatPage);
                  },
                );
              },
              childCount: type.value == _ShowMoreType.conversation
                  ? searchState.messages.length
                  : min(searchState.messages.length, _defaultLimit),
            ),
          ),
        if (searchState.messages.isNotEmpty)
          const SliverToBoxAdapter(child: SizedBox(height: 10))
      ],
    );
  }

  void _clear(BuildContext context) {
    context.read<SearchCubit>().keyword = '';
    context.read<TextEditingController>().text = '';
    context.read<FocusNode>().unfocus();
  }
}

class _SearchItem extends StatelessWidget {
  const _SearchItem({
    Key? key,
    required this.avatar,
    required this.name,
    required this.keyword,
    this.nameHighlight = true,
    required this.onTap,
    this.description,
    this.descriptionIcon,
    this.date,
  }) : super(key: key);

  final Widget avatar;
  final String name;
  final String keyword;
  final bool nameHighlight;
  final VoidCallback onTap;
  final String? description;
  final String? descriptionIcon;
  final DateTime? date;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 80,
          width: double.infinity,
          color: BrightnessData.themeOf(context).primary,
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 15,
          ),
          child: Row(
            children: [
              SizedBox(
                height: 50,
                width: 50,
                child: avatar,
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HighlightText(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: BrightnessData.themeOf(context).text,
                      fontSize: 16,
                    ),
                    highlightTextSpans: [
                      if (nameHighlight)
                        HighlightTextSpan(
                          keyword,
                          style: TextStyle(
                            color: BrightnessData.themeOf(context).accent,
                          ),
                        ),
                    ],
                  ),
                  if (description != null)
                    Row(
                      children: [
                        if (descriptionIcon != null)
                          SvgPicture.asset(
                            descriptionIcon!,
                            color:
                                BrightnessData.themeOf(context).secondaryText,
                          ),
                        Expanded(
                          child: HighlightText(
                            description!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: BrightnessData.themeOf(context).text,
                              fontSize: 14,
                            ),
                            highlightTextSpans: [
                              HighlightTextSpan(
                                keyword,
                                style: TextStyle(
                                  color: BrightnessData.themeOf(context).accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (date != null)
                          Text(
                            convertStringTime(date!),
                            style: TextStyle(
                              color:
                                  BrightnessData.themeOf(context).secondaryText,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _SearchHeader extends StatelessWidget {
  const _SearchHeader({
    Key? key,
    required this.title,
    required this.showMore,
    required this.onTap,
    required this.more,
  }) : super(key: key);

  final String title;
  final bool showMore;
  final VoidCallback onTap;
  final bool more;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
        child: Container(
          color: BrightnessData.themeOf(context).primary,
          padding: const EdgeInsets.only(
            top: 16,
            bottom: 10,
            right: 20,
            left: 20,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: BrightnessData.themeOf(context).text,
                ),
              ),
              if (showMore)
                GestureDetector(
                  onTap: onTap,
                  child: Text(
                    more
                        ? Localization.of(context).more
                        : Localization.of(context).less,
                    style: TextStyle(
                      fontSize: 14,
                      color: BrightnessData.themeOf(context).accent,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
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
          Localization.current.noData,
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
  Widget build(BuildContext context) => ColoredBox(
        color: BrightnessData.themeOf(context).primary,
        child: BlocBuilder<SlideCategoryCubit, SlideCategoryState>(
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
                              title: Localization.current.unPin,
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
                              title: Localization.current.pin,
                              onTap: () => Provider.of<AccountServer>(
                                context,
                                listen: false,
                              )
                                  .database
                                  .conversationDao
                                  .pin(conversation.conversationId),
                            ),
                          ContextMenu(
                            title: Localization.current.unMute,
                          ),
                          ContextMenu(
                            title: Localization.current.deleteChat,
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
          ),
        ),
      );
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
    final dynamicColor = BrightnessData.themeOf(context).secondaryText;
    return FutureBuilder<Tuple2<String?, String?>>(
      future: messageOptimize(
        conversation.messageStatus,
        conversation.contentType,
        conversation.content,
        UserRelationship.me == conversation.relationship,
      ),
      initialData: const Tuple2<String?, String?>(null, null),
      builder: (context, snapshot) => Row(
        children: [
          if (snapshot.data?.item1 != null)
            SvgPicture.asset(
              snapshot.data!.item1!,
              color: dynamicColor,
            ),
          if (snapshot.data?.item2 != null)
            Expanded(
              child: Text(
                snapshot.data!.item2!,
                style: TextStyle(
                  color: dynamicColor,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ].joinList(const SizedBox(width: 4)),
      ),
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
