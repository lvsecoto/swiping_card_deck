import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:swiping_card_deck/src/swiping_gesture_notification.dart';

//ignore: must_be_immutable
class SwipingGestureDetector<T> extends StatefulWidget {
  SwipingGestureDetector({
    Key? key,
    required this.cardDeck,
    required this.swipeLeft,
    required this.swipeRight,
    required this.cardWidth,
    this.minimumVelocity = 1000,
    this.rotationFactor = .8 / 3.14,
    this.swipeAnimationDuration = const Duration(milliseconds: 500),
    required this.swipeThreshold,
  }) : super(key: key);

  final List<T> cardDeck;
  final Function() swipeLeft, swipeRight;
  final double minimumVelocity;
  final double rotationFactor;
  final double swipeThreshold;
  final double cardWidth;
  final Duration swipeAnimationDuration;

  Alignment dragAlignment = Alignment.center;

  late final AnimationController swipeController;
  Animation<Alignment> swipe = const AlwaysStoppedAnimation(Alignment.center);

  @override
  State<StatefulWidget> createState() => _SwipingGestureDetector();
}

class _SwipingGestureDetector extends State<SwipingGestureDetector>
    with TickerProviderStateMixin {
  bool animationActive = false;
  late final AnimationController springController;
  late Animation<Alignment> spring;

  @override
  void initState() {
    super.initState();
    springController = AnimationController(vsync: this);
    springController.addListener(() {
      setState(() {
        widget.dragAlignment = spring.value;
        dispatchNotification(context);
      });
    });

    widget.swipeController = AnimationController(
        vsync: this, duration: widget.swipeAnimationDuration);
    widget.swipeController.addListener(() {
      setState(() {
        widget.dragAlignment = widget.swipe.value;
      });
    });
    SwipingGestureNotification(
      offsetX: widget.dragAlignment.x,
      position: SwipingGesturePosition.center,
    ).dispatch(context);
  }

  @override
  void didUpdateWidget(covariant SwipingGestureDetector oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.swipeController = oldWidget.swipeController;
    // todo 当Widget更新时，应当判断下卡片列表有无改变，如果没改变，则继续延续之前的滑动状态
    widget.dragAlignment = oldWidget.dragAlignment;
  }

  @override
  void dispose() {
    springController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    return GestureDetector(
      onPanUpdate: (DragUpdateDetails details) {
        setState(() {
          widget.dragAlignment += Alignment(details.delta.dx, details.delta.dy);
          dispatchNotification(context);
          DragGestureNotification(true).dispatch(context);
        });
      },
      onPanStart: (DragStartDetails details) async {
        if (animationActive) {
          springController.stop();
        }
      },
      onPanEnd: (DragEndDetails details) async {
        DragGestureNotification(false).dispatch(context);
        double vx = details.velocity.pixelsPerSecond.dx;
        if (vx >= widget.minimumVelocity ||
            widget.dragAlignment.x >= widget.swipeThreshold) {
          SwipingGestureNotification(
            offsetX: widget.dragAlignment.x,
            position: SwipingGesturePosition.overRight,
          ).dispatch(context);
          DragGestureNotification(false).dispatch(context);
          await widget.swipeRight();
        } else if (vx <= -widget.minimumVelocity ||
            widget.dragAlignment.x <= -widget.swipeThreshold) {
          SwipingGestureNotification(
            offsetX: widget.dragAlignment.x,
            position: SwipingGesturePosition.overLeft,
          ).dispatch(context);
          DragGestureNotification(false).dispatch(context);
          await widget.swipeLeft();
        } else {
          animateBackToDeck(details.velocity.pixelsPerSecond, screenSize);
          DragGestureNotification(true).dispatch(context);
        }
        setState(() {
          widget.dragAlignment = Alignment.center;
        });
      },
      child: Stack(
        alignment: Alignment.center,
        children: topTwoCards(),
      ),
    );
  }

  void dispatchNotification(BuildContext context) {
    if (widget.dragAlignment.x >= widget.swipeThreshold) {
      SwipingGestureNotification(
        offsetX: widget.dragAlignment.x,
        position: SwipingGesturePosition.overRight,
      ).dispatch(context);
    } else if (widget.dragAlignment.x <= -widget.swipeThreshold) {
      SwipingGestureNotification(
        offsetX: widget.dragAlignment.x,
        position: SwipingGesturePosition.overLeft,
      ).dispatch(context);
    } else {
      SwipingGestureNotification(
        offsetX: widget.dragAlignment.x,
        position: SwipingGesturePosition.center,
      ).dispatch(context);
    }
  }

  List<Widget> topTwoCards() {
    if (widget.cardDeck.isEmpty) {
      return [
        const SizedBox(
          height: 0,
          width: 0,
        )
      ];
    }
    List<Widget> cardDeck = [];
    int deckLength = widget.cardDeck.length;
    for (int i = max(deckLength - 2, 0); i < deckLength; ++i) {
      cardDeck.add(widget.cardDeck[i]);
    }
    Widget topCard = cardDeck.last;
    cardDeck.removeLast();
    cardDeck.add(
      Align(
          alignment: Alignment(getCardXPosition(), 0),
          child: Transform.rotate(
            angle: getCardAngle(),
            child: topCard,
          )),
    );
    return cardDeck;
  }

  double getCardAngle() {
    final double screenWidth = MediaQuery.of(context).size.width;
    return widget.rotationFactor * (widget.dragAlignment.x / screenWidth);
  }

  double getCardXPosition() {
    final double screenWidth = MediaQuery.of(context).size.width;
    return widget.dragAlignment.x / ((screenWidth - widget.cardWidth) / 2);
  }

  void animateBackToDeck(Offset pixelsPerSecond, Size size) async {
    spring = springController.drive(
      AlignmentTween(
        begin: widget.dragAlignment,
        end: Alignment.center,
      ),
    );

    // Calculate the velocity relative to the unit interval, [0,1],
    // used by the animation controller.
    final unitsPerSecondX = pixelsPerSecond.dx / size.width;
    final unitsPerSecondY = pixelsPerSecond.dy / size.height;
    final unitsPerSecond = Offset(unitsPerSecondX, unitsPerSecondY);
    final unitVelocity = unitsPerSecond.distance;

    const springProps = SpringDescription(
      mass: 30,
      stiffness: 1,
      damping: 1,
    );

    final simulation = SpringSimulation(springProps, 0, 1, -unitVelocity);
    animationActive = true;
    await springController.animateWith(simulation);
    animationActive = false;
  }
}
