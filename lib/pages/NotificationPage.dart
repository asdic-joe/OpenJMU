import 'package:flutter/material.dart';
import 'package:badges/badges.dart';
import 'package:extended_tabs/extended_tabs.dart';

import 'package:OpenJMU/constants/Constants.dart';
import 'package:OpenJMU/events/Events.dart';
import 'package:OpenJMU/model/Bean.dart';
import 'package:OpenJMU/model/PostController.dart';
import 'package:OpenJMU/model/CommentController.dart';
import 'package:OpenJMU/model/PraiseController.dart';
import 'package:OpenJMU/utils/ThemeUtils.dart';

class NotificationPage extends StatefulWidget {
  final Map arguments;

  NotificationPage({this.arguments});

  @override
  State<StatefulWidget> createState() => new NotificationPageState();
}

class NotificationPageState extends State<NotificationPage> with TickerProviderStateMixin {
  TabController _tabController, _mentionTabController;
  final List<IconData> actionsIcons = [Icons.alternate_email, Icons.comment, Icons.thumb_up];

  Color themeColor = ThemeUtils.currentColorTheme;
  Color primaryColor = Colors.white;
  Notifications currentNotifications;

  PostList _mentionPost;
  CommentList _mentionComment;
  CommentList _replyComment;
  PraiseList _praiseList;

  @override
  void initState() {
    super.initState();
    if (widget.arguments != null) {
      currentNotifications = widget.arguments['notifications'];
    } else {
      currentNotifications = new Notifications(0,0,0,0);
    }
    _tabController = new TabController(length: 3, vsync: this);
    _mentionTabController = new TabController(length: 2, vsync: this);
    postByMention();
    commentByMention();
    commentByReply();
    praiseList();
    Constants.eventBus.on<NotificationsChangeEvent>().listen((event) {
      if (this.mounted) {
        setState(() {
          currentNotifications = event.notifications;
        });
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  List<Widget> actions() {
    List<Tab> _tabs = [
      Tab(child: BadgeIconButton(
        itemCount: currentNotifications.at,
        icon: Icon(actionsIcons[0], color: primaryColor),
        badgeColor: themeColor,
        badgeTextColor: primaryColor,
        hideZeroCount: true,
        onPressed: () {
          _tabController.animateTo(0);
          var _notify = currentNotifications;
          setState(() {
            currentNotifications = new Notifications(_notify.count - _notify.at, 0, _notify.comment, _notify.praise);
          });
        },
      )),
      Tab(child: BadgeIconButton(
        itemCount: currentNotifications.comment,
        icon: Icon(actionsIcons[1], color: primaryColor),
        badgeColor: themeColor,
        badgeTextColor: primaryColor,
        hideZeroCount: true,
        onPressed: () {
          _tabController.animateTo(1);
          var _notify = currentNotifications;
          setState(() {
            currentNotifications = new Notifications(_notify.count - _notify.comment, _notify.at, 0, _notify.praise);
          });
        },
      )),
      Tab(child: BadgeIconButton(
        itemCount: currentNotifications.praise,
        icon: Icon(actionsIcons[2], color: primaryColor),
        badgeColor: themeColor,
        badgeTextColor: primaryColor,
        hideZeroCount: true,
        onPressed: () {
          _tabController.animateTo(2);
          var _notify = currentNotifications;
          setState(() {
            currentNotifications = new Notifications(_notify.count - _notify.praise, _notify.at, _notify.comment, 0);
          });
        },
      )),
    ];
//    actionsIcons.forEach((icon) => _tabs.add(
//      Tab(icon: new Icon(icon, color: primaryColor))
//    ));
    return [
      new Container(
        width: 200.0,
        child: new TabBar(
          tabs: _tabs,
          controller: _tabController,
        )
      )
    ];
  }

  Icon getActionIcon(int curIndex) {
    return new Icon(actionsIcons[curIndex], color: primaryColor);
  }

  void postByMention() {
    _mentionPost = new PostList(
        PostController(
            postType: "mention",
            isFollowed: false,
            isMore: false,
            lastValue: (Post post) => post.id
        ),
        needRefreshIndicator: true
    );
  }

  void commentByMention() {
    _mentionComment = new CommentList(
        CommentController(
            commentType: "mention",
            isMore: false,
            lastValue: (Comment comment) => comment.id
        ),
        needRefreshIndicator: true
    );
  }

  void commentByReply() {
    _replyComment = new CommentList(
        CommentController(
            commentType: "reply",
            isMore: false,
            lastValue: (Comment comment) => comment.id
        ),
        needRefreshIndicator: true
    );
  }

  void praiseList() {
    _praiseList = new PraiseList(
        PraiseController(
            isMore: false,
            lastValue: (Praise praise) => praise.id
        ),
        needRefreshIndicator: true
    );
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        backgroundColor: themeColor,
        elevation: 0,
        actions: actions(),
        iconTheme: new IconThemeData(color: primaryColor),
        brightness: Brightness.dark,
      ),
      body: ExtendedTabBarView(
        controller: _tabController,
        children: <Widget>[
          Column(
            children: <Widget>[
              Container(
                  width: MediaQuery.of(context).size.width,
                  height: 42.0,
                  color: themeColor,
                  child: TabBar(
                    labelColor: primaryColor,
                    tabs: <Tab>[
                      Tab(text: "@我的动态"),
                      Tab(text: "@我的评论"),
                    ],
                    controller: _mentionTabController,
                  )
              ),
              Expanded(
                  child: ExtendedTabBarView(
                      controller: _mentionTabController,
                      children: <Widget>[
                        _mentionPost,
                        _mentionComment,
                      ]
                  )
              ),
            ],
          ),
          _replyComment,
          _praiseList,
        ],
      ),
    );
  }

}