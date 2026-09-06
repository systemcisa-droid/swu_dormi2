import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/locale_provider.dart';
import '../../utils/board_strings.dart';
import '../../utils/meal_strings.dart';
import '../meal/meal_screen.dart';
import 'board_screen.dart';

class BoardMealScreen extends StatelessWidget {
  const BoardMealScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isEnglish = Provider.of<LocaleProvider>(context).isEnglish;
    final boardTitle = BoardStrings(isEnglish).title;
    final mealTitle = MealStrings(isEnglish).title;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('$boardTitle & $mealTitle'),
          centerTitle: true,
          bottom: TabBar(
            tabs: [
              Tab(text: boardTitle),
              Tab(text: mealTitle),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            BoardScreen(embedded: true),
            MealScreen(embedded: true),
          ],
        ),
      ),
    );
  }
}
