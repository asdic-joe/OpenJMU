import 'dart:math';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:extended_text_field/extended_text_field.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

import 'package:openjmu/constants/constants.dart';
import 'package:openjmu/widgets/rounded_check_box.dart';
import 'package:openjmu/widgets/dialogs/mention_people_dialog.dart';

@FFRoute(
  name: "openjmu://add-comment",
  routeName: "新增评论",
  argumentNames: ["post", "comment"],
  pageRouteType: PageRouteType.transparent,
)
class CommentPositioned extends StatefulWidget {
  final Post post;
  final Comment comment;

  const CommentPositioned({
    Key key,
    @required this.post,
    this.comment,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => CommentPositionedState();
}

class CommentPositionedState extends State<CommentPositioned> {
  final _commentController = TextEditingController();
  final _focusNode = FocusNode();
  File _image;
  int _imageID;

  Comment toComment;

  bool _commenting = false;
  bool forwardAtTheMeanTime = false;

  String commentContent = '';
  bool emoticonPadActive = false;

  double _keyboardHeight;

  @override
  void initState() {
    super.initState();
    if (widget.comment != null)
      setState(() {
        toComment = widget.comment;
      });
    _commentController
      ..addListener(() {
        setState(() {
          commentContent = _commentController.text;
        });
      });
  }

  @override
  void dispose() {
    super.dispose();
    _commentController?.dispose();
  }

  Future<void> _addImage() async {
    final file = await ImagePicker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    _image = file;
    if (mounted) setState(() {});
  }

  FormData createForm(File file) => FormData.from({
        'image': UploadFileInfo(file, path.basename(file.path)),
        'image_type': 0,
      });

  Future getImageRequest(FormData formData) async => NetUtils.postWithCookieAndHeaderSet(
        API.postUploadImage,
        data: formData,
      );

  Widget textField(context) {
    String _hintText;
    toComment != null ? _hintText = '回复:@${toComment.fromUserName} ' : _hintText = null;
    return ExtendedTextField(
      specialTextSpanBuilder: StackSpecialTextFieldSpanBuilder(),
      focusNode: _focusNode,
      controller: _commentController,
      decoration: InputDecoration(
        contentPadding: EdgeInsets.all(suSetWidth(16.0)),
        border: OutlineInputBorder(
          borderSide: BorderSide(color: currentThemeColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: currentThemeColor),
        ),
        hintText: _hintText,
        hintStyle: TextStyle(
          fontSize: suSetSp(20.0),
          textBaseline: TextBaseline.alphabetic,
        ),
        suffixIcon: _image != null
            ? Container(
                margin: EdgeInsets.only(right: suSetWidth(14.0)),
                width: suSetWidth(70.0),
                child: Image.file(
                  _image,
                  fit: BoxFit.cover,
                ),
              )
            : null,
      ),
      enabled: !_commenting,
      style: Theme.of(context).textTheme.body1.copyWith(
            fontSize: suSetSp(20.0),
            textBaseline: TextBaseline.alphabetic,
          ),
      cursorColor: currentThemeColor,
      autofocus: true,
      maxLines: 3,
      maxLength: 233,
    );
  }

  Future _request(context) async {
    if (commentContent.length <= 0 && _image == null) {
      showCenterErrorToast('内容不能为空！');
    } else {
      setState(() {
        _commenting = true;
      });
      String content = '';

      Comment _c = widget.comment;
      int _cid;
      if (toComment != null) {
        content =
            '回复:<M ${_c.fromUserUid}>@${_c.fromUserName}</M> $content${_commentController.text}';
        _cid = _c.id;
      } else {
        content = '$content${_commentController.text}';
      }

      /// Sending image if it exist.
      if (_image != null) {
        Map<String, dynamic> data = (await getImageRequest(createForm(_image))).data;
        _imageID = int.parse(data['image_id']);
        content += ' |$_imageID| ';
      }

      CommentAPI.postComment(
        content,
        widget.post.id,
        forwardAtTheMeanTime,
        replyToId: _cid,
      ).then((response) {
        showToast('评论成功');
        Navigator.of(context).pop();
        Instances.eventBus.fire(PostCommentedEvent(widget.post.id));
      }).catchError((e) {
        _commenting = false;
        debugPrint('Comment post failed: $e');
        if (e is DioError && e.response.statusCode == 404) {
          showToast('动态已被删除');
          Navigator.of(context).pop();
        } else {
          showToast('评论失败');
        }
        if (mounted) setState(() {});
      });
    }
  }

  void updatePadStatus(bool active) {
    final change = () {
      emoticonPadActive = active;
      if (mounted) setState(() {});
    };
    if (emoticonPadActive) {
      change();
    } else {
      if (MediaQuery.of(context).viewInsets.bottom != 0.0) {
        SystemChannels.textInput.invokeMethod('TextInput.hide').whenComplete(
          () {
            Future.delayed(300.milliseconds, null).whenComplete(change);
          },
        );
      } else {
        change();
      }
    }
  }

  void insertText(String text) {
    var value = _commentController.value;
    int start = value.selection.baseOffset;
    int end = value.selection.extentOffset;
    if (value.selection.isValid) {
      String newText = '';
      if (value.selection.isCollapsed) {
        if (end > 0) {
          newText += value.text.substring(0, end);
        }
        newText += text;
        if (value.text.length > end) {
          newText += value.text.substring(end, value.text.length);
        }
      } else {
        newText = value.text.replaceRange(start, end, text);
      }
      setState(() {
        _commentController.value = value.copyWith(
          text: newText,
          selection: value.selection.copyWith(
            baseOffset: end + text.length,
            extentOffset: end + text.length,
          ),
        );
      });
    }
  }

  Widget emoticonPad(context) {
    return EmotionPad(
      active: emoticonPadActive,
      height: _keyboardHeight,
      route: 'comment',
      controller: _commentController,
    );
  }

  void mentionPeople(context) {
    showDialog<User>(
      context: context,
      builder: (BuildContext context) => MentionPeopleDialog(),
    ).then((user) {
      _focusNode.requestFocus();
      if (user != null) {
        Future.delayed(250.milliseconds, () {
          insertText('<M ${user.id}>@${user.nickname}<\/M>');
        });
      }
    });
  }

  Widget get toolbar => SizedBox(
        height: suSetHeight(40.0),
        child: Row(
          children: <Widget>[
            RoundedCheckbox(
              activeColor: currentThemeColor,
              value: forwardAtTheMeanTime,
              onChanged: (value) {
                setState(() {
                  forwardAtTheMeanTime = value;
                });
              },
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            Text(
              '同时转发到微博',
              style: TextStyle(
                fontSize: suSetSp(20.0),
              ),
            ),
            Spacer(),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _addImage,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: suSetWidth(6.0),
                ),
                child: Icon(
                  Icons.add_photo_alternate,
                  size: suSetWidth(32.0),
                ),
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                mentionPeople(context);
              },
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: suSetWidth(6.0),
                ),
                child: Icon(
                  Icons.alternate_email,
                  size: suSetWidth(32.0),
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                if (emoticonPadActive && _focusNode.canRequestFocus) {
                  _focusNode.requestFocus();
                }
                updatePadStatus(!emoticonPadActive);
              },
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: suSetWidth(6.0),
                ),
                child: Icon(
                  Icons.sentiment_very_satisfied,
                  size: suSetWidth(32.0),
                  color: emoticonPadActive ? currentThemeColor : Theme.of(context).iconTheme.color,
                ),
              ),
            ),
            !_commenting
                ? GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: suSetWidth(6.0),
                      ),
                      child: Icon(
                        Icons.send,
                        size: suSetWidth(32.0),
                        color: currentThemeColor,
                      ),
                    ),
                    onTap: (_commentController.text.length > 0 || _image != null)
                        ? () => _request(context)
                        : null,
                  )
                : Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: suSetWidth(14.0),
                    ),
                    child: SizedBox(
                      width: suSetWidth(12.0),
                      height: suSetWidth(12.0),
                      child: PlatformProgressIndicator(strokeWidth: 2.0),
                    ),
                  ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    if (keyboardHeight > 0) {
      emoticonPadActive = false;
    }
    _keyboardHeight = max(keyboardHeight, _keyboardHeight ?? 0);

    return Material(
      color: Colors.black38,
      child: Column(
        children: <Widget>[
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Navigator.of(context).pop();
              },
            ),
          ),
          AnimatedContainer(
            curve: Curves.ease,
            duration: 100.milliseconds,
            color: Theme.of(context).cardColor,
            padding: EdgeInsets.only(
              bottom: !emoticonPadActive ? MediaQuery.of(context).padding.bottom : 0.0,
            ),
            child: Padding(
              padding: EdgeInsets.all(suSetWidth(12.0)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  textField(context),
                  toolbar,
                ],
              ),
            ),
          ),
          emoticonPad(context),
          AnimatedContainer(
            curve: Curves.ease,
            duration: 100.milliseconds,
            height: MediaQuery.of(context).viewInsets.bottom,
          ),
        ],
      ),
    );
  }
}
