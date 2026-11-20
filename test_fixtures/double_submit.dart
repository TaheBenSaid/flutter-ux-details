import 'package:flutter/material.dart';

Future<void> placeOrder() => Future<void>.delayed(const Duration(seconds: 2));

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  Future<void> _pay() async {
    await placeOrder();
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FilledButton(
          onPressed: () async {
            await placeOrder();
            if (!context.mounted) return;
            Navigator.pop(context);
          },
          child: const Text('Place order'),
        ),
        OutlinedButton(onPressed: _pay, child: const Text('Pay now')),
      ],
    );
  }
}
