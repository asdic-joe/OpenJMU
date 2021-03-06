///
/// [Author] Alex (https://github.com/AlexVincent525)
/// [Date] 2019-12-18 16:52
///
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:openjmu/constants/constants.dart';

class DateProvider extends ChangeNotifier {
  DateTime _startDate;
  DateTime get startDate => _startDate;
  set startDate(DateTime value) {
    _startDate = value;
    notifyListeners();
  }

  Timer _updateCurrentWeekTimer;
  Timer _fetchCurrentWeekTimer;

  int _currentWeek = 0;
  int get currentWeek => _currentWeek;
  set currentWeek(int value) {
    _currentWeek = value;
    notifyListeners();
  }

  int _difference;
  int get difference => _difference;
  set difference(int value) {
    _difference = value;
    notifyListeners();
  }

  DateTime _now;
  DateTime get now => _now;
  set now(DateTime value) {
    assert(value != null);
    if (value == _now) return;
    _now = value;
    notifyListeners();
  }

  Future<void> initCurrentWeek() async {
    final _dateInCache = HiveBoxes.startWeekBox.get('startDate');
    if (_dateInCache != null) _startDate = _dateInCache;
    await getCurrentWeek(init: _dateInCache == null);
    initCurrentWeekTimer();
  }

  Future<void> updateStartDate(DateTime date) async {
    _startDate = date;
    await HiveBoxes.startWeekBox.put('startDate', date);
  }

  Future<void> getCurrentWeek({bool init = false}) async {
    now = DateTime.now();
    final box = HiveBoxes.startWeekBox;
    try {
      DateTime _day;
      if (init) {
        final result = (await NetUtils.get(API.firstDayOfTerm)).data;
        _day = DateTime.parse(jsonDecode(result)['start']);
      } else {
        _day = box.get('startDate');
      }
      if (_startDate == null) {
        updateStartDate(_day);
      } else {
        if (_startDate != _day) updateStartDate(_day);
      }

      final _d = startDate.difference(now).inDays;
      if (_difference != _d) _difference = _d;

      final _w = -((_difference - 1) / 7).floor();
      if (_currentWeek != _w && _w <= 20) {
        _currentWeek = _w;
        notifyListeners();
        Instances.eventBus.fire(CurrentWeekUpdatedEvent());
      }
      _fetchCurrentWeekTimer?.cancel();
    } catch (e) {
      debugPrint('Failed when fetching current week: $e');
      startFetchCurrentWeekTimer();
    }
  }

  void initCurrentWeekTimer() {
    _updateCurrentWeekTimer?.cancel();
    _updateCurrentWeekTimer = Timer.periodic(1.minutes, (_) {
      getCurrentWeek();
    });
  }

  void startFetchCurrentWeekTimer() {
    _fetchCurrentWeekTimer?.cancel();
    _fetchCurrentWeekTimer = Timer.periodic(30.seconds, (_) {
      getCurrentWeek(init: true);
    });
  }
}

const shortWeekdays = <int, String>{
  1: '周一',
  2: '周二',
  3: '周三',
  4: '周四',
  5: '周五',
  6: '周六',
  7: '周日',
};
