import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';

typedef TextMapper = String Function(String numberText);

class NumberPicker extends StatefulWidget {
  /// Min value user can pick
  final int minValue;

  /// Max value user can pick
  final int maxValue;

  /// The initial value
  final int initialValue;

  /// Called when selected value changes
  final ValueChanged<int> onChanged;

  /// Specifies how many items should be shown - defaults to 3
  final int itemCount;

  /// Step between elements. Only for integer datePicker
  /// Examples:
  /// if step is 100 the following elements may be 100, 200, 300...
  /// if min=0, max=6, step=3, then items will be 0, 3 and 6
  /// if min=0, max=5, step=3, then items will be 0 and 3.
  final int step;

  /// height of single item in pixels
  final double itemHeight;

  /// width of single item in pixels
  final double itemWidth;

  /// Direction of scrolling
  final Axis axis;

  /// Style of non-selected numbers. If null, it uses Theme's bodyText2
  final TextStyle? textStyle;

  /// Style of non-selected numbers. If null, it uses Theme's headline5 with accentColor
  final TextStyle? selectedTextStyle;

  /// Whether to trigger haptic pulses or not
  final bool haptics;

  /// Build the text of each item on the picker
  final TextMapper? textMapper;

  /// Pads displayed integer values up to the length of maxValue
  final bool zeroPad;

  /// Decoration to apply to central box where the selected value is placed
  final Decoration? decoration;

  /// Whether the direction shall be reversed
  final bool reverse;

  final InputDecoration? inputDecoration;

  const NumberPicker({
    Key? key,
    required this.minValue,
    required this.maxValue,
    required this.initialValue,
    required this.onChanged,
    this.itemCount = 3,
    this.step = 1,
    this.itemHeight = 50,
    this.itemWidth = 100,
    this.axis = Axis.vertical,
    this.textStyle,
    this.selectedTextStyle,
    this.haptics = false,
    this.decoration,
    this.zeroPad = false,
    this.textMapper,
    this.reverse = false,
    this.inputDecoration,
  })  : assert(minValue <= initialValue),
        assert(initialValue <= maxValue),
        super(key: key);

  @override
  _NumberPickerState createState() => _NumberPickerState();
}

class _NumberPickerState extends State<NumberPicker> {
  late ScrollController _scrollController;
  bool isEditActive=false;
  TextEditingController _textEditingController = TextEditingController();
  late int currentValue;

  @override
  void initState() {
    super.initState();
    final initialOffset =
        (widget.initialValue - widget.minValue) ~/ widget.step * itemExtent;
    _scrollController = ScrollController(initialScrollOffset: initialOffset)
      ..addListener(_scrollListener);
    currentValue = widget.initialValue;
    _textEditingController.text = currentValue.toString();
  }

  void _scrollListener() {
    final indexOfMiddleElement =
        (_scrollController.offset / itemExtent).round().clamp(0, itemCount - 1);
    final intValueInTheMiddle = _intValueFromIndex(indexOfMiddleElement + 1);
    _textEditingController.text = intValueInTheMiddle.toString();
    currentValue = intValueInTheMiddle;
    widget.onChanged(intValueInTheMiddle);
    if (widget.haptics) {
      HapticFeedback.selectionClick();
    }
    Future.delayed(
      Duration(milliseconds: 100),
      () => _maybeCenterValue(),
    );
  }

  @override
  void didUpdateWidget(NumberPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue) {
      _maybeCenterValue();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textEditingController.dispose();
    super.dispose();
  }

  bool get isScrolling => _scrollController.position.isScrollingNotifier.value;

  double get itemExtent =>
      widget.axis == Axis.vertical ? widget.itemHeight : widget.itemWidth;

  int get itemCount => (widget.maxValue - widget.minValue) ~/ widget.step + 1;

  int get listItemsCount => itemCount + 2;

  @override
  Widget build(BuildContext context) => Builder(
      builder: (context) {
        VoidCallback finished = (){
          setState(()=>isEditActive=false);
          currentValue = int.parse(_textEditingController.text);
          currentValue = max(widget.minValue, min(currentValue, widget.maxValue));
          _scrollController.jumpTo(itemExtent*(_indexFromIntValue(currentValue)-1));
        };
        return GestureDetector(
            onDoubleTap: ()=>setState(()=>isEditActive=true),
            child: SizedBox(
                width: widget.axis == Axis.vertical
                    ? widget.itemWidth
                    : widget.itemCount * widget.itemWidth,
                height: widget.axis == Axis.vertical
                    ? widget.itemCount * widget.itemHeight
                    : widget.itemHeight,
                child: NotificationListener<ScrollEndNotification>(
                  onNotification: (not) {
                    if (not.dragDetails?.primaryVelocity == 0) {
                      Future.microtask(() => _maybeCenterValue());
                    }
                    return true;
                  },
                  child: Stack(
                    children: [
                      ListView.builder(
                        reverse: widget.reverse,
                        itemCount: listItemsCount,
                        scrollDirection: widget.axis,
                        controller: _scrollController,
                        itemExtent: itemExtent,
                        itemBuilder: _itemBuilder,
                      ),
                      _NumberPickerSelectedItemDecoration(
                        axis: widget.axis,
                        itemExtent: itemExtent,
                        decoration: widget.decoration,
                      ),
                      if (isEditActive)
                      Positioned.fill(
                        child: Opacity(
                            opacity: 0.5,
                            // child: Container(
                            //   width: double.infinity, // widget.axis == Axis.horizontal ? 2*itemExtent * itemCount : widget.itemWidth,
                            //   height: double.infinity, // widget.axis == Axis.vertical ? 2*itemExtent * itemCount : widget.itemHeight,
                            // )
                        )),
                      if (isEditActive) Center(
                        child: TextField(
                          controller: _textEditingController,
                          onEditingComplete: finished,
                          onSubmitted: (val)=>finished(),
                          decoration: widget.inputDecoration ?? InputDecoration(
                            focusedBorder: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            border: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            errorBorder: InputBorder.none
                          ),
                          keyboardType: TextInputType.number,
                          style: widget.textStyle,
                          textAlign: TextAlign.center,
                        )
                      )
                    ],
                  ),
                )
            )
        );
      }
  );

  Widget _itemBuilder(BuildContext context, int index) {
    final themeData = Theme.of(context);
    final defaultStyle = widget.textStyle ?? themeData.textTheme.bodyText2;
    final selectedStyle = widget.selectedTextStyle ??
        themeData.textTheme.headline5?.copyWith(color: themeData.accentColor);

    final value = _intValueFromIndex(index);
    final isExtra = index == 0 || index == listItemsCount - 1;
    final itemStyle = value == currentValue ? selectedStyle : defaultStyle;

    final child = isExtra
        ? SizedBox.shrink()
        : TextButton(
            onPressed: () {
              _scrollController.animateTo(itemExtent*(index-1),
                duration: Duration(milliseconds: 300),
                curve: Curves.easeOutCubic);
                currentValue = _intValueFromIndex(index);
            },
            // padding: const EdgeInsets(0.0),
            child: isEditActive ? Opacity(
                opacity: 0.5,
                child: Text(
                  _getDisplayedValue(value),
                  style: itemStyle,
                )
            ) : Text(
              _getDisplayedValue(value),
              style: itemStyle,
            )
        );

    return Container(
      width: widget.itemWidth,
      height: widget.itemHeight,
      alignment: Alignment.center,
      child: child,
    );
  }

  String _getDisplayedValue(int value) {
    final text = widget.zeroPad
        ? value.toString().padLeft(widget.maxValue.toString().length, '0')
        : value.toString();
    if (widget.textMapper != null) {
      return widget.textMapper!(text);
    } else {
      return text;
    }
  }

  int _intValueFromIndex(int index) {
    index--;
    index %= itemCount;
    return widget.minValue + index * widget.step;
  }

  int _indexFromIntValue(int value) {
    return (value - widget.minValue) ~/ widget.step + 1;
  }

  void _maybeCenterValue() {
    if (!isScrolling) {
      int diff = currentValue - widget.minValue;
      int index = diff ~/ widget.step;
      _scrollController.animateTo(
        index * itemExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }
}

class _NumberPickerSelectedItemDecoration extends StatelessWidget {
  final Axis axis;
  final double itemExtent;
  final Decoration? decoration;

  const _NumberPickerSelectedItemDecoration({
    Key? key,
    required this.axis,
    required this.itemExtent,
    required this.decoration,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: IgnorePointer(
        child: Container(
          width: isVertical ? double.infinity : itemExtent,
          height: isVertical ? itemExtent : double.infinity,
          decoration: decoration,
        ),
      ),
    );
  }

  bool get isVertical => axis == Axis.vertical;
}
