import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' hide ModifierKey;
import 'package:hid_listener/hid_listener.dart';
import 'package:window_size/window_size.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'package:keyviz/config/config.dart';
import 'package:keyviz/domain/vault/vault.dart';

import 'key_event_data.dart';

export 'key_event_data.dart';

// modifiers in a keyboard
enum ModifierKey {
  control("Control"),
  shift("Shift"),
  alt("Alt"),
  meta("Meta");

  const ModifierKey(this.label);
  final String label;

  String get keyLabel {
    if (this == ModifierKey.alt) {
      if (Platform.isMacOS) {
        return "Option";
      }
    } else if (this == ModifierKey.meta) {
      if (Platform.isWindows) {
        return "Win";
      } else if (Platform.isMacOS) {
        return "Command";
      }
    }

    return label;
  }
}

// key visualization history mode
enum VisualizationHistoryMode {
  none,
  vertical,
  horizontal;

  @override
  String toString() {
    return this == VisualizationHistoryMode.none
        ? "None"
        : "${name.capitalize()}ly";
  }
}

// keycap animation style
enum KeyCapAnimationType {
  none,
  fade,
  wham,
  grow,
  slide;

  @override
  String toString() => name.capitalize();
}


/// keyboard event provider and related configurations
class KeyEventProvider extends ChangeNotifier with TrayListener {
  KeyEventProvider() {
    _init();
  }

  // index of current screen in the screens list
  int _screenIndex = 0;

  // display/screens list
  final List<Screen> _screens = [];

  // an offset to adapt origin from topLeft

  // errors
  bool _hasError = false;

  // toggle for styling, if true keeps the events
  // on display unless changed by others
  bool _styling = false;

  // keyboard event listener id


 

  // keyboard event listener id
  int? _keyboardListenerId;

  // list of key id's currently hold down
  final Map<int, RawKeyDownEvent> _keyDown = {};

  // unfiltered keyboard event ids list
  final List<int> _unfilteredEvents = [];

  // tracking variable for every key down
  // follwed by key up  synchronously
  bool _lastKeyDown = false;
  bool _keyUpFollowed = true;

  // id for each key events group
  String? _groupId;

  // main list of key events to be consumed by the visualizer
  // may not include history is historyMode is set to none
  final Map<String, Map<int, KeyEventData>> _keyboardEvents = {};

  // filter letters, numbers, symbols, etc. and
  // show hotkeys/keyboard shortuts
  bool _filterHotkeys = _Defaults.filterHotkeys;

  // modifiers and function keys to ignore
  // when hotkey filter is turned on
  final Map<ModifierKey, bool> _ignoreKeys = {
    ModifierKey.control: false,
    ModifierKey.shift: true,
    ModifierKey.alt: false,
    ModifierKey.meta: false,
  };

  // whether to show history, if yes
  // then vertically or horizontally
  VisualizationHistoryMode _historyMode = _Defaults.historyMode;

  // max history number
  // TODO calculate based on keycap height and screen size
  final int _maxHistory = 6;

  // global keyviz toggle shortcut, list of keyIds
  // default [Shift] + [F10]
  List<int> keyvizToggleShortcut = _Defaults.toggleShortcut;

  // display events in the visualizer
  bool _visualizeEvents = true;

  // amount of time the visualization stays on the screen in seconds
  int _lingerDurationInSeconds = _Defaults.lingerDurationInSeconds;

  // key cap animation speed in milliseconds
  int _animationSpeed = _Defaults.animationSpeed;

  // keycap animation type
  KeyCapAnimationType _keyCapAnimation = _Defaults.keyCapAnimation;


  Screen get _currentScreen => _screens[_screenIndex];

  Map<String, Map<int, KeyEventData>> get keyboardEvents => _keyboardEvents;
  int get screenIndex => _screenIndex;
  List<Screen> get screens => _screens;
  bool get styling => _styling;
  bool get visualizeEvents => _visualizeEvents;
  bool get hasError => _hasError;

  bool get filterHotkeys => _filterHotkeys;
  Map<ModifierKey, bool> get ignoreKeys => _ignoreKeys;
  VisualizationHistoryMode get historyMode => _historyMode;
  Axis? get historyDirection {
    switch (_historyMode) {
      case VisualizationHistoryMode.none:
        return null;

      case VisualizationHistoryMode.horizontal:
        return Axis.horizontal;

      case VisualizationHistoryMode.vertical:
        return Axis.vertical;
    }
  }

  int get lingerDurationInSeconds => _lingerDurationInSeconds;
  Duration get lingerDuration => Duration(seconds: _lingerDurationInSeconds);
  int get animationSpeed => _animationSpeed;
  Duration get animationDuration => Duration(milliseconds: _animationSpeed);
  KeyCapAnimationType get keyCapAnimation => _keyCapAnimation;
  bool get noKeyCapAnimation => _keyCapAnimation == KeyCapAnimationType.none;

  bool get _ignoreHistory =>
      _historyMode == VisualizationHistoryMode.none || _styling;

  set screenIndex(int value) {
    _screenIndex = value;
    _changeDisplay();
  }

  set styling(bool value) {
    if (_hasError) return;
    _styling = value;
    windowManager.setIgnoreMouseEvents(!value);
    notifyListeners();
  }

  set filterHotkeys(value) {
    _filterHotkeys = value;
    notifyListeners();
  }

  void setModifierKeyIgnoring(ModifierKey key, bool ingnoring) {
    _ignoreKeys[key] = ingnoring;
    notifyListeners();
  }

  set historyMode(VisualizationHistoryMode value) {
    _historyMode = value;
    notifyListeners();
  }

  set lingerDurationInSeconds(int value) {
    _lingerDurationInSeconds = value;
    notifyListeners();
  }

  set animationSpeed(value) {
    _animationSpeed = value;
    notifyListeners();
  }

  set keyCapAnimation(KeyCapAnimationType value) {
    _keyCapAnimation = value;
    notifyListeners();
  }

  _toggleVisualizer() {
    _visualizeEvents = !_visualizeEvents;
    _setTrayIcon();
    _setTrayContextMenu();
    notifyListeners();
  }

  _init() async {
    // load data
    await _updateFromJson();
// register mouse event listener
    // _registerMouseListener();
    // register keyboard event listener
    _registerKeyboardListener();
    // setup tray manager
    trayManager.addListener(this);
    await _setTrayIcon();
    await _setTrayContextMenu();
  }

   

  

   

   
 
  _registerKeyboardListener() async {
    _keyboardListenerId =
        getListenerBackend()!.addKeyboardListener(_onRawKeyEvent);

    if (_keyboardListenerId == null) {
      _hasError = true;
      notifyListeners();
      debugPrint("cannot register keyboard listener!");
    } else {
      debugPrint("keyboard listener registered");
    }
  }

  _onRawKeyEvent(RawKeyEvent event) {
    // key pressed
    if (event is RawKeyDownEvent && !_keyDown.containsKey(event.keyId)) {
      // check for shortcut pressed
      _unfilteredEvents.add(event.keyId);
      if (listEquals(_unfilteredEvents, keyvizToggleShortcut)) {
        print("cuts");
        // _toggleVisualizer();
        _onChange();
      }

      if (_visualizeEvents) _onKeyDown(event);
    }
    // key released
    else if (event is RawKeyUpEvent) {
      _unfilteredEvents.remove(event.keyId);

      if (_visualizeEvents) _onKeyUp(event);
    }
  }

  _onChange() {
   

   
    // _keyDown[LogicalKeyboardKey.metaLeft.keyId] = event;

    // _keyboardEvents[_groupId]![event.keyId] = KeyEventData(
    //   event,
    //   show: noKeyCapAnimation,
    // );
  }



  _onKeyDown(RawKeyDownEvent event) {
    // filter hotkey
    if (_filterHotkeys && !_eventIsHotkey(event)) //return;
    {
      debugPrint("⬇️ [${event.data.keyLabel}] not hotkey, returning...");
      return;
    }


    // check if key pressed again while in view
    // ignoring history and current display events has key id
    if (_ignoreHistory &&
        (_keyboardEvents[_groupId]?.containsKey(event.keyId) ?? false)) {
      // track key pressed down
      _keyDown[event.keyId] = event;

      // animate key press
      final data = _keyboardEvents[_groupId]![event.keyId]!;
      _keyboardEvents[_groupId]![event.keyId] = data.copyWith(
        pressed: true,
        pressedCount: data.pressedCount + 1,
      );
      notifyListeners();

      // remove previous keys if the above was just tracked
      if (_keyDown.length == 1) {
        _keyboardEvents[_groupId]!.removeWhere((key, _) => key != event.keyId);
      }
      debugPrint("⬇️ [${event.label}]");
      return;
    }
    // showing history and the last display event
    // has only one key with this key id
    else if ((_keyboardEvents.values.lastOrNull?.length ?? 0) == 1 &&
        _keyboardEvents.values.last.keys.first == event.keyId) {
      // track key pressed down
      _keyDown[event.keyId] = event;
      // reuse last group id
      _groupId = _keyboardEvents.keys.last;
      // animate key press
      final data = _keyboardEvents[_groupId]![event.keyId]!;
      _keyboardEvents[_groupId]![event.keyId] = data.copyWith(
        pressed: true,
        pressedCount: data.pressedCount + 1,
      );
      notifyListeners();

      debugPrint("⬇️ [${event.label}]");
      return;
    }

    // init group id
    _groupId ??= _timestamp;
    // create group if not created
    if (!_keyboardEvents.containsKey(_groupId)) {
      _keyboardEvents[_groupId!] = {};
    }

    // don't show history i.e. replace existing with new keys
    if (_ignoreHistory) {
      // remove key events in display but not pressed down
      // i.e. waiting for animation out
      if (_keyboardEvents[_groupId]!.isNotEmpty && _keyDown.isEmpty) {
        _keyboardEvents[_groupId]!.clear();
      }
    }
    // show history
    else {
      // enforce display events length
      if (_keyboardEvents.length > _maxHistory) {
        for (final group in _keyboardEvents.keys
            .take(_keyboardEvents.length - _maxHistory)) {
          _keyboardEvents.remove(group);
        }
      }

      if (!_keyUpFollowed) {
        final events = _keyboardEvents[_groupId];
        // handle pressed again
        if (
            // last pressed event
            events?.keys.last == event.keyId &&
                // other keys are pressed down
                events!.values
                    .take(events.length - 1)
                    .every((value) => value.pressed)) {
          // press the last item
          // track key pressed down
          _keyDown[event.keyId] = event;
          // animate key press
          final data = _keyboardEvents[_groupId]![event.keyId]!;
          _keyboardEvents[_groupId]![event.keyId] = data.copyWith(
            pressed: true,
            pressedCount: data.pressedCount + 1,
          );
          notifyListeners();

          debugPrint("⬇️ [${event.label}]");
          return;
        }
        // create new group
        else {
          // dispatch key up for not removed
          for (final keyId in _keyDown.keys) {
            _animateOut(_groupId!, keyId);
          }
          // change group id
          _groupId = _timestamp;
          // duplicate key downs
          _keyboardEvents[_groupId!] = {
            for (final entry in _keyDown.entries)
              entry.key: KeyEventData(entry.value),
          };
        }
      }
    }

    // track key pressed down
    _keyDown[event.keyId] = event;

    _keyboardEvents[_groupId]![event.keyId] = KeyEventData(
      event,
      show: noKeyCapAnimation,
    );

    // animate with configured key cap animation
    if (!noKeyCapAnimation) {
      _animateIn(_groupId!, event.keyId);
    }

    notifyListeners();

    debugPrint("keyboardEvents: $_keyboardEvents");
    debugPrint("⬇️ [${event.label}]");

    // key event tracking
    _lastKeyDown = true;
  }

  _onKeyUp(RawKeyUpEvent event) async {
    // track key pressed up
    final removedEvent = _keyDown.remove(event.keyId);

    // sanity check
    if (removedEvent == null || _groupId == null) return;

    _animateOut(_groupId!, event.keyId);

    debugPrint("⬆️ [${event.label}]");

    // no keys pressed or only left with mouse events
    if (_keyDown.isEmpty) {
      // track all keys removed
      _keyUpFollowed = true;
      // reset _groupId when there are no keys pressed
      if (!_ignoreHistory) _groupId = null;
    } else {
      // track key combinations
      if (_lastKeyDown) {
        _lastKeyDown = false;
        _keyUpFollowed = false;
      }
    }
  }

  _animateIn(String groupId, int keyId) async {
    // wait for background bar to expand
    await Future.delayed(animationDuration);
    // set show to true

    final event = _keyboardEvents[groupId]?[keyId];
    if (event != null) {
      _keyboardEvents[groupId]![keyId] = event.copyWith(show: true);
      notifyListeners();
    }
  }

  _animateOut(String groupId, int keyId) async {
    final event = _keyboardEvents[groupId]?[keyId];
    if (event == null) return;

    // animate key released
    _keyboardEvents[groupId]![keyId] = event.copyWith(pressed: false);
    notifyListeners();

    // don't animate out when styling i.e. settings windows opened
    if (_styling) return;

    final pressedCount = event.pressedCount;

    // wait for linger duration
    await Future.delayed(lingerDuration);

    // new pressed count
    final newEvent = _keyboardEvents[groupId]?[keyId];

    if ( // make sure key event not removed
        // newPressedCount == null ||
        // key not pressed again
        pressedCount != newEvent?.pressedCount) {
      debugPrint("key pressed again, returning...");
      return;
    }

    if (!noKeyCapAnimation) {
      // animate out the key event
      _keyboardEvents[groupId]![keyId] = newEvent!.copyWith(show: false);
      notifyListeners();

      // wait for animation to finish
      await Future.delayed(animationDuration);
    }

    // remove key event
    _keyboardEvents[groupId]!.remove(keyId);
    notifyListeners();

    // check if the group is exhausted
    if (!_ignoreHistory && _keyboardEvents[groupId]!.isEmpty) {
      _keyboardEvents.remove(groupId);
    }
  }

  _removeKeyboardListener() {
    if (_keyboardListenerId != null) {
      getListenerBackend()!.removeKeyboardListener(_keyboardListenerId!);
    }
  }

  bool _eventIsHotkey(RawKeyDownEvent event) {
    if (_keyDown.isEmpty) {
      // event should be a modifier and not ignored
      return 
              (!_ignoreKeys[ModifierKey.control]! && event.isControl) ||
          (!_ignoreKeys[ModifierKey.meta]! && event.isMeta) ||
          (!_ignoreKeys[ModifierKey.alt]! && event.isAlt) ||
          (!_ignoreKeys[ModifierKey.shift]! && event.isShift);
    } else {
      // modifier should be pressed down
      return _keyDown.values.first.isModifier;
    }
  }

  String get _timestamp {
    final now = DateTime.now();
    return "${now.minute}${now.second}${now.millisecond}";
  }

  _setTrayIcon() async {
    if (_visualizeEvents) {
      await trayManager.setIcon(
        Platform.isWindows
            ? 'assets/img/tray-on.ico'
            : 'assets/img/tray-on.png',
      );
    } else {
      await trayManager.setIcon(
        Platform.isWindows
            ? 'assets/img/tray-off.ico'
            : 'assets/img/tray-off.png',
      );
    }
  }

  _setTrayContextMenu() async {
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(
            key: "toggle",
            label: _visualizeEvents ? "✗ Turn Off" : "✓ Turn On",
          ),
          MenuItem(
            key: "settings",
            label: "Settings",
            toolTip: "Open settings window",
          ),
          MenuItem.separator(),
          MenuItem(
            key: "quit",
            label: "Quit",
            toolTip: "Close Keyviz",
          ),
        ],
      ),
    );
  }

@override
  void onTrayIconMouseDown() {
    super.onTrayIconMouseDown();
    _toggleVisualizer();
  }

  @override
  void onTrayIconRightMouseDown() async {
    super.onTrayIconRightMouseDown();
    await trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    super.onTrayMenuItemClick(menuItem);

    switch (menuItem.key) {
      case "toggle":
        _toggleVisualizer();
        break;

      case "settings":
        styling = !_styling;
        break;

      case "quit":
        windowManager.close();
        break;
    }
  }

  Map<String, dynamic> get toJson => {
        _JsonKeys.screenFrame: [
          _screens[_screenIndex].frame.width,
          _screens[_screenIndex].frame.height,
        ],
        _JsonKeys.filterHotkeys: _filterHotkeys,
        _JsonKeys.ignoreKeys: {
          ModifierKey.control.name: _ignoreKeys[ModifierKey.control],
          ModifierKey.shift.name: _ignoreKeys[ModifierKey.shift],
          ModifierKey.alt.name: _ignoreKeys[ModifierKey.alt],
          ModifierKey.meta.name: _ignoreKeys[ModifierKey.meta],
        },
        _JsonKeys.historyMode: _historyMode.name,
        _JsonKeys.toggleShortcut: keyvizToggleShortcut,
        _JsonKeys.lingerDurationInSeconds: _lingerDurationInSeconds,
        _JsonKeys.animationSpeed: _animationSpeed,
        _JsonKeys.keyCapAnimation: _keyCapAnimation.name,
        // _JsonKeys.highlightCursor: _highlightCursor,
      };

  _updateFromJson() async {
    final data = await Vault.loadConfigData();

    // set preferred display
    _setDisplay(data?[_JsonKeys.screenFrame]);

    if (data == null) return;

    _filterHotkeys = data[_JsonKeys.filterHotkeys] ?? _Defaults.filterHotkeys;

    for (final modifier in ModifierKey.values) {
      _ignoreKeys[modifier] = data[_JsonKeys.ignoreKeys][modifier.name] ??
          _Defaults.ignoreKeys[modifier];
    }

    switch (data[_JsonKeys.historyMode]) {
      case "none":
        _historyMode = VisualizationHistoryMode.none;
        break;

      case "vertical":
        _historyMode = VisualizationHistoryMode.vertical;
        break;

      case "horizontal":
        _historyMode = VisualizationHistoryMode.horizontal;
        break;
    }

    if (data[_JsonKeys.toggleShortcut] != null) {
      keyvizToggleShortcut =
          (data[_JsonKeys.toggleShortcut] as List).cast<int>();
    }

    _lingerDurationInSeconds = data[_JsonKeys.lingerDurationInSeconds] ??
        _Defaults.lingerDurationInSeconds;

    _animationSpeed =
        data[_JsonKeys.animationSpeed] ?? _Defaults.animationSpeed;

    switch (data[_JsonKeys.keyCapAnimation]) {
      case "none":
        _keyCapAnimation = KeyCapAnimationType.none;
        break;

      case "slide":
        _keyCapAnimation = KeyCapAnimationType.slide;
        break;

      case "grow":
        _keyCapAnimation = KeyCapAnimationType.grow;
        break;

      case "fade":
        _keyCapAnimation = KeyCapAnimationType.fade;
        break;

      case "wham":
        _keyCapAnimation = KeyCapAnimationType.wham;
        break;
    }

 
  }

  _setDisplay(List? frame) async {
    _screens.addAll(await getScreenList());

    if (frame != null) {
      final index = _screens.indexWhere(
        (screen) =>
            screen.frame.width == frame[0] && screen.frame.height == frame[1],
      );

      if (index != -1) _screenIndex = index;
    }

 
    setWindowFrame(_currentScreen.frame);

    windowManager.show();
  }

  _changeDisplay() async {
      await windowManager.setFullScreen(false);
      await windowManager.hide();

      setWindowFrame(_currentScreen.frame);
      // simulate delay for above
      await Future.delayed(Durations.extralong2);
      await windowManager.setFullScreen(true);
      await windowManager.show();
    
    notifyListeners();
  }

  revertToDefaults() {
    _filterHotkeys = _Defaults.filterHotkeys;
    for (final modifier in ModifierKey.values) {
      _ignoreKeys[modifier] = _Defaults.ignoreKeys[modifier] ?? false;
    }
    _historyMode = _Defaults.historyMode;
    keyvizToggleShortcut = _Defaults.toggleShortcut;
    _lingerDurationInSeconds = _Defaults.lingerDurationInSeconds;
    _animationSpeed = _Defaults.animationSpeed;
    _keyCapAnimation = _Defaults.keyCapAnimation;
   
    notifyListeners();
  }

  @override
  void dispose() {
 
    _removeKeyboardListener();
    trayManager.removeListener(this);
    super.dispose();
  }
}

class _JsonKeys {
  static const screenFrame = "screen_frame";
  static const filterHotkeys = "filter_hotkeys";
  static const ignoreKeys = "ignore_keys";
  static const historyMode = "history_mode";
  static const toggleShortcut = "toggle_shortcut";
  static const lingerDurationInSeconds = "linger_duration";
  static const animationSpeed = "animation_speed";
  static const keyCapAnimation = "keycap_animation";
 
}

class _Defaults {
  static const filterHotkeys = true;
  static const ignoreKeys = {
    ModifierKey.control: false,
    ModifierKey.shift: true,
    ModifierKey.alt: false,
    ModifierKey.meta: false,
  };
  static const historyMode = VisualizationHistoryMode.none;
  static const toggleShortcut = [8589934850, 4294969354];
  static const lingerDurationInSeconds = 4;
  static const animationSpeed = 500;
  static const keyCapAnimation = KeyCapAnimationType.none;
 
}
