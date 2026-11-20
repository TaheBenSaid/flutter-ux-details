import 'package:flutter/material.dart';

class OrdersList extends StatelessWidget {
  const OrdersList({super.key, required this.orders});

  final List<String> orders;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: orders.length,
      separatorBuilder: (context, i) => const Divider(height: 1),
      itemBuilder: (context, i) => ListTile(title: Text(orders[i])),
    );
  }
}
