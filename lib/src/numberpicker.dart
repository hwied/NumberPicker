import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:infinite_listview/infinite_listview.dart';
import 'dart:math';

typedef TextMapper = String Function(String numberText);

class NumberPicker extends StatefulWidget {
  /// Min value user can pick
  final int minValue;

  /// Max value user can pick
  final int maxValue;

  /// Currently selected value
  final int value;

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

  /// InputDecoration for TextField Edit
  final InputDecoration? inputDecoration;

  /// Whether we scroll in infitie loop
  final bool infiniteLoop;

  const NumberPicker({
    Key? key,
    required this.minValue,
    required this.maxValue,
    required this.value,
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
    this.infiniteLoop = false,
  })  : assert(minValue <= value),
        assert(value <= maxValue),
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
        (widget.value - widget.minValue) ~/ widget.step * itemExtent;
    if (widget.infiniteLoop) {
      _scrollController =
          InfiniteScrollController(initialScrollOffset: initialOffset);
    } else {
      _scrollController = ScrollController(initialScrollOffset: initialOffset);
    }
    _scrollController.addListener(_scrollListener);
    currentValue = widget.value;
    _textEditingController.text = currentValue.toString();
  }

  void _scrollListener() {
    var indexOfMiddleElement = (_scrollController.offset / itemExtent).round();
    if (widget.infiniteLoop) {
      indexOfMiddleElement %= itemCount;
    } else {
      indexOfMiddleElement = indexOfMiddleElement.clamp(0, itemCount - 1);
    }
    final intValueInTheMiddle =
        _intValueFromIndex(indexOfMiddleElement + additionalItemsOnEachSide);
    _textEditingController.text = intValueInTheMiddle.toString();   
    widget.onChanged(intValueInTheMiddle);
    if (currentValue != intValueInTheMiddle) {
      if (widget.haptics) {
        HapticFeedback.selectionClick();
      }
    }    
    currentValue = intValueInTheMiddle; 
    Future.delayed(
      Duration(milliseconds: 100),
      () => _maybeCenterValue(),
    );
  }

  @override
  void didUpdateWidget(NumberPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
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

  int get listItemsCount => itemCount + 2 * additionalItemsOnEachSide;

  int get additionalItemsOnEachSide => (widget.itemCount - 1) ~/ 2;

  @override
  Widget build(BuildContext context) => Builder(
      builder: (context) {
        VoidCallback finished = (){
          setState(() {
            isEditActive = false;
            currentValue = int.parse(_textEditingController.text);
            currentValue = max(widget.minValue, min(currentValue, widget.maxValue));
          });
          _scrollController.jumpTo(itemExtent*(_indexFromIntValue(currentValue)));
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
                      if (widget.infiniteLoop)
                        InfiniteListView.builder(
                          scrollDirection: widget.axis,
                          controller: _scrollController as InfiniteScrollController,
                          itemExtent: itemExtent,
                          itemBuilder: _itemBuilder,
                          padding: EdgeInsets.zero,
                        )
                      else
                        ListView.builder(
                          itemCount: listItemsCount,
                          scrollDirection: widget.axis,
                          controller: _scrollController,
                          itemExtent: itemExtent,
                          itemBuilder: _itemBuilder,
                          padding: EdgeInsets.zero,
                        ),
                      _NumberPickerSelectedItemDecoration(
                         axis: widget.axis,
                         itemExtent: itemExtent,
                         decoration: widget.decoration,
                      ),
                      if (isEditActive) Center(child: Container(
                        height: widget.itemHeight,
                        width: widget.itemWidth,
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
                      ))
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
    final isExtra = !widget.infiniteLoop &&
        (index < additionalItemsOnEachSide ||
            index >= listItemsCount - additionalItemsOnEachSide);
    final itemStyle = value == currentValue ? selectedStyle : defaultStyle;

    final child = isExtra
        ? SizedBox.shrink()
        : TextButton(
            onPressed: () {
              _scrollController.animateTo(itemExtent*(index),
                duration: Duration(milliseconds: 300),
                curve: Curves.easeOutCubic);
                currentValue = _intValueFromIndex(index);
                _textEditingController.text = currentValue.toString();
            },
            // padding: const EdgeInsets(0.0),
            child: isEditActive ? Opacity(
                opacity: 0,
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
    index -= additionalItemsOnEachSide;
    index %= itemCount;
    return widget.minValue + index * widget.step;
  }

  int _indexFromIntValue(int value) {
    return (value - widget.minValue) ~/ widget.step;// + additionalItemsOnEachSide;
  }

  void _maybeCenterValue() {
    if (_scrollController.hasClients && !isScrolling) {
      int diff = currentValue - widget.minValue;
      int index = diff ~/ widget.step;
      if (widget.infiniteLoop) {
        final offset = _scrollController.offset + 0.5 * itemExtent;
        final cycles = (offset / (itemCount * itemExtent)).floor();
        index += cycles * itemCount;
      }
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
