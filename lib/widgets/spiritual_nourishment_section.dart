import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class SpiritualNourishmentSection extends StatefulWidget {
  final String? initialTopic;

  const SpiritualNourishmentSection({
    super.key,
    this.initialTopic,
  });

  @override
  State<SpiritualNourishmentSection> createState() => _SpiritualNourishmentSectionState();
}

class _SpiritualNourishmentSectionState extends State<SpiritualNourishmentSection> {
  late String _selectedTopic;

  final Map<String, Map<String, String>> _content = {
    'mass': {
      'title': 'Attend Mass',
      'subtitle': 'The Source and Summit of Catholic Life',
      'body': '''
The Eucharist is the source and summit of the Christian life (CCC 1324).

In the Holy Mass, we participate in the one eternal sacrifice of Jesus Christ on Calvary, made present for us today. We receive Our Lord truly, really, and substantially — Body, Blood, Soul, and Divinity.

Jesus Himself said, “I am the living bread that came down from heaven... whoever eats this bread will live forever” (John 6:51).

Making the Mass the center of our week transforms us into the likeness of Christ.
''',
    },
    'confession': {
      'title': 'Go to Confession',
      'subtitle': 'The Sacrament of God’s Mercy',
      'body': '''
The Sacrament of Reconciliation is one of the greatest gifts Christ gave His Church.

Here we meet the merciful Jesus who says “Your sins are forgiven.”

Regular Confession brings healing, peace, clarity, and increased grace.
''',
    },
    'adoration': {
      'title': 'Eucharistic Adoration',
      'subtitle': 'Sitting at the Feet of Jesus',
      'body': '''
In Eucharistic Adoration, we adore Jesus Christ truly present in the Blessed Sacrament.

Even 15–30 minutes a week can bring profound peace and deeper intimacy with the Lord.
''',
    },
    'examination': {
      'title': 'Examination of Conscience',
      'subtitle': 'Daily Review in God’s Light',
      'body': '''
A nightly Examination of Conscience is a powerful spiritual practice recommended by the saints.

It helps us become more aware of God’s presence and grow in virtue.
''',
    },
  };

  @override
  void initState() {
    super.initState();
    _selectedTopic = widget.initialTopic ?? 'mass';
  }

  @override
  void didUpdateWidget(covariant SpiritualNourishmentSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTopic != oldWidget.initialTopic && widget.initialTopic != null) {
      setState(() {
        _selectedTopic = widget.initialTopic!;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final topic = _content[_selectedTopic]!;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Spiritual Nourishment',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primaryMaroon),
          ),
          const SizedBox(height: 24),

          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(topic['title']!, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                  Text(topic['subtitle']!, style: TextStyle(fontSize: 17, color: AppColors.primaryMaroon)),
                  const SizedBox(height: 24),
                  SelectableText(
                    topic['body']!,
                    style: const TextStyle(fontSize: 16.5, height: 1.7),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}