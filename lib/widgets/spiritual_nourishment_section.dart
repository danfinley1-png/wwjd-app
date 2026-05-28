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
The Holy Mass is the source and summit of the entire Christian life (CCC 1324). It is the highest form of prayer and worship we can offer to God.

In every Mass, the one eternal sacrifice of Jesus Christ on Calvary is made present for us today. We are truly united with His Passion, Death, and Resurrection. We receive Our Lord Jesus Christ — Body, Blood, Soul, and Divinity — in the Holy Eucharist, the greatest gift God has given us.

**Why attending Mass is so important:**
- We give perfect worship to the Father through the Son in the Holy Spirit.
- We are nourished by God’s Word and strengthened by the Eucharist.
- We are united with the entire Church — on earth, in Purgatory, and in Heaven.
- We receive the grace needed to live as faithful disciples and to build the Kingdom of God in our families, workplaces, and communities.

**Practical encouragement:**
Make Sunday Mass the non-negotiable center of your week. When possible, attend daily Mass or at least one additional Mass during the week. Prepare your heart beforehand by reading the daily readings. Bring your joys, struggles, worries, and gratitude to the altar. Offer them to Jesus.

The more faithfully we participate in the Mass, the more we are transformed into the likeness of Christ and empowered to love God and neighbor as we are called to do.

**Important Note:** Catholics who are in a state of grace (having recently gone to Confession if needed) can receive Holy Communion at Mass.
''',
    },
    'confession': {
      'title': 'Go to Confession',
      'subtitle': 'The Sacrament of God’s Infinite Mercy',
      'body': '''
In the Sacrament of Reconciliation, we encounter the merciful Christ who says to each of us, “Your sins are forgiven. Go in peace.”

Regular Confession brings profound healing, peace of soul, clarity of conscience, and fresh grace to resist sin. It is one of the greatest gifts Jesus left His Church.

Do not be afraid. The priest stands in the person of Christ, ready to offer you complete forgiveness and a new beginning.
''',
    },
    'adoration': {
      'title': 'Eucharistic Adoration',
      'subtitle': 'Sitting at the Feet of Jesus',
      'body': '''
Eucharistic Adoration is one of the most beautiful and powerful practices in Catholic life. Here, Jesus Christ is truly, really, and substantially present — Body, Blood, Soul, and Divinity — in the Blessed Sacrament.

**How to best experience Adoration:**
- Come as you are. Bring your joys, struggles, dryness, or gratitude.
- Spend time in silent listening, reading Scripture, or praying the Rosary.
- Many find it helpful to journal thoughts or simply rest in His presence (“Jesus, I trust in You”).
- Even 15–30 minutes a week can bring profound peace, clarity, and deeper love for the Lord.

Many saints, including St. Thérèse of Lisieux, St. John Paul II, and St. Teresa of Calcutta, spent long hours before the Blessed Sacrament and credited it as the source of their strength and mission.
''',
    },
    'examination': {
      'title': 'Examination of Conscience',
      'subtitle': 'Daily Review in the Light of God’s Love',
      'body': '''
A nightly Examination of Conscience is a treasured spiritual practice recommended by the saints and the Church. It is not about scrupulous self-criticism, but about gently reviewing our day in the loving presence of God.

A simple structured approach:
1. **Thanksgiving** – Thank God for the gifts and graces of the day.
2. **Prayer for Light** – Ask the Holy Spirit to help you see clearly.
3. **Review** – Consider your thoughts, words, actions, and omissions. How did I love God? How did I love my neighbor?
4. **Sorrow and Resolution** – Express sorrow for failings and make a concrete resolution for tomorrow.
5. **Prayer** – End with an Act of Contrition and trust in God’s mercy.

This daily habit builds self-awareness, fosters gratitude, and opens our hearts to continual conversion. Over time, it becomes a powerful tool for growth in virtue and intimacy with the Lord.
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