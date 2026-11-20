import 'package:flutter/material.dart';

Future<List<String>> fetchArticles() async {
  await Future<void>.delayed(const Duration(seconds: 1));
  return ['First', 'Second'];
}

class ArticlesPage extends StatelessWidget {
  const ArticlesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: fetchArticles(),
      builder: (context, snapshot) {
        final articles = snapshot.data;
        if (articles == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (articles.isEmpty) return const Center(child: Text('No articles yet'));
        return ListView.builder(
          itemCount: articles.length,
          itemBuilder: (context, i) => ListTile(title: Text(articles[i])),
        );
      },
    );
  }
}
